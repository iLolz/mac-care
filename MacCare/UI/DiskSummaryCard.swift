import AppKit
import CleanerKit
import SwiftUI

struct DiskSummaryCard: View {
    let volume: VolumeUsage?
    let recoverableBytes: Int64
    let lastScan: Date?
    let isScanning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom, spacing: 24) {
                HStack(alignment: .center, spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 52, height: 52)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Espaço livre")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mcSecondary)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(volume?.availableBytes.formattedBytes ?? "—")
                                .font(.system(size: 28, weight: .semibold).monospacedDigit())
                                .kerning(-0.4)
                            if let volume {
                                Text("livres de \(volume.totalBytes.formattedBytes) · \(volume.usedBytes.formattedBytes) usados")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.mcSecondary)
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: 28) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Recuperável")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mcSecondary)
                        Text(recoverableBytes.formattedBytes)
                            .font(.system(size: 22, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.mcAccent)
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Última análise")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mcSecondary)
                        Text(lastScanText)
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }

            UsageBar(fractions: fractions)
                .frame(height: 12)
                .accessibilityElement()
                .accessibilityLabel(accessibilityText)

            HStack(spacing: 20) {
                LegendItem(color: .mcDiskUsed, text: String(localized: "Usado \(usedWithoutRecoverable.formattedBytes)"))
                LegendItem(color: .mcAccent, text: String(localized: "Recuperável \(recoverableShown.formattedBytes)"))
                LegendItem(
                    color: .mcDiskFree,
                    border: .mcDiskFreeBorder,
                    text: String(localized: "Livre \((volume?.availableBytes ?? 0).formattedBytes)")
                )
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.mcSecondary)
        }
        .foregroundStyle(Color.mcText)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var lastScanText: String {
        if isScanning { return String(localized: "Analisando…") }
        return lastScan?.relativeScanTime ?? "—"
    }

    private var recoverableShown: Int64 {
        min(recoverableBytes, volume?.usedBytes ?? recoverableBytes)
    }

    private var usedWithoutRecoverable: Int64 {
        max((volume?.usedBytes ?? 0) - recoverableShown, 0)
    }

    private var fractions: (used: Double, recoverable: Double) {
        guard let volume, volume.totalBytes > 0 else { return (0, 0) }
        let total = Double(volume.totalBytes)
        return (Double(usedWithoutRecoverable) / total, Double(recoverableShown) / total)
    }

    private var accessibilityText: String {
        let percent = { (value: Double) in value.formatted(.percent.precision(.fractionLength(1))) }
        let free = max(1 - fractions.used - fractions.recoverable, 0)
        return String(localized: "Disco: \(percent(fractions.used)) usado, \(percent(fractions.recoverable)) recuperável, \(percent(free)) livre")
    }
}

struct UsageBar: View {
    let fractions: (used: Double, recoverable: Double)
    var usedColor: Color = .mcDiskUsed
    var freeColor: Color = .mcDiskFree

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                usedColor
                    .frame(width: proxy.size.width * fractions.used)
                if fractions.recoverable > 0 {
                    Color.white.frame(width: 2)
                    Color.mcAccent
                        .frame(width: max(proxy.size.width * fractions.recoverable - 2, 0))
                }
                Spacer(minLength: 0)
            }
        }
        .background(freeColor)
        .clipShape(Capsule())
    }
}

private struct LegendItem: View {
    let color: Color
    var border: Color?
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .overlay {
                    if let border {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(border, lineWidth: 1)
                    }
                }
                .frame(width: 10, height: 10)
            Text(text)
                .monospacedDigit()
        }
    }
}
