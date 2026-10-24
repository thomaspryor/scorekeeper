import XCTest
@testable import Scorekeep

/// Pure rules: no UI, no storage. These also compile on Linux (see memory/testing.md).
final class GameLogicTests: XCTestCase {
    private func player(_ name: String, _ score: Int, id: String? = nil) -> Player {
        Player(id: id ?? name, name: name, score: score, color: "#AAAAAA")
    }

    // MARK: - Sort modes

    func testSortModeCyclesThroughAllThreeModes() {
        XCTAssertEqual(SortMode.none.next, .desc)
        XCTAssertEqual(SortMode.desc.next, .asc)
        XCTAssertEqual(SortMode.asc.next, .none)
    }

    func testOrderedHighToLowLowToHighAndOriginal() {
        let a = player("A", 5), b = player("B", 9), c = player("C", 1)
        let order = ["A", "B", "C"]
        XCTAssertEqual(GameLogic.ordered([a, b, c], mode: .desc, originalOrder: order).map(\.id), ["B", "A", "C"])
        XCTAssertEqual(GameLogic.ordered([a, b, c], mode: .asc, originalOrder: order).map(\.id), ["C", "A", "B"])
        XCTAssertEqual(GameLogic.ordered([c, b, a], mode: .none, originalOrder: order).map(\.id), ["A", "B", "C"])
    }

    func testOrderedKeepsTiesInOriginalOrder() {
        let players = (1...8).map { player("P\($0)", 3) }
        let order = players.map(\.id)
        XCTAssertEqual(GameLogic.ordered(players.reversed(), mode: .desc, originalOrder: order).map(\.id), order)
        XCTAssertEqual(GameLogic.ordered(players.reversed(), mode: .asc, originalOrder: order).map(\.id), order)
    }

    func testOrderedPutsPlayersMissingFromOriginalOrderLast() {
        let a = player("A", 1), stray = player("Z", 1)
        XCTAssertEqual(GameLogic.ordered([stray, a], mode: .none, originalOrder: ["A"]).map(\.id), ["A", "Z"])
    }

    func testOrderedToleratesRepeatedIdsInOriginalOrder() {
        let a = player("A", 1), b = player("B", 2)
        XCTAssertEqual(GameLogic.ordered([b, a], mode: .none, originalOrder: ["A", "B", "A"]).map(\.id), ["A", "B"])
    }

    // MARK: - Standings

    func testStandingsNeedsTwoPlayers() {
        XCTAssertNil(GameLogic.standings([player("A", 3)], lowestWins: false, originalOrder: ["A"]))
        XCTAssertNil(GameLogic.standings([], lowestWins: false, originalOrder: []))
    }

    func testHighestScoreWinsByDefault() throws {
        let s = try XCTUnwrap(GameLogic.standings([player("A", 4), player("B", 10), player("C", -2)],
                                                  lowestWins: false, originalOrder: ["A", "B", "C"]))
        XCTAssertEqual(s.winners.map(\.id), ["B"])
        XCTAssertEqual(s.winningScore, 10)
        XCTAssertEqual(s.ranked.map(\.id), ["B", "A", "C"])
    }

    func testLowestScoreWinsWhenSortedLowToHigh() throws {
        let s = try XCTUnwrap(GameLogic.standings([player("A", 4), player("B", 10), player("C", -2)],
                                                  lowestWins: true, originalOrder: ["A", "B", "C"]))
        XCTAssertEqual(s.winners.map(\.id), ["C"])
        XCTAssertEqual(s.winningScore, -2)
    }

    func testTiedWinnersAreAllReported() throws {
        let s = try XCTUnwrap(GameLogic.standings([player("A", 7), player("B", 3), player("C", 7)],
                                                  lowestWins: false, originalOrder: ["A", "B", "C"]))
        XCTAssertEqual(s.winners.map(\.id), ["A", "C"])
    }

    // MARK: - Names and colors

    func testDisplayNameFallsBackToPosition() {
        let named = player("MAYA", 0)
        let unnamed = Player(id: "x", name: "", score: 0, color: "#AAAAAA")
        XCTAssertEqual(GameLogic.displayName(for: named, in: [named, unnamed]), "MAYA")
        XCTAssertEqual(GameLogic.displayName(for: unnamed, in: [named, unnamed]), "Player 2")
    }

    func testNextColorPicksFirstUnusedThenCycles() {
        let palette = ["#1", "#2", "#3"]
        XCTAssertEqual(GameLogic.nextColor(for: [], palette: palette), "#1")
        let used = [Player(color: "#1"), Player(color: "#3")]
        XCTAssertEqual(GameLogic.nextColor(for: used, palette: palette), "#2")
        let full = palette.map { Player(color: $0) }
        XCTAssertEqual(GameLogic.nextColor(for: full, palette: palette), "#1")
    }

    // MARK: - Trash talk

    func testNoTrashTalkWithFewerThanTwoPlayers() {
        var rng = SeededGenerator(seed: 1)
        XCTAssertNil(TrashTalk.line(for: [], using: &rng))
        XCTAssertNil(TrashTalk.line(for: [player("A", 5)], using: &rng))
    }

    func testAllZeroScoresUseTheZeroLines() {
        var rng = SeededGenerator(seed: 2)
        for _ in 0..<20 {
            let line = TrashTalk.line(for: [player("A", 0), player("B", 0)], using: &rng)
            XCTAssertTrue(TrashTalk.zeroLines.contains(line ?? ""), "\(String(describing: line))")
        }
    }

    func testEveryoneTiedUsesTheAllTiedLines() {
        var rng = SeededGenerator(seed: 3)
        for _ in 0..<20 {
            let line = TrashTalk.line(for: [player("A", 4), player("B", 4), player("C", 4)], using: &rng)
            XCTAssertTrue(TrashTalk.allTiedLines.contains(line ?? ""), "\(String(describing: line))")
        }
    }

    func testEveryLineHasItsPlaceholdersFilled() {
        var rng = SeededGenerator(seed: 4)
        for round in 0..<2_000 {
            let count = 2 + round % 5
            let players = (0..<count).map { i in
                Player(id: "\(i)", name: i == 0 ? "" : "P\(i)", score: Int.random(in: -10...60, using: &rng), color: "#AAAAAA")
            }
            let line = TrashTalk.line(for: players, using: &rng)
            XCTAssertNotNil(line)
            XCTAssertFalse(line!.contains("{"), "Unfilled placeholder: \(line!)")
            XCTAssertFalse(line!.contains("}"), "Unfilled placeholder: \(line!)")
        }
    }

    func testEveryTemplateUsesOnlyKnownPlaceholders() {
        let known: Set<String> = ["{leader}", "{second}", "{last}", "{p1}", "{p2}", "{player}"]
        for template in TrashTalk.allTemplates {
            var rest = Substring(template)
            while let open = rest.firstIndex(of: "{") {
                let close = rest[open...].firstIndex(of: "}")
                XCTAssertNotNil(close, template)
                guard let close else { break }
                XCTAssertTrue(known.contains(String(rest[open...close])), "Unknown placeholder in: \(template)")
                rest = rest[rest.index(after: close)...]
            }
        }
    }

    func testAvoidsRepeatingThePreviousLineWhenPossible() {
        var rng = SeededGenerator(seed: 5)
        let players = [player("A", 30), player("B", 2), player("C", 1)]
        var repeats = 0
        var previous: String?
        for _ in 0..<200 {
            let line = TrashTalk.line(for: players, avoiding: previous, using: &rng)
            if line == previous { repeats += 1 }
            previous = line
        }
        // Two draws from a pool of dozens: a repeat needs both to match.
        XCTAssertLessThan(repeats, 5)
    }

    // MARK: - Persistence model

    func testPlayerDecodesWithMissingFields() throws {
        let data = Data(#"{"id":"abc"}"#.utf8)
        let decoded = try JSONDecoder().decode(Player.self, from: data)
        XCTAssertEqual(decoded, Player(id: "abc", name: "", score: 0, color: "#AAAAAA"))
    }

    func testSavedGameDecodesWithMissingFields() throws {
        let data = Data(##"{"id":"g1","players":[{"id":"p","name":"A","score":3,"color":"#FF4136"}]}"##.utf8)
        let decoded = try JSONDecoder().decode(SavedGame.self, from: data)
        XCTAssertEqual(decoded.name, "Untitled")
        XCTAssertEqual(decoded.increment, 1)
        XCTAssertEqual(decoded.players.first?.score, 3)
    }
}

/// Deterministic random numbers so trash talk tests are repeatable (SplitMix64).
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
