// MARK: - HardwareSampler
// 原生采样入口：一帧内读取 GPU/CPU/内存/Swap/温度

import Foundation

final class HardwareSampler: @unchecked Sendable {
    static let shared = HardwareSampler()
    
    private let lock = NSLock()
    private var prepared = false
    
    private init() {}
    
    /// 启动时预热一次（SMC 键枚举较慢，不能放进高频采样循环）
    func prepare() {
        lock.lock()
        defer { lock.unlock() }
        guard !prepared else { return }
        prepared = true
        _ = TemperatureReader.shared.prepare()
        _ = MachSystemSampler.cpuLoadPercent() // 建立 CPU tick 基线
    }
    
    func sample() -> HardwareSnapshot {
        lock.lock()
        defer { lock.unlock() }
        
        var snapshot = HardwareSnapshot()
        snapshot.gpuUtilization = GPUSampler.utilization()
        snapshot.cpuLoadPercent = MachSystemSampler.cpuLoadPercent()
        
        let memory = MachSystemSampler.memory()
        snapshot.ramTotalBytes = memory.total
        snapshot.ramUsedBytes = memory.used
        let swap = MachSystemSampler.swap()
        snapshot.swapTotalBytes = swap.total
        snapshot.swapUsedBytes = swap.used
        
        let temps = TemperatureReader.shared.read()
        snapshot.cpuTemperature = temps.cpu
        snapshot.gpuTemperature = temps.gpu
        snapshot.timestamp = Date()
        return snapshot
    }
}
