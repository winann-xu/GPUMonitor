// MARK: - MetricsCollector
// 指标采集协议 — 定义所有采集器接口

import Foundation

@MainActor
protocol MetricsCollector {
    var name: String { get }
    func collect() async throws -> String
}
