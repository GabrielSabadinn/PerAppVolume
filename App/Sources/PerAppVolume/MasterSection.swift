import AudioEngine
import SwiftUI

struct MasterSection: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Volume")
                    .font(.panelTitle)
                    .foregroundStyle(Theme.text)
                Spacer()
                OutputDeviceChip()
            }
            CapsuleSlider(value: masterBinding, level: mixLevel, isEnabled: engine.hasMasterVolume)
                .help(engine.hasMasterVolume ? "Volume do sistema" : "Este dispositivo não permite ajustar o volume pelo Mac")
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 1) }
    }

    private var mixLevel: Float {
        engine.apps.map { LevelScale.normalized($0.level, gain: 1) }.max() ?? 0
    }

    private var masterBinding: Binding<Float> {
        Binding(get: { engine.masterVolume }, set: { engine.masterVolume = $0 })
    }
}

struct OutputDeviceChip: View {
    @Environment(AudioEngine.self) private var engine

    var body: some View {
        Menu {
            ForEach(engine.outputDevices) { device in
                Button {
                    engine.selectOutputDevice(device)
                } label: {
                    if device.name == engine.outputDeviceName {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "hifispeaker")
                    .font(.system(size: 10, weight: .semibold))
                Text(engine.outputDeviceName.isEmpty ? "Saída" : engine.outputDeviceName)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 9)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
