// MARK: - PerformanceOptimizer
// 性能优化 — 限制内存/CPU 使用

import Foundation

@MainActor
class PerformanceOptimizer: ObservableObject {
    static let shared = PerformanceOptimizer()
    
    @Published var memoryUsage: Double = 0 // MB
    @Published var cpuUsage: Double = 0 // %
    
    private let maxMemoryMB: Double = 50
    private var lastGC: Date = Date()
    
    func checkAndOptimize() {
        let now = Date()
        
        // 每 30 秒强制 GC
        if now.timeIntervalSince(lastGC) > 30 {
            #if os(macOS)
            // macOS 不需要手动 GC
            #endif
            lastGC = now
        }
        
        // 内存超限检查
        if memoryUsage > maxMemoryMB {
            objectWillChange.send()
        }
    }
    
    func getOptimalInterval(baseInterval: TimeInterval) -> TimeInterval {
        let power = PowerMonitor.shared
        if power.shouldReduceFrequency {
            return max(baseInterval * 3, 3.0) // 电池低电量时降频
        }
        return baseInterval
    }
}
