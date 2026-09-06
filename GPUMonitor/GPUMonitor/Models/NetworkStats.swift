// MARK: - NetworkStats
// 网络指标模型

import Foundation

struct NetworkStats: Codable, Sendable {
    var downloadSpeed: Double?
    var uploadSpeed: Double?
    
    var downloadMBs: Double {
        (downloadSpeed ?? 0) / 1_000_000
    }
    
    var uploadMBs: Double {
        (uploadSpeed ?? 0) / 1_000_000
    }
}
