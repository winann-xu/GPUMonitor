// MARK: - GPUMonitorApp
// 主应用入口

import SwiftUI

@main
struct GPUMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarScene()
        SettingsScene()
    }
}

struct MenuBarScene: Scene {
    @StateObject private var metricData = MetricData.shared
    @StateObject private var menuBarCtrl = MenuBarController.shared
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var alertService = AlertService.shared
    @StateObject private var power = PowerMonitor.shared
    
    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(metricData)
                .environmentObject(settings)
                .environmentObject(alertService)
                .environmentObject(power)
        } label: {
            MenuBarView()
                .environmentObject(menuBarCtrl)
        }
        .menuBarExtraStyle(.window)
    }
}

struct SettingsScene: Scene {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var alertService = AlertService.shared
    @StateObject private var power = PowerMonitor.shared
    
    var body: some Scene {
        WindowGroup("设置", id: "settings-window") {
            EnhancedSettingsView()
                .environmentObject(settings)
                .environmentObject(alertService)
                .environmentObject(power)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var updateTask: Task<Void, Never>?
    private var menuBarCtrl = MenuBarController.shared
    private var metricData = MetricData.shared
    private var settings = SettingsStore.shared
    private var alertService = AlertService.shared
    private var metricHistory = MetricHistory.shared
    private var networkCollector = NetworkCollector.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        updateTask = Task {
            await collectLoop()
        }
    }
    
    private func collectLoop() async {
        // 预热：SMC 键枚举与 CPU tick 基线放到后台，避免阻塞启动
        await Task.detached(priority: .utility) {
            HardwareSampler.shared.prepare()
        }.value
        
        while !Task.isCancelled {
            let interval = max(settings.interval, 0.3)
            let snapshot = await Task.detached(priority: .utility) {
                HardwareSampler.shared.sample()
            }.value
            
            metricData.update(from: snapshot)
            alertService.checkAlerts(metricData: metricData)
            networkCollector.refresh(metricData)
            updateMenuBar()
            recordHistory(snapshot)
            
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
    }
    
    private func recordHistory(_ snapshot: HardwareSnapshot) {
        let now = snapshot.timestamp
        if let gpu = snapshot.gpuUtilization {
            metricHistory.add(point: HistoryPoint(metric: .gpuLoad, value: gpu, timestamp: now))
        }
        if let cpu = snapshot.cpuLoadPercent {
            metricHistory.add(point: HistoryPoint(metric: .cpuLoad, value: cpu, timestamp: now))
        }
        if snapshot.ramTotalBytes > 0 {
            let percent = Double(snapshot.ramUsedBytes) / Double(snapshot.ramTotalBytes) * 100
            metricHistory.add(point: HistoryPoint(metric: .ramUsage, value: percent, timestamp: now))
        }
    }
    
    private func updateMenuBar() {
        let memoryPercent = metricData.memoryPercent
        menuBarCtrl.textSummary = String(
            format: "M%.0f%% ↓%.1fM G%.0f%% %@",
            memoryPercent,
            metricData.netDownload,
            metricData.gpuLoad,
            metricData.gpuTempText
        )
        menuBarCtrl.gpuLoad = metricData.gpuLoad
        menuBarCtrl.gpuTemp = metricData.gpuTemp
        menuBarCtrl.netDownload = metricData.netDownload
        menuBarCtrl.netUpload = metricData.netUpload
        menuBarCtrl.isWarning = metricData.isWarning
        menuBarCtrl.isCritical = alertService.currentAlertLevel == .critical
    }
}
