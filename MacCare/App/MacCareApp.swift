import SwiftUI

@main
struct MacCareApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = ScanViewModel()
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = AppSettings.showInMenuBarDefault

    var body: some Scene {
        Window("Mac Care", id: WindowID.main) {
            ContentView(model: model)
                .frame(minWidth: 720, minHeight: 560)
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentMinSize)

        MenuBarExtra("Mac Care", systemImage: "internaldrive", isInserted: $showInMenuBar) {
            MenuBarPanel(model: model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentSize)
    }
}
