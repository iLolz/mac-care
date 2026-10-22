import AppKit
import CleanerKit
import SwiftUI

struct FullDiskAccessBanner: View {
    let onRecheck: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.shield")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.mcWarning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Permita o Acesso Total ao Disco")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.mcText)
                Text("O macOS protege pastas como a Lixeira e os dados de outros apps. Com o acesso, o Mac Care consegue medir o que dá para limpar nelas. A análise só lê o disco: nada sai do seu Mac e nada é apagado sem a sua confirmação.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.mcWarningText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button("Verificar de novo", action: onRecheck)
                .buttonStyle(MCButtonStyle(kind: .warningSecondary))
            Button("Abrir Ajustes") {
                NSWorkspace.shared.open(FullDiskAccess.settingsURL)
            }
            .buttonStyle(MCButtonStyle(kind: .warning))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .card(radius: Metrics.bannerRadius, fill: .mcBanner, border: .mcBannerBorder)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Permissão necessária")
    }
}
