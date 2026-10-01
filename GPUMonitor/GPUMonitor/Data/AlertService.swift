// MARK: - AlertService
// 告警通知服务

import Foundation
import UserNotifications

@MainActor
class AlertService: ObservableObject {
    static let shared = AlertService()
    
    @Published var alerts: [AlertModel] = []
    @Published var hasNotificationsEnabled: Bool = false
    @Published var currentAlertLevel: AlertModel.AlertLevel = .info
    
    private var lastAlertTime: Date = Date.distantPast
    private let cooldown: TimeInterval = 300 // 5 分钟冷却
    private let maxAlerts: Int = 50
    
    /// 通知中心只能在具备合法 Bundle Identifier 的 .app 内使用。
    /// 直接运行 `.build/.../debug/GPUMonitor` 裸二进制时
    /// `Bundle.main.bundleIdentifier == nil`，此时调用
    /// `UNUserNotificationCenter.current()` 会抛
    /// `NSInternalInconsistencyException`（bundleProxyForCurrentProcess is nil）
    /// 导致进程 SIGABRT 崩溃、菜单栏图标消失。
    private var notificationCenter: UNUserNotificationCenter? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }
    
    init() {
        requestNotificationPermission()
    }
    
    // MARK: - 请求通知权限
    func requestNotificationPermission() {
        guard let center = notificationCenter else {
            hasNotificationsEnabled = false
            return
        }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.hasNotificationsEnabled = granted
            }
        }
    }
    
    // MARK: - 检查并触发告警
    func checkAlerts(metricData: MetricData) {
        let settings = SettingsStore.shared
        
        // GPU 温度告警
        if metricData.gpuTemp > settings.tempThreshold {
            triggerAlert(level: .warning, title: "GPU 温度过高",
                        message: "\(Int(metricData.gpuTemp))°C > \(Int(settings.tempThreshold))°C",
                        metric: "GPU", value: metricData.gpuTemp, threshold: settings.tempThreshold)
        }
        
        // GPU 利用率告警
        if metricData.gpuLoad > settings.loadThreshold {
            triggerAlert(level: .warning, title: "GPU 负载过高",
                        message: "\(Int(metricData.gpuLoad))% > \(Int(settings.loadThreshold))%",
                        metric: "GPU", value: metricData.gpuLoad, threshold: settings.loadThreshold)
        }
        
        // CPU 温度告警
        if metricData.cpuTemp > settings.tempThreshold {
            triggerAlert(level: .warning, title: "CPU 温度过高",
                        message: "\(Int(metricData.cpuTemp))°C > \(Int(settings.tempThreshold))°C",
                        metric: "CPU", value: metricData.cpuTemp, threshold: settings.tempThreshold)
        }
        
        // 内存告警
        if metricData.ramUsed > 0 && metricData.ramTotal > 0 {
            let percent = metricData.ramUsed / metricData.ramTotal * 100
            if percent > 90 {
                triggerAlert(level: .critical, title: "内存不足",
                            message: "\(Int(percent))% 已用",
                            metric: "RAM", value: percent, threshold: 90)
            }
        }
        
        // 更新状态
        metricData.isWarning = metricData.gpuTemp > settings.tempThreshold ||
                              metricData.cpuTemp > settings.tempThreshold
    }
    
    // MARK: - 触发告警
    private func triggerAlert(level: AlertModel.AlertLevel, title: String,
                             message: String, metric: String,
                             value: Double, threshold: Double) {
        let now = Date()
        
        // 冷却时间检查
        if now.timeIntervalSince(lastAlertTime) < cooldown { return }
        
        let alert = AlertModel(level: level, title: title, message: message,
                              timestamp: now, metric: metric, value: value, threshold: threshold)
        
        // 添加告警（避免重复）
        if !alerts.contains(where: { $0.title == alert.title &&
                                      $0.timestamp.timeIntervalSince(now) < 60 }) {
            alerts.insert(alert, at: 0)
            if alerts.count > maxAlerts {
                alerts.removeLast(alerts.count - maxAlerts)
            }
            
            currentAlertLevel = level
            lastAlertTime = now
            
            // 发送通知
            if hasNotificationsEnabled {
                sendNotification(title: title, message: message)
            }
        }
    }
    
    // MARK: - 发送通知
    private func sendNotification(title: String, message: String) {
        guard let center = notificationCenter else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        
        // 严重告警使用不同声音
        if currentAlertLevel == .critical {
            content.sound = UNNotificationSound.default
        }
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                           content: content, trigger: nil)
        
        center.add(request)
    }
    
    // MARK: - 清除告警
    func clearAlerts() {
        alerts.removeAll()
        guard let center = notificationCenter else { return }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}