import Foundation

/// Pure game rules with no UI or platform dependencies, so they can be unit tested anywhere.
enum GameLogic {
    /// Name shown for a player: their name, or "Player N" by position in the list.
    static func displayName(for player: Player, in players: [Player]) -> String {
        if !player.name.isEmpty { return player.name }
        let index = players.firstIndex { $0.id == player.id } ?? 0
        return "Player \(index + 1)"
    }

    /// Players ordered for a sort mode. Ties keep their original order so sorting is stable.
    static func ordered(_ players: [Player], mode: SortMode, originalOrder: [String]) -> [Player] {
        let rank = Dictionary(uniqueKeysWithValues: originalOrder.enumerated().map { ($1, $0) })
        let position: (Player) -> Int = { rank[$0.id] ?? Int.max }

        switch mode {
        case .none:
            return players.sorted { position($0) < position($1) }
        case .desc:
            return players.sorted { $0.score != $1.score ? $0.score > $1.score : position($0) < position($1) }
        case .asc:
            return players.sorted { $0.score != $1.score ? $0.score < $1.score : position($0) < position($1) }
        }
    }

    struct Standings: Equatable {
        /// Everyone, best first.
        let ranked: [Player]
        /// Everyone tied for first place.
        let winners: [Player]
        let winningScore: Int
    }

    /// Final standings. Lowest score wins when the list is sorted low-to-high (golf, hearts).
    static func standings(_ players: [Player], lowestWins: Bool, originalOrder: [String]) -> Standings? {
        guard players.count >= 2 else { return nil }
        let ranked = ordered(players, mode: lowestWins ? .asc : .desc, originalOrder: originalOrder)
        let winningScore = ranked[0].score
        let winners = ranked.filter { $0.score == winningScore }
        return Standings(ranked: ranked, winners: winners, winningScore: winningScore)
    }

    /// First color in the palette no player is using yet, cycling once all are taken.
    static func nextColor(for players: [Player], palette: [String]) -> String {
        let used = Set(players.map(\.color))
        return palette.first { !used.contains($0) } ?? palette[players.count % palette.count]
    }
}
