// MARK: - CPUStats
// CPU 指标模型

import Foundation

struct CPUStats: Codable, Sendable {
    var loadPercent: Double?
    var temperature: Double?
    var power: Double?
    var frequency: Double?
    var pCores: Int = 0
    var eCores: Int = 0
    var perCoreLoad: [Double]?
    
    var totalCores: Int {
        return pCores + eCores
    }
}
