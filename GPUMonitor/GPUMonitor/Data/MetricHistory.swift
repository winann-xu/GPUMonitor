// MARK: - MetricHistory
// 指标历史记录

import Foundation
import Combine

class MetricHistory: ObservableObject {
    static let shared = MetricHistory()
    
    @Published private(set) var gpuHistory: [HistoryPoint] = []
    @Published private(set) var cpuHistory: [HistoryPoint] = []
    @Published private(set) var memoryHistory: [HistoryPoint] = []
    
    private let maxPoints: Int = 300 // 5 分钟 (1s 间隔)
    private var timerTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // 每秒检查裁剪
        let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
        timer.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.checkAndTrim()
        }.store(in: &cancellables)
    }
    
    func add(point: HistoryPoint) {
        switch point.metric {
        case .gpuLoad:
            gpuHistory.append(point)
            if gpuHistory.count > maxPoints { gpuHistory.removeFirst() }
        case .cpuLoad:
            cpuHistory.append(point)
            if cpuHistory.count > maxPoints { cpuHistory.removeFirst() }
        case .ramUsage:
            memoryHistory.append(point)
            if memoryHistory.count > maxPoints { memoryHistory.removeFirst() }
        }
    }
    
    func clearAll() {
        gpuHistory.removeAll()
        cpuHistory.removeAll()
        memoryHistory.removeAll()
    }
    
    private func checkAndTrim() {
        let now = Date()
        gpuHistory.removeAll { $0.timestamp.timeIntervalSince(now) > 600 }
        cpuHistory.removeAll { $0.timestamp.timeIntervalSince(now) > 600 }
        memoryHistory.removeAll { $0.timestamp.timeIntervalSince(now) > 600 }
    }
}