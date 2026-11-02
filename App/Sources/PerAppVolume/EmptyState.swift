import SwiftUI

struct EmptyState: View {
    @State private var breathing = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: 4, height: breathing ? 18 : 6)
                        .opacity(breathing ? 1 : 0.5)
                        .animation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true).delay(Double(index) * 0.3), value: breathing)
                }
            }
            .frame(height: 22)
            Text("Nenhum app tocando agora.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, 22)
        .onAppear { breathing = true }
    }
}
