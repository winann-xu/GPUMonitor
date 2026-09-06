# P7 交付物测试标准

## 测试清单

### T1: 编译通过 ✅
- [x] `swift build` 无错误、无严重警告
- [x] 产物二进制文件存在且可执行

### T2: DMG 安装包 ✅
- [x] `GPUMonitor.dmg` 存在且可挂载
- [x] DMG 内含 `GPUMonitor.app`
- [x] DMG 内含 Applications 快捷链接
- [x] DMG 大小 < 5MB

### T3: .app 包完整 ✅
- [x] `GPUMonitor.app/Contents/Info.plist` 存在
- [x] `LSUIElement = true` (菜单栏模式)
- [x] `CFBundleExecutable` 正确
- [x] `CFBundleIdentifier = com.gpu-monitor.app`
- [x] `MACOSX_DEPLOYMENT_TARGET >= 14.0`

### T4: 原生采集集成 ✅
- [x] 随包不包含 macmon 二进制（`Resources/bin/macmon` 不存在）
- [x] 项目源码含原生 GPU/CPU/内存采样（`GPUSampler` / `HardwareSampler`）
- [x] 项目源码含 SMC 温度桥接（`CSMCBridge`）
- [x] 不再通过 `macmon pipe` 子进程取数

### T5: 核心功能完整 ✅
- [x] 菜单栏实时显示 (GPU 利用率 + 温度)
- [x] 弹出面板 (GPU/CPU/内存/网络)
- [x] 动态配色 (绿/黄/橙/红)
- [x] 趋势图 (折线图组件)
- [x] 告警通知 (温度/负载/内存阈值)
- [x] UserDefaults 配置持久化

### T6: 项目结构规范 ✅
- [x] 10+ Swift 源文件
- [x] 合理的模块划分 (App/Data/MenuBar/Models/Settings/Views)
- [x] `Package.swift` 正确配置
- [x] `project.pbxproj` Xcode 项目文件存在
- [x] `build.sh` 自动化构建脚本

### T7: 代码质量 ✅
- [x] 单文件 < 300 行
- [x] 单函数 < 50 行
- [x] 无硬编码敏感信息
- [x] 有基本的错误处理

### T8: 定时监控运行 ✅
- [x] launchd 定时任务已加载 (com.gpu-monitor.auto-check)
- [x] 进程在运行中
- [x] 日志正常写入

---
*所有 [x] 打勾才算 P7 通过*

---

## 验收记录（2026-09-06 11:26）

- `swift build` 从零编译通过，无警告。
- `GPUMonitor.dmg` 挂载后含 `GPUMonitor.app` 与 Applications 链接，大小 2.2MB。
- `.app` 结构为 `Contents/MacOS/GPUMonitor` + `Contents/Info.plist`，ad-hoc 签名有效。
- 已去除 macmon 依赖；GPU/CPU/内存/SMC 温度全部原生读取。
- DMG 约 2.2MB，.app 约 2.0MB，包内无 macmon 二进制。
- 真机 OCR 验证菜单栏摘要 `M37% ↓0.0M G59% 49°`，面板 GPU/CPU/内存/网络显示正常。
- launchd `com.gpu-monitor.auto-check` 每 60 秒单次巡检；`P7_PASS` 于 11:26 生成。
