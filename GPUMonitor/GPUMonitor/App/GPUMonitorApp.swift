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
    private var tokenSpeedCollector = TokenSpeedCollector.shared
    
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
            await networkCollector.refresh(metricData)
            await tokenSpeedCollector.refresh(metricData)
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
        // 图标式（电池式）菜单栏：每个指标一个固定尺寸格子，
        // 数值画在格子内，宽度只由格子数决定 → 不随数值抖动。
        var chips: [MenuBarChip] = []

        if settings.showMemory {
            let percent = metricData.memoryPercent
            chips.append(MenuBarChip(
                text: "\(Int(percent.rounded()))",
                fraction: min(max(percent / 100, 0), 1),
                color: MenuBarPalette.level(percent, warn: 80, crit: 92),
                icon: .memory
            ))
        }
        if settings.showNetwork {
            let download = metricData.netDownload
            chips.append(MenuBarChip(
                text: String(format: "%.1f", download),
                fraction: min(max(download / 50, 0), 1),
                color: download > 0.05 ? MenuBarPalette.okColor : MenuBarPalette.idleColor,
                icon: .download
            ))
        }
        if settings.showGPU {
            let load = metricData.gpuLoad
            chips.append(MenuBarChip(
                text: "\(Int(load.rounded()))",
                fraction: min(max(load / 100, 0), 1),
                color: MenuBarPalette.level(load, warn: settings.loadThreshold,
                                            crit: min(99, settings.loadThreshold + 10)),
                icon: .gpu
            ))
        }
        if settings.showTokenSpeed {
            let speed = metricData.tokenSpeed
            chips.append(MenuBarChip(
                text: speed > 0 ? String(format: "%.0f", speed) : "–",
                fraction: min(max(speed / 100, 0), 1),
                color: speed > 0 ? MenuBarPalette.okColor : MenuBarPalette.idleColor,
                icon: .tokens
            ))
        }
        if settings.showSystem {
            let temp = metricData.gpuTemp
            chips.append(MenuBarChip(
                text: temp > 0 ? String(format: "%.0f", temp) : "–",
                fraction: min(max(temp / 100, 0), 1),
                color: temp > 0
                    ? MenuBarPalette.level(temp, warn: settings.tempThreshold,
                                           crit: settings.tempThreshold * 1.2)
                    : MenuBarPalette.idleColor,
                icon: .temperature
            ))
        }

        // 全部关掉时至少留一个格子，避免状态栏里出现空项
        if chips.isEmpty {
            chips.append(MenuBarChip(text: "–", fraction: 0, color: MenuBarPalette.idleColor, icon: .gpu))
        }

        menuBarCtrl.chips = chips
        menuBarCtrl.showValues = settings.showTextSummary
        menuBarCtrl.tooltip = MenuBarText.summary(
            memoryPercent: metricData.memoryPercent,
            downloadMBps: metricData.netDownload,
            gpuLoad: metricData.gpuLoad,
            tokenSpeed: metricData.tokenSpeed,
            gpuTemp: metricData.gpuTemp,
            showTokenSpeed: settings.showTokenSpeed
        )
        menuBarCtrl.isWarning = metricData.isWarning
        menuBarCtrl.isCritical = alertService.currentAlertLevel == .critical
    }
}
