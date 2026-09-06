// MARK: - HistoryPoint
// 历史数据点

import Foundation

struct HistoryPoint {
    let metric: MetricType
    let value: Double
    let timestamp: Date
    
    enum MetricType {
        case gpuLoad
        case cpuLoad
        case ramUsage
    }
}