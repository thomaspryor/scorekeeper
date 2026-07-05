import SwiftUI

struct PlayerRowView: View {
    let player: Player
    let index: Int
    let increment: Int
    let onScoreChange: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var scoreBump = false

    private var displayName: String {
        player.name.isEmpty ? "Player \(index + 1)" : player.name
    }

    private var bgColor: Color { ColorPalette.color(from: player.color) }
    private var fgColor: Color { ColorPalette.textColor(for: player.color) }

    var body: some View {
        HStack(spacing: 8) {
            Text(displayName)
                .font(.system(size: 20, weight: .bold))
                .textCase(.uppercase)
                .lineLimit(1)
                .truncationMode(.tail)

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 14, weight: .semibold))
                    .opacity(0.5)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle())
            }

            Spacer()

            Text("\(player.score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .scaleEffect(scoreBump ? 1.15 : 1.0)
                .animation(.easeOut(duration: 0.15), value: scoreBump)

            ScoreButton(label: "−", delta: -1, increment: increment, fgColor: fgColor) { delta in
                onScoreChange(delta)
                triggerBump()
            }

            ScoreButton(label: "+", delta: 1, increment: increment, fgColor: fgColor) { delta in
                onScoreChange(delta)
                triggerBump()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .background(bgColor)
        .foregroundStyle(fgColor)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    private func triggerBump() {
        scoreBump = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            scoreBump = false
        }
    }
}

// Separate view to handle tap + long-press without gesture conflicts
private struct ScoreButton: View {
    let label: String
    let delta: Int
    let increment: Int
    let fgColor: Color
    let action: (Int) -> Void

    @State private var timer: Timer?
    @State private var longPressActive = false

    var body: some View {
        ZStack {
            Text(label)
                .font(.system(size: 28, weight: .bold))
            if increment > 1 {
                Text("\(increment)")
                    .font(.system(size: 10, weight: .bold))
                    .opacity(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(4)
            }
        }
        .frame(width: 50, height: 50)
        .background(fgColor.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !longPressActive {
                        longPressActive = true
                        // Fire single tap immediately
                        action(delta)
                        // Start long-press timer after delay
                        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                            startRapidFire()
                        }
                    }
                }
                .onEnded { _ in
                    stopAll()
                }
        )
    }

    private func startRapidFire() {
        var count = 0
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { t in
            action(delta)
            count += 1
            if count > 10 {
                t.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    action(delta)
                }
            }
        }
    }

    private func stopAll() {
        timer?.invalidate()
        timer = nil
        longPressActive = false
    }
}
