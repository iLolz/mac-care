import CleanerKit
import SwiftUI

// Placeholder layout; replaced by the Claude Design screens.
struct ContentView: View {
    let model: ScanViewModel

    var body: some View {
        List(model.categories) { category in
            HStack {
                Image(systemName: category.symbol)
                Text(category.title)
                Spacer()
                switch model.state(for: category) {
                case .idle: Text("—")
                case .scanning: ProgressView().controlSize(.small)
                case .done(let result): Text(result.totalSize.formattedBytes)
                }
            }
        }
        .toolbar {
            Button("Analisar") { Task { await model.scan() } }
                .disabled(model.isScanning)
        }
        .task { await model.scan() }
    }
}

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}
