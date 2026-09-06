# 第三方代码说明

`CSMCBridge` 的 SMC 只读逻辑提炼自以下 MIT 开源项目的对应实现，
仅用于读取系统温度，不随应用打包任何第三方二进制：

- **macmon 0.8.2** — https://github.com/vladkens/macmon
  - Copyright (c) 2024 vladkens
  - 参考 `src_lib/sources.rs` 中的 SMC/IOHID 与内存读取思路
- **MacMonitor** — https://github.com/ryyansafar/MacMonitor
  - Copyright (c) 2025-2026 MacMonitor Contributors
  - 参考其 `SMC.c/SMC.h` 的 SMC 调用与 sp78/flt 数值解析

两者均以 MIT License 发布，允许修改与再分发。
