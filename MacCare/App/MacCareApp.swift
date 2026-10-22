import SwiftUI

@main
struct MacCareApp: App {
    @State private var model = ScanViewModel()

    var body: some Scene {
        WindowGroup("Mac Care") {
            ContentView(model: model)
                .frame(minWidth: 720, minHeight: 560)
                .preferredColorScheme(.light)
        }
        .windowResizability(.contentMinSize)

        Settings {
            Text("Ajustes em breve")
                .padding(40)
                .preferredColorScheme(.light)
        }
    }
}
