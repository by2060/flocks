#!/usr/bin/env bash
#
# setup-mergetool.sh
#
# 一键配置 git mergetool，支持多种图形化工具（全局 ~/.gitconfig）
#
# 用法：
#   ./scripts/setup-mergetool.sh              # 交互式选择
#   ./scripts/setup-mergetool.sh vscode       # VS Code
#   ./scripts/setup-mergetool.sh pycharm      # PyCharm
#   ./scripts/setup-mergetool.sh meld         # Meld（免费）
#   ./scripts/setup-mergetool.sh beyondcompare  # Beyond Compare
#   ./scripts/setup-mergetool.sh kaleidoscope # Kaleidoscope（Mac）
#   ./scripts/setup-mergetool.sh vimdiff      # vimdiff
#
set -euo pipefail

TOOL="${1:-}"

log()     { printf "\033[1;34m[setup]\033[0m %s\n" "$*"; }
success() { printf "\033[1;32m[  ok ]\033[0m %s\n" "$*"; }
warn()    { printf "\033[1;33m[warn ]\033[0m %s\n" "$*"; }
err()     { printf "\033[1;31m[err  ]\033[0m %s\n" "$*" >&2; }

if [ -z "$TOOL" ]; then
    echo ""
    echo "请选择要配置的图形化合并工具："
    echo "  1) VS Code       (推荐，免费，跨平台)"
    echo "  2) PyCharm       (Python 项目推荐)"
    echo "  3) Meld          (免费，跨平台)"
    echo "  4) Beyond Compare (付费)"
    echo "  5) Kaleidoscope  (Mac 专属，付费)"
    echo "  6) vimdiff       (终端，无 GUI 依赖)"
    echo ""
    read -rp "选择 [1-6]（默认 1）: " choice
    case "${choice:-1}" in
        1) TOOL="vscode" ;;
        2) TOOL="pycharm" ;;
        3) TOOL="meld" ;;
        4) TOOL="beyondcompare" ;;
        5) TOOL="kaleidoscope" ;;
        6) TOOL="vimdiff" ;;
        *) err "无效选择"; exit 1 ;;
    esac
fi

log "配置 git mergetool = $TOOL"

case "$TOOL" in
    vscode)
        if ! command -v code >/dev/null 2>&1; then
            err "未找到 'code' 命令。"
            err "请在 VS Code 里：Cmd+Shift+P → 输入 'Shell Command: Install code command in PATH'"
            exit 1
        fi
        git config --global merge.tool vscode
        git config --global mergetool.vscode.cmd 'code --wait --merge $REMOTE $LOCAL $BASE $MERGED'
        git config --global mergetool.vscode.trustExitCode false
        git config --global diff.tool vscode
        git config --global difftool.vscode.cmd 'code --wait --diff $LOCAL $REMOTE'
        ;;

    pycharm)
        PYCHARM_CMD=""
        if command -v pycharm >/dev/null 2>&1; then
            PYCHARM_CMD="pycharm"
        elif command -v charm >/dev/null 2>&1; then
            PYCHARM_CMD="charm"
        elif [ -d "/Applications/PyCharm.app" ]; then
            PYCHARM_CMD="/Applications/PyCharm.app/Contents/MacOS/pycharm"
        elif [ -d "/Applications/PyCharm CE.app" ]; then
            PYCHARM_CMD="/Applications/PyCharm CE.app/Contents/MacOS/pycharm"
        else
            err "未找到 PyCharm 命令。请在 PyCharm 里：Tools → Create Command-line Launcher"
            exit 1
        fi
        git config --global merge.tool pycharm
        git config --global mergetool.pycharm.cmd "$PYCHARM_CMD merge \$LOCAL \$REMOTE \$BASE \$MERGED"
        git config --global mergetool.pycharm.trustExitCode true
        git config --global diff.tool pycharm
        git config --global difftool.pycharm.cmd "$PYCHARM_CMD diff \$LOCAL \$REMOTE"
        ;;

    meld)
        if ! command -v meld >/dev/null 2>&1; then
            err "未找到 meld 命令。安装方法："
            err "  Mac:    brew install --cask meld"
            err "  Linux:  sudo apt install meld / sudo dnf install meld"
            exit 1
        fi
        git config --global merge.tool meld
        git config --global mergetool.meld.cmd 'meld --auto-merge $LOCAL $BASE $REMOTE --output=$MERGED'
        git config --global diff.tool meld
        ;;

    beyondcompare)
        if ! command -v bcomp >/dev/null 2>&1; then
            warn "未找到 bcomp 命令。从 Beyond Compare 菜单：Install Command Line Tools"
            exit 1
        fi
        git config --global merge.tool bcomp
        git config --global mergetool.bcomp.cmd 'bcomp "$LOCAL" "$REMOTE" "$BASE" "$MERGED"'
        git config --global mergetool.bcomp.trustExitCode true
        git config --global diff.tool bcomp
        git config --global difftool.bcomp.cmd 'bcomp "$LOCAL" "$REMOTE"'
        ;;

    kaleidoscope)
        if ! command -v ksdiff >/dev/null 2>&1; then
            err "未找到 ksdiff 命令。在 Kaleidoscope 里：Integration → Install ksdiff"
            exit 1
        fi
        git config --global merge.tool Kaleidoscope
        git config --global mergetool.Kaleidoscope.cmd 'ksdiff --merge --output "$MERGED" --base "$BASE" -- "$LOCAL" --snapshot "$REMOTE" --snapshot'
        git config --global mergetool.Kaleidoscope.trustExitCode true
        git config --global diff.tool Kaleidoscope
        git config --global difftool.Kaleidoscope.cmd 'ksdiff --partial-changeset --relative-path "$MERGED" -- "$LOCAL" "$REMOTE"'
        ;;

    vimdiff)
        git config --global merge.tool vimdiff
        git config --global merge.conflictstyle diff3
        ;;

    *)
        err "未知工具: $TOOL"
        exit 1
        ;;
esac

git config --global mergetool.keepBackup false
git config --global mergetool.prompt false

success "配置完成！"
echo ""
log "验证配置："
git config --global --get-regexp '^(merge|mergetool|diff|difftool)\.' | sed 's/^/       /'
echo ""
log "使用方法："
echo "       当遇到冲突时，执行："
echo "       \$ git mergetool          # 按配置的工具打开所有冲突"
echo "       \$ git mergetool <file>   # 只处理指定文件"
echo "       \$ git difftool HEAD~1    # 图形化查看 diff"
