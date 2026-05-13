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
| `npm-wrapper/` | **EVAL（待确认）** | 若不发 npm 包可整体 **DEL** |

#### 9.3.11 Assets & 品牌资源

| 路径 | 操作 |
|---|---|
| `assets/flocks.webp` | **DEL**（第 2 步替换 logo） |
| `assets/community-wecom-qr.png` | **KEEP**（社区二维码可替换内容） |

### 9.4 删减总量统计

| 分类 | DEL | MOVE | 节省 |
|---|---|---|---|
| Bundled Hub | 2 大目录（~290 项） | 4 项 | ~38 MB |
| 内置 Agents | 3 | 0 | ~40 KB |
| 插件 Agents | 0 | 8 | ~160 KB |
| 插件 Skills | 0 | 7 | ~400 KB |
| 插件 Tools | 0 | 19 | ~1.2 MB |
| 插件 Tasks/Workflows | 0 | 3 | ~30 KB |
| 代码工具 | 1 | 1 | 少量 |
| IM 渠道 | 0 | 2 | ~170 KB |
| CI / 脚本 | 2 | 0 | 少量 |
| Assets | 1 | 0 | ~800 KB |
| **合计** | **~296 项** | **~44 项** | **~40 MB** |

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

# === IM 渠道移出 ===
flocks/channel/builtin/weixin/
flocks/channel/builtin/telegram/

# === CI / 脚本 ===
.github/workflows/sync-gitee.yml
scripts/validate_flockshub.py

# === 品牌资产 ===
assets/flocks.webp
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
npm-wrapper/package.json
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

## 十一、需最终确认的三件事

1. **产品定位选项 C 是否确认**（通用核心 + SecOps 可选插件包）？
2. **weixin / telegram 两个 IM 渠道**：`MOVE` 到插件包？还是直接 `DEL`？
3. **npm-wrapper 是否保留**：继续发 npm 包？还是直接 `DEL`？

确认后即可进入第 1 步执行，产出预计 3 个 PR：

- **PR#1**：建立 `.upstream-sync/` 机制 + `upstream-guard.yml` CI
- **PR#2**：执行 DEL 清单（bundled hub + 内置 agent + 脚本）
- **PR#3**：执行 MOVE 清单（SecOps 内容搬到独立插件仓库，需先建立该仓库）
