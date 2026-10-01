// MARK: - PopoverView
// 弹出面板主视图 — 点击菜单栏图标后显示

import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var metricData: MetricData
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var alertService: AlertService
    @EnvironmentObject var power: PowerMonitor
    @StateObject private var metricHistory = MetricHistory.shared
    @Environment(\.openWindow) private var openWindow
    
    @State private var selectedTab: Int = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 状态栏
            HStack {
                Image(systemName: "gpu")
                    .foregroundColor(.blue)
                Text("GPU Monitor")
                    .font(.headline)
                Spacer()
                BatteryIndicatorView()
                    .environmentObject(power)
                if metricData.isWarning {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                }
                if alertService.currentAlertLevel == .critical {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .foregroundColor(.red)
                }
            }
            .padding()
            
            Divider()
            
            // 标签导航
            Picker("选择", selection: $selectedTab) {
                Text("概览").tag(0)
                Text("趋势").tag(1)
                Text("告警").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Divider()
            
            // 内容区域
            TabView(selection: $selectedTab) {
                overviewView.tag(0)
                historyView.tag(1)
                AlertPanelView().tag(2)
            }

        }
        .padding(0)
        .frame(width: 320, height: 520)
    }
    
    // MARK: - 概览视图
    private var overviewView: some View {
        ScrollView {
            VStack(spacing: 10) {
                // GPU
                if settings.showGPU {
                    metricSection("GPU", color: .blue) {
                        VStack(alignment: .leading, spacing: 3) {
                            MetricBarView.gpuLoad(metricData.gpuLoad)
                            if metricData.gpuTemp > 0 {
                                MetricBarView.temperature(metricData.gpuTemp)
                            } else {
                                Text("温度: 不可用")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            if metricData.gpuFreq >= 0 {
                                Text("频率: \(String(format: "%.2f", metricData.gpuFreq)) GHz")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            if metricData.gpuPower >= 0 {
                                Text("功耗: \(String(format: "%.1f", metricData.gpuPower)) W")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // CPU
                if settings.showCPU {
                    metricSection("CPU", color: .purple) {
                        VStack(alignment: .leading, spacing: 3) {
                            MetricBarView.cpuLoad(metricData.cpuLoad)
                            if metricData.cpuTemp > 0 {
                                MetricBarView.temperature(metricData.cpuTemp)
                            } else {
                                Text("温度: 不可用")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                            if metricData.cpuFreq >= 0 {
                                Text("频率: \(String(format: "%.2f", metricData.cpuFreq)) GHz")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // 内存
                if settings.showMemory {
                    metricSection("内存", color: .cyan) {
                        VStack(alignment: .leading, spacing: 3) {
                            MetricBarView.memoryUsage(metricData.ramUsed, total: metricData.ramTotal)
                            HStack {
                                Text("已用: \(String(format: "%.1f", metricData.ramUsed)) GB")
                                Spacer()
                                Text("Swap: \(String(format: "%.1f", metricData.swapUsed)) GB")
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                // 网络
                if settings.showNetwork {
                    metricSection("网络", color: .green) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("↓ 下载")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", metricData.netDownload)) MB/s")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.green)
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("↑ 上传")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(String(format: "%.1f", metricData.netUpload)) MB/s")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // 大模型（llama.cpp token 速率）
                if settings.showTokenSpeed {
                    metricSection("大模型", color: .orange) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Token 生成速度")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(metricData.tokenSpeedText) t/s")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(metricData.isLlamaGenerating ? "生成中" : "空闲")
                                    .font(.caption)
                                    .foregroundColor(metricData.isLlamaGenerating ? .green : .secondary)
                                Text("llama.cpp")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Divider()
                
                // 状态信息
                HStack {
                    Text(metricData.sensorState)
                    Spacer()
                    Text("v1.3.0")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                
                // 底部按钮
                HStack(spacing: 8) {
                    Button("⚙ 设置") {
                        openWindow(id: "settings-window")
                    }
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button("📋 CSV") {
                        _ = DataExporter.shared.exportToCSV(metricData: metricData)
                    }
                    .controlSize(.small)
                    
                    Button("📋 JSON") {
                        _ = DataExporter.shared.exportToJSON(metricData: metricData)
                    }
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button("✕ 退出") {
                        NSApp.terminate(nil)
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
            .padding(10)
        }
    }
    
    // MARK: - 历史视图
    private var historyView: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Text("历史记录 (最近 5 分钟)")
                        .font(.headline)
                    Spacer()
                    Button("清除") {
                        metricHistory.clearAll()
                    }
                    .controlSize(.small)
                    .foregroundColor(.secondary)
                }
                
                if !metricHistory.gpuHistory.isEmpty {
                    TrendChartView(
                        dataPoints: metricHistory.gpuHistory,
                        color: .blue,
                        title: "GPU (%)",
                        maxValue: 100
                    )
                }
                
                if !metricHistory.cpuHistory.isEmpty {
                    TrendChartView(
                        dataPoints: metricHistory.cpuHistory,
                        color: .purple,
                        title: "CPU (%)",
                        maxValue: 100
                    )
                }
                
                if !metricHistory.memoryHistory.isEmpty {
                    TrendChartView(
                        dataPoints: metricHistory.memoryHistory,
                        color: .cyan,
                        title: "内存 (%)",
                        maxValue: 100
                    )
                }
                
                if metricHistory.gpuHistory.isEmpty && metricHistory.cpuHistory.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("运行中，正在收集数据...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                Divider()
                
                HStack(spacing: 8) {
                    Button("导出 CSV") {
                        _ = DataExporter.shared.exportToCSV(metricData: metricData)
                    }
                    .controlSize(.small)
                    
                    Button("导出 JSON") {
                        _ = DataExporter.shared.exportToJSON(metricData: metricData)
                    }
                    .controlSize(.small)
                }
            }
            .padding(10)
        }
    }
    
    // MARK: - 指标区域
    private func metricSection<T: View>(_ title: String, color: Color, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content()
        }
        .padding(8)
        .background(color.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.35), lineWidth: 1)
        )
        .cornerRadius(8)
    }
}
