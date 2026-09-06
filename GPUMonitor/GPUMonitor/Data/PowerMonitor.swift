// MARK: - PowerMonitor
// 电源管理 — 检测电池/外接电源，优化采集策略

import Foundation
import IOKit.ps

@MainActor
class PowerMonitor: ObservableObject {
    static let shared = PowerMonitor()
    
    @Published var powerSource: PowerSource = .unknown
    @Published var batteryPercent: Double = 0
    @Published var isCharging: Bool = false
    
    enum PowerSource: String {
        case battery = "电池"
        case adapter = "外接电源"
        case unknown = "未知"
    }
    
    private var timer: Timer?
    
    init() {
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateStatus()
            }
        }
    }
    
    func updateStatus() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as? [[String: Any]] ?? []
        
        for source in sources {
            if let type = source[kIOPSTypeKey] as? String, type == "Battery" {
                if let percent = source[kIOPSPowerSourceStateKey] as? String {
                    isCharging = (percent == "AC Power")
                    powerSource = isCharging ? .adapter : .battery
                    // IOKit 返回的是 NSNumber（通常为整数百分比）
                    batteryPercent = (source[kIOPSCurrentCapacityKey] as? NSNumber)?.doubleValue ?? 0
                }
            } else if source[kIOPSTypeKey] as? String == "AC Power" {
                powerSource = .adapter
                isCharging = true
            }
        }
    }
    
    var shouldReduceFrequency: Bool {
        return (powerSource != .adapter) && batteryPercent < 30
    }
    
    deinit {
        timer?.invalidate()
    }
}
