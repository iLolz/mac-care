import AppKit
import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.showInMenuBar) private var showInMenuBar = AppSettings.showInMenuBarDefault
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var needsApproval = LaunchAtLogin.requiresApproval
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Geral") {
                Toggle(isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) })) {
                    Text("Abrir ao iniciar sessão")
                    if let launchError {
                        Text(launchError)
                            .foregroundStyle(Color.mcWarning)
                    } else if needsApproval {
                        Text("Permita o Mac Care em Ajustes do Sistema › Geral › Itens de Início.")
                    }
                }
                if needsApproval {
                    Button("Abrir Itens de Início…") {
                        LaunchAtLogin.openSystemSettings()
                    }
                }

                Toggle(isOn: $showInMenuBar) {
                    Text("Manter na barra de menus ao fechar a janela")
                    Text("O Mac Care continua rodando na barra de menus para avisar quando o espaço ficar baixo.")
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .scrollContentBackground(.hidden)
        .background(Color.mcWindow)
        .frame(width: 460, height: 260)
        .onAppear(perform: refreshLaunchAtLogin)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshLaunchAtLogin()
        }
    }

    private func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled
        needsApproval = LaunchAtLogin.requiresApproval
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = enabled
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
        refreshLaunchAtLogin()
    }
}
