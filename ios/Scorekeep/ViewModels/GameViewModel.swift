import Foundation
import Observation
import SwiftUI

// Undo snapshot — stores diffs, not full copies
struct UndoSnapshot: Codable {
    let players: [Player]
    let originalOrder: [String]
    let isSorted: Bool
    let increment: Int
}

@MainActor
@Observable
final class GameViewModel {
    // MARK: - Persisted state
    var players: [Player] = []
    var soundEnabled: Bool = true
    var isSorted: Bool = false
    var originalOrder: [String] = []
    var increment: Int = 1

    // MARK: - Undo
    private(set) var undoStack: [UndoSnapshot] = []
    private let maxUndo = 50
    var canUndo: Bool { !undoStack.isEmpty }

    // MARK: - Persistence
    private var saveTask: Task<Void, Never>?
    private let stateKey = "scorekeeper-state"
    private let historyKey = "scorekeeper-history"

    // MARK: - Toast
    var toastMessage: String?
    var toastShowUndo: Bool = false
    var toastUndoAction: (() -> Void)?
    private var toastDismissTask: Task<Void, Never>?

    init() {
        loadState()
    }

    // MARK: - Persistence (debounced)

    private struct PersistedState: Codable {
        var players: [Player]
        var soundEnabled: Bool
        var isSorted: Bool
        var originalOrder: [String]
        var increment: Int
    }

    private func loadState() {
        guard let data = UserDefaults.standard.data(forKey: stateKey) else { return }
        do {
            let saved = try JSONDecoder().decode(PersistedState.self, from: data)
            players = saved.players
            soundEnabled = saved.soundEnabled
            isSorted = saved.isSorted
            originalOrder = saved.originalOrder
            increment = saved.increment
            if originalOrder.isEmpty {
                originalOrder = players.map(\.id)
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
            isSorted: isSorted,
            originalOrder: originalOrder,
            increment: increment
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: stateKey)
        }
    }

    private func saveImmediately() {
        saveTask?.cancel()
        persistState()
    }

    // MARK: - Undo

    private func pushUndo() {
        let snapshot = UndoSnapshot(
            players: players,
            originalOrder: originalOrder,
            isSorted: isSorted,
            increment: increment
        )
        undoStack.append(snapshot)
        if undoStack.count > maxUndo {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        players = snapshot.players
        originalOrder = snapshot.originalOrder
        isSorted = snapshot.isSorted
        increment = snapshot.increment
        scheduleSave()
    }

    // MARK: - Player management

    func addPlayer() -> Player {
        pushUndo()
        let color = nextColor()
        let player = Player(color: color)
        players.append(player)
        originalOrder.append(player.id)
        isSorted = false
        scheduleSave()
        return player
    }

    func removePlayer(_ id: String) {
        guard let player = players.first(where: { $0.id == id }) else { return }
        pushUndo()
        players.removeAll { $0.id == id }
        originalOrder.removeAll { $0 == id }
        scheduleSave()
        HapticManager.warning()
        showToast("Deleted \(player.name.isEmpty ? "player" : player.name)", withUndo: true) { [weak self] in
            self?.undo()
        }
    }

    func updatePlayer(_ id: String, name: String? = nil, color: String? = nil) {
        guard let idx = players.firstIndex(where: { $0.id == id }) else { return }
        if let name { players[idx].name = name }
        if let color { players[idx].color = color }
        scheduleSave()
    }

    func changeScore(_ id: String, delta: Int) {
        guard let idx = players.firstIndex(where: { $0.id == id }) else { return }
        players[idx].score += delta * increment
        scheduleSave()
        HapticManager.light()
    }

    func movePlayer(from source: IndexSet, to destination: Int) {
        pushUndo()
        players.move(fromOffsets: source, toOffset: destination)
        originalOrder = players.map(\.id)
        isSorted = false
        scheduleSave()
        HapticManager.success()
    }

    // MARK: - Sort

    func toggleSort() {
        guard players.count >= 2 else { return }
        pushUndo()
        if isSorted {
            let playerMap = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
            players = originalOrder.compactMap { playerMap[$0] }
            isSorted = false
        } else {
            players.sort { $0.score > $1.score }
            isSorted = true
        }
        scheduleSave()
        HapticManager.success()
    }

    // MARK: - Reset / New game

    func resetScores() {
        guard !players.isEmpty, players.contains(where: { $0.score != 0 }) else { return }
        pushUndo()
        for i in players.indices {
            players[i].score = 0
        }
        scheduleSave()
        HapticManager.success()
        showToast("Scores reset to 0", withUndo: true) { [weak self] in
            self?.undo()
        }
    }

    func clearGame() {
        pushUndo()
        players = []
        originalOrder = []
        isSorted = false
        increment = 1
        scheduleSave()
        HapticManager.success()
    }

    // MARK: - Game history

    func loadHistory() -> [SavedGame] {
        guard let data = UserDefaults.standard.data(forKey: historyKey) else { return [] }
        return (try? JSONDecoder().decode([SavedGame].self, from: data)) ?? []
    }

    func saveCurrentGame(name: String) {
        guard !players.isEmpty else { return }
        let gameName = name.isEmpty ? defaultGameName() : name
        let game = SavedGame(name: gameName, players: players, increment: increment)
        var history = loadHistory()
        history.insert(game, at: 0)
        if history.count > 50 { history.removeLast() }
        saveHistory(history)
    }

    func loadGame(_ id: String) {
        let history = loadHistory()
        guard let game = history.first(where: { $0.id == id }) else { return }
        pushUndo()
        players = game.players
        originalOrder = players.map(\.id)
        isSorted = false
        increment = game.increment
        saveImmediately()
        HapticManager.success()
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
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    private func defaultGameName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Game \(formatter.string(from: Date()))"
    }

    // MARK: - Sound

    func toggleSound() {
        soundEnabled.toggle()
        scheduleSave()
    }

    // MARK: - Helpers

    private func nextColor() -> String {
        let used = Set(players.map(\.color))
        return ColorPalette.colors.first { !used.contains($0) }
            ?? ColorPalette.colors[players.count % ColorPalette.colors.count]
    }

    // MARK: - Toast

    func showToast(_ message: String, withUndo: Bool = false, undoAction: (() -> Void)? = nil) {
        toastDismissTask?.cancel()
        toastMessage = message
        toastShowUndo = withUndo
        toastUndoAction = undoAction
        toastDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self.dismissToast()
        }
    }

    func dismissToast() {
        toastMessage = nil
        toastShowUndo = false
        toastUndoAction = nil
    }

    func performToastUndo() {
        toastUndoAction?()
        dismissToast()
    }
}
