// MARK: - SettingsStore
// UserDefaults 配置存储

import SwiftUI

@MainActor
class SettingsStore: ObservableObject {
    static let shared = SettingsStore()
    
    // MARK: - 采集频率
    @Published var interval: TimeInterval {
        didSet { save() }
    }
    
    // MARK: - 指标开关
    @Published var showGPU: Bool = true { didSet { save() } }
    @Published var showCPU: Bool = true { didSet { save() } }
    @Published var showMemory: Bool = true { didSet { save() } }
    @Published var showNetwork: Bool = true { didSet { save() } }
    @Published var showSystem: Bool = true { didSet { save() } }
    
    // MARK: - 告警阈值
    @Published var tempThreshold: Double = 85.0 { didSet { save() } }
    @Published var loadThreshold: Double = 90.0 { didSet { save() } }
    
    // MARK: - 显示模式
    @Published var showTextSummary: Bool = true { didSet { save() } }
    @Published var showIcons: Bool = true { didSet { save() } }
    
    init() {
        // 设置默认值
        UserDefaults.standard.register(defaults: [
            "interval": 1.0,
            "showGPU": true,
            "showCPU": true,
            "showMemory": true,
            "showNetwork": true,
            "showSystem": true,
            "tempThreshold": 85.0,
            "loadThreshold": 90.0,
            "showTextSummary": true,
            "showIcons": true
        ])
        
        // 从 UserDefaults 加载
        interval = UserDefaults.standard.double(forKey: "interval")
        showGPU = UserDefaults.standard.bool(forKey: "showGPU")
        showCPU = UserDefaults.standard.bool(forKey: "showCPU")
        showMemory = UserDefaults.standard.bool(forKey: "showMemory")
        showNetwork = UserDefaults.standard.bool(forKey: "showNetwork")
        showSystem = UserDefaults.standard.bool(forKey: "showSystem")
        tempThreshold = UserDefaults.standard.double(forKey: "tempThreshold")
        loadThreshold = UserDefaults.standard.double(forKey: "loadThreshold")
        showTextSummary = UserDefaults.standard.bool(forKey: "showTextSummary")
        showIcons = UserDefaults.standard.bool(forKey: "showIcons")
    }
    
    func save() {
        UserDefaults.standard.set(interval, forKey: "interval")
        UserDefaults.standard.set(showGPU, forKey: "showGPU")
        UserDefaults.standard.set(showCPU, forKey: "showCPU")
        UserDefaults.standard.set(showMemory, forKey: "showMemory")
        UserDefaults.standard.set(showNetwork, forKey: "showNetwork")
        UserDefaults.standard.set(showSystem, forKey: "showSystem")
        UserDefaults.standard.set(tempThreshold, forKey: "tempThreshold")
        UserDefaults.standard.set(loadThreshold, forKey: "loadThreshold")
        UserDefaults.standard.set(showTextSummary, forKey: "showTextSummary")
        UserDefaults.standard.set(showIcons, forKey: "showIcons")
    }
}
