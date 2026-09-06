# G_if 项目改善提示词清单（审核稿 v1）

> 目标：把复盘报告中发现的 4 类问题（长任务反复停、token 速度低、定时器空转、签名/交付收尾）
> 拆成可逐条执行的提示词，供审核后按顺序交给 Pi/Codex 逐个改善。

## 使用说明

1. 打开 Pi（或 Codex），工作目录设为 `/Users/winann/01-project/02-G_if`。
2. 每次只投喂**一个任务块**；任务通过验收后再进入下一项。
3. 标注“需人工审批”的任务，代理只允许准备方案，**不得擅自执行**服务重启、杀进程、卸载 launchd 或删除模型文件。
4. 每条提示词已内置“不要总结式收尾、不要反复空转、阻塞时明确上报”的约束。

## 通用执行规则（每条提示词均默认生效）

- 遵循项目根目录与 `02-G_if/AGENTS.md` 的规范，使用简体中文汇报。
- 动手前先读：`STEERING.md`、`AGENTS.md`、`scripts/auto-monitor.sh`、`scripts/build.sh`、`P7_TEST_STANDARD.md`。
- 一次只改一个关注点；git 提交遵循 Conventional Commits，禁止直接提交到 main。
- 不伪造验收：每一步都要有真实命令输出作为证据。
- 严禁擅自重启/停止本地 llama-server（launchd: `com.local.llamacpp.qwen3.6`）、删除 GGUF，或 `kill` 推理进程。
- 如果同一失败原因连续尝试 3 次仍无进展，停止重试并把阻塞和可选方案报告给用户，等待指令。

## 任务清单总览

| 编号 | 任务 | 需人工审批 | 预期收益 |
|------|------|-----------|---------|
| 01 | 修复 P7 测试判定与交付标记 | 否 | 让“是否完成”可自动判定 |
| 02 | 把 auto-monitor 改成真正的“续跑驱动” | 否（首次试运行需在场） | 长任务停止后自动续跑 |
| 03 | 建立会话上下文瘦身与续跑协议 | 否 | 降低 80K 长上下文导致的卡顿与失忆 |
| 04 | llama-server 上下文与速度调优方案 | 是（执行重启前） | 15 token/s → 30–50 token/s |
| 05 | Pi + llama.cpp 集成兼容审计 | 否 | 找出工具被静默丢弃的根因 |
| 06 | Gatekeeper/签名/交付收尾 | 是（涉及用户手动操作） | 交付可打开的 DMG |
| 07 | 可选：本地模型对照基准 | 否 | 用数据验证换模型建议 |

---

## 01 修复 P7 测试判定与交付标记

### 提示词

```text
你是 G_if 项目的编码代理。本任务只修复 P7 自动判定的正确性，不扩展功能。

背景：
- 现有 scripts/auto-monitor.sh 的 P7 逻辑有路径 bug：它检查
  02-G_if/GPUMonitor.xcodeproj/project.pbxproj，但实际项目在
  02-G_if/GPUMonitor/GPUMonitor.xcodeproj。
- 即使 P7 失败，脚本仍打印“✅ 项目正常”，且 P7_PASS 文件从未生成。
- P7_TEST_STANDARD.md 是验收规格，不允许为迁就脚本而放宽。

要求：
1. 先逐条对照 P7_TEST_STANDARD.md 的 T1–T8，明确每条对应的可执行检查。
2. 修正 auto-monitor.sh 的路径与检查逻辑：全部通过才生成 P7_PASS，
   任一失败必须输出具体失败项，禁止再输出“项目正常”。
3. 保持“由 launchd 周期触发”的形态，但把 while true 死循环改为单次执行，
   配合 launchd StartInterval 每 60 秒触发，并加 flock 防重入。
4. 运行一次并贴出完整输出；若仍有失败项，给出失败清单而不是声称通过。

验收：
- P7_PASS 只在 T1–T8 全部真实通过后生成。
- 失败时日志能明确指出未通过项。
- 不改动 P7_TEST_STANDARD.md 的验收条目。
```

### 人工注意事项

本任务不涉及服务重启，可放行。验收时请人工核对一次 `P7_PASS` 是否与真实状态一致。

---

## 02 把 auto-monitor 改成真正的“续跑驱动”

### 提示词

```text
你是 G_if 项目的编码代理。本任务把 auto-monitor 从“编译巡检”
升级为“检测 Pi 停止后自动续跑”的驱动，禁止改动项目业务代码。

背景：
- 长任务场景：用户发出一次大指令后，Pi 在模型输出无工具调用的收尾回复时
  settle，需要外部在检测到停止后注入“继续”指令。
- 现有脚本只做 swift build / DMG 存在性检查，从不检查 Pi 会话，也不续跑。
- 项目验收标记为 P7_PASS（任务 01 修复后应可靠生成）。

要求：
1. 先阅读本地 Pi 的 RPC/headless 文档
   （~/.local/lib/node_modules/@earendil-works/pi-coding-agent/docs/rpc.md、
    docs/usage.md），确认向指定会话安全注入“继续”消息的可用机制。
2. 设计并实现驱动脚本，逻辑至少包含：
   a. 若 P7_PASS 存在：停止，不注入任何指令。
   b. 若 Pi 会话正在运行（最近有 toolUse/进行中）：跳过本次。
   c. 若 Pi 已 settle 且超过阈值（如 90 秒）仍无新活动：
      从 STEERING.md、PROGRESS.md（如存在）和最近会话摘要构造续跑提示，
      要求代理“继续执行下一未完成项，未达验收前不得输出最终收尾”。
   d. 连续 N 次续跑后若项目文件/编译状态无任何变化，判定死循环，
      停止续跑并生成卡死报告，而不是继续浪费 token。
3. 移除 while true 死循环；launchd 负责周期触发，flock 防重入。
4. 先做 dry-run：手动模拟“已停止”状态，验证只注入一次且不重复轰炸。
5. 做一次 20–30 分钟有人值守试运行，记录：停止时间、注入时间、恢复后的动作。

验收：
- 脚本能在 Pi 停止后自动续跑，且能区分“正常推进”与“死循环”。
- 不会和正在运行的 Pi GUI/CLI 冲突写同一个会话；若无法保证，必须停下说明冲突，
  不得用两个进程同时写同一 session。
- 有日志证明“检测到停止 → 注入 → 恢复”的完整链路。
```

### 人工注意事项

首次试运行需要你在场；如果实现方发现 Pi GUI 与 headless 续跑存在会话锁冲突，
应如实报告并把方案改为“夜间任务在独立 headless 会话运行、GUI 只读查看”。

---

## 03 建立会话上下文瘦身与续跑协议

### 提示词

```text
你是 G_if 项目的编码代理。本任务只更新项目文档与工作协议，不改业务代码。

背景：
- llama-server 实测显示：上下文越长 decode 越慢，80K+ 时约 14 token/s，
  短上下文约 50 token/s；单会话堆到 80K 也会降低模型遵守长指令的能力。
- Pi 当前会话在通宵任务中累积了大量工具历史与超大命令输出。

要求：
1. 在 STEERING.md 末尾新增“长任务执行协议”，包含：
   a. 每完成一个 Phase 就写/更新 PROGRESS.md（已完成项、当前阻塞、下一步）。
   b. 每个 Phase 建议新开会话，用 PROGRESS.md 交接，避免单会话无限膨胀。
   c. 接近上下文阈值时主动 /compact，压缩后必须能凭 PROGRESS.md 续跑。
   d. 未完成当前 Phase 前禁止输出“总结/询问是否继续”式的最终收尾。
2. 在 AGENTS.md 增加工具卫生规则：
   a. 终端输出默认截断（例如 head 限制行数），超大输出重定向到文件再 grep。
   b. 禁止把 ioreg、powermetrics、整份编译日志直接灌进上下文。
   c. 需要跨轮保留的大段内容写入文件，而不是留在对话里。
3. 输出修改后的 diff，并说明新协议下通宵任务的推荐启动流程。

验收：
- STEERING.md 与 AGENTS.md 的修改已落地并可在新会话中生效。
- 给出一个可直接使用的“Phase 交接模板”（PROGRESS.md 示例）。
```

### 人工注意事项

此任务改变后续所有代理的工作方式，请重点审核“禁止总结收尾”和“按 Phase 新开会话”
是否符合你的使用习惯。

---

## 04 llama-server 上下文与速度调优方案

### 提示词（只准备方案，不执行）

```text
你是本机本地推理服务与 G_if 项目的优化顾问。本任务只产出可审核方案，
禁止执行任何服务重启、launchctl 操作、kill、模型文件增删改。

背景与证据：
- 服务配置见 ~/Library/LaunchAgents/com.local.llamacpp.qwen3.6.plist：
  Qwen3.6-35B-A3B Q4_K_M + MTP、-c 131072、KV q8_0、单槽、-fa on。
- llama-server 日志实测：0–9K 约 52 token/s；80K 约 14 token/s；
  120K+ 约 10 token/s。瓶颈是超长上下文的注意力/带宽开销。
- Pi 的模型配置见 ~/.pi/agent/models.json：contextWindow/maxTokens 均为 131072/8192。

要求：
1. 给出精确改动方案：建议把 -c 降到 32768（或 49152），并同步修改
   models.json 的 contextWindow/maxTokens，避免 Pi 继续往超长上下文里塞。
2. 明确服务重启的唯一正确姿势：
   launchctl kickstart -k gui/501/com.local.llamacpp.qwen3.6
   并注明：必须在用户明确批准后才能执行。
3. 给出回滚方案（保留旧 plist 备份、如何恢复原参数）。
4. 可选：设计 10 分钟 A/B 测试（短/长上下文各跑同一段代码任务），
   用日志中的 tg/tokens-per-second 对比，判断是否达到预期。
5. 把方案写成独立文件：02-G_if/docs/llama-context-tuning-plan.md，
   不要修改正式 plist。

验收：
- 方案文件包含：当前参数、目标参数、预期速度、回滚步骤、A/B 测试脚本。
- 全程没有改动任何服务状态。
```

### 人工注意事项

这是需要你人工审批的重启项。**在我执行任何重启前，会先把完整 diff 给你确认。**

---

## 05 Pi + llama.cpp 集成兼容审计

### 提示词

```text
你是 G_if 项目与本地推理链路的调试代理。本任务只做只读审计与测试，不修改服务。

背景：
- Pi 通过 llama.cpp 的 /v1 接口使用模型，模型配置 api 为 openai-responses。
- llama-server 日志出现约 3000 行：
  unsupported Responses tool type 'custom'/'namespace'/'tool_search'/'web_search' skipped，
  怀疑 Pi 的 MCP/命名空间/搜索类工具被静默丢弃。

要求：
1. 统计并归类 llama-server.error.log 中的 unsupported tool 警告。
2. 对照 Pi 当前 models.json 与 pi-coding-agent 文档，确认这些工具类型
   从哪来、被谁定义、应该走哪条链路。
3. 分别测试：内置工具链（bash/read/edit/write）与搜索/MCP 工具，
   记录哪些可用、哪些被跳过、报什么错。
4. 输出结论与可选修复方向，例如：
   a. 升级 llama.cpp / pi 版本；
   b. 把该模型 provider 的 api 从 openai-responses 调整为 openai-completions 并做回归；
   c. 搜索/MCP 类工具只在云端模型上启用。
5. 只输出报告（docs/pi-llama-integration-audit.md），不落地配置改动。

验收：
- 报告含警告统计、可用性矩阵、修复选项及风险。
- 未改变任何运行中配置。
```

### 人工注意事项

如报告建议切换 provider api，请先备份 `~/.pi/agent/models.json` 再决定是否试验。

---

## 06 Gatekeeper / 签名 / 交付收尾

### 提示词

```text
你是 G_if 项目的编码代理。本任务解决最终交付物打不开的问题：
“你不能打开应用程序，因为它可能已损坏或不完整”。

背景：
- 项目没有 Apple Developer 证书。
- 之前代理在 23:23–00:07 反复尝试 codesign/自签名/xattr，形成 50+ 轮死循环，
  并发现 build.sh 存在路径问题（cp 到 GPUMonitor.app/MacOS 而非 Contents/MacOS 等）。
- 禁止为了放行而整体关闭 Gatekeeper（spctl --master-disable）；
  涉及 sudo 的操作必须停下来请用户手动执行。

要求：
1. 先修复 build.sh：确保 .app 目录结构完整（Contents/MacOS/Info.plist），
   再谈签名，不要把顺序搞反。
2. 对本地分发的内部工具，采用可接受的方案并验证：
   a. 先清理 quarantine 属性（xattr -dr com.apple.quarantine）；
   b. 再尝试 ad-hoc 签名 codesign --force --deep -s -；
   c. 如果仍被 Gatekeeper 拦截，给出针对当前 macOS 版本的
      “系统设置 > 隐私与安全性 > 仍要打开”精确操作步骤，
      并明确这是需要用户手动完成的一步。
3. 每步只做一次验证，失败就切换方案；同一方案不得重复尝试 3 次以上。
4. 交付后重建 DMG，验证：可挂载、内含 .app、.app 内可执行文件存在、
   用户按步骤操作后可以打开。

验收：
- 修复后的 build.sh 能稳定产出结构完整的 .app 与 DMG。
- 若最终仍需要用户手动放行，提供一份简明操作说明（docs/open-dmg-guide.md），
  并停在等待用户操作，而不是继续空转。
```

### 人工注意事项

涉及你手动点击“仍要打开”或输入 sudo 密码的步骤，代理必须停下等你，
不应尝试绕过系统安全机制。

---

## 07 可选：本地模型对照基准

### 提示词

```text
你是本机模型评估代理。本任务做一次受控对照实验，不改变服务配置。

目标：验证“qwen3.6-35b-a3b 在改进后的配置下，长任务表现是否足够”，
而不是先入为主地换模型。

要求：
1. 固定同一任务提示词与同一项目状态，分别在以下条件各跑一次：
   a. 当前 131072 上下文配置；
   b. 建议的 32768/49152 配置（需人工批准重启后再跑）；
   c. 可选：云端 DeepSeek V4 Pro/Flash 同任务对照。
2. 记录并对比：首 token 延迟、平均 token/s、工具调用成功率、
   完成同一验收所需人工“继续”次数、死循环次数。
3. 输出 docs/model-benchmark.md，含数据表与结论。

验收：
- 结论必须来自实测数据，而不是主观偏好。
- 不推荐任何低于当前任务质量下限的小模型。
```

### 人工注意事项

基准 04 的重启获批后才可执行 07b；07c 会消耗云端 API 额度，请确认是否运行。
