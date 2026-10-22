import AppKit
import CleanerKit
import SwiftUI

struct MenuBarPanel: View {
    let model: ScanViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(freeText)
                    .font(.system(size: 24, weight: .semibold).monospacedDigit())
                    .kerning(-0.3)
                    .foregroundStyle(isLowSpace ? Color.mcWarning : Color.mcText)
                if let volume = model.volume {
                    Text("de \(volume.totalBytes.formattedBytes)")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.mcSecondary)
                }
            }

            UsageBar(
                fractions: fractions,
                usedColor: isLowSpace ? .mcLowSpace : .mcDiskUsed,
                freeColor: isLowSpace ? .mcLowSpaceTrack : .mcDiskFree
            )
            .frame(height: 10)
            .accessibilityElement()
            .accessibilityLabel(accessibilityText)

            HStack(spacing: 4) {
                Text("Recuperável:")
                    .foregroundStyle(Color.mcSecondary)
                Text(model.selectedBytes.formattedBytes)
                    .fontWeight(.semibold)
                    .foregroundStyle(isLowSpace ? Color.mcText : Color.mcAccent)
                Spacer(minLength: 8)
                Text(lastScanText)
                    .foregroundStyle(Color.mcSecondary)
            }
            .font(.system(size: 12).monospacedDigit())

            if model.isScanning {
                ProgressView(value: scanProgress)
                    .progressViewStyle(.linear)
                    .tint(Color.mcAccent)
                    .controlSize(.small)
            }

            Button {
                Task { await model.scan() }
            } label: {
                Text(model.isScanning ? String(localized: "Analisando…") : String(localized: "Analisar agora"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MCButtonStyle(kind: isLowSpace ? .warning : .primary))
            .disabled(model.isScanning)
            .padding(.top, 2)

            HStack(spacing: 8) {
                Button {
                    openMainWindow()
                } label: {
                    Text("Abrir Mac Care")
                        .frame(maxWidth: .infinity)
                }
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Text("Sair do Mac Care")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(MCButtonStyle(kind: .secondary))
        }
        .padding(16)
        .frame(width: 300)
        .foregroundStyle(Color.mcText)
        .background(Color.mcCard)
        .environment(\.colorScheme, .light)
        .onAppear { model.refreshVolume() }
    }

    private var header: some View {
        HStack(spacing: 4) {
            if isLowSpace {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(headerText)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(isLowSpace ? Color.mcWarning : Color.mcSecondary)
    }

    private var headerText: String {
        let name = model.volumeName ?? String(localized: "Disco")
        return isLowSpace ? String(localized: "\(name) · pouco espaço") : name
    }

    private var isLowSpace: Bool {
        guard let volume = model.volume, volume.totalBytes > 0 else { return false }
        return volume.freeFraction < AppSettings.lowSpaceFraction
    }

    private var freeText: String {
        guard let volume = model.volume else { return "—" }
        return String(localized: "\(volume.availableBytes.formattedBytes) livres")
    }

    private var lastScanText: String {
        if model.isScanning { return String(localized: "Analisando…") }
        guard let lastScan = model.lastScan else { return String(localized: "Não analisado") }
        return lastScan.relativeScanTime
    }

    private var scanProgress: Double {
        guard !model.categories.isEmpty else { return 0 }
        let done = model.categories.filter { model.result(for: $0) != nil }.count
        return Double(done) / Double(model.categories.count)
    }

    private var fractions: (used: Double, recoverable: Double) {
        guard let volume = model.volume, volume.totalBytes > 0 else { return (0, 0) }
        let total = Double(volume.totalBytes)
        let recoverable = min(model.selectedBytes, volume.usedBytes)
        let used = max(volume.usedBytes - recoverable, 0)
        return (Double(used) / total, Double(recoverable) / total)
    }

    private var accessibilityText: String {
        let percent = { (value: Double) in value.formatted(.percent.precision(.fractionLength(1))) }
        let free = max(1 - fractions.used - fractions.recoverable, 0)
        return String(localized: "Disco: \(percent(fractions.used)) usado, \(percent(fractions.recoverable)) recuperável, \(percent(free)) livre")
    }

    private func openMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: WindowID.main)
        NSApp.activate()
    }
}
