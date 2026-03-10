import SwiftUI

struct EmptyStateView: View {
    let onAdd: () -> Void

    var body: some View {
        Button(action: onAdd) {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 80))
                    .opacity(0.9)

                Text("Tap to Add Your First Player")
                    .font(.system(size: 18, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        ColorPalette.color(from: "#2ECC40"),
                        ColorPalette.color(from: "#01FF70")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.black)
        }
        .buttonStyle(.plain)
    }
}
