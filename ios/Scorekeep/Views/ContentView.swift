import SwiftUI

struct ContentView: View {
    @Environment(GameViewModel.self) private var viewModel
    @State private var editingPlayerId: String?
    @State private var showEditSheet = false
    @State private var showIncrementPicker = false
    @State private var showNewGameSheet = false
    @State private var showPastGames = false

    var body: some View {
        @Bindable var vm = viewModel

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Top toolbar
                topToolbar

                // Player list or empty state
                if viewModel.players.isEmpty {
                    EmptyStateView {
                        let player = viewModel.addPlayer()
                        editingPlayerId = player.id
                        showEditSheet = true
                    }
                } else {
                    playerList
                }

                // Bottom toolbar
                bottomToolbar
            }

            // Toast overlay
            if let message = viewModel.toastMessage {
                ToastView(
                    message: message,
                    showUndo: viewModel.toastShowUndo,
                    onUndo: { viewModel.performToastUndo() },
                    onDismiss: { viewModel.dismissToast() }
                )
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: viewModel.toastMessage)
            }
        }
        .background(.black)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showEditSheet) {
            if let id = editingPlayerId {
                EditPlayerSheet(playerId: id, isPresented: $showEditSheet)
                    .environment(viewModel)
            }
        }
        .sheet(isPresented: $showIncrementPicker) {
            IncrementPickerView(isPresented: $showIncrementPicker)
                .environment(viewModel)
        }
        .sheet(isPresented: $showNewGameSheet) {
            NewGameSheet(isPresented: $showNewGameSheet)
                .environment(viewModel)
        }
        .sheet(isPresented: $showPastGames) {
            PastGamesSheet(isPresented: $showPastGames)
                .environment(viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            if viewModel.canUndo {
                HapticManager.medium()
                viewModel.undo()
                viewModel.showToast("Shake undo!")
            }
        }
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(label: "Player", icon: "person.badge.plus") {
                let player = viewModel.addPlayer()
                editingPlayerId = player.id
                showEditSheet = true
            }

            toolbarButton(label: "Undo", icon: "arrow.uturn.backward") {
                viewModel.undo()
            }
            .disabled(!viewModel.canUndo)

            toolbarButton(label: viewModel.isSorted ? "Unsort" : "Sort", icon: "line.3.horizontal.decrease") {
                withAnimation(.spring(duration: 0.35)) {
                    viewModel.toggleSort()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Player List

    private var playerList: some View {
        List {
            ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, player in
                PlayerRowView(
                    player: player,
                    index: index,
                    increment: viewModel.increment,
                    onScoreChange: { delta in
                        viewModel.changeScore(player.id, delta: delta)
                    },
                    onEdit: {
                        editingPlayerId = player.id
                        showEditSheet = true
                    },
                    onDelete: {
                        viewModel.removePlayer(player.id)
                    }
                )
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(ColorPalette.color(from: player.color))
            }
            .onMove { source, destination in
                viewModel.movePlayer(from: source, to: destination)
            }

            // Add player button at bottom
            Button {
                let player = viewModel.addPlayer()
                editingPlayerId = player.id
                showEditSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.badge.plus")
                        .font(.title3)
                        .opacity(0.6)
                    Text("Add Player")
                        .font(.system(size: 16, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.secondary)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.black)
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(label: "±\(viewModel.increment)", icon: "plusminus") {
                showIncrementPicker = true
            }

            toolbarButton(label: "Reset", icon: "arrow.counterclockwise") {
                viewModel.resetScores()
            }

            toolbarButton(label: "+ Game", icon: nil) {
                if viewModel.players.isEmpty {
                    showPastGames = true
                } else {
                    showNewGameSheet = true
                }
            }

            toolbarButton(
                label: "Sound",
                icon: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
            ) {
                viewModel.toggleSound()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }

    // MARK: - Toolbar Button

    private func toolbarButton(label: String, icon: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shake detection

extension NSNotification.Name {
    static let deviceDidShake = NSNotification.Name("deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: .deviceDidShake, object: nil)
        }
        super.motionEnded(motion, with: event)
    }
}
