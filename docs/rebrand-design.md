# smartClaw 品牌改造设计文档

> 项目代号：Flocks → smartClaw 品牌重塑
> 文档版本：v1.0
> 面向对象：项目评审与决策

---

## 一、结论

本次改造需完成 **四项独立工作**：

| 代号 | 任务 | 新旧对照 |
|---|---|---|
| **D** | 内置资源删减 | 按产品定位收敛 agent / skill / tool / workflow 的数量 |
| **A** | 项目品牌去 flocks 化 | `flocks` → `smartclaw`（包、目录、环境变量、CI、镜像等） |
| **B** | 主智能体改名 | `Rex` → `Sentry`（agent 身份、prompt 自称、委派引用） |
| **C** | 整体中文化 | prompt、CLI 输出、description、错误消息 |

**推荐执行顺序**：

> **D（删减） → A（去 flocks 化） → B（Rex 改名为 Sentry） → C（中文化）**

**核心决策依据**：

1. 四件事作用域不同、风险不同、互相有依赖，**不应合并也不应并行**；
2. 每一步完成后产物都能独立发布，**中途可暂停、可交付**；
3. 先做减法再做改名，**工作量可砍掉近一半**；
4. 高风险任务前置、低风险翻译收尾，**有出问题的回滚窗口**；
5. 改名先于翻译，**避免翻译好的中文文本被二次修改**。

---

## 二、四项任务的本质区别

过往讨论中曾将"Rex 改名"与"去 flocks 化"视为同一件事，这是误判。两者作用域完全不同：

| 维度 | A：去 flocks 化 | B：Rex 改名为 Sentry |
|---|---|---|
| 作用域 | 项目品牌层 | 智能体身份层 |
| 改动对象 | Python 包名、目录、环境变量、配置路径、Docker 镜像、CI、类名前缀、URL | Agent 目录名、prompt 自称、委派引用、AGENTS.md |
| 影响点数（粗估） | 约 3500 处 | 约 200 处 |
| 风险等级 | 🟠 中高 | 🟢 低 |
| 是否触达基础设施 | 是（运行时路径、环境变量、Docker 镜像断档） | 否 |
| 是否需要兼容层 | 是（老用户 `~/.flocks/` 数据、旧环境变量） | 否或仅需 agent 别名 |

同理，**C（中文化）**属于"内容层"改动，**D（删减）**属于"资产减法"，与 A、B 的"重命名"本质不同。

---

## 三、命名决策（已确认）

| 维度 | 取值 |
|---|---|
| 项目品牌名（展示） | `smartClaw` |
| Python 包 / 目录 / PyPI / Docker | `smartclaw`（全小写一个词） |
| CLI 命令 | `smartclaw`（例：`smartclaw start`） |
| Python 类前缀 | `SmartClaw`（例：`SmartClawClient`、`SmartClawToolAdapter`） |
| 环境变量前缀 | `SMARTCLAW_`（例：`SMARTCLAW_ROOT`） |
| 配置目录 | `~/.smartclaw/`（带老目录 `~/.flocks/` 迁移逻辑） |
| 主智能体代号 | `Sentry`（替代 `Rex`） |
| Agent 目录名 | `sentry`（对应旧 `rex` / `rex_junior` → `sentry` / `sentry_junior`） |

**关于 Sentry 的选型说明**：
- 英文短名，含"哨兵"语义，与 SecOps 场景高度契合；
- 独特性高，不与自然语言常用词冲突（不像 `safe`）；
- grep 友好，代码检索不会误命中；
- 与 agent 身份天然契合（哨兵 = 主动防御、观察、响应）。

---

## 四、执行顺序与理由

### 4.1 推荐顺序

```
第 1 步：D（删减内置资源）
第 2 步：A（去 flocks 化：flocks → smartclaw）
第 3 步：B（Rex 改名为 Sentry）
第 4 步：C（整体中文化）
```

### 4.2 为什么 D 第一 —— 倍数收益

**减法在前，后续所有工作量等比例下降**。

当前仓库待处理的主要增量：

| 待删除对象 | 规模 | 其中 flocks / Rex 引用数量 |
|---|---|---|
| `pentest-ai-agents/` | 37 个渗透测试 subagent | 每个 manifest 均带品牌字段 |
| `Anthropic-Cybersecurity-Skills/` | 社区打包 skill 集 | 若干 |
| 冗余 agent（`hephaestus` / `metis` / `momus`） | 3 个 + 各自 prompt（合计 600+ 行英文） | 密集 |
| 厂商专用 skill（视产品定位决定） | 最多 8 个 | 中等 |

**估算**：仓库 `flocks` / `Flocks` 字样总计约 3500 处，其中至少 **1500 处集中在后续可能被整块删除的目录里**。先删减可直接避免对这些内容做改名和翻译。

**额外收益**：
- 与 A、B、C 三步**零耦合**，任何时候都能独立回滚；
- 完成后可立即发布"产品聚焦"版本，用户感知明确；
- 为后续三步提供干净的工作面，grep 校验结果更可信。

### 4.3 为什么 A 在 B 前 —— 风险前置

将 A（高风险）放在 B（低风险）之前，核心考虑是**留足回滚窗口**。

**A 涉及的高风险点**：
- 运行时路径 `~/.flocks/` → `~/.smartclaw/`（老用户数据迁移）
- 环境变量 `FLOCKS_*` → `SMARTCLAW_*`（部署脚本失效）
- Docker 镜像名变更（老用户 `docker pull` 失败）
- Gitee 同步 workflow 需配套新仓库
- PyPI 包名可用性需验证

**B 涉及的改动**：
- 仅 `flocks/agent/agents/rex/` 目录及其内部 prompt
- 其他 subagent 中对 Rex 的委派引用
- `AGENTS.md` 全局指令文档
- 不触及任何基础设施

**顺序收益**：
- A 做完，仓库里 `flocks` 字样已清零；此时做 B 的 grep 校验不会被 `FlocksClient` 等残留干扰；
- 任何 A 相关的部署问题（镜像、环境变量、配置目录）都可以在 B 开始前暴露并修复；
- B 如果出问题，只需回滚单一 PR，不影响 A 建立的新基础设施。

### 4.4 为什么 B 在 C 前 —— 避免二次修改

**这是修正过往顺序的关键点**。

Rex 主 prompt 当前约 858 行英文，内部硬写 `"Rex"` 自称及第三人称引用约 60+ 处，典型形态：

- `You are "Rex" - Powerful AI orchestrator ...`
- `Rex detects: no email tool exists`
- `Rex delegates: delegate_task(...)`
- `Rex has a dedicated xxx tool`

**先 C 后 B 的问题**：翻译完成的中文 prompt 仍然会含有"Rex"硬字符串，B 阶段必须在**中文文本中再扫一遍做替换**。中文文本搜索精度低于代码文本，容易漏改。

**先 B 后 C 的收益**：Sentry 品牌在 B 阶段固化，C 阶段翻译时只处理周围的英文叙述，agent 自称字段本身不再变化，**翻译成为一次性工作**。

同理适用于 `AGENTS.md`、其他 subagent prompt、工具 description 等含 Rex 引用的文本。

### 4.5 为什么 C 压轴 —— 工作量最大且需回归

**C 是四步中单步工作量最大的一步**：

| 待中文化内容 | 规模 |
|---|---|
| Sentry 主 prompt（原 Rex） | 858 行 |
| 其他 subagent prompt（10 个） | 约 1500 行 |
| CLI 用户可见输出 | 13 个子命令 + 服务管理器 |
| Agent/Skill/Tool 的 description 字段 | 50+ 项 |
| 错误消息、交互提示 | 数十处 |
| `AGENTS.md` 全局指令文档 | ~200 行 |

**需独立回归的原因**：LLM 对中英文 prompt 行为并非完全等价，改完必须过一轮端到端回归测试（委派流程、Phase 0-3 意图识别、工具选择），不宜与其他改动混在一个 PR 内，否则出问题时无法定位根因。

**放在最后的好处**：
- 仓库品牌、agent 名已全部定型，翻译一次到位；
- 可独立并行化（例如 prompt 翻译与 CLI 翻译可分头进行）；
- 翻译阶段出问题不阻塞前三步的上线；
- 可以借助 LLM 辅助批量翻译 + 人工审核，流程化收尾。

---

## 五、阶段化交付计划

每个阶段产物均可独立发布。

| 阶段 | 工作内容 | 预计 PR 数 | 可交付产物 |
|---|---|---|---|
| **1. 删减** | 依据产品定位下线冗余 agent / skill / tool / workflow；删除 bundled hub 中的第三方包 | 2-3 | 产品聚焦版（形态收敛） |
| **2. 去 flocks 化** | 包目录重命名、import 批量替换、类名 / 常量 / 字符串替换、entry_point、Docker、CI、资产、环境变量前缀、运行路径迁移、兼容层 | 3-4 | smartClaw 品牌版 |
| **3. Sentry 改名** | Agent 目录重命名、prompt 自称替换、委派引用修正、AGENTS.md 调整、别名兼容 | 1-2 | Sentry 身份版 |
| **4. 中文化** | Sentry prompt + 其他 subagent prompt + CLI 输出 + description + 错误消息 + 端到端 LLM 回归 | 3-5 | 中文发布版 |

**合计**：9-14 个 PR，每阶段完成均具备发布条件，允许中途暂停。

---

## 六、主要风险与缓解

| 风险 | 阶段 | 缓解措施 |
|---|---|---|
| PyPI `smartclaw` 包名被占用 | A | 正式开工前验证可用性，备选 `smartclaw-ai` |
| 老用户 `~/.flocks/` 数据丢失 | A | 首次启动检测旧目录并自动迁移，保留 3 个月兼容窗口 |
| 旧环境变量 `FLOCKS_*` 失效 | A | `SMARTCLAW_*` 与 `FLOCKS_*` 并行读取一个版本周期，旧变量触发 deprecation warning |
| Docker 镜像断档 | A | 新镜像发布至 `ghcr.io/<新组织>/smartclaw`；旧镜像发布一版"迁移提示版"后废弃 |
| Rex 别名丢失导致用户委派失败 | B | `agent.yaml` 保留 `aliases: [rex]` 一个版本周期 |
| 中文 prompt 后 LLM 行为偏移 | C | 独立 PR + 完整端到端回归测试（委派流程、意图识别、工具选择） |
| PR 规模过大不可评审 | A/C | 采用 shim 策略（先 `smartclaw/` 与 `flocks/` 并存，再分批迁移）；翻译按 agent 分 PR |

---

## 七、需评审确认的决策点

在第 1 步（删减）开工前，需确认一项：

**产品定位**：
- 选项 A：继续做 AI-Native SecOps 平台 → 保留 host-forensics / ndr-analyst / ti-analyst / vul-threat-intelligence 等业务 agent
- 选项 B：转为通用 AI 开发助手 → 全面下线 SecOps 特化内容
- 选项 C：通用能力为核心 + SecOps 作为可选插件包

第 3 步前需最终确认：
- 是否保留 `rex` 作为 Sentry 的委派别名

第 4 步前需最终确认：
- 是否保留工具 description 的英文版本作为 fallback（影响多语言切换能力）

---

## 八、结语

本次改造四项任务虽然表面都是"重命名"，但内在的作用域、风险、依赖各不相同。通过 **D → A → B → C** 的顺序，能够做到：

- **每一步独立可回滚**
- **每一步独立可交付**
- **总工作量最小**
- **风险暴露窗口最大**

确认产品定位后即可进入第 1 步执行。

---

## 九、第 1 步（D：删减）全集方案

> 本节为**全集评估**，覆盖 bundled hub、用户插件目录、内置智能体、代码工具、IM 渠道、CLI 子命令、CI/打包、脚本、assets 共 9 大块。每项均标注 **DEL / MOVE / KEEP / SHRINK** 四种操作，并配套"上游同步保护"机制（见第 10 章）。

### 9.1 产品定位（决定删多少）

按选项 **C（通用核心 + SecOps 可选插件包）** 执行删减，理由：

- 保留已有 SecOps 能力不丢失（搬走而非丢弃）
- 主仓库轻量化，利于后续改名、翻译、维护
- SecOps 客户仍能通过插件安装回所需能力

### 9.2 操作分级

| 操作 | 含义 | 上游同步时如何处理 |
|---|---|---|
| **DEL** | 从本仓库彻底移除 | 写入 exclude-paths，上游新增时自动丢弃 |
| **MOVE** | 从本仓库移除，搬到独立的 SecOps 插件仓库 | 写入 exclude-paths，同 DEL |
| **KEEP** | 保留在本仓库 | 正常同步（如有本地改造则写入 keep-ours） |
| **SHRINK** | 保留但精简内部内容 | 写入 keep-ours，保持本地版本 |

### 9.3 删减对象清单

#### 9.3.1 Bundled Hub（`.flocks/flockshub/`）—— 占约 40 MB 的最大头

| 路径 | 操作 | 说明 |
|---|---|---|
| `.flocks/flockshub/plugins/agents/pentest-ai-agents/` | **DEL** | 37 个渗透 subagent，社区来源，非自研 |
| `.flocks/flockshub/plugins/skills/Anthropic-Cybersecurity-Skills/` | **DEL** | 250+ 社区 skill，体积大 |
| `.flocks/flockshub/plugins/skills/ndr-alert-analysis/` | **MOVE** | SecOps 插件包 |
| `.flocks/flockshub/plugins/tools/api/onesig_v2_5_3_D20250710/` | **MOVE** | SecOps 插件包 |
| `.flocks/flockshub/plugins/tools/api/sangfor_af_v8_0_48/` | **MOVE** | SecOps 插件包 |
| `.flocks/flockshub/plugins/tools/api/sangfor_af_v8_0_85/` | **MOVE** | SecOps 插件包 |
| `.flocks/flockshub/index.json` | **SHRINK** | 按删减后重新生成 |
| `.flocks/flockshub/taxonomy.json` | **SHRINK** | 同上 |

#### 9.3.2 内置 Agents（`flocks/agent/agents/`）

| 路径 | 操作 | 说明 |
|---|---|---|
| `flocks/agent/agents/rex/` | **KEEP** | 主 agent（第 3 步改名为 sentry） |
| `flocks/agent/agents/rex_junior/` | **KEEP** | 执行者 |
| `flocks/agent/agents/explore/` | **KEEP** | 代码库探索 |
| `flocks/agent/agents/plan/` | **KEEP** | 计划模式 |
| `flocks/agent/agents/self_enhance/` | **KEEP** | 能力补齐 |
| `flocks/agent/agents/multimodal_looker/` | **KEEP** | 多模态 |
| `flocks/agent/agents/oracle/` | **KEEP** | 只读顾问 |
| `flocks/agent/agents/librarian/` | **KEEP** | 外部文档检索 |
| `flocks/agent/agents/hephaestus/` | **DEL** | 与 rex_junior 职责重叠 |
| `flocks/agent/agents/metis/` | **DEL** | 预规划，Rex 可直接承担 |
| `flocks/agent/agents/momus/` | **DEL** | 计划评审，Rex 可直接承担 |

#### 9.3.3 插件 Agents（`.flocks/plugins/agents/`）

全部属于 SecOps 业务 agent，整体移出到 SecOps 插件仓库。

| 路径 | 操作 |
|---|---|
| `.flocks/plugins/agents/host-forensics/` | **MOVE** |
| `.flocks/plugins/agents/host-forensics-fast/` | **MOVE** |
| `.flocks/plugins/agents/ndr-analyst/` | **MOVE** |
| `.flocks/plugins/agents/ti-analyst/` | **MOVE** |
| `.flocks/plugins/agents/vul_threat_intelligence/` | **MOVE** |
| `.flocks/plugins/agents/hrti_threat_intelligence/` | **MOVE** |
| `.flocks/plugins/agents/asset-survey/` | **MOVE** |
| `.flocks/plugins/agents/phishing-detector/` | **MOVE** |

#### 9.3.4 插件 Skills（`.flocks/plugins/skills/`）

| 路径 | 操作 | 说明 |
|---|---|---|
| `agent-builder/` | **KEEP** | 元能力 |
| `tool-builder/` | **KEEP** | 元能力 |
| `workflow-builder/` | **KEEP** | 元能力 |
| `find-skills/` | **KEEP** | skill 发现 |
| `detect-malicious-skill/` | **KEEP** | 安全兜底 |
| `browser-use/` | **KEEP** | 通用浏览器 |
| `web2cli/` | **KEEP** | 通用能力 |
| `onboarding/` | **SHRINK** | 重写（品牌强耦合） |
| `ndr-alert-analysis/` | **MOVE** | SecOps |
| `onesec-use/` | **MOVE** | SecOps |
| `onesig-use/` | **MOVE** | SecOps |
| `qingteng-use/` | **MOVE** | SecOps |
| `skyeye-use/` | **MOVE** | SecOps |
| `skyeye-sensor-data-fetch/` | **MOVE** | SecOps |
| `tdp-use/` | **MOVE** | SecOps |

#### 9.3.5 插件 Tools（`.flocks/plugins/tools/`）

| 路径 | 操作 |
|---|---|
| `api/fofa/` | **MOVE** |
| `api/greynoise/` | **MOVE** |
| `api/ngsoc_v4_15_1/` | **MOVE** |
| `api/ngtip_v5_1_5/` | **MOVE** |
| `api/onesec_v2_8_2/` | **MOVE** |
| `api/onesig_v2_5_3_D20260321/` | **MOVE** |
| `api/qingteng_v3_4_1_66/` | **MOVE** |
| `api/sangfor_af_v8_0_106/` | **MOVE** |
| `api/sangfor_sip_v92/` | **MOVE** |
| `api/sangfor_xdr_v2_2/` | **MOVE** |
| `api/skyeye_v4_0_14_0_SP2/` | **MOVE** |
| `api/tdp_v3_3_10/` | **MOVE** |
| `api/threatbook-cn/` | **MOVE** |
| `api/threatbook-io/` | **MOVE** |
| `api/urlscan/` | **MOVE** |
| `api/virustotal/` | **MOVE** |
| `mcp/nsfocus_mcp.yaml` | **MOVE** |
| `mcp/qianxin_mcp.yaml` | **MOVE** |
| `mcp/threatbook_mcp.yaml` | **MOVE** |
| `python/flocks_mcp.py` | **KEEP**（第 2 步改名） | 自研 MCP 入口 |

#### 9.3.6 插件 Tasks / Workflows

| 路径 | 操作 |
|---|---|
| `.flocks/plugins/tasks/daily-intel.yaml` | **MOVE** |
| `.flocks/plugins/workflows/tdp_alert_triage/` | **MOVE** |
| `.flocks/plugins/workflows/loop_host_forensics_fast/` | **MOVE** |

#### 9.3.7 代码工具（`flocks/tool/`）

| 路径 | 操作 | 说明 |
|---|---|---|
| `flocks/tool/wecom/` | **MOVE** | 企微专用 MCP，SecOps 渠道才用 |
| `flocks/tool/agent/call_omo_agent.py` | **DEL** | 外部 OMO 依赖，已不维护 |
| `flocks/tool/skill/flocks_skills.py` | **KEEP** | 第 2 步改名为 `smartclaw_skills.py`，第 3 步再改 `sentry_skills.py` |
| `flocks/tool/{file,code,web,system,task,agent,channel,security,skill}/**` | **KEEP** | 通用工具集 |

#### 9.3.8 IM 渠道（`flocks/channel/`）

| 路径 | 操作 | 说明 |
|---|---|---|
| `flocks/channel/base.py` / `events.py` / `registry.py` / `inbound/` / `outbound/` / `gateway/` | **KEEP** | 渠道框架核心 |
| `flocks/channel/builtin/feishu/` | **KEEP** | 国内主流 |
| `flocks/channel/builtin/wecom/` | **KEEP** | 国内主流 |
| `flocks/channel/builtin/dingtalk/` | **KEEP** | 国内主流 |
| `flocks/channel/builtin/weixin/` | **MOVE / DEL**（待确认） | 非企业主流（个人微信），不建议保留在主仓库 |
| `flocks/channel/builtin/telegram/` | **MOVE / DEL**（待确认） | 海外渠道，国内场景用不上 |

#### 9.3.9 CLI 子命令（`flocks/cli/commands/`）

| 命令文件 | 操作 |
|---|---|
| `session.py` / `admin.py` / `skill.py` / `mcp.py` / `update.py` / `task.py` / `agent.py` / `browser.py` / `acp.py` / `export.py` / `import_.py` / `debug.py` | **KEEP** |
| `stats.py` | **SHRINK** |

#### 9.3.10 CI / 打包 / 脚本

| 路径 | 操作 | 说明 |
|---|---|---|
| `.github/workflows/sync-gitee.yml` | **DEL** | 无 Gitee 镜像则删除 |
| `.github/workflows/ci.yml` | **SHRINK** | 第 2 步移除 `validate_flockshub.py` 调用 |
| `.github/workflows/docker-publish.yml` | **SHRINK** | 第 2 步改镜像名 |
| `.github/workflows/windows-packaging.yml` / `windows-packaging-publish.yml` | **KEEP** | 第 2 步改 artifact 名 |
| `.github/ISSUE_TEMPLATE/plugin_request.yml` | **SHRINK** | 去品牌化 |
| `scripts/validate_flockshub.py` | **DEL** | bundled hub 删空后无用 |
| `scripts/recover_raw_flocks_db.py` | **KEEP** | 第 2 步改名 |
| `scripts/migrate_legacy_task_tables.py` / `run_legacy_task_migration.sh` | **KEEP** | 数据迁移 |
| 根目录 `install*.sh` / `install*.ps1`（4 份）+ `scripts/install*.sh` / `install*.ps1`（4 份） | **SHRINK** | 第 2 步统一处理 |
| `packaging/windows/flocks-setup.iss` / `uninstall-flocks-user-state.ps1` / `start-flocks-elevated.ps1` | **SHRINK** | 第 2 步改名 |
| `npm-wrapper/` | **DEL** | 仅为 `npx → uvx` 转发壳程序（50 行 mjs），非必需。npm 用户直接装 uv 即可 |

#### 9.3.11 Assets & 品牌资源

| 路径 | 操作 |
|---|---|
| `assets/flocks.webp` | **DEL**（第 2 步替换 logo） |
| `assets/community-wecom-qr.png` | **KEEP**（社区二维码可替换内容） |

### 9.4 删减总量统计（已根据最终决策更新）

依据已确认的 3 项决策：
- 产品定位：**选项 C**（通用核心 + SecOps 可选插件包）
- weixin / telegram 渠道：**DEL**（直接删除，不搬迁）
- npm-wrapper：**DEL**

| 分类 | DEL | MOVE | 节省 |
|---|---|---|---|
| Bundled Hub | 2 大目录（~290 项） | 4 项 | ~38 MB |
| 内置 Agents | 3 | 0 | ~40 KB |
| 插件 Agents | 0 | 8 | ~160 KB |
| 插件 Skills | 0 | 7 | ~400 KB |
| 插件 Tools | 0 | 19 | ~1.2 MB |
| 插件 Tasks/Workflows | 0 | 3 | ~30 KB |
| 代码工具 | 1 | 1 | 少量 |
| IM 渠道 | 2 | 0 | ~170 KB |
| CI / 脚本 | 2 | 0 | 少量 |
| Assets | 1 | 0 | ~800 KB |
| npm-wrapper | 1 整个目录 | 0 | ~12 KB |
| **合计** | **~299 项** | **~42 项** | **~40 MB** |

---

## 十、上游同步保护机制

### 10.1 核心问题

后续需要周期性从上游 `AgentFlocks/flocks` 拉取更新，但删除/移出的目录如果上游仍存在，常规 `git merge` 会将其重新拉回本仓库。必须引入机制使得**被删除/移出的路径永远不会被上游同步恢复**。

### 10.2 总体策略：下游覆盖 + 忽略清单 + 自动化脚本

| 组件 | 作用 |
|---|---|
| `.upstream-sync/exclude-paths.txt` | 删除/移出路径的"黑名单"，每次同步后强制清理 |
| `.upstream-sync/keep-ours.txt` | 本地深度改造路径的"白名单"，同步时保持本地版本 |
| `.upstream-sync/sync.sh` | 同步脚本：fetch → merge → 应用黑白名单 → 推 PR |
| `.github/workflows/upstream-guard.yml` | CI 守卫：PR 中若重新出现黑名单路径，CI 直接失败 |
| `.gitignore` 强化 | 黑名单路径同时加入 gitignore，防止手动误提交 |

### 10.3 分支模型

```
upstream/main          ← 上游官方主干
    │
    └──▶ upstream-sync/YYYYMMDD   ← 每次同步的专用分支（脚本自动创建）
              │
              ├── 应用 exclude-paths.txt（git rm 黑名单）
              ├── 应用 keep-ours.txt（checkout 本地版本）
              │
              └──▶ PR ──▶ main    ← 人工 review 后合入主分支
```

**严禁**直接 `git merge upstream/main` 到 `main`。

### 10.4 `.upstream-sync/exclude-paths.txt` 示例

```
# === Bundled hub — 整块删除 ===
.flocks/flockshub/plugins/agents/pentest-ai-agents/
.flocks/flockshub/plugins/skills/Anthropic-Cybersecurity-Skills/
.flocks/flockshub/plugins/skills/ndr-alert-analysis/
.flocks/flockshub/plugins/tools/api/onesig_v2_5_3_D20250710/
.flocks/flockshub/plugins/tools/api/sangfor_af_v8_0_48/
.flocks/flockshub/plugins/tools/api/sangfor_af_v8_0_85/

# === 内置 agent 删除 ===
flocks/agent/agents/hephaestus/
flocks/agent/agents/metis/
flocks/agent/agents/momus/

# === SecOps 插件已移至独立仓库 ===
.flocks/plugins/agents/
.flocks/plugins/skills/ndr-alert-analysis/
.flocks/plugins/skills/onesec-use/
.flocks/plugins/skills/onesig-use/
.flocks/plugins/skills/qingteng-use/
.flocks/plugins/skills/skyeye-use/
.flocks/plugins/skills/skyeye-sensor-data-fetch/
.flocks/plugins/skills/tdp-use/
.flocks/plugins/tools/api/
.flocks/plugins/tools/mcp/
.flocks/plugins/tasks/
.flocks/plugins/workflows/

# === 代码工具移出 ===
flocks/tool/wecom/
flocks/tool/agent/call_omo_agent.py

# === IM 渠道删除 ===
flocks/channel/builtin/weixin/
flocks/channel/builtin/telegram/

# === CI / 脚本 ===
.github/workflows/sync-gitee.yml
scripts/validate_flockshub.py

# === 品牌资产 ===
assets/flocks.webp

# === npm wrapper 删除 ===
npm-wrapper/
```

### 10.5 `.upstream-sync/keep-ours.txt` 示例

```
# 这些文件在本仓库做了品牌/中文化深度改造，同步时始终保持本地版本
pyproject.toml
flocks/__init__.py
flocks/cli/main.py
flocks/cli/service_manager.py
flocks/cli/commands/update.py
flocks/agent/agents/rex/prompt_builder.py
flocks/agent/agents/rex/agent.yaml
flocks/agent/registry.py
flocks/config/config.py
AGENTS.md
README.md
README_zh.md
docker/Dockerfile
.github/workflows/docker-publish.yml
.github/workflows/ci.yml
packaging/windows/flocks-setup.iss
packaging/windows/staging-layout.json
webui/index.html
tui/package.json
```

### 10.6 `.upstream-sync/sync.sh` 关键逻辑（伪代码）

```bash
#!/usr/bin/env bash
set -euo pipefail

DATE=$(date +%Y%m%d)
BRANCH="upstream-sync/${DATE}"

git fetch upstream main
git checkout -b "${BRANCH}" main
git merge --no-commit --no-ff upstream/main || true

# 1. 清除黑名单路径（即使上游新加）
while IFS= read -r path; do
  [[ -z "${path}" || "${path}" == \#* ]] && continue
  git rm -rf --cached --ignore-unmatch "${path}" 2>/dev/null || true
  rm -rf "${path}" 2>/dev/null || true
done < .upstream-sync/exclude-paths.txt

# 2. 白名单路径强制使用本地版本
while IFS= read -r path; do
  [[ -z "${path}" || "${path}" == \#* ]] && continue
  git checkout HEAD -- "${path}" 2>/dev/null || true
done < .upstream-sync/keep-ours.txt

git add -A
git commit -m "chore: sync from upstream (${DATE})" || true
git push origin "${BRANCH}"
echo "请到 GitHub 为 ${BRANCH} 创建 PR 并 review 后合入 main"
```

### 10.7 `.github/workflows/upstream-guard.yml` CI 守卫

作用：任何 PR 合入 `main` 前，检查黑名单路径**不得**再次出现。

核心逻辑：

```yaml
name: Upstream Path Guard
on:
  pull_request:
    branches: [main]
jobs:
  guard:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
      - name: Check forbidden paths
        run: |
          while IFS= read -r path; do
            [[ -z "${path}" || "${path}" == \#* ]] && continue
            if [ -e "${path}" ]; then
              echo "::error::禁止路径 ${path} 再次出现"
              exit 1
            fi
          done < .upstream-sync/exclude-paths.txt
```

### 10.8 辅助措施

1. **`.gitignore` 强化**：黑名单路径同时加入 `.gitignore`，防止开发者手动误提交；
2. **定期巡检**：建议每月跑一次 `sync.sh`，即使无代码变更，也能及时发现上游的目录重命名/新增；
3. **上游目录重命名应对**：若上游把 `flocks/` 整体改名（可能性低），同步脚本会在 merge 阶段冲突——此时由人工决策；配合本地第 2 步的 `flocks/ → smartclaw/` 改名，我们已基本脱离上游目录结构，冲突面会非常小。

---

## 十一、关键决策（已确认）

| 编号 | 决策项 | 结果 | 影响 |
|---|---|---|---|
| 1 | 产品定位 | **选项 C**：通用核心 + SecOps 可选插件包 | SecOps 内容 MOVE 到独立插件仓库 |
| 2 | weixin / telegram IM 渠道 | **DEL**（直接删除） | 不在主仓库保留，也不搬迁 |
| 3 | npm-wrapper | **DEL** | 不继续维护 npm 发布通道 |

---

## 十二、完整删除与搬迁清单（附录）

> 本节列出**每一个具体的目录和文件**，可直接作为第 1 步执行脚本的输入。

### 12.1 DEL — 整目录删除

| # | 路径 | 类型 | 体积 | 说明 |
|---|---|---|---|---|
| 1 | `.flocks/flockshub/plugins/agents/pentest-ai-agents/` | 目录（37 子目录） | 860 KB | 社区渗透 subagent 集合 |
| 2 | `.flocks/flockshub/plugins/skills/Anthropic-Cybersecurity-Skills/` | 目录（755 子目录） | 38 MB | 社区 Cybersecurity skill 集合 |
| 3 | `flocks/agent/agents/hephaestus/` | 目录 | ~15 KB | 与 rex_junior 职责重叠 |
| 4 | `flocks/agent/agents/metis/` | 目录 | ~12 KB | 预规划顾问，Rex 可直接承担 |
| 5 | `flocks/agent/agents/momus/` | 目录 | ~13 KB | 计划评审，Rex 可直接承担 |
| 6 | `flocks/tool/wecom/` | 目录 | ~40 KB | 第 2 步后将移出；第 1 步先 MOVE |
| 7 | `flocks/channel/builtin/weixin/` | 目录（11 文件） | 100 KB | 个人微信渠道，主仓库不再维护 |
| 8 | `flocks/channel/builtin/telegram/` | 目录（8 文件） | 72 KB | 海外渠道，不保留 |
| 9 | `npm-wrapper/` | 目录（3 文件） | 12 KB | npx → uvx 转发壳，用户可直接装 uv |

### 12.2 DEL — 单文件删除

| # | 路径 | 说明 |
|---|---|---|
| 10 | `flocks/tool/agent/call_omo_agent.py` | 外部 OMO agent 调用，无业务依赖 |
| 11 | `.github/workflows/sync-gitee.yml` | Gitee 同步 workflow（不继续同步 Gitee） |
| 12 | `scripts/validate_flockshub.py` | bundled hub 删空后失效 |
| 13 | `assets/flocks.webp` | 旧品牌 logo，第 2 步替换 |

### 12.3 MOVE — 搬到 SecOps 插件仓库

> 目标仓库：`by2060/smartclaw-secops`（第 1 步前需新建）

#### 12.3.1 Bundled Hub（bundled 的 SecOps 插件）

| # | 路径 |
|---|---|
| M01 | `.flocks/flockshub/plugins/skills/ndr-alert-analysis/` |
| M02 | `.flocks/flockshub/plugins/tools/api/onesig_v2_5_3_D20250710/` |
| M03 | `.flocks/flockshub/plugins/tools/api/sangfor_af_v8_0_48/` |
| M04 | `.flocks/flockshub/plugins/tools/api/sangfor_af_v8_0_85/` |

#### 12.3.2 插件 Agents（8 个，整块搬迁）

| # | 路径 |
|---|---|
| M05 | `.flocks/plugins/agents/asset-survey/` |
| M06 | `.flocks/plugins/agents/host-forensics/` |
| M07 | `.flocks/plugins/agents/host-forensics-fast/` |
| M08 | `.flocks/plugins/agents/hrti_threat_intelligence/` |
| M09 | `.flocks/plugins/agents/ndr-analyst/` |
| M10 | `.flocks/plugins/agents/phishing-detector/` |
| M11 | `.flocks/plugins/agents/ti-analyst/` |
| M12 | `.flocks/plugins/agents/vul_threat_intelligence/` |

#### 12.3.3 插件 Skills（7 个，SecOps 专属）

| # | 路径 |
|---|---|
| M13 | `.flocks/plugins/skills/ndr-alert-analysis/` |
| M14 | `.flocks/plugins/skills/onesec-use/` |
| M15 | `.flocks/plugins/skills/onesig-use/` |
| M16 | `.flocks/plugins/skills/qingteng-use/` |
| M17 | `.flocks/plugins/skills/skyeye-sensor-data-fetch/` |
| M18 | `.flocks/plugins/skills/skyeye-use/` |
| M19 | `.flocks/plugins/skills/tdp-use/` |

#### 12.3.4 插件 Tools（19 个）

**API 工具（16 个）**

| # | 路径 |
|---|---|
| M20 | `.flocks/plugins/tools/api/fofa/` |
| M21 | `.flocks/plugins/tools/api/greynoise/` |
| M22 | `.flocks/plugins/tools/api/ngsoc_v4_15_1/` |
| M23 | `.flocks/plugins/tools/api/ngtip_v5_1_5/` |
| M24 | `.flocks/plugins/tools/api/onesec_v2_8_2/` |
| M25 | `.flocks/plugins/tools/api/onesig_v2_5_3_D20260321/` |
| M26 | `.flocks/plugins/tools/api/qingteng_v3_4_1_66/` |
| M27 | `.flocks/plugins/tools/api/sangfor_af_v8_0_106/` |
| M28 | `.flocks/plugins/tools/api/sangfor_sip_v92/` |
| M29 | `.flocks/plugins/tools/api/sangfor_xdr_v2_2/` |
| M30 | `.flocks/plugins/tools/api/skyeye_v4_0_14_0_SP2/` |
| M31 | `.flocks/plugins/tools/api/tdp_v3_3_10/` |
| M32 | `.flocks/plugins/tools/api/threatbook-cn/` |
| M33 | `.flocks/plugins/tools/api/threatbook-io/` |
| M34 | `.flocks/plugins/tools/api/urlscan/` |
| M35 | `.flocks/plugins/tools/api/virustotal/` |

**MCP 工具（3 个）**

| # | 路径 |
|---|---|
| M36 | `.flocks/plugins/tools/mcp/nsfocus_mcp.yaml` |
| M37 | `.flocks/plugins/tools/mcp/qianxin_mcp.yaml` |
| M38 | `.flocks/plugins/tools/mcp/threatbook_mcp.yaml` |

#### 12.3.5 Tasks / Workflows

| # | 路径 |
|---|---|
| M39 | `.flocks/plugins/tasks/daily-intel.yaml` |
| M40 | `.flocks/plugins/workflows/loop_host_forensics_fast/` |
| M41 | `.flocks/plugins/workflows/tdp_alert_triage/` |

### 12.4 SHRINK — 保留但精简

| # | 路径 | 操作 |
|---|---|---|
| S01 | `.flocks/flockshub/index.json` | bundled hub 删减后重新生成 |
| S02 | `.flocks/flockshub/taxonomy.json` | 同上 |
| S03 | `.flocks/plugins/skills/onboarding/` | 文案强耦合品牌，第 2/3/4 步逐步重写 |
| S04 | `.github/workflows/ci.yml` | 移除 `validate_flockshub.py` 步骤 |
| S05 | `.github/workflows/docker-publish.yml` | 第 2 步改镜像名 |
| S06 | `.github/workflows/windows-packaging.yml` | 第 2 步改 artifact 名 |
| S07 | `.github/workflows/windows-packaging-publish.yml` | 同上 |
| S08 | `.github/ISSUE_TEMPLATE/plugin_request.yml` | 去品牌化 |
| S09 | `flocks/cli/commands/stats.py` | 可简化展示逻辑 |
| S10 | 根目录 `install.sh` / `install.ps1` / `install_zh.sh` / `install_zh.ps1` | 第 2 步统一处理品牌 |
| S11 | `scripts/install.sh` / `install.ps1` / `install_zh.sh` / `install_zh.ps1` | 同上 |
| S12 | `packaging/windows/flocks-setup.iss` | 第 2 步改安装器名 |
| S13 | `packaging/windows/uninstall-flocks-user-state.ps1` | 第 2 步改名 |
| S14 | `packaging/windows/start-flocks-elevated.ps1` | 第 2 步改名 |
| S15 | `packaging/windows/staging-layout.json` | 第 2 步改路径变量 |
| S16 | `scripts/recover_raw_flocks_db.py` | 第 2 步改名 |
| S17 | `assets/community-wecom-qr.png` | 二维码内容更换为 smartClaw 社区入口 |

### 12.5 KEEP — 保留（通用核心）

保留的核心内容概览，不需逐条列出：

- **内置 Agents**：`rex`、`rex_junior`、`explore`、`plan`、`self_enhance`、`multimodal_looker`、`oracle`、`librarian` —— 第 3 步主 agent 改名为 `sentry`、`sentry_junior`
- **代码工具** `flocks/tool/`：除 9.3.7 标注外，其余全部保留（约 35 个通用工具）
- **IM 渠道**：`flocks/channel/` 框架代码 + `builtin/feishu`、`builtin/wecom`、`builtin/dingtalk`
- **核心模块**：`server/`、`session/`、`provider/`、`mcp/`、`memory/`、`workflow/`、`task/`、`skill/`、`plugin/`、`browser/`、`acp/`、`auth/`、`config/` 等
- **CLI 子命令**：`session`、`admin`、`skill`、`mcp`、`task`、`update`、`browser`、`acp`、`export`、`import`、`agent`、`debug`
- **前端**：`webui/`、`tui/`
- **打包**：`docker/`、`packaging/windows/`（内容精简）
- **脚本**：`scripts/migrate_legacy_task_tables.py`、`run_legacy_task_migration.sh`、`dev.sh`、`container-start.sh`、`run-tests.py` 等

### 12.6 执行顺序建议

| 序号 | 动作 | 依赖 |
|---|---|---|
| Step 0 | 新建 `by2060/smartclaw-secops` 仓库（用于接收 MOVE 内容） | 无 |
| Step 1 | 在当前仓库建立 `.upstream-sync/` 目录与 `upstream-guard.yml` CI | 无（可先做） |
| Step 2 | 执行 MOVE（12.3）—— 将 SecOps 内容搬到 smartclaw-secops，本地 `git rm` | Step 0 |
| Step 3 | 执行 DEL（12.1 + 12.2）—— 删除冗余目录和文件 | Step 1（保证 CI 守卫到位） |
| Step 4 | 执行 SHRINK（12.4）—— 精简保留内容（可在第 2/3/4 步陆续完成） | 第 2 步改名时顺带 |

---

## 十三、接下来的动作

确认无误即可开始执行 **Step 1（建立 `.upstream-sync/` + CI 守卫）**，这一步不依赖外部插件仓库的建立，可以立刻开工。

**对应 PR 计划**：

- **PR#1（立即可做）**：建立 `.upstream-sync/exclude-paths.txt` + `keep-ours.txt` + `sync.sh` + `upstream-guard.yml`
- **PR#2**（需先建 smartclaw-secops 仓库）：执行 MOVE 清单（M01-M41）
- **PR#3**：执行 DEL 清单（#1-#13）
- **PR#4**：执行必要的 SHRINK（跟随第 2 步品牌改造一起做）




---

## 十四、顶层目录与被遗漏路径的补充评估（v1.1 补充）

> 前九章仅聚焦 `flocks/` Python 包与 `.flocks/` 插件目录，未覆盖仓库顶层的 `docker/`、`tests/`、`tui/`、`webui/`、`scripts/`、`packaging/`、`docs/`、根目录配置文件等。本章将这些补齐，形成真正的"全集"。

### 14.1 根目录文件评估

| 路径 | 操作 | 说明 |
|---|---|---|
| `AGENTS.md` | **KEEP → SHRINK（B 步改写，C 步翻译）** | Sentry 全局指令，23 处 flocks 引用 |
| `LICENSE.txt` | **KEEP** | 无品牌字符串 |
| `Makefile` | **KEEP** | 1 处 `flocks` 字样，第 2 步品牌替换 |
| `pyproject.toml` | **KEEP** | 6 处，第 2 步包名/entry_point 替换 |
| `README.md` / `README_zh.md` | **KEEP**（第 2 步大改 + C 步翻译） | 49/47 处 flocks |
| `uv.lock` | **KEEP** | 第 2 步 `uv sync` 自动重新生成 |
| `.gitignore` | **KEEP**（SHRINK） | 引用 `.flocks/` 路径，第 2 步改 + 加入 exclude 黑名单 |
| `.dockerignore` | **KEEP**（SHRINK） | 同上，含 `.flocks/*.db` 等路径 |
| `.gitattributes` | **KEEP** | 无品牌字符串 |
| `install.sh` / `install.ps1` | **KEEP**（第 2 步改品牌） | 12/18 处 flocks |
| `install_zh.sh` / `install_zh.ps1` | **KEEP**（第 2 步改品牌） | 22/38 处 flocks |

### 14.2 docker/ 目录

| 路径 | 操作 | 说明 |
|---|---|---|
| `docker/Dockerfile` | **KEEP**（第 2 步深度改品牌） | 2.6 KB，16 处 `FLOCKS_*` 环境变量 + `/opt/flocks` 等路径 + `flocks` 用户名 + `VITE_APP_NAME=Flocks` |

### 14.3 docs/ 目录

| 路径 | 操作 | 说明 |
|---|---|---|
| `docs/CONTRIBUTING.md` | **KEEP**（第 2 步改品牌 + C 步翻译） | 4 处 flocks |
| `docs/rebrand-design.md` | **KEEP** | 本文档 |

### 14.4 scripts/ 目录全集（之前只提了 4 个，现在共 11 个）

| # | 路径 | 操作 | 说明 |
|---|---|---|---|
| SCR01 | `scripts/validate_flockshub.py` | **DEL**（已列，再次重申） | bundled hub 删空后无用 |
| SCR02 | `scripts/container-start.sh` | **KEEP**（第 2 步） | `/opt/flocks`、`FLOCKS_*` 需改 |
| SCR03 | `scripts/dev.sh` | **KEEP**（第 2 步） | `uvicorn flocks.server.app:app`、`_FLOCKS_WEBUI_*` 需改 |
| SCR04 | `scripts/serve_webui.py` | **KEEP** | 带 SPA fallback 的 WebUI 静态服务，无品牌耦合 |
| SCR05 | `scripts/install.sh` | **KEEP**（第 2 步） | 32 KB，大量 `FLOCKS_INSTALL_*` |
| SCR06 | `scripts/install.ps1` | **KEEP**（第 2 步） | 46 KB，Windows PS 版本 |
| SCR07 | `scripts/install_zh.sh` | **KEEP**（第 2 步） | 中文国内镜像版 |
| SCR08 | `scripts/install_zh.ps1` | **KEEP**（第 2 步） | 同上 |
| SCR09 | `scripts/migrate_legacy_task_tables.py` | **KEEP** | 数据迁移，需评估是否仍有调用 |
| SCR10 | `scripts/run_legacy_task_migration.sh` | **KEEP** | 配套 SCR09 |
| SCR11 | `scripts/recover_raw_flocks_db.py` | **KEEP**（第 2 步改名为 `recover_raw_smartclaw_db.py`） | 数据库灾难恢复工具 |

> 注：根目录的 `install.sh` / `install.ps1` / `install_zh.sh` / `install_zh.ps1` 与 `scripts/` 下同名文件为"一键在线安装入口"与"离线落地安装"两套，都保留但品牌要同步替换。

### 14.5 packaging/windows/ 目录全集（之前只提了 3 个，现在共 9 个）

| # | 路径 | 操作 | 说明 |
|---|---|---|---|
| PKG01 | `packaging/README.md` | **KEEP**（第 2 步品牌改写） | Windows 打包说明 |
| PKG02 | `packaging/windows/flocks-setup.iss` | **SHRINK** | Inno Setup 脚本，第 2 步改名为 `smartclaw-setup.iss` |
| PKG03 | `packaging/windows/bootstrap-windows.ps1` | **KEEP**（第 2 步） | 安装引导，含 `FLOCKS_*` 变量 |
| PKG04 | `packaging/windows/build-installer.ps1` | **KEEP**（第 2 步） | 调用 Inno Setup 打 exe |
| PKG05 | `packaging/windows/build-staging.ps1` | **KEEP**（第 2 步） | 搭 staging 目录，含 `FLOCKS_INSTALL_ROOT` 等 |
| PKG06 | `packaging/windows/staging-layout.json` | **KEEP**（第 2 步） | 安装目录布局 |
| PKG07 | `packaging/windows/versions.manifest.json` | **KEEP** | 版本清单 |
| PKG08 | `packaging/windows/DOWNLOAD-HOSTING.txt` | **SHRINK** | 下载镜像说明，品牌替换 |
| PKG09 | `packaging/windows/start-flocks-elevated.ps1` | **SHRINK** | 第 2 步改名为 `start-smartclaw-elevated.ps1` |
| PKG10 | `packaging/windows/uninstall-flocks-user-state.ps1` | **SHRINK** | 同上改名 |

### 14.6 tui/ 目录（TypeScript TUI，3.4 MB）

> ⚠️ 这是个值得单独决策的大件：113 处 flocks 引用，38 个子目录，package 名 `flocks-tui`。

**背景**：
- `tui/flocks/` 是**早期 TypeScript 版 Flocks 的完整移植**，作为 TUI 的底层实现依赖
- 与 Python 主包通过 `flocks tui` 子命令 + 本地 HTTP API 通信
- 若放弃 TUI，可整个 `tui/` DEL；若保留 TUI，需要 3.4 MB TS 代码做品牌替换

**建议分两种情形决策**：

| 情形 | 操作 | 理由 |
|---|---|---|
| A. 保留 TUI 界面（终端用户需要） | **KEEP + 第 2 步改名 `tui/flocks/` → `tui/smartclaw/`** | TUI 是 CLI 用户的主要交互方式，不建议弃用 |
| B. 仅保留 WebUI，不维护 TUI | **DEL 整个 tui/** | 3.4 MB 代码 + 113 处 flocks → smartclaw 替换是大工程 |

#### 14.6.1 若保留 TUI，需处理的路径

| 路径 | 操作 |
|---|---|
| `tui/flocks/` （38 个子目录） | **RENAME → `tui/smartclaw/`**（第 2 步） |
| `tui/sdk/` | **KEEP**（第 2 步内部 import 替换） |
| `tui/util/` | **KEEP**（第 2 步内部 import 替换） |
| `tui/src/index.ts` | **KEEP**（第 2 步品牌替换） |
| `tui/package.json` | **KEEP**（第 2 步改 `"name": "smartclaw-tui"`） |
| `tui/README.md` | **KEEP**（第 2 步 + C 步翻译） |
| `tui/tsconfig.json` / `tui/bunfig.toml` | **KEEP**（第 2 步路径别名替换） |
| `tui/bun.lock` | **KEEP**（自动重新生成） |

**请在进入第 1 步前确认：tui 保留（情形 A）或删除（情形 B）？**

### 14.7 webui/ 目录（React + Vite，5.1 MB）

> 品牌替换 + 翻译的主战场之一，76 处 flocks 引用。

| 路径 | 操作 | 说明 |
|---|---|---|
| `webui/src/App.tsx` / `main.tsx` | **KEEP**（第 2 步） | |
| `webui/src/pages/`（24 个页面） | **KEEP**（第 2 步 + C 步翻译） | AdminUsers/Agent/Channel/... 等 |
| `webui/src/components/layout/Layout.tsx` | **KEEP**（第 2 步） | Header 中 `Flocks` 品牌字样 |
| `webui/src/locales/en-US/*.json` | **KEEP**（第 2 步品牌替换） | 8 个 i18n 字典 |
| `webui/src/locales/zh-CN/*.json` | **KEEP**（第 2 步品牌替换） | 同上中文版 |
| `webui/src/i18n.ts` | **KEEP** | i18n 基础设施 |
| `webui/src/api/` / `hooks/` / `utils/` | **KEEP**（第 2 步 import 路径替换） | |
| `webui/index.html` | **KEEP**（第 2 步改 `<title>`） | `<title>Flocks - AI Native SecOps Platform</title>` |
| `webui/package.json` | **KEEP**（第 2 步改 `"name"`） | |
| `webui/public/favicon.svg` | **KEEP**（第 2 步建议换 logo） | |
| `webui/public/vite.svg` | **KEEP** | Vite 自带 |
| `webui/public/gitee-logo.png` | **SHRINK**（若不再用 Gitee 则删） | |
| `webui/public/channel-feishu.png` | **KEEP** | 飞书引导图 |
| `webui/public/channel-wecom.png` | **KEEP** | 企微引导图 |
| `webui/public/channel-dingtalk.png` | **KEEP** | 钉钉引导图 |
| `webui/public/channel-weixin.png` | **DEL** | 对应已 DEL 的 weixin 渠道 |
| `webui/public/channel-telegram.png` | **DEL** | 对应已 DEL 的 telegram 渠道 |
| `webui/public/feishu-bot-guide.pdf` | **KEEP** | 1.1 MB 飞书机器人引导 |
| `webui/public/wecom-bot-guide.pdf` | **KEEP** | 779 KB 企微机器人引导 |
| `webui/public/dingtalk-channel-guide.pdf` | **KEEP** | 290 KB 钉钉引导 |
| `webui/vite.config.ts` / `vitest.config.ts` | **KEEP** | |
| `webui/eslint.config.js` / `postcss.config.js` / `tailwind.config.js` | **KEEP** | |
| `webui/.env.example` | **KEEP**（第 2 步改变量前缀） | |

### 14.8 tests/ 目录（Python 测试套件，3.6 MB，38 子目录，282 个测试文件）

> **268/282 个测试文件含 flocks 引用**，第 2 步 import 替换时必须同步改。

#### 14.8.1 整体策略

- **268 个含 `from flocks...` 的测试文件**：第 2 步跟随主代码 import 替换（批量 sed）
- **部分测试因 DEL 而失效**，需要删除对应测试文件（见 14.8.2）
- **测试目录结构整体保留**

#### 14.8.2 需要删除的测试（跟随 DEL/MOVE）

| # | 测试路径 | DEL 原因 |
|---|---|---|
| T01 | `tests/hub/test_bundled_tools.py` | 对应 `scripts/validate_flockshub.py` DEL 和 bundled hub 清空 |
| T02 | `tests/hub/test_hub_catalog.py` | 同上 |
| T03 | `tests/channel/test_weixin.py`（如有） | 对应 weixin 渠道 DEL |
| T04 | `tests/channel/test_telegram.py` | 对应 telegram 渠道 DEL |
| T05 | `tests/mcp/test_mcp_threatbook_demo.py` | SecOps 依赖，MOVE 到插件仓库 |
| T06 | `tests/skill/test_skyeye_project_skills.py` | 对应 skyeye 系列 skill MOVE |
| T07 | `tests/skill/test_product_use_project_skills.py` | SecOps 厂商 skill 测试，评估后 MOVE |
| T08 | `tests/skill/test_onboarding_skill.py` | `onboarding/` SHRINK 需重写，测试同步重写 |
| T09 | `tests/skill/test_onboarding_status.py` | 同上 |

#### 14.8.3 需要评估删除的测试目录

| 路径 | 评估结论 |
|---|---|
| `tests/docker/` | **KEEP**（Dockerfile 回归测试） |
| `tests/packaging/` | **KEEP**（Windows 安装器回归测试） |
| `tests/integration/` | **KEEP** |
| `tests/cli/`、`tests/server/`、`tests/session/` 等主流程目录 | **KEEP**（核心回归） |
| `tests/conftest.py` | **KEEP** |

---

## 十五、v1.1 补充后删减总量重算

| 分类 | DEL | MOVE | 备注 |
|---|---|---|---|
| Bundled Hub | 2 大目录（~290 项） | 4 项 | 不变 |
| 内置 Agents | 3 | 0 | 不变 |
| 插件 Agents | 0 | 8 | 不变 |
| 插件 Skills | 0 | 7 | 不变 |
| 插件 Tools | 0 | 19 | 不变 |
| 插件 Tasks/Workflows | 0 | 3 | 不变 |
| 代码工具 | 1 | 1 | 不变 |
| IM 渠道 | 2 | 0 | 不变 |
| CI / 脚本 | 2 | 0 | 不变 |
| Assets | 1 | 0 | 不变 |
| npm-wrapper | 1 整目录 | 0 | 不变 |
| **webui/public 图标** | **2（channel-weixin.png / channel-telegram.png）** | 0 | **v1.1 新增** |
| **tests（DEL 失效测试）** | **9（T01-T09）** | 0 | **v1.1 新增** |
| **tui/（若选情形 B）** | **1 大目录（~3.4 MB）** | 0 | **待决策** |
| **合计（不含 tui 情形 B）** | **~310 项** | **~42 项** | **~41 MB** |
| **合计（含 tui 情形 B）** | **~311 项** | **~42 项** | **~44 MB** |

---

## 十六、v1.1 版执行清单补丁

原第 12.1-12.4 清单保持不变，在其后追加以下条目：

### 16.1 额外 DEL

| # | 路径 | 说明 |
|---|---|---|
| 14 | `webui/public/channel-weixin.png` | 对应 weixin 渠道 DEL |
| 15 | `webui/public/channel-telegram.png` | 对应 telegram 渠道 DEL |
| 16 | `tests/hub/test_bundled_tools.py` | hub 删空后失效 |
| 17 | `tests/hub/test_hub_catalog.py` | 同上 |
| 18 | `tests/channel/test_weixin.py`（如存在） | 对应渠道 DEL |
| 19 | `tests/channel/test_telegram.py` | 对应渠道 DEL |
| 20 | `tests/mcp/test_mcp_threatbook_demo.py` | SecOps 依赖 MOVE |
| 21 | `tests/skill/test_skyeye_project_skills.py` | SecOps skill MOVE |
| 22 | `tests/skill/test_product_use_project_skills.py` | SecOps skill MOVE |
| 23 | `tests/skill/test_onboarding_skill.py` | onboarding 将重写 |
| 24 | `tests/skill/test_onboarding_status.py` | 同上 |
| 25 | `tui/`（整目录，若选情形 B） | **待决策**：是否放弃 TUI 界面 |

### 16.2 额外 SHRINK（第 2 步执行，非 Step 1）

| 路径 | 操作 |
|---|---|
| `docker/Dockerfile` | 品牌替换（16 处） |
| `docs/CONTRIBUTING.md` | 品牌替换（4 处） |
| 根目录 `Makefile` / `pyproject.toml` / `install*.{sh,ps1}` / `LICENSE.txt` | 品牌替换 |
| `.gitignore` / `.dockerignore` | 路径与注释替换 |
| 全部 11 个 `scripts/*` 脚本 | 路径+品牌替换 |
| 全部 10 个 `packaging/windows/*` 文件 | 路径+品牌替换 |
| `webui/` 全量 | import 路径 + i18n 字典 + title 品牌替换 |
| `tui/flocks/` → `tui/smartclaw/`（若选情形 A） | 整目录重命名 |
| `tests/` 中 268 个测试的 `from flocks...` | 批量替换 |

### 16.3 新增 `.upstream-sync/exclude-paths.txt` 条目

```
# === v1.1 补充：对应已 DEL 的 IM 渠道图标 ===
webui/public/channel-weixin.png
webui/public/channel-telegram.png

# === v1.1 补充：对应已 DEL 的测试 ===
tests/hub/test_bundled_tools.py
tests/hub/test_hub_catalog.py
tests/mcp/test_mcp_threatbook_demo.py
tests/skill/test_skyeye_project_skills.py
tests/skill/test_product_use_project_skills.py
tests/skill/test_onboarding_skill.py
tests/skill/test_onboarding_status.py

# === v1.1 待决策：若选情形 B 则启用 ===
# tui/
```

### 16.4 新增 `.upstream-sync/keep-ours.txt` 条目

```
# === v1.1 补充：webui i18n 字典 + 品牌字符串 ===
webui/index.html
webui/src/locales/en-US/common.json
webui/src/locales/zh-CN/common.json
webui/src/components/layout/Layout.tsx

# === v1.1 补充：tui 若保留则全量保持本地版本 ===
tui/package.json
tui/src/index.ts
tui/README.md

# === v1.1 补充：安装脚本（内嵌大量 FLOCKS_* 环境变量，第 2 步深度改造）===
install.sh
install.ps1
install_zh.sh
install_zh.ps1
scripts/install.sh
scripts/install.ps1
scripts/install_zh.sh
scripts/install_zh.ps1
scripts/container-start.sh
scripts/dev.sh
scripts/recover_raw_flocks_db.py

# === v1.1 补充：Windows 打包 ===
packaging/README.md
packaging/windows/bootstrap-windows.ps1
packaging/windows/build-installer.ps1
packaging/windows/build-staging.ps1
packaging/windows/versions.manifest.json
packaging/windows/DOWNLOAD-HOSTING.txt
```

---

## 十七、新增待确认决策（1 项）

| 编号 | 决策项 | 选项 |
|---|---|---|
| 4 | **`tui/` 是否保留？** | A：保留（改名 `tui/smartclaw/`，工作量大）<br>B：整体 DEL（3.4 MB TS 代码不再维护） |

> 其他已覆盖：产品定位 C / weixin+telegram DEL / npm-wrapper DEL。确认 tui 情形后第 1 步即可开工。
