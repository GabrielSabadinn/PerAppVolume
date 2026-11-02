import AudioEngine
import SwiftUI

struct PanelFooter: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: statusColor, radius: 4)
                Text(statusText)
                    .lineLimit(1)
            }
            .font(.footer)
            .foregroundStyle(Theme.textTertiary)
            Spacer()
            if engine.state == .permissionDenied {
                Button("Permitir") { PermissionSettings.open() }
                    .buttonStyle(.plain)
                    .font(.footer)
                    .foregroundStyle(Theme.warning)
            }
            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 24, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Ajustes")
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var statusColor: Color {
        switch engine.state {
        case .running: Theme.healthy
        case .idle: Theme.textTertiary
        case .awaitingPermission, .permissionDenied, .failed: Theme.warning
        }
    }

    private var statusText: String {
        switch engine.state {
        case .running: "Motor de áudio ativo"
        case .idle: "Motor de áudio parado"
        case .awaitingPermission: "Aguardando permissão de áudio"
        case .permissionDenied: "Sem permissão de áudio do sistema"
        case .failed(let message): "Falha no áudio: \(message)"
        }
    }
}

enum PermissionSettings {
    static func open() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}
