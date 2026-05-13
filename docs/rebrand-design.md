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
