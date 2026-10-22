import CleanerKit
import SwiftUI

struct CategoryRow: View {
    let category: CleanupCategory
    let state: ScanViewModel.CategoryState
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                Text(category.localizedTitle)
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .tint(.mcAccent)
            .disabled(isLocked)

            Image(systemName: category.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isLocked ? Color.mcDisabled : Color.mcAccent)
                .frame(width: 28, height: 28)
                .background(
                    isLocked ? Color.mcRowBorder : Color.mcAccentTint,
                    in: RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(category.localizedTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isLocked ? Color.mcSecondary : Color.mcText)
                Text(isLocked ? String(localized: "Precisa de Acesso Total ao Disco para ser lida") : category.localizedSummary)
                    .font(.system(size: 12))
                    .foregroundStyle(isLocked ? Color.mcDisabled : Color.mcSecondary)
            }
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)

            status

            size
                .frame(width: Metrics.sizeColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: Metrics.rowHeight)
        .background(isLocked ? Color.mcDisabledRow : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isLocked { onToggle() }
        }
    }

    private var result: CategoryScanResult? {
        if case .done(let result) = state { return result }
        return nil
    }

    private var isLocked: Bool {
        guard let result else { return false }
        return result.items.isEmpty && !result.unreadableFolders.isEmpty
    }

    @ViewBuilder
    private var status: some View {
        if let result, !result.unreadableFolders.isEmpty {
            let count = result.unreadableFolders.count
            HStack(spacing: 4) {
                Image(systemName: isLocked ? "lock" : "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .semibold))
                Text(statusText(unreadable: count))
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.mcWarning)
            .help(result.unreadableFolders.map(\.path).joined(separator: "\n"))
        }
    }

    private func statusText(unreadable count: Int) -> String {
        if isLocked { return String(localized: "Sem acesso") }
        return count == 1 ? String(localized: "1 pasta sem leitura") : String(localized: "\(count) pastas sem leitura")
    }

    @ViewBuilder
    private var size: some View {
        switch state {
        case .scanning:
            ProgressView()
                .controlSize(.small)
        case .done(let result) where !isLocked:
            Text(result.totalSize.formattedBytes)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(Color.mcText)
        default:
            Text(verbatim: "—")
                .font(.system(size: 13))
                .foregroundStyle(Color.mcDisabled)
        }
    }
}
