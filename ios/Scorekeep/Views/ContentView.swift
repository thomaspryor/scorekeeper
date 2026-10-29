import SwiftUI

struct ContentView: View {
    var demo: DemoScenario? = nil

    @Environment(GameViewModel.self) private var viewModel
    @State private var editingPlayerId: String?
    @State private var showEditSheet = false
    @State private var showIncrementPicker = false
    @State private var showNewGameSheet = false
    @State private var showPastGames = false
    /// Set by the celebration's "New Game" button; acted on once the cover is gone.
    @State private var newGameAfterCelebration = false

    var body: some View {
        @Bindable var vm = viewModel

        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                topToolbar

                if viewModel.players.isEmpty {
                    EmptyStateView {
                        addPlayer()
                    }
                } else {
                    playerList
                }

                if let line = viewModel.trashTalk, viewModel.players.count >= 2 {
                    trashTalkBar(line)
                }

                bottomToolbar
            }

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

            if viewModel.showHints {
                GestureHintsView {
                    HapticManager.light()
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.dismissHints()
                    }
                }
                .transition(.opacity)
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
        .fullScreenCover(item: $vm.celebration, onDismiss: {
            if newGameAfterCelebration {
                newGameAfterCelebration = false
                showNewGameSheet = true
            }
        }) { celebration in
            CelebrationView(
                celebration: celebration,
                onBack: { viewModel.celebration = nil },
                onRematch: { viewModel.rematch() },
                onNewGame: {
                    newGameAfterCelebration = true
                    viewModel.celebration = nil
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in
            // Don't undo behind an open sheet (e.g. removing the player being named)
            let sheetOpen = showEditSheet || showIncrementPicker || showNewGameSheet
                || showPastGames || viewModel.celebration != nil || viewModel.showHints
            if !sheetOpen && viewModel.canUndo {
                HapticManager.medium()
                viewModel.undo()
                viewModel.showToast("Shake undo!")
            }
        }
        // Tips wait until the second player's name sheet closes, so they never
        // cover the keyboard.
        .onChange(of: showEditSheet) { _, isOpen in
            if !isOpen {
                withAnimation(.easeIn(duration: 0.3)) {
                    viewModel.offerHintsIfNeeded()
                }
            }
        }
        .onAppear {
            if demo == .history {
                showPastGames = true
            }
            viewModel.offerHintsIfNeeded()
        }
    }

    private func addPlayer() {
        let player = viewModel.addPlayer()
        editingPlayerId = player.id
        showEditSheet = true
    }

    private func editPlayer(_ id: String) {
        editingPlayerId = id
        showEditSheet = true
    }

    // MARK: - Top Toolbar

    private var topToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(label: "Undo", icon: "arrow.uturn.backward") {
                viewModel.undo()
            }
            .disabled(!viewModel.canUndo)
            .opacity(viewModel.canUndo ? 1.0 : 0.3)

            toolbarButton(label: "Player", icon: "person.badge.plus", accessibilityLabel: "Add player") {
                addPlayer()
            }

            toolbarButton(
                label: viewModel.sortMode.buttonLabel,
                icon: viewModel.sortMode.buttonIcon,
                accessibilityLabel: sortAccessibilityLabel
            ) {
                withAnimation(.spring(duration: 0.35)) {
                    viewModel.cycleSort()
                }
            }
            .disabled(viewModel.players.count < 2)
            .opacity(viewModel.players.count < 2 ? 0.3 : 1.0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .padding(.top, 4)
        .background(Color(.systemGray6))
    }

    private var sortAccessibilityLabel: String {
        switch viewModel.sortMode {
        case .none: return "Sort by score, highest first"
        case .desc: return "Sort by score, lowest first"
        case .asc: return "Restore original order"
        }
    }

    // MARK: - Player List

    private var playerList: some View {
        List {
            ForEach(Array(viewModel.players.enumerated()), id: \.element.id) { index, player in
                PlayerRowView(
                    player: player,
                    index: index,
                    increment: viewModel.increment,
                    delta: viewModel.scoreDeltas[player.id],
                    onScoreChange: { delta in
                        viewModel.changeScore(player.id, delta: delta)
                    },
                    onEdit: {
                        editPlayer(player.id)
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

            Button {
                addPlayer()
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

    // MARK: - Trash talk

    private func trashTalkBar(_ line: String) -> some View {
        Text(line)
            .font(.system(size: 14, weight: .semibold))
            .italic()
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGray6).opacity(0.6))
            .id(line)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Bottom Toolbar

    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(label: "±\(viewModel.increment)", icon: "plusminus", accessibilityLabel: "Score increment \(viewModel.increment)") {
                showIncrementPicker = true
            }

            toolbarButton(label: "End", icon: "trophy.fill", accessibilityLabel: "End game and show winner") {
                viewModel.endGame()
            }
            .disabled(viewModel.players.count < 2)
            .opacity(viewModel.players.count < 2 ? 0.3 : 1.0)

            toolbarButton(label: "Reset", icon: "arrow.counterclockwise", accessibilityLabel: "Reset all scores to zero") {
                viewModel.resetScores()
            }

            toolbarButton(label: "Game", icon: "plus.square.on.square", accessibilityLabel: viewModel.players.isEmpty ? "Past games" : "New game") {
                if viewModel.players.isEmpty {
                    showPastGames = true
                } else {
                    showNewGameSheet = true
                }
            }

            toolbarButton(
                label: "Sound",
                icon: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                accessibilityLabel: viewModel.soundEnabled ? "Sound on" : "Sound off"
            ) {
                viewModel.toggleSound()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .padding(.bottom, 4)
        .background(Color(.systemGray6))
    }

    // MARK: - Toolbar Button

    /// Icon and label side by side when there is room, stacked on narrow phones.
    private func toolbarButton(
        label: String,
        icon: String?,
        accessibilityLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .fixedSize()
                }
                VStack(spacing: 2) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label)
    }
}

// MARK: - First-run tips

/// One-time overlay explaining the gestures that have no visible button.
/// Same tips as the web app's "Quick Tips".
private struct GestureHintsView: View {
    let onDismiss: () -> Void

    private struct Hint {
        let icon: String
        /// Palette color behind the icon; nil for the neutral gray.
        let color: String?
        let title: String
        let detail: String
    }

    private let hints = [
        Hint(icon: "arrow.right", color: "#0074D9", title: "Swipe right", detail: "Edit a player's name and color"),
        Hint(icon: "arrow.left", color: "#FF4136", title: "Swipe left", detail: "Delete a player"),
        Hint(icon: "arrow.up.arrow.down", color: nil, title: "Hold and drag", detail: "Reorder players"),
        Hint(icon: "iphone.gen3.radiowaves.left.and.right", color: nil, title: "Shake your phone", detail: "Undo the last change"),
        Hint(icon: "plus.forwardslash.minus", color: nil, title: "Hold + or −", detail: "Change the score fast"),
    ]

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 24) {
                    Text("Quick Tips")
                        .font(.title2.weight(.bold))
                        .textCase(.uppercase)
                        .accessibilityAddTraits(.isHeader)

                    ForEach(hints, id: \.title) { hint in
                        HStack(spacing: 16) {
                            Image(systemName: hint.icon)
                                .font(.title3.weight(.semibold))
                                .frame(width: 48, height: 48)
                                .background(
                                    hint.color.map(ColorPalette.color(from:)) ?? Color.white.opacity(0.15),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hint.title).font(.headline)
                                Text(hint.detail).font(.subheadline).foregroundStyle(.white.opacity(0.75))
                            }
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                    }

                    Button(action: onDismiss) {
                        Text("Got it")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                    .accessibilityHint("Closes the tips. They won't show again.")
                }
                .foregroundStyle(.white)
                .frame(maxWidth: 340)
                .padding(.horizontal, 24)
                .padding(.vertical, 32)
                .frame(maxWidth: .infinity, minHeight: geometry.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.black.opacity(0.92).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityAddTraits(.isModal)
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
