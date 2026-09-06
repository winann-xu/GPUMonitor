// MARK: - AlertPanelView
// 告警面板视图

import SwiftUI

struct AlertPanelView: View {
    @EnvironmentObject var alertService: AlertService
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("告警记录")
                    .font(.headline)
                Spacer()
                Button("清除") {
                    alertService.clearAlerts()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            if alertService.alerts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("暂无告警")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(alertService.alerts.prefix(20)) { alert in
                            alertRow(alert)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .padding()
    }
    
    // MARK: - 告警行
    private func alertRow(_ alert: AlertModel) -> some View {
        HStack(spacing: 8) {
            // 告警级别图标
            Image(systemName: alertIcon(alert.level))
                .foregroundColor(alertColor(alert.level))
                .font(.system(size: 16))
            
            // 告警内容
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.title)
                    .font(.caption)
                    .fontWeight(.medium)
                Text(alert.message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 时间
            Text(alert.timestamp.timeAgo())
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(6)
        .background(alertColor(alert.level).opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - 告警图标
    private func alertIcon(_ level: AlertModel.AlertLevel) -> String {
        switch level {
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    // MARK: - 告警颜色
    private func alertColor(_ level: AlertModel.AlertLevel) -> Color {
        switch level {
        case .warning: return .yellow
        case .critical: return .red
        case .info: return .blue
        }
    }
}

// MARK: - Date 扩展
extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}