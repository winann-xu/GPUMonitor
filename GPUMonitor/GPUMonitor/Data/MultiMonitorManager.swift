// MARK: - MultiMonitorManager
// 多显示器管理

import SwiftUI

@MainActor
class MultiMonitorManager: ObservableObject {
    static let shared = MultiMonitorManager()
    
    @Published var screens: [ScreenInfo] = []
    
    struct ScreenInfo: Identifiable {
        let id: UUID = UUID()
        let name: String
        let frame: CGRect
        let isMain: Bool
    }
    
    init() {
        updateScreens()
    }
    
    func updateScreens() {
        screens = NSScreen.screens.map { screen in
            ScreenInfo(
                name: screen.localizedName,
                frame: screen.frame,
                isMain: (NSScreen.main == screen)
            )
        }
    }
    
    var mainScreen: ScreenInfo? {
        screens.first(where: { $0.isMain })
    }
}
