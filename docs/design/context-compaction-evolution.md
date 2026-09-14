# Context Compaction 演进全景（v1 → v2 → 正确性修复）

> 仓库：`AgentFlocks/flocks`（已同步到当前 `by2060/flocks`）  
> 目标：梳理上下文压缩机制的系统性升级与细节打磨，覆盖代码级实现、协议、策略、影响范围与兼容性。

## 1. 演进路线总览

| 阶段 | 时间 | 里程碑 | 核心目标 |
|---|---:|---|---|
| v1 基础压缩 | 2026-04-07 起 | `1a7d5f37`（explicit compaction orchestration） | 建立独立压缩编排链路（显式 `run_compaction`） |
| v1 性能/可观测性增强 | 2026-04-20 | PR #147 `perf/context-compaction` | 把长耗时压缩过程阶段化、可观测化（SSE + 前端进度） |
| v2 机制升级 | 2026-05-26 | PR #321 `feat/context-compaction-v2` | 引入迭代式摘要框架、分层策略、预剪枝与更强容错 |
| v2 精修（正确性） | 2026-06-12 | `7c11839a` | 仅压缩“摘要边界之后增量消息”，避免重复压缩 |
| 正确性修复（主动压缩） | 2026-08-12 | PR #699 `fix(compaction): account for post-call tool results` | 修复 provider usage 漏算“模型调用后新增上下文”问题 |

---

## 2. 阶段 A：v1 基础压缩（显式编排）

### 2.1 关键提交
- `1a7d5f37` `feat(session): add explicit compaction orchestration`
  - 变更规模：**7 files changed, +683 / -83**
  - 关键文件：
    - `flocks/session/lifecycle/compaction/orchestrator.py`
    - `flocks/session/lifecycle/compaction/compaction.py`
    - `flocks/server/routes/session.py`
    - `flocks/session/session_loop.py`

### 2.2 代码级新增能力
- 编排入口：
  - `run_compaction(...) -> Literal["continue", "stop", "skipped"]`
- 压缩执行体：
  - `SessionCompaction.process(...)`
- 主流程开始从“隐式/分散触发”收敛为“编排器统一调度 + 状态切换”。

### 2.3 兼容性
- 向后兼容：保留会话循环触发路径，仅新增显式编排入口。
- 向前兼容：为后续 SSE 进度、策略分层、迭代摘要提供固定扩展点。

---

## 3. 阶段 B：PR #147（可观测性与交互体验升级）

### 3.1 PR 规模
- PR #147（2026-04-20）
- **12 files, +2248 / -63**

### 3.2 后端协议升级（SSE）
- 新事件：`session.compaction_progress`
- 事件载荷（由后端统一发布）：
  - `sessionID`
  - `stage`（`load | strategy | chunk_done | merge_started | merge_done | summarize_done | complete`）
  - `data`（各阶段结构化字段）

相关代码：
- `flocks/server/routes/session.py:3448`
  - `progress_callback(stage, data)` 桥接到 `event_publish_callback("session.compaction_progress", ...)`
- `flocks/session/session_loop.py:1527`, `1974`
  - 自动压缩与 overflow 压缩路径均接入进度回调
- `flocks/session/lifecycle/compaction/compaction.py:300`
  - `_emit_progress(...)` 容错发布（观测失败不影响正确性）

### 3.3 前端消费协议升级
- `webui/src/features/session-chat/sseActions.ts:13`
  - 新增 `CompactionStage` 联合类型
- `webui/src/features/session-chat/sseActions.ts:123`
  - `session.compaction_progress` → `kind: 'compaction-progress'`
- `webui/src/components/common/SessionChat.tsx:2658`
  - 事件落地与分块去重（按 `chunk` 索引去重）
- `webui/src/components/common/SessionChat.tsx:1964`
  - 统一权重式阶段进度条计算

### 3.4 兼容性
- 不破坏既有 `session.status` 语义；新增独立事件类型，老消费者可忽略。

---

## 4. 阶段 C：PR #321（v2 机制升级）

### 4.1 PR 规模
- PR #321（2026-05-26）
- **29 files, +4002 / -939**

> 注：该 PR 混入了少量非 compaction 主题改动（如 channel slash 解析、tool output 配置化）。以下仅提取 compaction 主链。

### 4.2 v2 的核心结构升级（代码级）

#### 4.2.1 迭代式摘要（E1/E2）
- `flocks/session/lifecycle/compaction/summary.py`
  - `build_iterative_prompt(prompt_text, previous_summary)`
  - `summarize_chunked_iterative(..., previous_summary: Optional[str] = None)`
  - `summarize_chunked(...)` 作为兼容包装转发至 iterative 实现
- `flocks/session/lifecycle/compaction/models.py`
  - `DEFAULT_COMPACTION_PROMPT_WITH_PREVIOUS`
  - `ITERATIVE_SUMMARY_REBUILD_INTERVAL = 5`
- `flocks/session/lifecycle/compaction/compaction.py`
  - `_get_iterative_summary_state(session_id)`
  - `_store_iterative_summary_state(session_id, summary_text, count)`
  - `_should_force_full_rebuild(count)`

含义：新一轮压缩可复用上一轮摘要，仅处理增量语义，降低提示词膨胀和漂移风险（每 N 轮强制全量重建）。

#### 4.2.2 分层策略与阈值体系（B1）
- `flocks/session/lifecycle/compaction/policy.py`
  - `ContextTier`（`SMALL/MEDIUM/LARGE/XLARGE`）
  - `CompactionPolicy.from_model(...)`
  - `MAX_OUTPUT_RATIO_THRESHOLD = 0.7`
  - `SAFE_OUTPUT_RATIO = 0.25`
  - 固定阈值路径：`overflow_threshold = int(context_window * 0.85)`（可 override）

含义：把“是否压缩、压缩预算、预清理窗口、保留尾部”统一收敛到可计算策略对象。

#### 4.2.3 预剪枝与工具结果保留策略（T1/T2/T3）
- `flocks/session/lifecycle/compaction/models.py`
  - `TOOL_PRUNE_POLICY`
  - `resolve_tool_preserve_turns(tool_name)`
- `flocks/session/lifecycle/compaction/pruning.py`
  - `prune(session_id, ..., policy=...)`
  - `truncate_oversized_tool_outputs(session_id, context_window_tokens)`

含义：由“粗粒度 token 保护”演进为“按工具类型 + user-turn 窗口”的细粒度保留；对超大 tool output 提供两段式收缩。

#### 4.2.4 反抖与容错（E4/E5/E6）
- `flocks/session/lifecycle/compaction/compaction.py`
  - `CompactionHistory`（无效压缩计数、冷却窗口）
- `flocks/session/lifecycle/compaction/orchestrator.py`
  - 主压缩后追加 `post-prune`，降低下一轮立刻再触发概率
- `flocks/session/prompt.py`
  - message 级 token 缓存及失效机制（与 prune/truncate 联动）

### 4.3 兼容性
- 对外命令与会话入口保持兼容（`/compact` 仍可用）。
- 通过 `summarize_chunked` 兼容壳保留旧调用点 ABI。

---

## 5. 阶段 D：v2 后续精修（摘要边界正确性）

### 5.1 关键提交
- `7c11839a` `fix(session): compact only new turns after summary`
  - 规模：**3 files, +417 / -13**

### 5.2 代码级修复点
- `flocks/session/lifecycle/compaction/compaction.py`
  - `_is_summary_message(...)`
  - `_latest_summary_boundary(...)`
  - `_is_compaction_control_message(...)`

含义：以“最近 summary 边界”为切分点，仅压缩边界后的新增消息，避免重复处理旧历史导致摘要污染或冗余。

---

## 6. 阶段 E：PR #699（主动压缩正确性修复）

### 6.1 PR 规模
- PR #699（2026-08-12）
- **4 files, +338 / -57**

### 6.2 根因
旧逻辑过度依赖 provider 回传 usage；但该 usage 只覆盖“模型调用时刻”，无法覆盖“调用后新增 tool results / 后续消息”，导致 near-overflow 误判。

### 6.3 代码级修复
- `flocks/session/prompt.py:563`
  - 新增 `estimate_tool_result_tokens(session_id, message_id)`
- `flocks/session/session_loop.py:1636`
  - 新增 `_estimate_effective_tokens()`：
    - 路径1：`reported_total + (tool_result_delta + later_messages_delta)`
    - 路径2：fallback 到全量估算
- `flocks/session/session_loop.py:1705`
  - pre-compact cleanup 后二次估算并重检阈值

### 6.4 兼容性
- 行为兼容：无接口破坏；仅修正 overflow 判定准确性。
- 结果变化：更早、更稳定地触发清理/压缩，减少“明明超限却未压缩”的漏判。

---

## 7. 前后端协议与配置策略变更清单

### 7.1 协议（SSE）
| 项 | 变更 |
|---|---|
| 新事件类型 | `session.compaction_progress` |
| 核心字段 | `sessionID`, `stage`, `data` |
| 前端动作 | `compaction-progress`（`sseActions.ts`） |
| 兼容策略 | 保留 `session.status`，新增独立事件，不覆写旧语义 |

### 7.2 策略/常量（代表性）
| 文件 | 项 | 说明 |
|---|---|---|
| `policy.py` | `ContextTier` | 按模型上下文窗口分层 |
| `policy.py` | `overflow_threshold` | 默认 `context_window * 0.85` |
| `policy.py` | `MAX_OUTPUT_RATIO_THRESHOLD/SAFE_OUTPUT_RATIO` | provider 元数据异常保护 |
| `models.py` | `TOOL_PRUNE_POLICY` | 工具级保留窗口 |
| `models.py` | `ITERATIVE_SUMMARY_REBUILD_INTERVAL` | 迭代摘要定期全量重建 |
| `summary.py` | `build_iterative_prompt` | 复用上轮摘要模板 |
| `pruning.py` | `truncate_oversized_tool_outputs` | 超大工具输出压缩 |

---

## 8. 影响分析（文件、行数、兼容性）

### 8.1 PR 级别
| PR | 时间 | 文件数 | 新增/删除 | 兼容性结论 |
|---|---:|---:|---:|---|
| #147 | 2026-04-20 | 12 | +2248 / -63 | 新增事件通道，向后兼容 |
| #321 | 2026-05-26 | 29 | +4002 / -939 | 机制升级较大，但通过兼容包装维持调用稳定 |
| #699 | 2026-08-12 | 4 | +338 / -57 | 无接口破坏，纯正确性修复 |

### 8.2 核心文件影响（按阶段）
- #147：
  - `compaction.py` (+672/-10)
  - `summary.py` (+275/-42)
  - `session.py route` (+46/-6)
  - `session_loop.py` (+37/-2)
  - `SessionChat.tsx` (+187/-1)
- #321（compaction 主链）：
  - `compaction.py` (+561/-163)
  - `summary.py` (+504/-250)
  - `models.py` (+128/-0)
  - `policy.py` (+85/-23)
  - `pruning.py` (+59/-17)
  - `prompt.py` (+159/-98)
  - `session_loop.py` (+153/-40)
- #699：
  - `prompt.py` (+44/-0)
  - `session_loop.py` (+145/-56)

---

## 9. “约 82 个细节提交”校验结论

基于本仓库本地历史的核心路径统计（`flocks/session/lifecycle/compaction` + `flocks/session/session_loop.py` + `flocks/session/prompt.py`），可见 **79 个相关提交**，与“约 82”同量级，说明除 3 个主 PR 外确实存在大量连续打磨（性能、容错、UI、边界条件、测试补齐）。

---

## 10. 结论

上下文压缩机制不是单点 PR，而是“**编排基础化 → 可观测化 → 机制升级（v2）→ 正确性闭环**”的持续工程：
- #147 解决“看不见、等不动”的体验与可观测性问题；
- #321 建立 v2 的策略化与迭代化框架；
- #699 修复主动压缩在真实运行中的 usage 口径偏差，补上 correctness 最后一环。

该演进路径已完整体现在当前同步后的代码基线上。
