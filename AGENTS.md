# GPU 状况查看插件 — 项目上下文

> 项目名称：GPU 状况查看插件 (GPU Monitor)
> 当前阶段：P7 通过 — 原生采集版
> 参考项目：macmon 0.8.2 / MacMonitor（仅参考源码，MIT）

---

## 项目目标

开发 macOS 菜单栏常驻应用，实时显示 GPU/CPU/温度/网络状态，
用于后期运行大模型时监控本机性能。

---

## 技术栈

- **UI**: SwiftUI (macOS 原生)
- **数据采集**: 原生 macOS API（IORegistry / Mach / SMC / netstat），无 macmon 依赖
- **数据存储**: UserDefaults
- **开机自启**: SMLoginItemSetEnabled

---

## 项目结构

```
02-G_if/
├── STEERING.md          # 长程任务提示词（完整文档）
├── AGENTS.md            # 本文件（项目上下文）
├── GPUMonitor/          # Xcode 项目（待创建）
│   └── ...
├── docs/
├── scripts/
└── README.md
```

---

## 开发规则

1. **严格按 STEERING.md 执行** — 6 个 Phase，每阶段完成后确认
2. **原生采集** — GPU 走 IOReg `AGXAccelerator`；内存/CPU 走 Mach；
   温度走 `CSMCBridge`（SMC sp78/flt），回退 IOHID；网络走 `netstat -ib` 差分
3. **性能约束** — 内存 < 50MB, CPU < 5%, 电池影响可忽略
4. **兼容性** — macOS 14+ (Sonoma), arm64 优先

---

## 关键命令

- 构建：`swift build` / `bash scripts/build.sh`
- 巡检：`bash scripts/auto-monitor.sh`

---

*最后更新：2026-09-06*
