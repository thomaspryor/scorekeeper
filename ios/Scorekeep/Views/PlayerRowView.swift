import SwiftUI

struct PlayerRowView: View {
    let player: Player
    let index: Int
    let increment: Int
    let onScoreChange: (Int) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    // Long-press state
    @State private var longPressTimer: Timer?
    @State private var isLongPressing = false
    @State private var scoreBump = false

    private var displayName: String {
        player.name.isEmpty ? "Player \(index + 1)" : player.name
    }

    private var bgColor: Color { ColorPalette.color(from: player.color) }
    private var fgColor: Color { ColorPalette.textColor(for: player.color) }

    var body: some View {
        HStack(spacing: 8) {
            // Player name
            Text(displayName)
                .font(.system(size: 20, weight: .bold))
                .textCase(.uppercase)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            // Score
            Text("\(player.score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .scaleEffect(scoreBump ? 1.15 : 1.0)
                .animation(.easeOut(duration: 0.15), value: scoreBump)

            // Minus button
            scoreButton(label: "−", delta: -1)

            // Plus button
            scoreButton(label: "+", delta: 1)
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

    private func scoreButton(label: String, delta: Int) -> some View {
        Button {
            // Single tap handled here
        } label: {
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
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.3)
                .onEnded { _ in
                    startLongPress(delta: delta)
                }
        )
        .onTapGesture {
            if !isLongPressing {
                onScoreChange(delta)
                triggerBump()
            }
        }
        .onChange(of: isLongPressing) { _, pressing in
            if !pressing {
                stopLongPress()
            }
        }
    }

    private func startLongPress(delta: Int) {
        isLongPressing = true
        var count = 0
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
            onScoreChange(delta)
            triggerBump()
            count += 1
            if count > 10 {
                timer.invalidate()
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                    onScoreChange(delta)
                    triggerBump()
                }
            }
        }
    }

    private func stopLongPress() {
        longPressTimer?.invalidate()
        longPressTimer = nil
        isLongPressing = false
    }

    private func triggerBump() {
        scoreBump = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            scoreBump = false
        }
    }
}
