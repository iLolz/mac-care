import AppKit
import CleanerKit
import SwiftUI

struct CleanupSheet: View {
    let model: CleanupViewModel
    /// Called when the sheet goes away after something was cleaned.
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch model.phase {
            case .review:
                CleanupReviewView(model: model, onCancel: { dismiss() })
            case .cleaning:
                CleanupProgressView(model: model)
            case .done:
                CleanupResultView(model: model, onClose: { dismiss() })
            }
        }
        .frame(width: 640, height: 600)
        .foregroundStyle(Color.mcText)
        .background(Color.mcCard)
        .preferredColorScheme(.light)
        .interactiveDismissDisabled(model.phase == .cleaning)
        .onDisappear {
            if model.phase != .review { onFinished() }
        }
    }
}

// MARK: - Shared pieces

private struct SheetHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Color.mcSecondary)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }
}

private struct SheetFooter<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Color.mcRowBorder.frame(height: 1)
            HStack(spacing: 10) {
                content
            }
            .padding(.horizontal, 20)
            .frame(height: 63)
        }
        .background(Color.mcChrome)
    }
}

// MARK: - Review

struct CleanupReviewView: View {
    let model: CleanupViewModel
    let onCancel: () -> Void

    var body: some View {
        let included = model.includedGroups
        VStack(spacing: 0) {
            SheetHeader(title: String(localized: "Revisar limpeza"), subtitle: subtitle(included))
            Color.mcRowBorder.frame(height: 1)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.groups) { group in
                        ReviewGroup(group: group, model: model)
                        if group.id != model.groups.last?.id {
                            Color.mcRowBorder.frame(height: 1)
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity)

            SheetFooter {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.mcSecondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Os itens vão para a Lixeira. Você pode restaurá-los até esvaziá-la.")
                        .foregroundStyle(Color.mcSecondary)
                    if model.includesTrash {
                        Text("Itens da Lixeira serão apagados definitivamente.")
                            .fontWeight(.medium)
                            .foregroundStyle(Color.mcWarning)
                    }
                }
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("Cancelar", action: onCancel)
                    .buttonStyle(MCButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
                Button("Mover para a Lixeira") { model.start() }
                    .buttonStyle(MCButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
                    .disabled(included.isEmpty)
            }
        }
    }

    private func subtitle(_ included: [CleanupViewModel.Group]) -> String {
        guard !included.isEmpty else { return String(localized: "Nada selecionado. Marque o que quiser limpar.") }
        let bytes = included.reduce(Int64(0)) { $0 + $1.totalSize }
        let categories = included.count == 1
            ? String(localized: "1 categoria")
            : String(localized: "\(included.count) categorias")
        return String(localized: "\(bytes.formattedBytes) em \(categories). Desmarque o que quiser manter.")
    }
}

private struct ReviewGroup: View {
    let group: CleanupViewModel.Group
    let model: CleanupViewModel

    @State private var isExpanded: Bool
    @State private var showsAll = false

    private static let previewLimit = 8

    init(group: CleanupViewModel.Group, model: CleanupViewModel) {
        self.group = group
        self.model = model
        // Categories that may hold files people still want start open.
        _isExpanded = State(initialValue: ScanViewModel.optInCategories.contains(group.id))
    }

    var body: some View {
        let included = model.includedItems(in: group)
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Toggle(isOn: Binding(get: { model.isIncluded(group) }, set: { _ in model.toggle(group) })) {
                    Text("Incluir \(group.category.localizedTitle)")
                }
                .toggleStyle(.checkbox)
                .labelsHidden()
                .tint(.mcAccent)

                Button {
                    withAnimation(.easeOut(duration: 0.15)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.mcSecondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        Text(group.category.localizedTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.mcText)
                        Text(countText(included: included.count))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.mcSecondary)
                            .monospacedDigit()
                        Spacer(minLength: 0)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(isExpanded ? Text("Expandido") : Text("Recolhido"))

                Text(included.reduce(Int64(0)) { $0 + $1.size }.formattedBytes)
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(included.isEmpty ? Color.mcDisabled : Color.mcText)
            }
            .padding(.horizontal, 20)
            .frame(height: 44)

            if isExpanded {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(visibleItems, id: \.url) { item in
                        ReviewItemRow(item: item, model: model)
                    }
                    if hiddenItems.count > 0 {
                        Button {
                            showsAll = true
                        } label: {
                            Text(showMoreText)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.mcAccent)
                                .frame(height: 28)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 66)
                .padding(.trailing, 20)
                .padding(.bottom, 8)
            }
        }
    }

    private var visibleItems: ArraySlice<ScanItem> {
        showsAll ? group.items[...] : group.items.prefix(Self.previewLimit)
    }

    private var hiddenItems: ArraySlice<ScanItem> {
        showsAll ? [] : group.items.dropFirst(Self.previewLimit)
    }

    private var showMoreText: String {
        let bytes = hiddenItems.reduce(Int64(0)) { $0 + $1.size }
        return String(localized: "Mostrar mais \(hiddenItems.count.itemCount) · \(bytes.formattedBytes)")
    }

    private func countText(included: Int) -> String {
        let total = group.items.count
        return included == total ? total.itemCount : String(localized: "\(included.formatted()) de \(total.itemCount)")
    }
}

private struct ReviewItemRow: View {
    let item: ScanItem
    let model: CleanupViewModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle(isOn: Binding(get: { model.isIncluded(item) }, set: { _ in model.toggle(item) })) {
                Text(item.url.lastPathComponent)
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .controlSize(.small)
            .tint(.mcAccent)

            Text(item.url.abbreviatedPath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(model.isIncluded(item) ? Color.mcPath : Color.mcDisabled)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(item.url.path)

            Text(item.size.formattedBytes)
                .font(.system(size: 12).monospacedDigit())
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .onTapGesture { model.toggle(item) }
    }
}

// MARK: - Progress

struct CleanupProgressView: View {
    let model: CleanupViewModel

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: model.isCancelling ? String(localized: "Cancelando…") : String(localized: "Limpando…"),
                subtitle: model.isCancelling
                    ? String(localized: "Parando depois do item atual. O que já foi feito fica como está.")
                    : String(localized: "Os itens vão para a Lixeira um a um.")
            )

            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: model.progress)
                    .progressViewStyle(.linear)
                    .tint(.mcAccent)
                    .accessibilityLabel("Progresso da limpeza")
                Text(counterText)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mcSecondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.plan) { group in
                        StepRow(group: group, model: model)
                        if group.id != model.plan.last?.id {
                            Color.mcRowBorder.frame(height: 1)
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
                .card()
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            }
            .frame(maxHeight: .infinity)

            SheetFooter {
                Text(currentItemText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.mcSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .help(model.currentItem?.path ?? "")
                Button("Cancelar") { model.cancel() }
                    .buttonStyle(MCButtonStyle(kind: .secondary))
                    .keyboardShortcut(.cancelAction)
                    .disabled(model.isCancelling)
            }
        }
    }

    private var counterText: String {
        let items = model.processedItems.formatted()
        return String(localized: "\(items) de \(model.totalItems.itemCount) · \(model.processedBytes.formattedBytes) de \(model.totalBytes.formattedBytes)")
    }

    private var currentItemText: String {
        guard let url = model.currentItem else { return String(localized: "Preparando…") }
        let path = url.abbreviatedPath
        return model.currentCategory == .trash ? String(localized: "Apagando \(path)") : String(localized: "Movendo \(path)")
    }
}

private struct StepRow: View {
    let group: CleanupViewModel.Group
    let model: CleanupViewModel

    var body: some View {
        let state = model.state(of: group)
        let failures = model.stepFailures[group.id] ?? 0
        HStack(spacing: 10) {
            indicator(state)
                .frame(width: 18, height: 18)

            Text(state == .running ? String(localized: "Limpando \(group.category.localizedTitle)…") : group.category.localizedTitle)
                .font(.system(size: 13, weight: state == .running ? .semibold : .regular))
                .foregroundStyle(state == .pending ? Color.mcSecondary : Color.mcText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if failures > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 11, weight: .semibold))
                    Text(failures == 1 ? String(localized: "1 falha") : String(localized: "\(failures.formatted()) falhas"))
                }
                .font(.system(size: 12))
                .foregroundStyle(Color.mcWarning)
            }

            Text(sizeText(state))
                .font(.system(size: 13, weight: state == .done ? .medium : .regular).monospacedDigit())
                .foregroundStyle(state == .done ? Color.mcAccent : Color.mcSecondary)
                .frame(width: Metrics.sizeColumnWidth + 20, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .frame(height: 40)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func indicator(_ state: CleanupViewModel.StepState) -> some View {
        switch state {
        case .pending:
            Circle()
                .strokeBorder(Color.mcControlBorder, lineWidth: 1.5)
                .padding(1)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color.mcAccent)
        }
    }

    private func sizeText(_ state: CleanupViewModel.StepState) -> String {
        switch state {
        case .pending, .running:
            return group.totalSize.formattedBytes
        case .done:
            return (model.stepRemovedBytes[group.id] ?? 0).formattedBytes
        }
    }
}

// MARK: - Result

struct CleanupResultView: View {
    let model: CleanupViewModel
    let onClose: () -> Void

    var body: some View {
        let summary = model.summary ?? CleanupSummary()
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    headline(summary)
                    if let volume = model.volumeBefore, volume.totalBytes > 0, summary.removedBytes > 0 {
                        BeforeAfterCard(volume: volume, summary: summary)
                    }
                    if !summary.failures.isEmpty {
                        FailureList(failures: summary.failures)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
            .frame(maxHeight: .infinity)

            SheetFooter {
                Spacer()
                Button("Concluído", action: onClose)
                    .buttonStyle(MCButtonStyle(kind: .primary))
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func headline(_ summary: CleanupSummary) -> some View {
        let succeeded = summary.removedBytes > 0
        return VStack(spacing: 8) {
            Image(systemName: succeeded ? "checkmark" : "exclamationmark.triangle")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(succeeded ? Color.mcAccent : Color.mcWarning)
                .frame(width: 52, height: 52)
                .background(succeeded ? Color.mcAccentTint : Color.mcBanner, in: Circle())
                .accessibilityHidden(true)

            Text(title(summary))
                .font(.system(size: 22, weight: .semibold))
                .kerning(-0.3)
                .multilineTextAlignment(.center)
                .padding(.top, 4)

            if summary.trashedBytes > 0, summary.deletedBytes > 0 {
                Text("e \(summary.deletedBytes.formattedBytes) apagados definitivamente")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.mcText)
            }

            Text(detail(summary))
                .font(.system(size: 13))
                .foregroundStyle(Color.mcSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func title(_ summary: CleanupSummary) -> String {
        if summary.trashedBytes > 0 {
            return String(localized: "\(summary.trashedBytes.formattedBytes) movidos para a Lixeira")
        }
        if summary.deletedBytes > 0 {
            return String(localized: "\(summary.deletedBytes.formattedBytes) apagados definitivamente")
        }
        return String(localized: "Nenhum item foi removido")
    }

    private func detail(_ summary: CleanupSummary) -> String {
        var parts: [String] = []
        if summary.wasCancelled {
            parts.append(String(localized: "Limpeza cancelada. O que já tinha sido feito foi mantido."))
        }
        if summary.trashedBytes > 0 {
            parts.append(String(localized: "O espaço só é liberado de fato quando você esvazia a Lixeira."))
        } else if summary.deletedBytes > 0 {
            parts.append(String(localized: "O espaço já foi liberado."))
        }
        return parts.joined(separator: " ")
    }
}

private struct BeforeAfterCard: View {
    let volume: VolumeUsage
    let summary: CleanupSummary

    var body: some View {
        let total = Double(volume.totalBytes)
        let freed = min(summary.removedBytes, volume.usedBytes)
        let usedAfter = volume.usedBytes - freed
        VStack(alignment: .leading, spacing: 14) {
            row(
                label: String(localized: "Antes"),
                value: String(localized: "\(volume.availableBytes.formattedBytes) livres"),
                highlighted: false,
                used: Double(volume.usedBytes) / total,
                freed: 0
            )
            row(
                label: summary.trashedBytes > 0 ? String(localized: "Depois de esvaziar a Lixeira") : String(localized: "Depois"),
                value: String(localized: "\((volume.availableBytes + freed).formattedBytes) livres"),
                highlighted: true,
                used: Double(usedAfter) / total,
                freed: Double(freed) / total
            )
            HStack(spacing: 20) {
                legend(.mcDiskUsed, String(localized: "Usado"))
                legend(.mcFreed, String(localized: "Liberado: \(freed.formattedBytes)"))
                legend(.mcDiskFree, String(localized: "Livre"), border: .mcDiskFreeBorder)
            }
            .font(.system(size: 12))
            .foregroundStyle(Color.mcSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(label: String, value: String, highlighted: Bool, used: Double, freed: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .foregroundStyle(Color.mcSecondary)
                Spacer()
                Text(value)
                    .fontWeight(highlighted ? .semibold : .medium)
                    .foregroundStyle(highlighted ? Color.mcAccent : Color.mcText)
                    .monospacedDigit()
            }
            .font(.system(size: 12))

            GeometryReader { proxy in
                HStack(spacing: 0) {
                    Color.mcDiskUsed
                        .frame(width: proxy.size.width * used)
                    if freed > 0 {
                        Color.white.frame(width: 2)
                        Color.mcFreed
                            .frame(width: max(proxy.size.width * freed - 2, 0))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 12)
            .background(Color.mcDiskFree)
            .clipShape(Capsule())
            .accessibilityHidden(true)
        }
    }

    private func legend(_ color: Color, _ text: String, border: Color? = nil) -> some View {
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

private struct FailureList: View {
    let failures: [CleanupFailure]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mcWarning)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
            .background(Color.mcBanner)

            LazyVStack(spacing: 0) {
                ForEach(failures, id: \.self) { failure in
                    Color.mcRowBorder.frame(height: 1)
                    FailureRow(failure: failure)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous))
        .card()
    }

    private var title: String {
        let bytes = failures.reduce(Int64(0)) { $0 + $1.item.size }
        let count = failures.count == 1
            ? String(localized: "1 item não foi removido")
            : String(localized: "\(failures.count.formatted()) itens não foram removidos")
        return "\(count) · \(bytes.formattedBytes)"
    }
}

private struct FailureRow: View {
    let failure: CleanupFailure

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(failure.item.url.abbreviatedPath)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(failure.item.url.path)
                Text(failure.localizedReason)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mcWarning)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(failure.item.size.formattedBytes)
                .font(.system(size: 12).monospacedDigit())

            Button("Mostrar no Finder") { reveal() }
                .buttonStyle(MCButtonStyle(kind: .secondary))
                .accessibilityLabel("Mostrar \(failure.item.url.lastPathComponent) no Finder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
    }

    private func reveal() {
        let url = failure.item.url
        let target = FileManager.default.fileExists(atPath: url.path) ? url : url.deletingLastPathComponent()
        NSWorkspace.shared.activateFileViewerSelecting([target])
    }
}
