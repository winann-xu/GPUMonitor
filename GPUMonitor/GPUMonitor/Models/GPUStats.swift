// MARK: - GPUStats
// GPU 指标模型

import Foundation

struct GPUStats: Codable, Sendable {
    var loadPercent: Double?
    var temperature: Double?
    var power: Double?
    var frequency: Double?
    var memoryTotal: Int64?
    var memoryUsed: Int64?
    var name: String = "GPU"
    
    // 计算属性
    var memoryUsagePercent: Double? {
        guard let total = memoryTotal, total > 0, let used = memoryUsed else { return nil }
        return (Double(used) / Double(total)) * 100
    }
}
