// MARK: - EnhancedSettingsView
// 增强设置面板 — 含所有配置选项

import SwiftUI

struct EnhancedSettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var alertService: AlertService
    @EnvironmentObject var power: PowerMonitor
    @Environment(\.dismissWindow) var dismissWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("GPU Monitor 设置")
                    .font(.headline)
                Spacer()
                Button("✕") { dismissWindow() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 采集设置
            GroupBox("采集设置") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("采集频率:")
                        Spacer()
                        Picker("频率", selection: $settings.interval) {
                            Text("0.5s").tag(0.5)
                            Text("1s").tag(1.0)
                            Text("2s").tag(2.0)
                            Text("5s").tag(5.0)
                        }
                        .frame(width: 120)
                    }
                    
                    HStack {
                        Text("电源模式:")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(power.isCharging ? "⚡ 外接电源" : "🔋 电池")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(power.shouldReduceFrequency ? .red : .green)
                    }
                }
                .padding(4)
            }
            
            // 显示设置
            GroupBox("显示设置") {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("显示 GPU", isOn: $settings.showGPU)
                    Toggle("显示 CPU", isOn: $settings.showCPU)
                    Toggle("显示内存", isOn: $settings.showMemory)
                    Toggle("显示网络", isOn: $settings.showNetwork)
                    Toggle("显示文本摘要", isOn: $settings.showTextSummary)
                }
                .padding(4)
            }
            
            // 告警设置
            GroupBox("告警设置") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("温度阈值:")
                        Slider(value: $settings.tempThreshold, in: 60...100)
                        Text("\(Int(settings.tempThreshold))°C")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 40)
                    }
                    
                    HStack {
                        Text("负载阈值:")
                        Slider(value: $settings.loadThreshold, in: 70...99)
                        Text("\(Int(settings.loadThreshold))%")
                            .font(.system(size: 10, design: .monospaced))
                            .frame(width: 40)
                    }
                    
                    Button("清除所有告警") {
                        alertService.clearAlerts()
                    }
                    .controlSize(.small)
                    .foregroundColor(.secondary)
                }
                .padding(4)
            }
            
            Spacer()
            
            // 底部信息
            VStack(spacing: 4) {
                Divider()
                HStack {
                    Text("Version: 1.3.0")
                    Spacer()
                    Text("原生采集 · 无外部依赖")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                
                Button("关闭窗口") {
                    dismissWindow()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding()
        .frame(width: 320, height: 500)
    }
}
