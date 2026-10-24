import Foundation
import Observation
import SwiftUI

// Undo snapshot: the full scoreboard before a change
struct UndoSnapshot: Codable {
    let players: [Player]
    let originalOrder: [String]
    let sortMode: SortMode
    let increment: Int
}

/// Shown full screen when a game ends.
struct Celebration: Identifiable {
    let id = UUID()
    let standings: GameLogic.Standings
    /// Display name per player id, captured when the game ended.
    let names: [String: String]
}

@MainActor
@Observable
final class GameViewModel {
    // MARK: - Persisted state
    var players: [Player] = []
    var soundEnabled: Bool = true
    var sortMode: SortMode = .none
    var originalOrder: [String] = []
    var increment: Int = 1

    // MARK: - Undo
    private(set) var undoStack: [UndoSnapshot] = []
    private let maxUndo = 50
    var canUndo: Bool { !undoStack.isEmpty }
    /// Player whose edit sheet already recorded an undo step, so a rename plus a
    /// color change (or adding then naming a player) undoes in one tap.
    private var editUndoPlayerId: String?

    // MARK: - Running score change ("+5" next to the score)
    /// Points added in the current burst of taps, per player id.
    private(set) var scoreDeltas: [String: Int] = [:]
    private var deltaResetTasks: [String: Task<Void, Never>] = [:]
    private let deltaWindow: Duration

    // MARK: - Trash talk and end of game
    var trashTalk: String?
    private var trashTalkTask: Task<Void, Never>?
    var celebration: Celebration?

    // MARK: - Persistence
    private let store: UserDefaults
    private let effectsEnabled: Bool
    private var saveTask: Task<Void, Never>?
    static let stateKey = "scorekeeper-state"
    static let historyKey = "scorekeeper-history"
    static let maxHistory = 50

    // MARK: - Toast
    var toastMessage: String?
    var toastShowUndo: Bool = false
    var toastUndoAction: (() -> Void)?
    private var toastDismissTask: Task<Void, Never>?

    /// - Parameters:
    ///   - store: where the game and history are saved.
    ///   - deltaWindow: how long a burst of taps on one player counts as one change.
    ///   - effects: play sounds and haptics (off in unit tests).
    init(store: UserDefaults = .standard, deltaWindow: Duration = .seconds(2), effects: Bool = true) {
        self.store = store
        self.deltaWindow = deltaWindow
        self.effectsEnabled = effects
        loadState()
        if players.count >= 2 {
            trashTalk = nextTrashTalk()
        }
    }

    // MARK: - Persistence (debounced)

    struct PersistedState: Codable {
        var players: [Player]
        var soundEnabled: Bool
        var sortMode: SortMode
        var originalOrder: [String]
        var increment: Int

        private enum CodingKeys: String, CodingKey {
            case players, soundEnabled, sortMode, originalOrder, increment
        }

        // Builds before 1.0 stored a two-way `isSorted` flag instead of sortMode.
        private enum LegacyKeys: String, CodingKey {
            case isSorted
        }

        init(players: [Player], soundEnabled: Bool, sortMode: SortMode, originalOrder: [String], increment: Int) {
            self.players = players
            self.soundEnabled = soundEnabled
            self.sortMode = sortMode
            self.originalOrder = originalOrder
            self.increment = increment
        }

        // Every field is optional so a missing or newly added key never wipes a saved game.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            players = try c.decodeIfPresent([Player].self, forKey: .players) ?? []
            soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
            originalOrder = try c.decodeIfPresent([String].self, forKey: .originalOrder) ?? []
            increment = try c.decodeIfPresent(Int.self, forKey: .increment) ?? 1
            if let mode = try? c.decodeIfPresent(SortMode.self, forKey: .sortMode) {
                sortMode = mode
            } else {
                let legacy = try decoder.container(keyedBy: LegacyKeys.self)
                let wasSorted = try legacy.decodeIfPresent(Bool.self, forKey: .isSorted) ?? false
                sortMode = wasSorted ? .desc : .none
            }
        }
    }

    private func loadState() {
        guard let data = store.data(forKey: Self.stateKey) else { return }
        do {
            let saved = try JSONDecoder().decode(PersistedState.self, from: data)
            players = saved.players
            soundEnabled = saved.soundEnabled
            sortMode = saved.sortMode
            increment = max(1, saved.increment)
            // Keep originalOrder in step with the players actually present.
            let ids = Set(players.map(\.id))
            originalOrder = saved.originalOrder.filter { ids.contains($0) }
            for player in players where !originalOrder.contains(player.id) {
                originalOrder.append(player.id)
            }
        } catch {
            print("Failed to load state: \(error)")
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self.persistState()
        }
    }

    private func persistState() {
        let state = PersistedState(
            players: players,
            soundEnabled: soundEnabled,
            sortMode: sortMode,
            originalOrder: originalOrder,
            increment: increment
        )
        if let data = try? JSONEncoder().encode(state) {
            store.set(data, forKey: Self.stateKey)
        }
    }

    /// Write any pending change now. Called when the app goes to the background,
    /// so a change made just before the app is closed is not lost.
    func saveNow() {
        saveTask?.cancel()
        persistState()
    }

    // MARK: - Undo

    private func pushUndo() {
        let snapshot = UndoSnapshot(
            players: players,
            originalOrder: originalOrder,
            sortMode: sortMode,
            increment: increment
        )
        undoStack.append(snapshot)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        clearDeltas()
        editUndoPlayerId = nil
        players = snapshot.players
        originalOrder = snapshot.originalOrder
        sortMode = snapshot.sortMode
        increment = snapshot.increment
        scheduleSave()
        scheduleTrashTalk()
    }

    // MARK: - Player management

    func addPlayer() -> Player {
        pushUndo()
        clearDeltas()
        let player = Player(color: GameLogic.nextColor(for: players, palette: ColorPalette.colors))
        players.append(player)
        originalOrder.append(player.id)
        sortMode = .none
        // Naming the new player is part of adding it: one undo removes both.
        editUndoPlayerId = player.id
        scheduleSave()
        scheduleTrashTalk()
        return player
    }

    func removePlayer(_ id: String) {
        guard let player = players.first(where: { $0.id == id }) else { return }
        pushUndo()
        clearDeltas()
        let name = GameLogic.displayName(for: player, in: players)
        players.removeAll { $0.id == id }
        originalOrder.removeAll { $0 == id }
        scheduleSave()
        scheduleTrashTalk()
        if effectsEnabled { HapticManager.warning() }
        showToast("Deleted \(name)", withUndo: true) { [weak self] in
            self?.undo()
        }
    }

    func updatePlayer(_ id: String, name: String? = nil, color: String? = nil) {
        guard let idx = players.firstIndex(where: { $0.id == id }) else { return }
        let nameChanged = name.map { $0 != players[idx].name } ?? false
        let colorChanged = color.map { $0 != players[idx].color } ?? false
        guard nameChanged || colorChanged else { return }
        if editUndoPlayerId != id {
            pushUndo()
            editUndoPlayerId = id
        }
        if let name { players[idx].name = name }
        if let color { players[idx].color = color }
        scheduleSave()
    }

    /// Call when the edit sheet closes so the next edit records its own undo step.
    func endEditing() {
        editUndoPlayerId = nil
    }

    func changeScore(_ id: String, delta: Int) {
        guard let idx = players.firstIndex(where: { $0.id == id }) else { return }
        // A burst of taps (or a long press) on one player is a single undo step.
        if scoreDeltas[id] == nil {
            pushUndo()
        }
        editUndoPlayerId = nil
        let points = delta * increment
        players[idx].score += points
        scoreDeltas[id, default: 0] += points
        restartDeltaTimer(for: id)
        scheduleSave()
        scheduleTrashTalk()
        if effectsEnabled {
            HapticManager.light()
            if soundEnabled { SoundManager.shared.playTick() }
        }
    }

    func movePlayer(from source: IndexSet, to destination: Int) {
        pushUndo()
        clearDeltas()
        players.move(fromOffsets: source, toOffset: destination)
        originalOrder = players.map(\.id)
        sortMode = .none
        scheduleSave()
        if effectsEnabled { HapticManager.success() }
    }

    // MARK: - Sort

    /// Cycles high-to-low, low-to-high, then back to the original order.
    func cycleSort() {
        guard players.count >= 2 else { return }
        pushUndo()
        clearDeltas()
        sortMode = sortMode.next
        players = GameLogic.ordered(players, mode: sortMode, originalOrder: originalOrder)
        scheduleSave()
        if effectsEnabled {
            HapticManager.success()
            if soundEnabled { SoundManager.shared.playSortSound() }
        }
    }

    // MARK: - Increment

    func setIncrement(_ value: Int) {
        guard value > 0, value != increment else { return }
        pushUndo()
        clearDeltas()
        increment = value
        scheduleSave()
    }

    // MARK: - Reset / New game

    func resetScores() {
        guard players.contains(where: { $0.score != 0 }) else { return }
        zeroScores()
        showToast("Scores reset to 0", withUndo: true) { [weak self] in
            self?.undo()
        }
    }

    func clearGame() {
        pushUndo()
        clearDeltas()
        players = []
        originalOrder = []
        sortMode = .none
        increment = 1
        trashTalk = nil
        scheduleSave()
        if effectsEnabled { HapticManager.success() }
    }

    // MARK: - End game

    /// Lowest score wins when the list is sorted low-to-high.
    var lowestScoreWins: Bool { sortMode == .asc }

    func endGame() {
        guard let standings = GameLogic.standings(players, lowestWins: lowestScoreWins, originalOrder: originalOrder) else { return }
        let names = Dictionary(uniqueKeysWithValues: players.map { ($0.id, GameLogic.displayName(for: $0, in: players)) })
        celebration = Celebration(standings: standings, names: names)
        if effectsEnabled {
            HapticManager.success()
            if soundEnabled { SoundManager.shared.playCelebration() }
        }
    }

    /// Same players, scores back to zero.
    func rematch() {
        celebration = nil
        guard players.contains(where: { $0.score != 0 }) else { return }
        zeroScores()
        showToast("Rematch! Scores reset", withUndo: true) { [weak self] in
            self?.undo()
        }
    }

    private func zeroScores() {
        pushUndo()
        clearDeltas()
        for i in players.indices {
            players[i].score = 0
        }
        scheduleSave()
        scheduleTrashTalk()
        if effectsEnabled { HapticManager.success() }
    }

    // MARK: - Game history

    func loadHistory() -> [SavedGame] {
        guard let data = store.data(forKey: Self.historyKey) else { return [] }
        return (try? JSONDecoder().decode([SavedGame].self, from: data)) ?? []
    }

    func saveCurrentGame(name: String) {
        guard !players.isEmpty else { return }
        let gameName = name.isEmpty ? defaultGameName() : name
        let game = SavedGame(name: gameName, players: players, increment: increment)
        var history = loadHistory()
        history.insert(game, at: 0)
        if history.count > Self.maxHistory {
            history.removeLast(history.count - Self.maxHistory)
        }
        saveHistory(history)
    }

    func loadGame(_ id: String) {
        let history = loadHistory()
        guard let game = history.first(where: { $0.id == id }) else { return }
        pushUndo()
        clearDeltas()
        players = game.players
        originalOrder = players.map(\.id)
        sortMode = .none
        increment = max(1, game.increment)
        saveNow()
        scheduleTrashTalk()
        if effectsEnabled { HapticManager.success() }
        showToast("Loaded \"\(game.name)\"")
    }

    func deleteGame(_ id: String) {
        var history = loadHistory()
        let game = history.first { $0.id == id }
        history.removeAll { $0.id == id }
        saveHistory(history)
        if let game {
            showToast("Deleted \"\(game.name)\"")
        }
    }

    private func saveHistory(_ history: [SavedGame]) {
        if let data = try? JSONEncoder().encode(history) {
            store.set(data, forKey: Self.historyKey)
        }
    }

    private func defaultGameName() -> String {
        "Game \(Date().formatted(.dateTime.month(.abbreviated).day()))"
    }

    // MARK: - Sound

    func toggleSound() {
        soundEnabled.toggle()
        scheduleSave()
    }

    // MARK: - Running deltas

    private func restartDeltaTimer(for id: String) {
        deltaResetTasks[id]?.cancel()
        deltaResetTasks[id] = Task { @MainActor [deltaWindow] in
            try? await Task.sleep(for: deltaWindow)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                self.scoreDeltas[id] = nil
            }
            self.deltaResetTasks[id] = nil
        }
    }

    /// Ends every running burst so the next tap starts a new undo step.
    func clearDeltas() {
        deltaResetTasks.values.forEach { $0.cancel() }
        deltaResetTasks = [:]
        scoreDeltas = [:]
    }

    // MARK: - Trash talk

    private func nextTrashTalk() -> String? {
        var rng = SystemRandomNumberGenerator()
        return TrashTalk.line(for: players, avoiding: trashTalk, using: &rng)
    }

    private func scheduleTrashTalk() {
        trashTalkTask?.cancel()
        guard players.count >= 2 else {
            trashTalk = nil
            return
        }
        trashTalkTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                self.trashTalk = self.nextTrashTalk()
            }
        }
    }

    // MARK: - Toast

    func showToast(_ message: String, withUndo: Bool = false, undoAction: (() -> Void)? = nil) {
        toastDismissTask?.cancel()
        withAnimation(.spring(duration: 0.3)) {
            toastMessage = message
            toastShowUndo = withUndo
            toastUndoAction = undoAction
        }
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self.dismissToast()
        }
    }

    func dismissToast() {
        withAnimation(.spring(duration: 0.3)) {
            toastMessage = nil
            toastShowUndo = false
            toastUndoAction = nil
        }
    }

    func performToastUndo() {
        toastUndoAction?()
        dismissToast()
    }
}
