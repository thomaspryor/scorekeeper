import Foundation

/// Sample games for App Store screenshots and UI checks. Launch with `-demo <scenario>`;
/// the demo runs on its own scratch store and never touches the user's saved game.
enum DemoScenario: String {
    /// Fresh, empty game (UI tests)
    case empty
    case scoreboard
    case celebration
    case history

    /// The scenario passed on the command line, if any.
    static var current: DemoScenario? {
        UserDefaults.standard.string(forKey: "demo").flatMap(DemoScenario.init(rawValue:))
    }

    static let players = [
        Player(name: "MAYA", score: 42, color: "#2ECC40"),
        Player(name: "JORDAN", score: 38, color: "#0074D9"),
        Player(name: "SAM", score: 35, color: "#FF851B"),
        Player(name: "PRIYA", score: 27, color: "#F012BE"),
        Player(name: "LEO", score: 19, color: "#FFDC00"),
    ]

    static let history = [
        SavedGame(name: "Catan night", date: Date(timeIntervalSinceNow: -2 * 86_400), players: [
            Player(name: "MAYA", score: 10, color: "#2ECC40"),
            Player(name: "SAM", score: 8, color: "#FF851B"),
            Player(name: "LEO", score: 7, color: "#FFDC00"),
        ]),
        SavedGame(name: "Hearts", date: Date(timeIntervalSinceNow: -6 * 86_400), players: [
            Player(name: "JORDAN", score: 26, color: "#0074D9"),
            Player(name: "PRIYA", score: 31, color: "#F012BE"),
            Player(name: "MAYA", score: 54, color: "#2ECC40"),
            Player(name: "SAM", score: 70, color: "#FF851B"),
        ]),
        SavedGame(name: "Scrabble", date: Date(timeIntervalSinceNow: -13 * 86_400), players: [
            Player(name: "PRIYA", score: 362, color: "#F012BE"),
            Player(name: "JORDAN", score: 341, color: "#0074D9"),
        ]),
        SavedGame(name: "Family Uno", date: Date(timeIntervalSinceNow: -21 * 86_400), players: [
            Player(name: "LEO", score: 500, color: "#FFDC00"),
            Player(name: "MAYA", score: 455, color: "#2ECC40"),
            Player(name: "SAM", score: 210, color: "#FF851B"),
        ], increment: 5),
    ]

    @MainActor
    func makeViewModel() -> GameViewModel {
        let suite = "scorekeep-demo"
        let store = UserDefaults(suiteName: suite) ?? .standard
        store.removePersistentDomain(forName: suite)
        if self == .empty {
            return GameViewModel(store: store, effects: false)
        }

        let state = GameViewModel.PersistedState(
            players: Self.players,
            soundEnabled: false,
            sortMode: .desc,
            originalOrder: Self.players.map(\.id),
            increment: 1
        )
        store.set(try? JSONEncoder().encode(state), forKey: GameViewModel.stateKey)
        store.set(try? JSONEncoder().encode(Self.history), forKey: GameViewModel.historyKey)

        let viewModel = GameViewModel(store: store, effects: false)
        viewModel.trashTalk = "Somebody stop MAYA"
        if self == .celebration {
            viewModel.endGame()
        }
        return viewModel
    }
}
