import SwiftUI

@main
struct MacCareApp: App {
    @State private var model = ScanViewModel()

    var body: some Scene {
        WindowGroup("Mac Care") {
            ContentView(model: model)
                .frame(minWidth: 720, minHeight: 560)
        }
        .windowResizability(.contentMinSize)
    }
}
