// MARK: - MetricBarView
// 进度条组件 — 根据值显示彩色进度条

import SwiftUI

struct MetricBarView: View {
    let label: String
    let value: Double
    let maxValue: Double
    let unit: String
    let color: Color
    
    let barHeight: CGFloat = 8
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))\(unit)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(Color.primary.opacity(0.12))
                        .frame(height: barHeight)
                    
                    RoundedRectangle(cornerRadius: barHeight / 2)
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / maxValue, 1), height: barHeight)
                        .animation(.easeInOut(duration: 0.3), value: value)
                        .overlay(
                            RoundedRectangle(cornerRadius: barHeight / 2)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                        )
                }
            }
            .frame(height: barHeight)
        }
    }
}

// MARK: - 快捷构造器
extension MetricBarView {
    static func gpuLoad(_ value: Double) -> MetricBarView {
        MetricBarView(label: "利用率", value: value, maxValue: 100, unit: "%", color: DynamicColorTheme.gpuColor(value))
    }
    
    static func cpuLoad(_ value: Double) -> MetricBarView {
        MetricBarView(label: "利用率", value: value, maxValue: 100, unit: "%", color: DynamicColorTheme.cpuColor(value))
    }
    
    static func temperature(_ value: Double) -> MetricBarView {
        let color = DynamicColorTheme.tempColor(value)
        return MetricBarView(label: "温度", value: value, maxValue: 100, unit: "°C", color: color)
    }
    
    static func memoryUsage(_ used: Double, total: Double) -> MetricBarView {
        let percent = total > 0 ? used / total * 100 : 0
        return MetricBarView(label: "已用", value: used, maxValue: total, unit: "GB", color: DynamicColorTheme.memoryColor(percent))
    }
}
