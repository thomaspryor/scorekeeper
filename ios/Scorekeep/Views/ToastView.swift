import SwiftUI

struct ToastView: View {
    let message: String
    let showUndo: Bool
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if showUndo {
                Button {
                    onUndo()
                } label: {
                    Text("Undo")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(ColorPalette.color(from: "#0074D9"))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .background(Color(.systemGray2).opacity(0.8))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .onTapGesture { onDismiss() }
    }
}
