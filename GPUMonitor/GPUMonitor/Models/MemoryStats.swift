// MARK: - MemoryStats
// 内存指标模型

import Foundation

struct MemoryStats: Codable, Sendable {
    var ramUsed: Int64?
    var ramTotal: Int64?
    var swapUsed: Int64?
    var swapTotal: Int64?
    
    var ramUsagePercent: Double? {
        guard let total = ramTotal, total > 0, let used = ramUsed else { return nil }
        return (Double(used) / Double(total)) * 100
    }
}
