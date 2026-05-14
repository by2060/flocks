#!/usr/bin/env bash
#
# sync-upstream.sh
#
# 将 GitHub 上游 (by2060/flocks) 的最新更新，合并到 yf3/ais 仓库的 flocks-0509/
# 子目录中，并自动清理本地已排除的文件 / 文件夹，最后可选择性推送到 GitLab。
#
# ------------------------------------------------------------------------------
# 典型用法：
#   ./scripts/sync-upstream.sh                    # 完整同步（默认 squash、不推送）
#   ./scripts/sync-upstream.sh --push             # 同步完成后推送到 origin
#   DRY_RUN=1 ./scripts/sync-upstream.sh          # 演练模式（只 fetch 不合并）
#   NO_SQUASH=1 ./scripts/sync-upstream.sh        # 不压缩上游历史（3-way merge 更精确）
#   PREFIX=flocks-0510 ./scripts/sync-upstream.sh # 同步到其他子目录
#
# 可用环境变量：
#   PREFIX           subtree 子目录，默认 flocks-0509
#   UPSTREAM_NAME    上游 remote 名，默认 flocks-upstream
#   UPSTREAM_URL     上游仓库 URL，默认 GitHub by2060/flocks
#   UPSTREAM_BRANCH  上游分支，默认 main
#   ORIGIN           推送目标 remote，默认 origin（GitLab）
#   LOCAL_BRANCH     要推送的本地分支，默认 main
#   EXCLUDES_FILE    排除清单文件，默认 ${PREFIX}/.local-excludes
#   NO_SQUASH        设为 1 时不使用 --squash（更精确但历史变长）
#   DRY_RUN          设为 1 时只 fetch 和打印差异，不合并不推送
#   OPEN_GUI         冲突时是否开 GUI（auto/none/vscode/pycharm/mergetool）
#
# 标志：
#   --push           同步成功后自动推送到 ${ORIGIN}/${LOCAL_BRANCH}
#   --no-gui         冲突时不自动打开 GUI
#   --gui=vscode     冲突时强制用 VS Code
#   --gui=pycharm    冲突时强制用 PyCharm / IntelliJ
#   --gui=mergetool  冲突时调用 git mergetool（预配置的图形工具）
# ------------------------------------------------------------------------------

set -euo pipefail

# --- 参数解析 -----------------------------------------------------------------
DO_PUSH=0
OPEN_GUI="${OPEN_GUI:-auto}"
for arg in "$@"; do
    case "$arg" in
        --push)           DO_PUSH=1 ;;
        --no-gui)         OPEN_GUI="none" ;;
        --gui=vscode)     OPEN_GUI="vscode" ;;
        --gui=pycharm)    OPEN_GUI="pycharm" ;;
        --gui=mergetool)  OPEN_GUI="mergetool" ;;
        -h|--help)
            sed -n '2,40p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "[err ] 未知参数: $arg" >&2
            echo "       使用 --help 查看用法" >&2
            exit 1
            ;;
    esac
done

# --- 配置 --------------------------------------------------------------------
PREFIX="${PREFIX:-flocks-0509}"
UPSTREAM_NAME="${UPSTREAM_NAME:-flocks-upstream}"
UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/by2060/flocks.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
ORIGIN="${ORIGIN:-origin}"
LOCAL_BRANCH="${LOCAL_BRANCH:-main}"
EXCLUDES_FILE="${EXCLUDES_FILE:-${PREFIX}/.local-excludes}"
NO_SQUASH="${NO_SQUASH:-0}"
DRY_RUN="${DRY_RUN:-0}"

# --- 颜色日志 -----------------------------------------------------------------
log()     { printf "\033[1;34m[sync]\033[0m %s\n" "$*"; }
success() { printf "\033[1;32m[ ok ]\033[0m %s\n" "$*"; }
warn()    { printf "\033[1;33m[warn]\033[0m %s\n" "$*"; }
err()     { printf "\033[1;31m[err ]\033[0m %s\n" "$*" >&2; }

# --- 预检查 -------------------------------------------------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    err "当前目录不是 git 仓库"
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

if ! git diff --quiet || ! git diff --cached --quiet; then
    err "工作区有未提交的改动，请先 commit 或 stash 后重试"
    git status --short
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$LOCAL_BRANCH" ]; then
    err "当前分支是 $CURRENT_BRANCH，期望在 $LOCAL_BRANCH 上操作"
    err "请执行：git checkout $LOCAL_BRANCH"
    exit 1
fi

if ! git remote get-url "$ORIGIN" >/dev/null 2>&1; then
    err "找不到 remote '$ORIGIN'（应指向你的 GitLab 仓库）"
    exit 1
fi

if ! git remote get-url "$UPSTREAM_NAME" >/dev/null 2>&1; then
    log "首次使用，添加上游 remote: $UPSTREAM_NAME -> $UPSTREAM_URL"
    git remote add "$UPSTREAM_NAME" "$UPSTREAM_URL"
    git remote set-url --push "$UPSTREAM_NAME" DISABLE
fi

if [ ! -d "$PREFIX" ]; then
    err "子目录 '$PREFIX' 不存在。"
    err "首次添加请执行："
    err "  git subtree add --prefix=$PREFIX $UPSTREAM_NAME $UPSTREAM_BRANCH --squash"
    exit 1
fi

# --- Step 1: 拉取上游 ---------------------------------------------------------
log "Fetching 上游 $UPSTREAM_NAME ..."
git fetch "$UPSTREAM_NAME" --prune

log "上游 $UPSTREAM_NAME/$UPSTREAM_BRANCH 最近 5 个 commit："
git --no-pager log --oneline -5 "$UPSTREAM_NAME/$UPSTREAM_BRANCH" | sed 's/^/       /'

if [ "$DRY_RUN" = "1" ]; then
    warn "DRY_RUN=1，跳过合并与推送"
    exit 0
fi

# --- Step 2: subtree pull -----------------------------------------------------
SQUASH_FLAG="--squash"
[ "$NO_SQUASH" = "1" ] && SQUASH_FLAG=""

log "执行 git subtree pull --prefix=$PREFIX $UPSTREAM_NAME $UPSTREAM_BRANCH $SQUASH_FLAG ..."

set +e
git subtree pull --prefix="$PREFIX" "$UPSTREAM_NAME" "$UPSTREAM_BRANCH" $SQUASH_FLAG \
    -m "sync: merge upstream $UPSTREAM_NAME/$UPSTREAM_BRANCH into $PREFIX"
PULL_EXIT=$?
set -e

if [ $PULL_EXIT -ne 0 ]; then
    if git ls-files --unmerged | grep -q .; then
        err "subtree pull 出现冲突，请手动解决后重新运行脚本。"
        err "冲突文件："
        git --no-pager diff --name-only --diff-filter=U | sed 's/^/         /' >&2
        err ""
        err "解决步骤："
        err "  1. 编辑冲突文件（找到 <<<<<<< ======= >>>>>>> 标记）"
        err "  2. git add <已解决的文件>"
        err "  3. git commit                       （完成合并提交）"
        err "  4. 再次运行本脚本以执行排除清理和推送"
        err ""

        open_gui_for_conflicts() {
            local mode="$1"
            case "$mode" in
                none)
                    return ;;
                vscode)
                    if command -v code >/dev/null 2>&1; then
                        log "正在用 VS Code 打开仓库（Source Control 面板会显示冲突）..."
                        code "$REPO_ROOT" 2>/dev/null &
                        local first_conflict
                        first_conflict="$(git --no-pager diff --name-only --diff-filter=U | head -1)"
                        if [ -n "$first_conflict" ]; then
                            code --goto "$REPO_ROOT/$first_conflict" 2>/dev/null &
                        fi
                    else
                        warn "未找到 'code' 命令，跳过 VS Code 打开"
                        warn "安装方法：在 VS Code 里 Cmd+Shift+P → 输入 'Shell Command: Install code command in PATH'"
                    fi
                    ;;
                pycharm)
                    if command -v pycharm >/dev/null 2>&1; then
                        log "正在用 PyCharm 打开仓库..."
                        pycharm "$REPO_ROOT" 2>/dev/null &
                    elif [ -d "/Applications/PyCharm.app" ]; then
                        log "正在用 PyCharm 打开仓库..."
                        open -a "PyCharm" "$REPO_ROOT" 2>/dev/null &
                    elif [ -d "/Applications/PyCharm CE.app" ]; then
                        log "正在用 PyCharm CE 打开仓库..."
                        open -a "PyCharm CE" "$REPO_ROOT" 2>/dev/null &
                    else
                        warn "未找到 PyCharm。请手动打开项目并在 VCS 菜单解决冲突"
                    fi
                    ;;
                mergetool)
                    log "调起 git mergetool（按预配置的图形工具打开冲突）..."
                    log "提示：如果没反应，先执行 ./scripts/setup-mergetool.sh 配置工具"
                    git mergetool || warn "mergetool 退出（可能未配置或被取消）"
                    ;;
                auto)
                    if command -v code >/dev/null 2>&1; then
                        open_gui_for_conflicts vscode
                    elif [ -d "/Applications/PyCharm.app" ] || [ -d "/Applications/PyCharm CE.app" ]; then
                        open_gui_for_conflicts pycharm
                    else
                        warn "未检测到 VS Code 或 PyCharm。如需 GUI 解决冲突："
                        warn "  - 安装 VS Code 并配置 'code' 命令到 PATH"
                        warn "  - 或使用 --gui=mergetool（需要先配置 git mergetool）"
                    fi
                    ;;
            esac
        }

        open_gui_for_conflicts "$OPEN_GUI"
        exit 2
    else
        err "subtree pull 失败（非冲突原因），退出码 $PULL_EXIT"
        exit $PULL_EXIT
    fi
fi

success "上游合并完成"

# --- Step 3: 应用本地排除清单 -------------------------------------------------
if [ -f "$EXCLUDES_FILE" ]; then
    log "读取排除清单：$EXCLUDES_FILE"
    REMOVED_COUNT=0

    while IFS= read -r line || [ -n "$line" ]; do
        pattern="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$pattern" ] && continue
        case "$pattern" in \#*) continue ;; esac

        target="$PREFIX/$pattern"
        target="${target%/}"

        if [ -e "$target" ] || git ls-files --error-unmatch "$target" >/dev/null 2>&1; then
            log "  删除: $target"
            git rm -rf --ignore-unmatch "$target" >/dev/null
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
        fi
    done < "$EXCLUDES_FILE"

    if [ "$REMOVED_COUNT" -gt 0 ]; then
        if ! git diff --cached --quiet; then
            log "提交排除清单清理（共 $REMOVED_COUNT 项）"
            git commit -m "sync: apply local excludes after upstream merge"
            success "已清理并提交"
        fi
    else
        log "排除清单匹配 0 项（可能都已不存在）"
    fi
else
    warn "未找到排除清单：$EXCLUDES_FILE （跳过清理步骤）"
    warn "如需维护排除清单，创建该文件并写入需要删除的路径（每行一个）"
fi

# --- Step 4: 推送 -------------------------------------------------------------
if [ "$DO_PUSH" = "1" ]; then
    log "推送到 $ORIGIN/$LOCAL_BRANCH ..."
    git push "$ORIGIN" "$LOCAL_BRANCH"
    success "已推送到 $ORIGIN/$LOCAL_BRANCH"
else
    log "同步完成（未推送）。如需推送，执行："
    log "  git push $ORIGIN $LOCAL_BRANCH"
fi

success "全部完成"
