# Upstream Sync 工作流说明

本目录提供从 GitHub 社区上游（`by2060/flocks`）同步代码到 GitLab 私有仓库（`yf3/ais`）的自动化脚本。

---

## 背景

本仓库 `yf3/ais` 的 `flocks-0509/` 子目录是 GitHub 社区版 flocks 的定制版本。我们通过 `git subtree` 机制维护这层关系：

```
GitHub by2060/flocks (上游社区，只读)
        |
        | subtree pull（同步上游更新）
        v
本地工作区 ais/flocks-0509/
        |
        | push
        v
GitLab yf3/ais (团队仓库)
```

---

## 初始化（一次性）

### 1. 添加上游 remote
```bash
git remote add flocks-upstream https://github.com/by2060/flocks.git
git remote set-url --push flocks-upstream DISABLE
git fetch flocks-upstream
```

### 2. 选择基准 commit 做 subtree add
```bash
rm -rf flocks-0509
git subtree add --prefix=flocks-0509 <基准-commit-完整-hash>
```

### 3. 把本地定制覆盖进去
```bash
rsync -av /path/to/your/backup/ flocks-0509/
git add flocks-0509/
git commit -m "feat: apply local customizations on top of upstream"
git push origin main
```

---

## 日常同步

### 预览上游更新
```bash
DRY_RUN=1 ./scripts/sync-upstream.sh
```

### 同步（默认不推送）
```bash
./scripts/sync-upstream.sh
```

### 同步并推送到 GitLab
```bash
./scripts/sync-upstream.sh --push
```

### 不压缩历史（更精确的 3-way merge）
```bash
NO_SQUASH=1 ./scripts/sync-upstream.sh --push
```

### 遇到冲突
脚本会停下来，自动打开 VS Code（或 PyCharm）。解决冲突后：
```bash
git add <冲突文件>
git commit
./scripts/sync-upstream.sh --push   # 再次运行继续后续步骤
```

---

## 排除清单

`flocks-0509/.local-excludes` 列出本地不想要的文件 / 文件夹。每次 `subtree pull` 后自动删除。

格式：
- 每行一个路径，相对于 `flocks-0509/`
- `#` 注释，空行忽略

示例：
```bash
docs/
packaging/windows/
webui/public/channel-weixin.png
flocks/browser/
```

---

## 命令行选项

| 选项 | 作用 |
|------|------|
| `--push` | 同步完成后推送到 GitLab |
| `--no-gui` | 冲突时不打开 GUI |
| `--gui=vscode` | 强制用 VS Code |
| `--gui=pycharm` | 强制用 PyCharm |
| `--gui=mergetool` | 用 git mergetool（需先配置） |
| `--help` | 显示帮助 |

| 环境变量 | 默认值 | 说明 |
|----------|--------|------|
| `PREFIX` | `flocks-0509` | subtree 子目录 |
| `UPSTREAM_NAME` | `flocks-upstream` | 上游 remote 名 |
| `UPSTREAM_BRANCH` | `main` | 上游分支 |
| `ORIGIN` | `origin` | GitLab remote |
| `LOCAL_BRANCH` | `main` | 本地分支 |
| `NO_SQUASH` | `0` | 不压缩历史 |
| `DRY_RUN` | `0` | 演练模式 |

---

## 图形化冲突解决

### VS Code（推荐）
项目已配置 `.vscode/settings.json`，启用了 3-way merge editor。
- 冲突时脚本自动打开 VS Code
- 每个冲突块上有 `Accept Current / Incoming / Both` 按钮
- 点击 "Resolve in Merge Editor" 进入三方视图

### PyCharm
```bash
./scripts/sync-upstream.sh --gui=pycharm
```

### 配置外部工具（Meld / Beyond Compare 等）
```bash
./scripts/setup-mergetool.sh meld          # 一次性配置
./scripts/sync-upstream.sh --gui=mergetool # 使用
```

### GitLab 原生界面？
**不支持** subtree 跨仓库合并。GitLab 的 "Resolve conflicts" 按钮只对 MR 内的分支冲突有效。

---

## 常见问题

### Q1：subtree pull 后改动消失？
`--squash` 模式合并基准不完美。要更精确就用 `NO_SQUASH=1`。

### Q2：排除的文件每次还会回来？
会先合入再被删除，历史里有两个 commit。GitLab 最终状态干净。

### Q3：冲突解决后怎么继续？
`git add` → `git commit` → 再次运行 `./scripts/sync-upstream.sh`。

### Q4：能否反向同步？
不行。上游是社区仓库，没权限。可通过 GitHub PR 贡献。

---

## 故障排查

### `.DS_Store` 干扰
```bash
echo ".DS_Store" >> ~/.gitignore_global
git config --global core.excludesfile ~/.gitignore_global
```

### 工作区不干净
```bash
git stash
# 或
git checkout -- <file>
```

### prefix 已存在
```bash
rm -rf <目录>
git rm -rf <目录>
git commit -m "chore: remove before re-adding"
```
