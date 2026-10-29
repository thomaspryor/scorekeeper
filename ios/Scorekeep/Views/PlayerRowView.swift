import SwiftUI

struct PlayerRowView: View {
    let player: Player
    let index: Int
    let increment: Int
    /// Points added in the current burst of taps, shown as "+5" beside the score.
    let delta: Int?
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
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(displayName)")

            Spacer(minLength: 4)

            if let delta, delta != 0 {
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .opacity(0.7)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }

            Text("\(player.score)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .scaleEffect(scoreBump ? 1.15 : 1.0)
                .animation(.easeOut(duration: 0.15), value: scoreBump)
                .accessibilityLabel("\(displayName) score \(player.score)")

            ScoreButton(
                label: "−", delta: -1, increment: increment, fgColor: fgColor,
                accessibilityLabel: "Subtract \(increment) from \(displayName)"
            ) { delta in
                onScoreChange(delta)
                triggerBump()
            }

            ScoreButton(
                label: "+", delta: 1, increment: increment, fgColor: fgColor,
                accessibilityLabel: "Add \(increment) to \(displayName)"
            ) { delta in
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

/// Tap to change the score once; hold to repeat, speeding up after a moment.
/// The tap counts on release, so a scroll that starts on the button never changes a score.
private struct ScoreButton: View {
    let label: String
    let delta: Int
    let increment: Int
    let fgColor: Color
    let accessibilityLabel: String
    let action: (Int) -> Void

    /// True while a finger is down. Resets on its own if the system cancels the
    /// touch (a scroll takes over, a sheet appears), which stops any repeat.
    @GestureState private var isPressing = false
    @State private var pressActive = false
    @State private var repeatTask: Task<Void, Never>?
    @State private var didRepeat = false

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
        .background(fgColor.opacity(isPressing ? 0.3 : 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressing) { _, pressing, _ in
                    pressing = true
                }
                .onChanged { _ in
                    // Fires on touch down (minimumDistance 0), before onEnded.
                    if !pressActive {
                        pressActive = true
                        startHoldTimer()
                    }
                }
                .onEnded { value in
                    let wasRepeating = didRepeat
                    stopRepeating()
                    let moved = hypot(value.translation.width, value.translation.height)
                    if !wasRepeating && moved < 20 {
                        action(delta)
                    }
                }
        )
        .onChange(of: isPressing) { _, pressing in
            if !pressing {
                stopRepeating()
            }
        }
        .onDisappear { stopRepeating() }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action(delta) }
    }

    private func startHoldTimer() {
        didRepeat = false
        repeatTask?.cancel()
        repeatTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            var count = 0
            // Re-check the finger every step: a touch the system cancels within one
            // frame fires neither onEnded nor onChange(of: isPressing), and the
            // score would count up forever (seen in CI: four taps ended at 36).
            while !Task.isCancelled && isPressing {
                didRepeat = true
                action(delta)
                count += 1
                try? await Task.sleep(for: .milliseconds(count > 10 ? 50 : 150))
            }
        }
    }

    private func stopRepeating() {
        repeatTask?.cancel()
        repeatTask = nil
        pressActive = false
    }
}
