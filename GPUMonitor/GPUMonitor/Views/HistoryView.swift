// MARK: - HistoryView
// 历史记录视图

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var metricData: MetricData
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var metricHistory: MetricHistory
    @State private var selectedChart: Int = 0
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("历史记录")
                    .font(.headline)
                Spacer()
                
                // 图表选择
                Picker("图表", selection: $selectedChart) {
                    Text("GPU").tag(0)
                    Text("CPU").tag(1)
                    Text("内存").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }
            
            // 图表
            ZStack {
                if selectedChart == 0 && !metricHistory.gpuHistory.isEmpty {
                    TrendChartView(
                        dataPoints: metricHistory.gpuHistory,
                        color: .blue,
                        title: "GPU 利用率 (%)",
                        maxValue: 100
                    )
                } else if selectedChart == 1 && !metricHistory.cpuHistory.isEmpty {
                    TrendChartView(
                        dataPoints: metricHistory.cpuHistory,
                        color: .purple,
                        title: "CPU 利用率 (%)",
                        maxValue: 100
                    )
                } else if selectedChart == 2 && !metricHistory.memoryHistory.isEmpty {
                    TrendChartView(
                        dataPoints: metricHistory.memoryHistory,
                        color: .cyan,
                        title: "内存使用 (%)",
                        maxValue: 100
                    )
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("暂无历史数据")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 120)
            
            // 统计信息
            VStack(spacing: 4) {
                HStack {
                    Text("当前: \(String(format: "%.1f", getCurrentValue()))")
                    Spacer()
                    Text("最高: \(String(format: "%.1f", getMaxValue()))")
                    Spacer()
                    Text("最低: \(String(format: "%.1f", getMinValue()))")
                    Spacer()
                    Text("平均: \(String(format: "%.1f", getAverage()))")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
                
                Divider()
                
                // 导出按钮
                HStack(spacing: 8) {
                    Button("导出 CSV") {
                        _ = DataExporter.shared.exportToCSV(metricData: metricData)
                    }
                    .controlSize(.small)
                    
                    Button("导出 JSON") {
                        _ = DataExporter.shared.exportToJSON(metricData: metricData)
                    }
                    .controlSize(.small)
                    
                    Spacer()
                    
                    Button("清除历史") {
                        metricHistory.clearAll()
                    }
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding()
        .frame(width: 320, height: 300)
    }
    
    private func getCurrentValue() -> Double {
        switch selectedChart {
        case 0: return metricHistory.gpuHistory.last?.value ?? 0
        case 1: return metricHistory.cpuHistory.last?.value ?? 0
        case 2: return metricHistory.memoryHistory.last?.value ?? 0
        default: return 0
        }
    }
    
    private func getMaxValue() -> Double {
        let points: [HistoryPoint]
        switch selectedChart {
        case 0: points = metricHistory.gpuHistory
        case 1: points = metricHistory.cpuHistory
        case 2: points = metricHistory.memoryHistory
        default: points = []
        }
        return points.map { $0.value }.max() ?? 0
    }
    
    private func getMinValue() -> Double {
        let points: [HistoryPoint]
        switch selectedChart {
        case 0: points = metricHistory.gpuHistory
        case 1: points = metricHistory.cpuHistory
        case 2: points = metricHistory.memoryHistory
        default: points = []
        }
        return points.map { $0.value }.min() ?? 0
    }
    
    private func getAverage() -> Double {
        let points: [HistoryPoint]
        switch selectedChart {
        case 0: points = metricHistory.gpuHistory
        case 1: points = metricHistory.cpuHistory
        case 2: points = metricHistory.memoryHistory
        default: points = []
        }
        guard !points.isEmpty else { return 0 }
        return Double(points.map { $0.value }.reduce(0, +)) / Double(points.count)
    }
}
