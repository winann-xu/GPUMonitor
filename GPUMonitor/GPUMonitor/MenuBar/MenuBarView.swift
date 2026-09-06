// MARK: - MenuBarView
// 菜单栏主视图 — 常驻在右上角状态栏

import SwiftUI

@MainActor
class MenuBarController: ObservableObject {
    static let shared = MenuBarController()
    
    @Published var textSummary: String = "..."
    @Published var gpuLoad: Double = 0
    @Published var gpuTemp: Double = 0
    @Published var netDownload: Double = 0
    @Published var netUpload: Double = 0
    @Published var isWarning: Bool = false
    @Published var isCritical: Bool = false
}

struct MenuBarView: View {
    @EnvironmentObject var menuBarCtrl: MenuBarController
    
    var body: some View {
        // MenuBarExtra 的 label 对自定义 Button/组合视图支持有限，
        // 纯 Text 才能可靠跟随系统菜单栏的字体与明暗配色。
        Text(labelText)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .fixedSize()
            .help(menuBarCtrl.isCritical ? "GPU Monitor 告警" : "GPU Monitor")
    }
    
    private var labelText: String {
        if SettingsStore.shared.showTextSummary {
            return menuBarCtrl.textSummary + menuBarCtrl.statusSuffix
        }
        return "GPU" + menuBarCtrl.statusSuffix
    }
}

// MARK: - 菜单栏状态文本
// 告警/警告时在摘要后附加状态符号（纯文本，确保菜单栏可见）
extension MenuBarController {
    var statusSuffix: String {
        if isCritical { return " ▲▲" }
        if isWarning { return " ▲" }
        return ""
    }
}
