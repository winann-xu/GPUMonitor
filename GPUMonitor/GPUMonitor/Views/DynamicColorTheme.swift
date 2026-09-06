// MARK: - DynamicColorTheme
// 动态配色主题

import SwiftUI

struct DynamicColorTheme {
    // 通用负载配色（绿 → 黄 → 橙 → 红）
    static func loadColor(_ load: Double) -> Color {
        switch load {
        case 0...30: return .green
        case 30...70: return .yellow
        case 70...90: return .orange
        default: return .red
        }
    }
    
    // GPU/CPU 负载均使用通用负载配色，便于用户一眼识别压力等级
    static func gpuColor(_ load: Double) -> Color { loadColor(load) }
    static func cpuColor(_ load: Double) -> Color { loadColor(load) }
    
    // 温度颜色
    static func tempColor(_ temp: Double) -> Color {
        switch temp {
        case 0...60: return .green
        case 60...75: return .yellow
        case 75...85: return .orange
        default: return .red
        }
    }
    
    // 内存颜色
    static func memoryColor(_ percent: Double) -> Color {
        switch percent {
        case 0...70: return .cyan
        case 70...85: return .yellow
        case 85...95: return .orange
        default: return .red
        }
    }
    
    // 网络颜色
    static func networkColor(_ isDown: Bool) -> Color {
        isDown ? .green : .blue
    }
}
