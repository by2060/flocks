# 去 Flocks 化改造 — 残留检测脚本 + CI 升级 设计文档

> **文档版本**: v1.0
> **日期**: 2026-05-14
> **状态**: 待评审
> **作用**: 在品牌改名 / 中文化 / 插件删减的每个阶段,提供自动化手段检测遗漏和回归,保障改造后框架稳定可工作。

---

## 一、背景与问题

### 1.1 当前 CI 覆盖严重不足

| 现状 | 影响 |
|------|------|
| `ci.yml` 仅跑 `tests/scripts` + `tests/hub`(约 30 个文件) | 282 个 Python 测试文件中 90% 未进入 CI |
| `Makefile` 引用 `scripts/run-tests.py` 但该文件 **不存在** | `make test` 直接报错,形同虚设 |
| WebUI CI 只跑 lint + build,未跑 `vitest run` | 35 个前端测试文件零 CI 覆盖 |
| 无"品牌残留"专项检查 | 改名后漏网之鱼无法被自动发现 |
| 无 Python type check (mypy) | 改名引入的类型错误无法提前捕获 |

### 1.2 改造带来的三类风险

| 风险类型 | 具体表现 |
|----------|----------|
| **残留风险** | 用户可见位置仍出现 "Flocks" / "Rex" 旧品牌名 |
| **断链风险** | 删除插件后,注册表 / prompt / 测试引用了不存在的 agent / skill / tool |
| **回归风险** | 改名导致 import 断裂、agent 加载失败、config 解析异常 |

### 1.3 设计目标

1. **每个改造阶段提交前,CI 能在 5 分钟内自动判定是否可合并**
2. **品牌残留零容忍**(白名单机制管理已知例外)
3. **断链检测覆盖 agent / skill / tool / workflow / task 五类注册表**
4. **不依赖外部 API Key 即可完成核心验证**(集成测试另行安排)
5. **棘轮(ratchet)效应**:违规数只能减少不能增加,渐进式收紧

---

## 二、整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Job 1: python-quality                                      │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Step 1: ruff check (全量 lint)                        │  │
│  │ Step 2: mypy --ignore-missing-imports (允许失败)      │  │
│  │ Step 3: python scripts/check_rebrand.py  (残留检测)   │  │
│  │ Step 4: python scripts/check_registry.py (断链检测)   │  │
│  │ Step 5: python scripts/validate_flockshub.py (Hub)    │  │
│  │ Step 6: pytest tests/ -m "not integration and not     │  │
│  │         live" --tb=short (单元测试,~95% 覆盖)         │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Job 2: frontend-quality                                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Step 1: npm run lint                                  │  │
│  │ Step 2: npm run build                                 │  │
│  │ Step 3: npm run test:run (vitest 单次执行)            │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
│  Job 3: smoke-test (依赖 Job 1 + Job 2)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │ Step 1: CLI --help 验证                               │  │
│  │ Step 2: Agent registry 加载验证                       │  │
│  │ Step 3: Tool registry schema 序列化验证               │  │
│  │ Step 4: Config 加载验证                               │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**关键设计原则**

- 所有新增脚本只用标准库 + 项目已有 dev 依赖,**不引入新的第三方包**
- 三个 Job 在 CI 上并行,Job 3 只 `needs: [python-quality, frontend-quality]`
- 总耗时目标 ≤ 5 分钟
- 任何 Job 失败 → PR 不可合并

---

## 三、新增 / 修改文件清单

| 文件路径 | 类型 | 作用 | 行数预估 |
|----------|------|------|----------|
| `scripts/check_rebrand.py` | **新增** | 品牌残留检测脚本(核心交付物) | ~250 行 |
| `scripts/check_registry.py` | **新增** | 注册表断链检测脚本 | ~180 行 |
| `scripts/run_tests.py` | **新增** | 统一测试入口(修复 Makefile 引用) | ~80 行 |
| `scripts/smoke_test.py` | **新增** | 无 LLM 冒烟测试(CLI + registry 加载) | ~120 行 |
| `scripts/rebrand_whitelist.yaml` | **新增** | 残留检测白名单配置 | ~80 行 |
| `.rebrand-baseline.json` | **新增** | 残留违规基线(自动生成,提交入库) | ~30 行 |
| `.github/workflows/ci.yml` | **修改** | CI 全面升级 | 约 60 行改动 |
| `Makefile` | **修改** | 修复 test target + 新增 check / smoke / ci-local target | 约 25 行改动 |



---

## 四、核心脚本详细设计

### 4.1 `scripts/check_rebrand.py` — 品牌残留检测【**最核心**】

#### 4.1.1 职责

扫描全仓源码,检测用户可见位置是否仍存在旧品牌名(`flocks` / `Flocks` / `FLOCKS` / `rex` / `Rex` / `REX`),
基于白名单机制过滤合法用法,输出清晰的违规报告,非零退出码阻止 CI 合并。

#### 4.1.2 检测规则分类

| 规则 ID | 检测目标 | 严重级别 | 典型命中位置 |
|---------|----------|----------|------|
| **R-BRAND-01** | 文档/界面字符串中的 "Flocks" / "flocks" | ERROR | `README.md` / `prompt.md` / `SKILL.md` / `i18n` JSON / HTML title |
| **R-BRAND-02** | 文档/界面字符串中的 "Rex" / "rex" | ERROR | agent 描述、prompt 中对用户展示的名称 |
| **R-BRAND-03** | 环境变量名 `FLOCKS_*` | ERROR | 只允许在 `flocks/utils/env.py` 兼容层中出现 |
| **R-BRAND-04** | 目录名 / 文件名包含 `flocks` 或 `rex` | ERROR | 如 `.flocks/`、`flocks.json`、`flocks_mcp.py`、`agents/rex/` |
| **R-BRAND-05** | Docker 镜像名 / GitHub URL 中的旧名 | WARN | workflow YAML、Dockerfile、安装脚本 URL |
| **R-BRAND-06** | ASCII Art / Logo 中的旧品牌 | ERROR | CLI banner、README badge |
| **R-BRAND-07** | CLI 命令字符串 `flocks <subcommand>` | ERROR | shell 脚本、文档示例 |

#### 4.1.3 白名单机制 — `scripts/rebrand_whitelist.yaml`

每条记录指定一个允许出现旧品牌名的"模式 + 范围 + 原因",`reason` 字段必填:

```yaml
# scripts/rebrand_whitelist.yaml
schemaVersion: rebrand.whitelist.v1

# rules: 每条 rule 描述一种合法残留场景
# pattern: 命中行的正则
# scope:   glob 模式,限定文件路径
# rule_id: 可选,限定只对哪条 R-BRAND-XX 规则生效;省略则对全部生效
# reason:  必填,审计用

rules:
  # —— Python 包名永久白名单 ——
  - pattern: '^\s*(from|import)\s+flocks(\.|$|\s)'
    scope: "**/*.py"
    rule_id: R-BRAND-01
    reason: "Python 包名保持不变,所有 import path 中的 flocks 合法"

  # —— Agent 别名兼容表 ——
  - pattern: '"rex"|"rex-junior"'
    scope: "flocks/agent/registry.py"
    rule_id: R-BRAND-02
    reason: "AGENT_ALIASES 旧名兼容映射,需保留至少一个版本周期"

  # —— 环境变量兼容层 ——
  - pattern: 'FLOCKS_[A-Z_]+'
    scope: "flocks/utils/env.py"
    rule_id: R-BRAND-03
    reason: "旧环境变量 fallback 读取逻辑,改造期间必须保留"

  # —— 路径迁移工具 ——
  - pattern: 'flocks|FLOCKS'
    scope: "scripts/migrate_*.py"
    reason: "迁移脚本需引用旧路径"

  # —— 历史变更记录 ——
  - pattern: 'flocks|rex'
    scope: "CHANGELOG.md"
    reason: "历史版本记录不修改"

  # —— Git 忽略规则(指向 .flocks/) ——
  - pattern: '\.flocks'
    scope: ".gitignore"
    reason: "兼容期间忽略规则需引用旧目录"

  # —— 本设计文档 ——
  - pattern: 'flocks|rex|Rex|Flocks'
    scope: "docs/rebrand-*.md"
    reason: "改造设计文档中讨论旧名属合法用法"

# baseline_file: 棘轮模式读取的基线文件
baseline_file: ".rebrand-baseline.json"
```

#### 4.1.4 扫描范围与排除

```python
# 扫描的文件扩展名
SCAN_EXTENSIONS = {
    ".py", ".yaml", ".yml", ".json", ".md", ".ts", ".tsx",
    ".js", ".jsx", ".html", ".css", ".toml", ".sh", ".ps1",
    ".txt", ".cfg", ".ini",
}

# 永远排除的目录
EXCLUDE_DIRS = {
    ".git", "node_modules", ".venv", "venv", "__pycache__",
    "dist", "build", ".mypy_cache", ".ruff_cache", ".pytest_cache",
    "htmlcov", ".coverage", "*.egg-info",
}

# 永远排除的文件(锁文件 / 二进制)
EXCLUDE_FILES = {
    "package-lock.json", "uv.lock", "poetry.lock", "yarn.lock",
    "*.whl", "*.tar.gz", "*.zip", "*.png", "*.jpg", "*.webp", "*.ico",
    ".rebrand-baseline.json",  # 自身不检
}
```

#### 4.1.5 输出格式示例

```
$ python scripts/check_rebrand.py

[check_rebrand] Scanning 1247 files...

ERROR R-BRAND-01 flocks/cli/main.py:45               'Welcome to Flocks!'
ERROR R-BRAND-02 flocks/agent/agents/self_enhance/prompt.md:3
                                                     'when Rex or another agent'
ERROR R-BRAND-03 flocks/server/app.py:12             FLOCKS_WEBUI_HOST (not in compat layer)
ERROR R-BRAND-04 flocks/agent/agents/rex/agent.yaml  directory name contains 'rex'
WARN  R-BRAND-05 .github/workflows/docker-publish.yml:28
                                                     'ghcr.io/agentflocks/flocks'

──────────────────────────────────────────────
  4 ERROR(s), 1 WARN(s)  /  1247 files scanned
  Baseline: 1523 ERROR / 45 WARN
  Delta:    -1519 ERROR / -44 WARN  ✓ ratchet ok
  EXIT: 1 (still above zero, fail)
──────────────────────────────────────────────
```

#### 4.1.6 退出码定义

| 退出码 | 含义 |
|--------|------|
| `0` | 当前违规数 ≤ baseline,且 ERROR 总数为 0(终态) |
| `1` | 存在 ERROR 且超过 baseline → 阻止合并 |
| `2` | 脚本自身异常(白名单文件损坏等) |

**特殊**:`--baseline` 模式只生成 baseline 文件,**永远返回 0**,用于初始化或重置基线。

#### 4.1.7 棘轮(ratchet)模式

```
默认 enforce 模式:
  if total_errors > baseline.total_errors:
      → 比基线还差,FAIL (exit 1)
  elif total_errors < baseline.total_errors:
      → 比基线好,自动更新 baseline,PASS (exit 0,但需要 commit baseline)
  else:
      → 持平,PASS (exit 0)

baseline 模式 (--baseline):
  → 强制写入当前数值到 .rebrand-baseline.json
  → 只在初始化或确认收紧策略时使用
```

`.rebrand-baseline.json` 内容示例:

```json
{
  "schemaVersion": "rebrand.baseline.v1",
  "generated_at": "2026-05-14T10:00:00Z",
  "total_errors": 1523,
  "total_warns": 45,
  "by_rule": {
    "R-BRAND-01": 892,
    "R-BRAND-02": 257,
    "R-BRAND-03": 198,
    "R-BRAND-04": 134,
    "R-BRAND-05": 45,
    "R-BRAND-06": 0,
    "R-BRAND-07": 42
  }
}
```

#### 4.1.8 命令行参数

```
python scripts/check_rebrand.py [options]

Options:
  --baseline           写入新的基线文件(慎用)
  --no-ratchet         禁用棘轮模式,只看绝对违规数
  --rule R-BRAND-XX    只跑指定规则
  --paths PATH ...     只扫描指定路径
  --format human|json  输出格式(默认 human)
  --quiet              只输出汇总,不输出每条 finding
```

#### 4.1.9 核心伪代码

```python
def main():
    args = parse_args()
    config = load_whitelist(WHITELIST_PATH)
    rules = compile_rules(config)            # R-BRAND-01 ~ R-BRAND-07

    findings = []
    for path in walk_repo(SCAN_EXTENSIONS, EXCLUDE_DIRS, EXCLUDE_FILES):
        for rule in rules:
            for hit in rule.scan_file(path):
                if config.is_whitelisted(rule.id, path, hit.line):
                    continue
                findings.append(hit)

    print_findings(findings)
    exit_code = decide_exit_code(findings, baseline=load_baseline(),
                                 ratchet=not args.no_ratchet)
    sys.exit(exit_code)
```

---

### 4.2 `scripts/check_registry.py` — 注册表断链检测【**关键**】

#### 4.2.1 职责

验证所有在配置 / 代码 / prompt 中**引用**的 agent / skill / tool / workflow / task 实际存在于文件系统;
反之,存在于文件系统但未注册的(orphan)报 WARN。

#### 4.2.2 检测维度

| 检测项 | 数据源 | 校验目标 |
|--------|--------|----------|
| Agent 完整性 | `flocks/agent/agents/*/agent.yaml` 与 `.flocks/plugins/agents/*/agent.yaml` | 每个声明 agent 的目录下 `agent.yaml` + `prompt.md` 或 `prompt_builder.py` 存在,YAML 字段合法 |
| Agent 交叉引用 | `prompt.md` / `prompt_builder.py` 中提到的 agent name | 引用的 agent 在 registry 中存在 |
| Skill 完整性 | `.flocks/plugins/skills/*/SKILL.md` | 每个 skill 的 `SKILL.md` 存在,front-matter `name` 与目录名一致 |
| Tool API | `.flocks/plugins/tools/api/*/_provider.yaml` | provider yaml 与 handler 文件名一致,handler 可被 import |
| Tool MCP | `.flocks/plugins/tools/mcp/*.yaml` | MCP yaml schema 合法 |
| Tool Python | `.flocks/plugins/tools/python/*.py` | Python 文件可被 ast.parse 通过 |
| Workflow 引用 | `.flocks/plugins/workflows/*/workflow.json` | JSON 可解析,引用的 `agentName` 在 registry 存在 |
| Task 引用 | `.flocks/plugins/tasks/*.yaml` | YAML 可解析,`agentName` 在 registry 存在 |
| Hub index 一致性 | `.flocks/flockshub/index.json` | 每个 plugin 的 `manifestPath` 对应文件存在,`category` 在 taxonomy 中 |
| Default agent | `flocks/agent/registry.py` 中 `default_agent` 解析 | 解析结果对应的 agent 实际存在 |

#### 4.2.3 输出格式示例

```
$ python scripts/check_registry.py

[check_registry] Validating registries...

  Agents (code):     11 declared, 11 found  ✓
  Agents (plugin):    8 declared,  8 found  ✓
  Skills:            17 declared, 17 found  ✓
  Tools (API):       17 declared, 17 found  ✓
  Tools (MCP):        3 declared,  3 found  ✓
  Tools (Python):     1 declared,  1 found  ✓
  Workflows:          2 declared,  2 found  ✓
  Tasks:              1 declared,  1 found  ✓
  Hub index:        128 entries, 128 manifest files exist  ✓

  Cross-references:
    ERROR  flocks/agent/agents/self_enhance/prompt.md:3
           references agent "Rex" → NOT FOUND in registry (did you mean "<新名>"?)
    ERROR  .flocks/plugins/tasks/daily-intel.yaml:16
           agentName "rex" → NOT FOUND in registry
    WARN   .flocks/plugins/tools/api/old-tool/   no _provider.yaml (orphan?)

──────────────────────────────────
  2 ERROR, 1 WARN
  EXIT: 1
──────────────────────────────────
```

#### 4.2.4 特别说明

- 这个脚本在 **阶段 3(Rex 改名)** 和 **阶段 5(插件删减)** 后尤为重要
- 它能精确定位"删了 agent 但忘记改引用处"的问题
- agent name 提取使用启发式正则 `\b{NAME}\b`,可能产生少量误报,通过白名单 `agent_name_whitelist` 字段控制

#### 4.2.5 与 `validate_flockshub.py` 的关系

| 脚本 | 关注点 | 是否取代 |
|------|--------|----------|
| `validate_flockshub.py` | 仅 hub 目录(taxonomy + index 一致性) | **保留**,作为 hub 专项 |
| `check_registry.py` | 全仓注册表交叉引用 | **新增**,补充 hub 之外的所有维度 |

两者互补,CI 中并行执行。



---

### 4.3 `scripts/run_tests.py` — 统一测试入口【**修复历史问题**】

#### 4.3.1 职责

修复当前 `Makefile` 中 `make test` 引用 `scripts/run-tests.py`(不存在)的问题,提供分级测试执行入口。

#### 4.3.2 三种执行模式

| 模式 | 命令 | 范围 | 超时 |
|------|------|------|------|
| **core** (默认) | `python scripts/run_tests.py` | 排除 `integration` / `live` / `slow` 标记 | 单 test 30s,总 5min |
| **all** | `python scripts/run_tests.py --all` | 全部 test,含 integration(无 key 自动 skip) | 单 test 60s,总 15min |
| **verbose** | `python scripts/run_tests.py --verbose` | core 模式 + `-v --tb=long` | 同 core |

#### 4.3.3 内部实现

```python
def main():
    args = parse_args()
    cmd = ["uv", "run", "pytest", "tests/"]

    if args.all:
        cmd += ["-v", "--tb=short", "--timeout=60"]
    else:
        cmd += [
            "-m", "not integration and not live and not slow",
            "--tb=short",
            "--timeout=30",
            "-q",
        ]
    if args.verbose:
        cmd += ["-v", "--tb=long"]

    return subprocess.call(cmd)
```

#### 4.3.4 与 CI 的关系

- CI 直接调用 `pytest`,不通过此脚本(避免双重抽象)
- 此脚本主要供**本地开发者**使用,统一 `make test` 入口

---

### 4.4 `scripts/smoke_test.py` — 无 LLM 冒烟测试【**最后防线**】

#### 4.4.1 职责

不依赖任何 API Key,验证框架最关键的加载链路在改造后仍然可用:
"框架到底能不能起来"是改名之后最容易踩坑的问题。

#### 4.4.2 测试项

| # | 测试 | 验证内容 | 失败含义 |
|---|------|----------|----------|
| 1 | CLI import | `import flocks.cli.main` 不抛异常 | import 链断裂 |
| 2 | CLI `--help` | 子进程 `python -m flocks.cli.main --help` 退出码 0,输出包含 `<新 CLI 名>` | CLI 入口损坏 / 改名不彻底 |
| 3 | Agent registry | `await Agent.list()` 返回 ≥ N 个,无 deprecation warning | agent.yaml 损坏或缺失 |
| 4 | Primary agent | `await Agent.get(PRIMARY_AGENT_NAME)` 非 None,`mode == "primary"` | 主 agent 改名不一致 |
| 5 | Default agent | `await Agent.default()` 解析正确 | 默认 agent 路由失效 |
| 6 | Subagents | 所有 `mode=subagent` 的 agent prompt 可读取 | prompt 文件丢失 |
| 7 | Tool registry | 所有注册 tool 的 `input_schema` 可 `json.dumps` | tool schema 语法错误 |
| 8 | Config 加载 | `Config.load()` 在临时目录无异常 | 配置 schema 不兼容 |
| 9 | Hub index parse | `json.loads(.flocks/flockshub/index.json)` 成功且非空 | Hub 索引损坏 |
| 10 | i18n 完整性 | `webui/src/locales/{zh-CN,en-US}/*.json` 中 key 数量一致 | 翻译漏字段 |

#### 4.4.3 输出格式示例

```
$ python scripts/smoke_test.py

[smoke_test] Running smoke tests (no LLM required)...

  ✓ [01] CLI import
  ✓ [02] CLI --help (exit=0, brand=<新名>)
  ✓ [03] Agent registry (loaded 11 agents)
  ✓ [04] Primary agent: <新名> (mode=primary)
  ✓ [05] Default agent resolves to: <新名>
  ✓ [06] Subagent prompts (10/10 readable)
  ✓ [07] Tool registry schema (47/47 serializable)
  ✓ [08] Config.load() OK
  ✓ [09] Hub index (128 plugins indexed)
  ✓ [10] i18n parity (zh-CN: 312 keys, en-US: 312 keys)

──────────────────────────────────
  10/10 PASSED in 2.1s
──────────────────────────────────
```

#### 4.4.4 特别说明

- 此脚本作为 **CI Job 3** 核心,模拟真实启动但不连接 LLM
- 是改名后"能不能跑起来"的最后一道防线
- 任何一项失败 → CI 红灯,且失败信息明确指向问题模块

---

## 五、CI 升级详细设计

### 5.1 改动文件: `.github/workflows/ci.yml`

#### 5.1.1 现状(改动前)

```yaml
# 当前 ci.yml 的核心问题:
# - Python test 只跑 tests/scripts tests/hub (约30个文件,占总量10%)
# - 无 mypy type check
# - 无品牌残留检测
# - 无注册表断链检测
# - WebUI 无 vitest
# - 无冒烟测试
```

#### 5.1.2 目标态(改动后)

```yaml
name: CI

on:
  pull_request:
    branches: [main, dev]
  push:
    branches: [dev]

permissions:
  contents: read

jobs:
  # ════════════════════════════════════════════
  # Job 1: Python 质量门禁
  # ════════════════════════════════════════════
  python-quality:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v6

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - uses: astral-sh/setup-uv@v6
        with:
          enable-cache: true

      - name: 安装依赖
        run: uv sync --group dev --frozen

      # ---- 静态检查 ----
      - name: Ruff lint (全量)
        run: uv run ruff check flocks/ scripts/ tests/

      - name: Mypy 类型检查
        run: uv run mypy flocks/ --ignore-missing-imports --no-error-summary
        continue-on-error: true   # 初期允许失败,逐步收紧

      # ---- 品牌改造专项 ----
      - name: 品牌残留检测 (check_rebrand)
        run: uv run python scripts/check_rebrand.py

      - name: 注册表断链检测 (check_registry)
        run: uv run python scripts/check_registry.py

      - name: Hub 目录校验 (validate_flockshub)
        run: uv run python scripts/validate_flockshub.py

      # ---- 单元测试 ----
      - name: Python 单元测试
        run: |
          uv run pytest tests/ \
            -m "not integration and not live and not slow" \
            --tb=short \
            --timeout=30 \
            -q

  # ════════════════════════════════════════════
  # Job 2: 前端质量门禁
  # ════════════════════════════════════════════
  frontend-quality:
    runs-on: ubuntu-latest
    timeout-minutes: 8
    defaults:
      run:
        working-directory: webui
    steps:
      - uses: actions/checkout@v6

      - uses: actions/setup-node@v4
        with:
          node-version: "22"
          cache: npm
          cache-dependency-path: webui/package-lock.json

      - name: 安装依赖
        run: npm ci

      - name: ESLint
        run: npm run lint

      - name: TypeScript build
        run: npm run build

      - name: Vitest 单元测试
        run: npm run test:run

  # ════════════════════════════════════════════
  # Job 3: 冒烟测试 (依赖前两个 Job)
  # ════════════════════════════════════════════
  smoke-test:
    runs-on: ubuntu-latest
    needs: [python-quality, frontend-quality]
    timeout-minutes: 5
    steps:
      - uses: actions/checkout@v6

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - uses: astral-sh/setup-uv@v6
        with:
          enable-cache: true

      - name: 安装依赖
        run: uv sync --group dev --frozen

      - name: 冒烟测试 (无需 LLM key)
        run: uv run python scripts/smoke_test.py
```

#### 5.1.3 关键改动说明

| 变更点 | 为什么重要 |
|--------|-----------|
| `pytest` 改为全量(排除 integration/live/slow) | 从覆盖 10% 提升到 ~95%,所有 agent / session / config / tool 测试入围 |
| 新增 `check_rebrand.py` step | **改名改造的命脉**——任何 PR 引入新的旧品牌名立即红灯 |
| 新增 `check_registry.py` step | **删减改造的命脉**——删插件漏改引用立即红灯 |
| 新增 `vitest run` | 前端 35 个测试从"装饰品"变成"门禁" |
| 新增 `smoke-test` job | 端到端验证框架可加载,不依赖 LLM,3 分钟内反馈 |
| 触发条件加 `push: [dev]` | dev 分支推送也触发,不只 PR |
| `timeout-minutes` 限制 | 防止 hang 住浪费 GitHub Actions 配额 |
| `mypy` 用 `continue-on-error` | 初期不阻塞,建立 baseline 后再改成强制 |

#### 5.1.4 特别强调:**残留检测必须在单元测试之前**

```
顺序:lint → check_rebrand → check_registry → pytest
理由:
  - check_rebrand 秒级完成,失败时无需等 5 分钟 pytest
  - 残留问题往往会引发 pytest 失败,先报上层错误更清晰
  - 节省 CI 资源
```



---

### 5.2 改动文件: `Makefile`

#### 5.2.1 现状(改动前)

```makefile
test:
	@python3 scripts/run-tests.py     # ← 此文件不存在,make test 直接报错
test-verbose:
	@python3 scripts/run-tests.py --verbose
test-core: test
test-all:
	@uv run pytest tests/ -v --tb=short
```

#### 5.2.2 目标态(改动后)

```makefile
.PHONY: help test test-verbose test-core test-all \
        check check-rebrand check-registry check-hub \
        smoke ci-local lint typecheck

help:
	@echo "测试与验证命令:"
	@echo "  make test            - 运行核心单元测试 (合并前必须通过)"
	@echo "  make test-verbose    - 运行核心测试 + 详细输出"
	@echo "  make test-all        - 运行所有测试 (含 integration)"
	@echo ""
	@echo "  make lint            - Ruff lint (Python)"
	@echo "  make typecheck       - Mypy 类型检查"
	@echo ""
	@echo "  make check           - 跑全部静态检查 (lint + rebrand + registry + hub)"
	@echo "  make check-rebrand   - 品牌残留检测"
	@echo "  make check-registry  - 注册表断链检测"
	@echo "  make check-hub       - Hub 目录校验"
	@echo ""
	@echo "  make smoke           - 冒烟测试 (无需 LLM key)"
	@echo "  make ci-local        - 本地模拟完整 CI (推荐提交前跑)"

# ---- 测试 ----
test:
	@uv run python scripts/run_tests.py

test-verbose:
	@uv run python scripts/run_tests.py --verbose

test-core: test

test-all:
	@uv run python scripts/run_tests.py --all

# ---- 静态检查 ----
lint:
	@uv run ruff check flocks/ scripts/ tests/

typecheck:
	@uv run mypy flocks/ --ignore-missing-imports

check-rebrand:
	@uv run python scripts/check_rebrand.py

check-registry:
	@uv run python scripts/check_registry.py

check-hub:
	@uv run python scripts/validate_flockshub.py

check: lint check-rebrand check-registry check-hub
	@echo "✓ 静态检查全部通过"

# ---- 冒烟 ----
smoke:
	@uv run python scripts/smoke_test.py

# ---- 本地模拟 CI ----
ci-local: check test smoke
	@echo "✓ 本地 CI 全部通过,可以推送"
```

#### 5.2.3 关键改动说明

| 变更点 | 为什么重要 |
|--------|-----------|
| 修复 `make test` 指向真实存在的脚本 | 当前直接报错,形同虚设 |
| 新增 `make ci-local` | 开发者提交前**一条命令**验证所有门禁,减少 CI 反复 |
| 新增 `make check` 复合 target | 静态检查一次跑完,失败信息集中 |
| 新增 `make check-rebrand` / `check-registry` 单独可调 | 改名过程中高频使用,允许只跑一项 |

---

## 六、改造阶段与验证矩阵

每个改造阶段完成后,必须通过对应验证项才能合并:

| 改造阶段 | check_rebrand | check_registry | pytest | vitest | smoke_test | 备注 |
|----------|:---:|:---:|:---:|:---:|:---:|------|
| **阶段 0: 本 PR(基础设施)** | ✓ baseline 建立 | ✓ baseline 建立 | ✓ 全绿 | ✓ 全绿 | ✓ 全绿 | 只新增脚本,不改业务代码 |
| 阶段 1: 兼容层(branding.py 等) | ✓ | ✓ | ✓ | ✓ | ✓ | 纯加法,违规不增加 |
| 阶段 2: 品牌替换 | **✓ 核心** | ✓ | ✓ | ✓ | ✓ | 棘轮收紧,违规递减 |
| 阶段 3: Rex 改名 | **✓ 核心** | **✓ 核心** | ✓ 需修测试 | ✓ | **✓ 核心** | 最高风险阶段 |
| 阶段 4: 中文化 | ✓ | ✓ | ✓ 部分需调 | ✓ | ✓ | prompt 变更不影响 schema |
| 阶段 5: 插件删减 | ✓ | **✓ 核心** | ✓ 需删测试 | ✓ | **✓ 核心** | 断链风险最大 |
| 阶段 6: 终态验收 | **✓ 归零** | ✓ | ✓ | ✓ | ✓ | baseline 清零 |

---

## 七、白名单演进策略

白名单不是"一劳永逸",而是随阶段收紧:

```
阶段 0 (初始):
  baseline 模式生成基线,白名单宽松
  → 允许所有现存的 "flocks" / "rex" 残留 (不红灯)
  → CI 阻止"新增"残留即可

阶段 1 (兼容层):
  白名单不变,baseline 不变
  → 新增代码不允许出现旧名 (增量检查)

阶段 2 (品牌替换):
  逐步收紧白名单
  → 每替换一类用法,从白名单中移除对应规则
  → baseline 数字单调递减

阶段 3 (Rex 改名):
  R-BRAND-02 白名单收紧到只剩别名表 + CHANGELOG

阶段 5 (删减完成):
  白名单最终态
  → 仅保留: Python import path / CHANGELOG / 设计文档
  → baseline 趋近于 0

阶段 6 (终态验收):
  baseline 清零
  → 任何残留都是 ERROR
  → 拆除棘轮,变成绝对零容忍
```

**重要**:每次收紧白名单本身也是独立提交,方便 review。

---

## 八、依赖与环境要求

### 8.1 Python 依赖

所有新增脚本只使用标准库 + 项目已有 dev 依赖:

| 用途 | 模块 | 来源 |
|------|------|------|
| 路径处理 | `pathlib`, `os` | 标准库 |
| 正则 / JSON | `re`, `json` | 标准库 |
| YAML | `yaml` | `PyYAML`(已在主依赖) |
| 子进程 | `subprocess`, `sys` | 标准库 |
| 命令行 | `argparse` | 标准库 |
| 异步加载 (smoke_test) | `asyncio` | 标准库 |

**结论:无需新增任何第三方依赖**。

### 8.2 CI 环境

- Python 3.12(已有)
- Node.js 22(已有)
- uv(已有)
- 无需 Docker / 无需 LLM API Key / 无需访问外网服务

---

## 九、风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|:---:|:---:|----------|
| 全量 pytest 耗时过长(>10min) | 中 | CI 慢 | `--timeout=30` 单 test 超时;后续可加 `pytest-xdist -n auto` 并行 |
| mypy 全量初次报错过多 | 高 | 阻塞合并 | 初期 `continue-on-error: true`,建 baseline 后逐步收紧 |
| `check_rebrand` 白名单配错导致误报 | 低 | 开发者困惑 | 白名单 YAML 简单格式,每条必有 reason,scope 只用 glob |
| 部分测试依赖运行时 fixture(如 DB) | 中 | CI 报错 | 用 `@pytest.mark.live` 标记,排除 |
| vitest 因环境差异(jsdom)失败 | 低 | CI 红 | jsdom 已在 devDeps,前置 dryrun 验证 |
| smoke_test 误判 primary agent | 低 | 改名期假阳 | smoke_test 从 `branding.py` 读 `PRIMARY_AGENT_NAME`,与 branding 解耦 |
| baseline 文件冲突(多 PR 并行) | 中 | merge conflict | baseline 仅在违规减少时更新,冲突时取较小值 |

---

## 十、实施顺序(本 PR 内部)

本 PR 拆为 8 个独立可 review 的 commit,每个 commit 后跑一次本地验证:

```
commit 1: docs(rebrand): 新增残留检测脚本+CI升级设计文档(本文档)
commit 2: scripts: 新增 rebrand_whitelist.yaml(白名单宽松版)
commit 3: scripts: 新增 check_rebrand.py(支持 --baseline / 棘轮模式)
commit 4: scripts: 新增 check_registry.py(注册表断链检测)
commit 5: scripts: 新增 run_tests.py(修复 Makefile 引用缺失文件)
commit 6: scripts: 新增 smoke_test.py(无 LLM 冒烟)
commit 7: chore: 升级 Makefile(新增 check / smoke / ci-local)
commit 8: ci: 升级 .github/workflows/ci.yml(全量门禁)
commit 9: chore: 生成 .rebrand-baseline.json 初始基线
```

**强烈建议**:每个 commit 之间跑 `make ci-local`,确保都是绿的再继续。

---

## 十一、验收标准

本 PR 合并必须满足:

- [ ] `make ci-local` 在本地全绿
- [ ] `make test` 修复后正常运行(不再报"找不到 run-tests.py")
- [ ] `make check-rebrand --baseline` 生成 `.rebrand-baseline.json`,文件入库
- [ ] `make check-registry` 全绿(当前注册表完整无断链)
- [ ] `make smoke` 全绿(框架可正常加载)
- [ ] 新 CI workflow 在 PR 触发时三个 Job 全绿
- [ ] 所有新增脚本提供清晰的 `--help` 输出
- [ ] `scripts/rebrand_whitelist.yaml` 每条规则有 `reason` 字段
- [ ] 文档(本文档)与实际脚本行为一致

---

## 十二、后续展望(本 PR 不含,供参考)

| 方向 | 说明 |
|------|------|
| Coverage 门禁 | `pytest-cov` 生成覆盖率报告,设最低阈值(如 60%) |
| 增量 lint | 只检查 PR 变更文件,加速 CI |
| E2E with LLM | 需 LLM key,放在单独 workflow,手动触发 / 定时触发 |
| Playwright WebUI 测试 | 浏览器自动化验证前端无旧品牌名 |
| 性能基线 | Agent 启动时间、首 token 延迟回归检测 |
| pre-commit hook | 本地提交前自动跑 `check_rebrand` 子集 |

---

## 评审检查表(供评审者使用)

请逐条确认或反馈:

### 设计完整性
- [ ] 三类风险(残留 / 断链 / 回归)都被覆盖
- [ ] 每个改造阶段都有对应验证项
- [ ] 不依赖外部服务(LLM / DB / 网络)

### 实施可行性
- [ ] 不引入新的第三方依赖
- [ ] CI 总耗时控制在 10 分钟内
- [ ] 脚本规模可控(每个 ≤ 250 行)

### 棘轮策略
- [ ] baseline 机制不会卡住正常开发
- [ ] 白名单收紧策略清晰
- [ ] 终态(阶段 6)有明确退出条件

### 用户体验
- [ ] 报错信息明确(规则 ID + 文件 + 行号 + 上下文)
- [ ] 本地可复现 CI 结果(`make ci-local`)
- [ ] `--help` 完整

### 兼容性
- [ ] Python 包名不改的前提没被破坏
- [ ] AGENT_ALIASES 等兼容机制有白名单兜底
- [ ] 现有 `validate_flockshub.py` 不被取代,继续保留

---

*文档结束。请评审后给出修改意见,确认后即按"实施顺序"逐步落地。*
