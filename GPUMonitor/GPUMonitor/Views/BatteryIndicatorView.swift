// MARK: - BatteryIndicatorView
// 电池指示器

import SwiftUI

struct BatteryIndicatorView: View {
    @EnvironmentObject var power: PowerMonitor
    
    var body: some View {
        HStack(spacing: 4) {
            // 电池图标
            Image(systemName: batteryIcon())
                .foregroundColor(batteryColor())
                .font(.system(size: 12))
            
            // 电量百分比
            if power.powerSource == .battery {
                Text("\(Int(power.batteryPercent))%")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(batteryColor())
            }
            
            // 充电状态
            if power.isCharging && power.powerSource == .battery {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private func batteryIcon() -> String {
        let level = power.batteryPercent
        
        if !power.isCharging && level < 20 {
            return "battery.0"
        } else if level < 50 {
            return "battery.25"
        } else if level < 80 {
            return "battery.50"
        } else {
            return "battery.100"
        }
    }
    
    private func batteryColor() -> Color {
        if !power.isCharging && power.batteryPercent < 20 {
            return .red
        }
        return .green
    }
}