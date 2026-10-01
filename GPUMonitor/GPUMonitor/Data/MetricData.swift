// MARK: - MetricData
// 统一指标数据（由原生 HardwareSampler 快照填充）

import Foundation

@MainActor
class MetricData: ObservableObject {
    static let shared = MetricData()
    
    // MARK: - 当前值（用于 UI 绑定）
    @Published var gpuLoad: Double = 0
    @Published var gpuTemp: Double = -1
    @Published var gpuFreq: Double = -1
    @Published var gpuPower: Double = -1
    @Published var gpuMemoryUsed: Double = 0
    @Published var gpuMemoryTotal: Double = 0
    
    @Published var cpuLoad: Double = 0
    @Published var cpuTemp: Double = -1
    @Published var cpuFreq: Double = -1
    @Published var cpuPower: Double = -1
    
    @Published var ramUsed: Double = 0
    @Published var ramTotal: Double = 0
    @Published var swapUsed: Double = 0
    @Published var swapTotal: Double = 0
    
    @Published var netDownload: Double = 0
    @Published var netUpload: Double = 0

    // llama.cpp token 生成速度（t/s）；为 0 表示空闲/不可用
    @Published var tokenSpeed: Double = 0
    @Published var isLlamaGenerating: Bool = false
    
    @Published var sensorState: String = "初始化…"
    
    // MARK: - 状态指示灯
    @Published var isWarning: Bool = false
    @Published var isCritical: Bool = false
    
    // MARK: - 解析原生快照
    func update(from snapshot: HardwareSnapshot) {
        if let gpu = snapshot.gpuUtilization {
            gpuLoad = gpu
        }
        if let cpu = snapshot.cpuLoadPercent {
            cpuLoad = cpu
        }
        
        gpuTemp = snapshot.gpuTemperature ?? -1
        cpuTemp = snapshot.cpuTemperature ?? -1
        
        // 频率/功耗来自 IOReport 私有通道；轻量版暂不采集
        gpuFreq = -1
        cpuFreq = -1
        gpuPower = -1
        cpuPower = -1
        
        let toGB = 1024.0 * 1024.0 * 1024.0
        ramTotal = Double(snapshot.ramTotalBytes) / toGB
        ramUsed = Double(snapshot.ramUsedBytes) / toGB
        swapTotal = Double(snapshot.swapTotalBytes) / toGB
        swapUsed = Double(snapshot.swapUsedBytes) / toGB
        
        if cpuTemp > 0 || gpuTemp > 0 {
            sensorState = "原生采集 ✅"
        } else {
            sensorState = "温度不可用"
        }
        
        let settings = SettingsStore.shared
        isWarning = (gpuTemp > 0 && gpuTemp > settings.tempThreshold)
            || (cpuTemp > 0 && cpuTemp > settings.tempThreshold)
        isCritical = (gpuTemp > 0 && gpuTemp > settings.tempThreshold * 1.2)
            || (cpuTemp > 0 && cpuTemp > settings.tempThreshold * 1.2)
    }
    
    // MARK: - 展示辅助
    var gpuTempText: String {
        gpuTemp > 0 ? "\(Int(gpuTemp.rounded()))°" : "—"
    }

    var tokenSpeedText: String {
        tokenSpeed > 0 ? String(format: "%.0f", tokenSpeed) : "—"
    }
    
    var cpuTempText: String {
        cpuTemp > 0 ? "\(Int(cpuTemp.rounded()))°" : "—"
    }
    
    var memoryPercent: Double {
        ramTotal > 0 ? ramUsed / ramTotal * 100 : 0
    }
}
