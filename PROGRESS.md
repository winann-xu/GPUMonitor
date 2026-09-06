# PROGRESS — GPU Monitor 项目进度

> 更新时间：2026-09-06 11:26（Asia/Shanghai）

## 当前状态

- **P7 测试 8/8 通过**，`P7_PASS` 已重新生成。
- 数据采集已改为 **100% 原生、零 macmon 依赖**：
  - GPU 利用率：IORegistry `AGXAccelerator` `PerformanceStatistics`
  - CPU 利用率：Mach `host_processor_info` tick 差分
  - 内存/Swap：Mach `host_statistics64` + sysctl
  - 温度：`CSMCBridge`（SMC sp78/flt，源码级 C 桥）→ 回退 IOHID
  - 网络：系统 `netstat -ib` 差分
- `.app` 大小约 2.0MB，DMG 约 2.2MB；包内不再含任何 macmon 二进制。
- 真机已启动新版并截屏 OCR 验证：
  - 菜单栏摘要显示四项：`M内存% ↓下载 G GPU% 温度°`
  - 弹出面板 GPU/CPU/内存/网络均显示真实数据，非灰白空面板。

## 本轮完成内容（2026-09-06）

1. **原生化改造**：删除 `MacmonCollector`（子进程取 JSON 方式）；
   新增 `HardwareSampler`、`GPUSampler`、`MachSystemSampler`、
   `TemperatureReader`、`HardwareSnapshot`。
2. **SMC 温度桥**：从 macmon/MacMonitor 提炼 `CSMCBridge`（C 目标），
   只读 CPU/GPU 温度；本机 M1 Max 实测 CPU ≈56°、GPU die ≈50°。
3. **打包瘦身**：`build.sh` 移除 macmon 复制/签名步骤；
   产物大小由约 4.2MB DMG 降到约 2.2MB，无需 Homebrew/macmon。
4. **P7 语义更新**：T4 从“macmon 集成”改为“原生采集集成”，
   并断言包内无 macmon、源码中无 `pipe` 子进程调用。
5. **UI 文案清理**：面板状态行改为“原生采集 ✅”，版本 v1.3.0；
   频率/功耗在未采集时不再显示误导性的 0 值。
6. **采集线程化**：每帧在后台任务采样，不阻塞菜单栏 UI。

## 之前修复记录

- macmon pipe 死锁、功耗单位、巡检脚本路径/死循环等已修复。
- 菜单栏纯 Text 标签 + 共享 `MenuBarController`；动态配色；
  面板 11pt+；设置窗口 `openWindow(id:)`。
- CPU 内存公式沿用 macmon `libc_ram` 语义并 clamp 到物理内存。

## 已知剩余项

- 频率/功耗目前未采集（原 macmon 走 IOReport 私有通道），
  面板对应区域显示“—”；如需精确 W/Hz 需再实现 IOReport 采样。
- RSS 约 77MB，高于 STEERING 50MB 目标，属后续性能优化项。
- ad-hoc 签名；正式分发需开发者证书 + 公证。
- `project.pbxproj` 只维护了部分源文件，Xcode 直接打开构建仍不完整；
  日常构建走 SwiftPM（`swift build` / `build.sh`）。

## 推荐下一步

- 运行 Phase 6 功能/性能验收（内存 <50MB、CPU <5%、长稳）。
- 如需补回频率/功耗，参考 macmon `IOReport` 通道做轻量实现。
