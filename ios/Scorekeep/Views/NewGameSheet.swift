import SwiftUI

struct NewGameSheet: View {
    @Environment(GameViewModel.self) private var viewModel
    @Binding var isPresented: Bool
    @State private var gameName: String = ""
    @State private var showPastGames = false

    private var scoreSummary: String {
        viewModel.players
            .sorted { $0.score > $1.score }
            .map { "\($0.name.isEmpty ? "Player" : $0.name) \($0.score)" }
            .joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Save this game?")
                    .font(.title2.bold())

                Text(scoreSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                TextField("Game name (optional)", text: $gameName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .semibold))
                    .padding(14)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onSubmit { saveAndNew() }

                VStack(spacing: 8) {
                    Button { saveAndNew() } label: {
                        Text("Save & New Game")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(ColorPalette.color(from: "#2ECC40"))
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        viewModel.clearGame()
                        isPresented = false
                    } label: {
                        Text("Don't Save")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Color(.systemGray4))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Button("View Past Games") {
                    showPastGames = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .padding(.top, 4)

                Spacer()
            }
            .padding(24)
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
            .sheet(isPresented: $showPastGames) {
                PastGamesSheet(isPresented: $showPastGames)
                    .environment(viewModel)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func saveAndNew() {
        viewModel.saveCurrentGame(name: gameName.trimmingCharacters(in: .whitespaces))
        viewModel.clearGame()
        viewModel.showToast("Game saved")
        isPresented = false
    }
}
