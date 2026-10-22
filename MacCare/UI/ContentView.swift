import AppKit
import CleanerKit
import SwiftUI

struct ContentView: View {
    let model: ScanViewModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: Metrics.cardGap) {
                DiskSummaryCard(
                    volume: model.volume,
                    recoverableBytes: model.selectedBytes,
                    lastScan: model.lastScan,
                    isScanning: model.isScanning
                )
                if !model.hasFullDiskAccess {
                    FullDiskAccessBanner(onRecheck: { model.refreshAccess() })
                }
                categoryList
            }
            .padding(.horizontal, Metrics.windowPaddingH)
            .padding(.vertical, Metrics.windowPaddingV)
            .frame(maxHeight: .infinity)

            footer
        }
        .foregroundStyle(Color.mcText)
        .background(Color.mcWindow)
        .navigationSubtitle(model.volumeName ?? "")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.scan() }
                } label: {
                    Label("Analisar", systemImage: "arrow.clockwise")
                }
                .labelStyle(.titleAndIcon)
                .disabled(model.isScanning)
            }
            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .help("Ajustes")
            }
        }
        .toolbarBackground(Color.mcChrome, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshAccess()
        }
        .task { await model.scan() }
    }

    private var categoryList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Categorias")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.mcText)
                Spacer()
                Text(listSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mcSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 16)
            .frame(height: Metrics.listHeaderHeight)

            Color.mcRowBorder.frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.categories.enumerated()), id: \.element.id) { index, category in
                        CategoryRow(
                            category: category,
                            state: model.state(for: category),
                            isSelected: model.isSelected(category),
                            onToggle: { model.toggle(category) }
                        )
                        if index < model.categories.count - 1 {
                            Color.mcRowBorder.frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .card()
    }

    private var listSummary: String {
        if model.isScanning { return "Analisando…" }
        guard model.lastScan != nil else { return "" }
        var parts = ["\(model.recoverableBytes.formattedBytes) encontrados"]
        if model.lockedCount > 0 {
            parts.append("\(model.lockedCount) sem acesso")
        }
        return parts.joined(separator: " · ")
    }

    private func footerSummary(count: Int) -> String {
        let selection = count == 1 ? "1 categoria selecionada" : "\(count) categorias selecionadas"
        return "\(selection) · os itens vão para a Lixeira e você revisa antes"
    }

    private var footer: some View {
        let count = model.selectedCategories.count
        let bytes = model.selectedBytes
        return VStack(spacing: 0) {
            Color.mcChromeBorder.frame(height: 1)
            HStack(spacing: 16) {
                Text(footerSummary(count: count))
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mcSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Limpar \(bytes.formattedBytes)") {
                    // TODO: step 2
                }
                .buttonStyle(MCButtonStyle(kind: .primary))
                .shadow(color: Color.mcAccent.opacity(0.3), radius: 1, y: 1)
                .disabled(bytes <= 0)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, Metrics.windowPaddingH)
            .frame(height: Metrics.footerHeight - 1)
        }
        .background(Color.mcChrome)
    }
}
