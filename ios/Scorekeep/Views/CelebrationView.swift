import SwiftUI

/// Full-screen winner announcement with final standings and confetti.
struct CelebrationView: View {
    let celebration: Celebration
    let onBack: () -> Void
    let onRematch: () -> Void
    let onNewGame: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var standings: GameLogic.Standings { celebration.standings }
    private var winnerColor: String { standings.winners[0].color }
    private var textColor: Color { ColorPalette.textColor(for: winnerColor) }

    private var winnerName: String {
        standings.winners.map { name(for: $0) }.joined(separator: " & ")
    }

    private func name(for player: Player) -> String {
        celebration.names[player.id] ?? "Player"
    }

    var body: some View {
        ZStack {
            ColorPalette.color(from: winnerColor)
                .ignoresSafeArea()

            if !reduceMotion {
                ConfettiView()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(spacing: 8) {
                    Text("🏆")
                        .font(.system(size: 80))
                        .padding(.top, 40)
                        .accessibilityHidden(true)

                    Text(winnerName)
                        .font(.system(size: 34, weight: .heavy))
                        .textCase(.uppercase)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.5)

                    Text(standings.winners.count > 1 ? "Tied!" : "Wins!")
                        .font(.system(size: 22, weight: .bold))
                        .opacity(0.8)

                    Text("\(standings.winningScore)")
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("with \(standings.winningScore) points")

                    VStack(spacing: 6) {
                        ForEach(Array(standings.ranked.enumerated()), id: \.element.id) { rank, player in
                            HStack {
                                Text("\(rank + 1).")
                                    .frame(width: 28, alignment: .leading)
                                    .opacity(0.7)
                                Text(name(for: player))
                                    .textCase(.uppercase)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(player.score)")
                                    .monospacedDigit()
                            }
                            .font(.system(size: 18, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(textColor.opacity(rank == 0 ? 0.15 : 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(.top, 16)

                    HStack(spacing: 10) {
                        celebrationButton("Back", action: onBack)
                        celebrationButton("Rematch", action: onRematch)
                        celebrationButton("New Game", action: onNewGame)
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(textColor)
    }

    private func celebrationButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(textColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// Three seconds of falling confetti, drawn with Canvas.
private struct ConfettiView: View {
    private struct Piece {
        let x: Double       // 0...1 across the width
        let y: Double       // starting height above the top, in points
        let width: Double
        let height: Double
        let color: Color
        let vy: Double      // points per second
        let vx: Double
        let rotation: Double
        let spin: Double    // degrees per second
    }

    private static let colors = ["#FF4136", "#FF851B", "#FFDC00", "#2ECC40", "#0074D9", "#F012BE", "#B10DC9", "#01FF70"]
        .map { ColorPalette.color(from: $0) }
    private static let duration = 3.0
    private static let fadeTime = 0.5

    @State private var start = Date()
    @State private var finished = false
    @State private var pieces: [Piece] = (0..<80).map { _ in
        Piece(
            x: .random(in: 0...1),
            y: .random(in: 0...600),
            width: .random(in: 4...12),
            height: .random(in: 3...9),
            color: colors.randomElement()!,
            vy: .random(in: 120...300),
            vx: .random(in: -60...60),
            rotation: .random(in: 0...360),
            spin: .random(in: -300...300)
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: finished)) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard t < Self.duration else { return }
                let opacity = min(1, (Self.duration - t) / Self.fadeTime)
                for piece in pieces {
                    let x = piece.x * size.width + piece.vx * t
                    // gravity: 180 pt/s²
                    let y = -piece.y + piece.vy * t + 90 * t * t
                    var ctx = context
                    ctx.opacity = opacity
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .degrees(piece.rotation + piece.spin * t))
                    let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
                    ctx.fill(Path(rect), with: .color(piece.color))
                }
            }
        }
        .task {
            // Stop redrawing once the confetti has fallen.
            try? await Task.sleep(for: .seconds(Self.duration))
            finished = true
        }
    }
}
