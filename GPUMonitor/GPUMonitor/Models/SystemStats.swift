// MARK: - SystemStats
// 系统信息模型

import Foundation

struct SystemStats: Codable, Sendable {
    var osName: String = ""
    var osVersion: String = ""
    var uptime: TimeInterval = 0
    var bootDate: Date?
}
