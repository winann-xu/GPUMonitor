// MARK: - AlertModel
// 告警模型

import Foundation

struct AlertModel: Identifiable, Equatable {
    let id: UUID = UUID()
    let level: AlertLevel
    let title: String
    let message: String
    let timestamp: Date
    let metric: String
    let value: Double
    let threshold: Double
    
    enum AlertLevel {
        case warning   // 黄色
        case critical  // 红色
        case info      // 蓝色
    }
    
    var levelColor: String {
        switch level {
        case .warning: return "yellow"
        case .critical: return "red"
        case .info: return "blue"
        }
    }
}
