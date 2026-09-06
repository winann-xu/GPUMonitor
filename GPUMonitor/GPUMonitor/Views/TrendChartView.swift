// MARK: - TrendChartView
// 趋势图组件 — 用 SwiftUI 绘制折线图

import SwiftUI

struct TrendChartView: View {
    let dataPoints: [HistoryPoint]
    let color: Color
    let title: String
    let maxValue: Double
    
    let chartHeight: CGFloat = 80
    let chartPadding: CGFloat = 10
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if let latest = dataPoints.last {
                    Text("\(Int(latest.value))")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
            
            GeometryReader { geometry in
                if dataPoints.count < 2 {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                } else {
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                        
                        // 绘制折线
                        path.move(to: CGPoint(x: 0, y: chartHeight - (dataPoints[0].value / maxValue) * chartHeight))
                        for i in 1..<dataPoints.count {
                            let x = CGFloat(i) * stepX
                            let y = chartHeight - (dataPoints[i].value / maxValue) * chartHeight
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        // 填充区域
                        path.addLine(to: CGPoint(x: geometry.size.width, y: chartHeight))
                        path.addLine(to: CGPoint(x: 0, y: chartHeight))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.3))
                    
                    Path { path in
                        let stepX = geometry.size.width / CGFloat(dataPoints.count - 1)
                        path.move(to: CGPoint(x: 0, y: chartHeight - (dataPoints[0].value / maxValue) * chartHeight))
                        for i in 1..<dataPoints.count {
                            let x = CGFloat(i) * stepX
                            let y = chartHeight - (dataPoints[i].value / maxValue) * chartHeight
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(color, lineWidth: 2)
                }
            }
            .frame(height: chartHeight)
            .padding(.horizontal, chartPadding)
        }
    }
}