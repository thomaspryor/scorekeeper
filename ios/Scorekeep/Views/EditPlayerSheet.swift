import SwiftUI

struct EditPlayerSheet: View {
    @Environment(GameViewModel.self) private var viewModel
    let playerId: String
    @Binding var isPresented: Bool

    @State private var name: String = ""
    @State private var selectedColor: String = "#AAAAAA"

    private var player: Player? {
        viewModel.players.first { $0.id == playerId }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Color picker grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(ColorPalette.colors, id: \.self) { hex in
                        Button {
                            selectedColor = hex
                            viewModel.updatePlayer(playerId, color: hex)
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(ColorPalette.color(from: hex))
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(
                                            selectedColor == hex ? Color.white : Color.white.opacity(0.2),
                                            lineWidth: selectedColor == hex ? 3 : 1
                                        )
                                )
                                .scaleEffect(selectedColor == hex ? 1.1 : 1.0)
                                .animation(.easeOut(duration: 0.15), value: selectedColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                // Name input
                HStack(spacing: 12) {
                    Button {
                        viewModel.removePlayer(playerId)
                        isPresented = false
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title2)
                            .frame(width: 50, height: 50)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    TextField("Player name", text: $name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .bold))
                        .textCase(.uppercase)
                        .padding(.horizontal, 12)
                        .frame(height: 50)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.characters)
                        .submitLabel(.done)
                        .onSubmit { confirmEdit() }

                    Button {
                        confirmEdit()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.title2.bold())
                            .frame(width: 50, height: 50)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .background(Color(.systemGray6))
            .navigationBarHidden(true)
        }
        .onAppear {
            if let player {
                name = player.name
                selectedColor = player.color
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func confirmEdit() {
        let finalName: String
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            let idx = viewModel.players.firstIndex(where: { $0.id == playerId }) ?? 0
            finalName = "Player \(idx + 1)"
        } else {
            finalName = name.trimmingCharacters(in: .whitespaces)
        }
        viewModel.updatePlayer(playerId, name: finalName)
        isPresented = false
    }
}
