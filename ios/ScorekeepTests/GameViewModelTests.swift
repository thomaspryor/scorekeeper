import AVFoundation
import XCTest
@testable import Scorekeep

/// Scoreboard behavior through the view model, each test on its own scratch UserDefaults.
@MainActor
final class GameViewModelTests: XCTestCase {
    /// A UserDefaults suite of its own, deleted when the test ends.
    private func freshStore() -> UserDefaults {
        let name = "scorekeep-tests-\(UUID().uuidString)"
        addTeardownBlock {
            UserDefaults(suiteName: name)?.removePersistentDomain(forName: name)
        }
        return UserDefaults(suiteName: name)!
    }

    private func makeViewModel(_ store: UserDefaults? = nil, deltaWindow: Duration = .seconds(60)) -> GameViewModel {
        GameViewModel(store: store ?? freshStore(), deltaWindow: deltaWindow, effects: false)
    }

    /// Adds players with these names and scores (scores via changeScore at increment 1).
    private func seed(_ vm: GameViewModel, _ entries: [(String, Int)]) {
        for (name, score) in entries {
            let p = vm.addPlayer()
            vm.updatePlayer(p.id, name: name)
            vm.endEditing()
            if score != 0 { vm.changeScore(p.id, delta: score) }
            vm.clearDeltas()
        }
    }

    // MARK: - Players

    func testAddPlayerGivesEachPlayerADifferentColor() {
        let vm = makeViewModel()
        for _ in 0..<ColorPalette.colors.count { _ = vm.addPlayer() }
        XCTAssertEqual(Set(vm.players.map(\.color)).count, ColorPalette.colors.count)
    }

    func testAddingAndNamingAPlayerUndoesInOneStep() {
        let vm = makeViewModel()
        let p = vm.addPlayer()
        vm.updatePlayer(p.id, name: "MAYA")
        vm.updatePlayer(p.id, color: "#FF4136")
        vm.endEditing()
        vm.undo()
        XCTAssertTrue(vm.players.isEmpty)
        XCTAssertFalse(vm.canUndo)
    }

    func testEditingAnExistingPlayerUndoesInOneStep() {
        let vm = makeViewModel()
        seed(vm, [("MAYA", 0)])
        let id = vm.players[0].id
        let before = vm.players[0]
        vm.updatePlayer(id, color: "#FF4136")
        vm.updatePlayer(id, color: "#0074D9")
        vm.updatePlayer(id, name: "MAYA B")
        vm.endEditing()
        vm.undo()
        XCTAssertEqual(vm.players[0], before)
    }

    func testUpdateWithNoChangeRecordsNoUndo() {
        let vm = makeViewModel()
        seed(vm, [("MAYA", 0)])
        let depth = vm.undoStack.count
        vm.updatePlayer(vm.players[0].id, name: "MAYA", color: vm.players[0].color)
        XCTAssertEqual(vm.undoStack.count, depth)
    }

    func testRemovePlayerAndUndoRestoresIt() {
        let vm = makeViewModel()
        seed(vm, [("A", 1), ("B", 2)])
        let removed = vm.players[0]
        vm.removePlayer(removed.id)
        XCTAssertEqual(vm.players.map(\.name), ["B"])
        XCTAssertFalse(vm.originalOrder.contains(removed.id))
        vm.undo()
        XCTAssertEqual(vm.players.first, removed)
    }

    // MARK: - Scores

    func testScoreChangesUseTheIncrement() {
        let vm = makeViewModel()
        seed(vm, [("A", 0)])
        vm.setIncrement(5)
        vm.changeScore(vm.players[0].id, delta: 1)
        vm.changeScore(vm.players[0].id, delta: 1)
        vm.changeScore(vm.players[0].id, delta: -1)
        XCTAssertEqual(vm.players[0].score, 5)
        XCTAssertEqual(vm.scoreDeltas[vm.players[0].id], 5)
    }

    func testABurstOfTapsIsOneUndoStep() {
        let vm = makeViewModel()
        seed(vm, [("A", 0)])
        let id = vm.players[0].id
        let depth = vm.undoStack.count
        for _ in 0..<25 { vm.changeScore(id, delta: 1) }
        XCTAssertEqual(vm.undoStack.count, depth + 1)
        vm.undo()
        XCTAssertEqual(vm.players[0].score, 0)
    }

    func testTapsOnDifferentPlayersAreSeparateUndoSteps() {
        let vm = makeViewModel()
        seed(vm, [("A", 0), ("B", 0)])
        vm.changeScore(vm.players[0].id, delta: 1)
        vm.changeScore(vm.players[1].id, delta: 1)
        vm.undo()
        XCTAssertEqual(vm.players.map(\.score), [1, 0])
    }

    func testBurstEndsAfterTheDeltaWindow() async throws {
        let vm = makeViewModel(deltaWindow: .milliseconds(50))
        seed(vm, [("A", 0)])
        let id = vm.players[0].id
        vm.changeScore(id, delta: 1)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertNil(vm.scoreDeltas[id])
        vm.changeScore(id, delta: 1)
        vm.undo()
        XCTAssertEqual(vm.players[0].score, 1, "Second burst should undo on its own")
    }

    func testResetScoresAndUndo() {
        let vm = makeViewModel()
        seed(vm, [("A", 3), ("B", 7)])
        vm.resetScores()
        XCTAssertEqual(vm.players.map(\.score), [0, 0])
        vm.performToastUndo()
        XCTAssertEqual(vm.players.map(\.score), [3, 7])
    }

    func testResetWithAllZeroScoresDoesNothing() {
        let vm = makeViewModel()
        seed(vm, [("A", 0), ("B", 0)])
        let depth = vm.undoStack.count
        vm.resetScores()
        XCTAssertEqual(vm.undoStack.count, depth)
    }

    func testSetIncrementIgnoresSameOrInvalidValues() {
        let vm = makeViewModel()
        let depth = vm.undoStack.count
        vm.setIncrement(1)
        vm.setIncrement(0)
        vm.setIncrement(-5)
        XCTAssertEqual(vm.increment, 1)
        XCTAssertEqual(vm.undoStack.count, depth)
    }

    func testUndoStackIsCapped() {
        let vm = makeViewModel()
        seed(vm, [("A", 0), ("B", 0)])
        for i in 0..<120 {
            vm.changeScore(vm.players[i % 2].id, delta: 1)
            vm.clearDeltas()
        }
        XCTAssertEqual(vm.undoStack.count, 50)
    }

    // MARK: - Undo toast

    func testANewStepClosesThePendingUndoToast() {
        let vm = makeViewModel()
        seed(vm, [("A", 0), ("B", 0)])
        vm.removePlayer(vm.players[0].id)
        XCTAssertTrue(vm.toastShowUndo)
        vm.changeScore(vm.players[0].id, delta: 1)
        XCTAssertFalse(vm.toastShowUndo, "toast Undo would now undo the score change, not the delete")
        vm.performToastUndo()
        XCTAssertEqual(vm.players.map(\.name), ["B"])
        XCTAssertEqual(vm.players[0].score, 1)
    }

    func testToolbarUndoClosesTheUndoToast() {
        let vm = makeViewModel()
        seed(vm, [("A", 3), ("B", 7)])
        vm.resetScores()
        XCTAssertTrue(vm.toastShowUndo)
        vm.undo()
        XCTAssertFalse(vm.toastShowUndo)
        XCTAssertEqual(vm.players.map(\.score), [3, 7])
    }

    // MARK: - Sort

    func testSortCyclesAndRestoresOriginalOrder() {
        let vm = makeViewModel()
        seed(vm, [("A", 5), ("B", 9), ("C", 1)])
        vm.cycleSort()
        XCTAssertEqual(vm.sortMode, .desc)
        XCTAssertEqual(vm.players.map(\.name), ["B", "A", "C"])
        vm.cycleSort()
        XCTAssertEqual(vm.sortMode, .asc)
        XCTAssertEqual(vm.players.map(\.name), ["C", "A", "B"])
        vm.cycleSort()
        XCTAssertEqual(vm.sortMode, .none)
        XCTAssertEqual(vm.players.map(\.name), ["A", "B", "C"])
    }

    func testSortNeedsTwoPlayers() {
        let vm = makeViewModel()
        seed(vm, [("A", 5)])
        vm.cycleSort()
        XCTAssertEqual(vm.sortMode, .none)
    }

    func testMovingAPlayerBecomesTheNewOriginalOrder() {
        let vm = makeViewModel()
        seed(vm, [("A", 1), ("B", 2), ("C", 3)])
        vm.cycleSort()
        vm.movePlayer(from: IndexSet(integer: 2), to: 0)
        XCTAssertEqual(vm.sortMode, .none)
        XCTAssertEqual(vm.originalOrder, vm.players.map(\.id))
    }

    // MARK: - End game

    func testEndGamePicksTheHighestScore() throws {
        let vm = makeViewModel()
        seed(vm, [("A", 5), ("B", 9), ("C", 1)])
        vm.endGame()
        let c = try XCTUnwrap(vm.celebration)
        XCTAssertEqual(c.standings.winners.map { c.names[$0.id] }, ["B"])
    }

    func testEndGamePicksTheLowestScoreWhenSortedLowToHigh() throws {
        let vm = makeViewModel()
        seed(vm, [("A", 5), ("B", 9), ("C", 1)])
        vm.cycleSort()
        vm.cycleSort()
        vm.endGame()
        let c = try XCTUnwrap(vm.celebration)
        XCTAssertEqual(c.standings.winners.map { c.names[$0.id] }, ["C"])
    }

    func testEndGameNeedsTwoPlayers() {
        let vm = makeViewModel()
        seed(vm, [("A", 5)])
        vm.endGame()
        XCTAssertNil(vm.celebration)
    }

    func testRematchZeroesScoresAndCanBeUndone() {
        let vm = makeViewModel()
        seed(vm, [("A", 5), ("B", 9)])
        vm.endGame()
        vm.rematch()
        XCTAssertNil(vm.celebration)
        XCTAssertEqual(vm.players.map(\.score), [0, 0])
        XCTAssertEqual(vm.players.map(\.name), ["A", "B"])
        vm.undo()
        XCTAssertEqual(vm.players.map(\.score), [5, 9])
    }

    // MARK: - Persistence

    func testStateSurvivesARelaunch() {
        let store = freshStore()
        let vm = makeViewModel(store)
        seed(vm, [("A", 5), ("B", 9)])
        vm.setIncrement(10)
        vm.cycleSort()
        vm.toggleSound()
        vm.saveNow()

        let relaunched = makeViewModel(store)
        XCTAssertEqual(relaunched.players, vm.players)
        XCTAssertEqual(relaunched.increment, 10)
        XCTAssertEqual(relaunched.sortMode, .desc)
        XCTAssertFalse(relaunched.soundEnabled)
        XCTAssertEqual(relaunched.originalOrder, vm.originalOrder)
    }

    func testLegacySortedFlagMigratesToHighToLow() {
        let json = ##"""
        {"players":[{"id":"a","name":"A","score":2,"color":"#FF4136"},{"id":"b","name":"B","score":4,"color":"#0074D9"}],
         "soundEnabled":true,"isSorted":true,"originalOrder":["a","b"],"increment":1}
        """##
        let store = freshStore()
        store.set(Data(json.utf8), forKey: GameViewModel.stateKey)
        let vm = makeViewModel(store)
        XCTAssertEqual(vm.sortMode, .desc)
        XCTAssertEqual(vm.players.map(\.id), ["a", "b"])
    }

    func testMissingKeysDoNotWipeTheSavedGame() {
        let store = freshStore()
        store.set(Data(##"{"players":[{"id":"a","name":"A","score":2}]}"##.utf8), forKey: GameViewModel.stateKey)
        let vm = makeViewModel(store)
        XCTAssertEqual(vm.players.map(\.score), [2])
        XCTAssertEqual(vm.originalOrder, ["a"])
        XCTAssertEqual(vm.increment, 1)
        XCTAssertTrue(vm.soundEnabled)
    }

    func testDuplicateIdsInSavedStateAreDropped() {
        let json = ##"""
        {"players":[{"id":"a","name":"A","score":2},{"id":"a","name":"A2","score":9},{"id":"b","name":"B","score":4}],
         "originalOrder":["a","b","a"]}
        """##
        let store = freshStore()
        store.set(Data(json.utf8), forKey: GameViewModel.stateKey)
        let vm = makeViewModel(store)
        XCTAssertEqual(vm.players.map(\.name), ["A", "B"])
        XCTAssertEqual(vm.originalOrder, ["a", "b"])
        vm.cycleSort()
        vm.endGame()
        XCTAssertEqual(vm.celebration?.standings.winningScore, 4)
    }

    func testCorruptStateFallsBackToAnEmptyGame() {
        let store = freshStore()
        store.set(Data("not json".utf8), forKey: GameViewModel.stateKey)
        let vm = makeViewModel(store)
        XCTAssertTrue(vm.players.isEmpty)
    }

    // MARK: - History

    func testSaveLoadAndDeleteAGame() throws {
        let vm = makeViewModel()
        seed(vm, [("A", 5), ("B", 9)])
        vm.saveCurrentGame(name: "Catan")
        vm.clearGame()
        XCTAssertTrue(vm.players.isEmpty)

        let saved = try XCTUnwrap(vm.loadHistory().first)
        XCTAssertEqual(saved.name, "Catan")
        vm.loadGame(saved.id)
        XCTAssertEqual(vm.players.map(\.score), [5, 9])

        vm.deleteGame(saved.id)
        XCTAssertTrue(vm.loadHistory().isEmpty)
    }

    func testUnnamedGamesGetADefaultName() throws {
        let vm = makeViewModel()
        seed(vm, [("A", 1)])
        vm.saveCurrentGame(name: "")
        XCTAssertTrue(try XCTUnwrap(vm.loadHistory().first).name.hasPrefix("Game "))
    }

    func testHistoryKeepsTheNewestFifty() {
        let vm = makeViewModel()
        seed(vm, [("A", 1)])
        for i in 0..<55 { vm.saveCurrentGame(name: "G\(i)") }
        let history = vm.loadHistory()
        XCTAssertEqual(history.count, GameViewModel.maxHistory)
        XCTAssertEqual(history.first?.name, "G54")
    }

    func testEmptyGameIsNotSaved() {
        let vm = makeViewModel()
        vm.saveCurrentGame(name: "Nothing")
        XCTAssertTrue(vm.loadHistory().isEmpty)
    }

    // MARK: - First-run tips

    func testTipsAppearOnceTheGameHasTwoPlayers() {
        let vm = makeViewModel()
        seed(vm, [("MAYA", 0)])
        vm.offerHintsIfNeeded()
        XCTAssertFalse(vm.showHints, "one player: nothing to swipe or reorder yet")
        seed(vm, [("LEO", 0)])
        vm.offerHintsIfNeeded()
        XCTAssertTrue(vm.showHints)
    }

    func testTipsNeverReturnAfterGotIt() {
        let store = freshStore()
        let vm = makeViewModel(store)
        seed(vm, [("MAYA", 0), ("LEO", 0)])
        vm.offerHintsIfNeeded()
        vm.dismissHints()
        XCTAssertFalse(vm.showHints)
        vm.offerHintsIfNeeded()
        XCTAssertFalse(vm.showHints)

        vm.saveNow()
        let relaunched = makeViewModel(store)
        relaunched.offerHintsIfNeeded()
        XCTAssertFalse(relaunched.showHints, "dismissal survives a relaunch")
    }

    // MARK: - Demo data used for screenshots

    func testDemoScenariosLoadWithoutTouchingTheRealStore() {
        for scenario in [DemoScenario.scoreboard, .celebration, .history] {
            let vm = scenario.makeViewModel()
            XCTAssertEqual(vm.players.count, DemoScenario.samplePlayers.count)
            XCTAssertEqual(vm.loadHistory().count, DemoScenario.sampleHistory.count)
            XCTAssertEqual(vm.celebration != nil, scenario == .celebration)
            vm.offerHintsIfNeeded()
            XCTAssertFalse(vm.showHints, "tips would cover the \(scenario) screenshot")
        }
    }

    // MARK: - Sound

    /// The .ambient category obeyed the silent switch, so a phone on silent heard
    /// nothing even with the volume up. The in-app Sound button is the control.
    func testSoundPlaysWithTheSilentSwitchOnAndMixesWithMusic() throws {
        XCTAssertEqual(SoundManager.sessionCategory, .playback)
        XCTAssertTrue(SoundManager.sessionOptions.contains(.mixWithOthers))
        try SoundManager.shared.configureSession()
        XCTAssertEqual(AVAudioSession.sharedInstance().category, .playback)
        XCTAssertTrue(AVAudioSession.sharedInstance().categoryOptions.contains(.mixWithOthers))
    }
}
