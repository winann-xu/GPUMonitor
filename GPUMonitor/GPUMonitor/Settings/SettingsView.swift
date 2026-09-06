// MARK: - SettingsView
// 设置面板

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismissWindow) var dismissWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.headline)
            
            Divider()
            
            // 采集频率
            GroupBox("采集频率") {
                Picker("频率", selection: $settings.interval) {
                    Text("500ms").tag(0.5)
                    Text("1秒").tag(1.0)
                    Text("2秒").tag(2.0)
                    Text("5秒").tag(5.0)
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)
            }
            
            // 显示开关
            GroupBox("显示指标") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("GPU", isOn: $settings.showGPU)
                    Toggle("CPU", isOn: $settings.showCPU)
                    Toggle("内存", isOn: $settings.showMemory)
                    Toggle("网络", isOn: $settings.showNetwork)
                }
                .padding(.vertical, 4)
            }
            
            // 告警阈值
            GroupBox("告警阈值") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("温度")
                        Slider(value: $settings.tempThreshold, in: 60...100)
                        Text("\(Int(settings.tempThreshold))°C")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 35)
                    }
                    
                    HStack {
                        Text("利用率")
                        Slider(value: $settings.loadThreshold, in: 70...99)
                        Text("\(Int(settings.loadThreshold))%")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 35)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()
            
            Button("关闭") {
                dismissWindow()
            }
            .controlSize(.large)
        }
        .padding()
    }
}
