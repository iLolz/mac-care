import Foundation

extension Int64 {
    var formattedBytes: String {
        ByteCountFormatter.string(fromByteCount: self, countStyle: .file)
    }
}

extension Date {
    private static let relativeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    /// "hoje 09:42", "ontem 18:10" or a short date, following the user's locale.
    var relativeScanTime: String {
        Date.relativeFormatter.string(from: self)
    }
}

extension Int {
    /// "1 item", "1.234 itens".
    var itemCount: String {
        self == 1 ? "1 item" : "\(formatted()) itens"
    }
}

extension URL {
    /// The path with the home folder shown as `~`.
    var abbreviatedPath: String {
        (path as NSString).abbreviatingWithTildeInPath
    }
}
