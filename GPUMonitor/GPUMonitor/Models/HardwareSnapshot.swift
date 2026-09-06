// MARK: - HardwareSnapshot
// 一帧原生硬件数据（全部数值都来自系统 API，不依赖任何外部 CLI）

import Foundation

struct HardwareSnapshot: Sendable {
    var gpuUtilization: Double?
    var cpuLoadPercent: Double?
    var gpuTemperature: Double?
    var cpuTemperature: Double?
    
    var ramTotalBytes: UInt64 = 0
    var ramUsedBytes: UInt64 = 0
    var swapTotalBytes: UInt64 = 0
    var swapUsedBytes: UInt64 = 0
    
    var timestamp: Date = Date()
}
