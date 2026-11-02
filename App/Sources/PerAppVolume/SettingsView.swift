import AudioEngine
import SwiftUI

struct SettingsView: View {
    @Environment(AudioEngine.self) private var engine
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Abrir ao iniciar o Mac", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in applyLaunchAtLogin(enabled) }
                if let launchError {
                    Text(launchError).font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Áudio") {
                LabeledContent("Estado", value: stateText)
                LabeledContent("Saída atual", value: engine.outputDeviceName)
                if engine.state == .permissionDenied {
                    Button("Abrir Privacidade e Segurança") { PermissionSettings.open() }
                }
            }
            Section {
                Text("Apps profissionais de áudio e players com proteção de conteúdo não são interceptados.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var stateText: String {
        switch engine.state {
        case .running: "Ativo"
        case .idle: "Parado"
        case .awaitingPermission: "Aguardando permissão"
        case .permissionDenied: "Sem permissão"
        case .failed(let message): message
        }
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}
