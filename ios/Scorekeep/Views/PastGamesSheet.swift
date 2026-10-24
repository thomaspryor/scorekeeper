import SwiftUI

struct PastGamesSheet: View {
    @Environment(GameViewModel.self) private var viewModel
    @Binding var isPresented: Bool
    var onLoad: (() -> Void)? = nil
    @State private var history: [SavedGame] = []

    var body: some View {
        NavigationStack {
            Group {
                if history.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Text("No saved games yet.")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Games are saved when you start a new one.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .padding()
                } else {
                    List {
                        ForEach(history) { game in
                            Button {
                                viewModel.loadGame(game.id)
                                onLoad?()
                                isPresented = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(game.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    HStack(spacing: 0) {
                                        Text(game.date, format: dateFormat(for: game.date))
                                            .foregroundStyle(.secondary)
                                        Text(" · ")
                                            .foregroundStyle(.secondary)
                                        Text(playerSummary(game))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    .font(.caption)
                                }
                                .padding(.vertical, 4)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    viewModel.deleteGame(game.id)
                                    history = viewModel.loadHistory()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Past Games")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { isPresented = false }
                }
            }
        }
        .onAppear {
            history = viewModel.loadHistory()
        }
    }

    private func playerSummary(_ game: SavedGame) -> String {
        game.players
            .sorted { $0.score > $1.score }
            .map { "\(GameLogic.displayName(for: $0, in: game.players)) \($0.score)" }
            .joined(separator: ", ")
    }

    /// "Oct 24" this year, "Oct 24, 2025" for older games.
    private func dateFormat(for date: Date) -> Date.FormatStyle {
        let sameYear = Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
        return sameYear ? .dateTime.month(.abbreviated).day() : .dateTime.month(.abbreviated).day().year()
    }
}
