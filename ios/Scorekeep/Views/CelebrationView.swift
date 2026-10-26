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
                // Screenshot demo: keep it falling so a slow simulator still
                // captures confetti mid-air (screenshots.sh checks it moves).
                ConfettiView(loops: DemoScenario.current == .celebration)
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

/// Three seconds of falling confetti, driven by SwiftUI animations.
private struct ConfettiView: View {
    var loops = false

    private struct Piece: Identifiable {
        let id: Int
        let x: Double       // 0...1 across the width
        let startY: Double  // fraction of the height; negative starts above the screen
        let endY: Double    // fraction of the height; past 1 ends below the screen
        let drift: Double   // sideways travel in points
        let width: Double
        let height: Double
        let color: Color
        let rotation: Double
        let spin: Double    // degrees turned while falling
    }

    private static let colors = ["#FF4136", "#FF851B", "#FFDC00", "#2ECC40", "#0074D9", "#F012BE", "#B10DC9", "#01FF70"]
        .map { ColorPalette.color(from: $0) }
    private static let duration = 3.0

    @State private var pieces: [Piece] = (0..<80).map { i in
        Piece(
            id: i,
            x: .random(in: 0...1),
            startY: .random(in: -0.4...0.35),
            endY: .random(in: 1.05...1.6),
            drift: .random(in: -120...120),
            width: .random(in: 4...12),
            height: .random(in: 3...9),
            color: ConfettiView.colors.randomElement()!,
            rotation: .random(in: 0...360),
            spin: .random(in: -900...900)
        )
    }
    @State private var falling = false
    @State private var faded = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    Rectangle()
                        .fill(piece.color)
                        .frame(width: piece.width, height: piece.height)
                        .rotationEffect(.degrees(piece.rotation + (falling ? piece.spin : 0)))
                        .position(
                            x: piece.x * geo.size.width + (falling ? piece.drift : 0),
                            y: (falling ? piece.endY : piece.startY) * geo.size.height
                        )
                }
            }
            .opacity(faded ? 0 : 1)
        }
        .onAppear {
            // easeIn reads as gravity: slow at the top, faster as pieces fall.
            if loops {
                withAnimation(.easeIn(duration: Self.duration).repeatForever(autoreverses: false)) { falling = true }
                return
            }
            withAnimation(.easeIn(duration: Self.duration)) { falling = true }
            withAnimation(.linear(duration: 0.6).delay(Self.duration - 0.6)) { faded = true }
        }
    }
}
