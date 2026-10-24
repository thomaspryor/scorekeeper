import Foundation

/// Contextual one-liners shown under the scoreboard. Ported from the web app (docs/app.js).
enum TrashTalk {
    // {leader} = 1st place, {second} = 2nd place, {last} = last place,
    // {p1}/{p2} = the two players tied for first, {player} = a random player.
    static let leaderLines = [
        "{leader} is absolutely cooking right now",
        "Somebody stop {leader}",
        "{leader} came to play today",
        "Must be nice being {leader}",
        "{leader} woke up and chose violence",
        "OK {leader}, we get it, you're good",
        "{leader} is built different apparently",
        "Everyone else is just playing for second",
        "{leader} has no chill right now",
        "The {leader} show, everyone else is a background character",
        "{leader} making it look easy",
        "Is {leader} even trying or is everyone else just bad",
    ]
    static let lastPlaceLines = [
        "{last} is down bad",
        "Thoughts and prayers for {last}",
        "{last} out here catching strays",
        "It's not too late {last}... actually it might be",
        "{last}'s strategy is bold. Unclear, but bold",
        "We're all rooting for you {last}. Kind of",
        "{last} providing the comic relief",
        "At least {last} is having fun... right?",
        "{last} bringing a participation trophy energy",
        "Somebody check on {last}",
        "{last} is just building character at this point",
        "{last} down there inventing new ways to lose",
    ]
    static let rivalryLines = [
        "{leader} vs {second} is getting spicy",
        "{second} breathing down {leader}'s neck",
        "The gap between {leader} and {second} is getting personal",
        "{second} is NOT giving up on {leader}",
        "This {leader} vs {second} beef is real",
    ]
    static let tiedLines = [
        "{p1} and {p2} are deadlocked. Someone do something",
        "Tie game between {p1} and {p2}. The tension is thick",
        "{p1} and {p2} refuse to let the other win",
        "{p1} = {p2}. Math checks out, drama doesn't",
    ]
    static let blowoutLines = [
        "This is getting uncomfortable for everyone except {leader}",
        "Maybe we should start a new game... for {last}'s sake",
        "Mercy rule? Anyone?",
        "{leader} is farming points at this point",
        "This stopped being competitive a while ago",
        "There are closer elections than this game",
    ]
    static let allTiedLines = [
        "Everyone's tied. This is either very balanced or very boring",
        "Dead heat across the board. Someone make a move",
        "All tied up. The suspense is killing nobody",
    ]
    static let earlyLines = [
        "It's still early... anything can happen",
        "Game's just getting started. Trash talk loading...",
        "Warming up the roasts, check back soon",
    ]
    static let zeroLines = [
        "Somebody score already, this is painful",
        "A game of zeros. Truly inspiring stuff",
        "We'll wait...",
    ]

    /// Every template, for tests that check all placeholders get filled.
    static var allTemplates: [String] {
        leaderLines + lastPlaceLines + rivalryLines + tiedLines + blowoutLines + allTiedLines + earlyLines + zeroLines
    }

    /// A line for the current scores, or nil with fewer than two players.
    /// `avoiding` skips the line shown last time when another option exists.
    static func line<R: RandomNumberGenerator>(
        for players: [Player],
        avoiding previous: String? = nil,
        using rng: inout R
    ) -> String? {
        guard players.count >= 2 else { return nil }
        let first = pickLine(for: players, using: &rng)
        if first != previous { return first }
        return pickLine(for: players, using: &rng)
    }

    private static func pickLine<R: RandomNumberGenerator>(for players: [Player], using rng: inout R) -> String {
        let sorted = GameLogic.ordered(players, mode: .desc, originalOrder: players.map(\.id))
        let leader = sorted[0]
        let second = sorted[1]
        let last = sorted[sorted.count - 1]
        let maxScore = leader.score
        let leaderSecondGap = leader.score - second.score

        if sorted.allSatisfy({ $0.score == 0 }) {
            return zeroLines.randomElement(using: &rng)!
        }
        if sorted.allSatisfy({ $0.score == maxScore }) {
            return allTiedLines.randomElement(using: &rng)!
        }

        var pool: [(template: String, weight: Int)] = []
        if maxScore > 0 && maxScore <= 5 {
            pool += earlyLines.map { ($0, 2) }
        }
        pool += leaderLines.map { ($0, 3) }
        if last.id != leader.id {
            pool += lastPlaceLines.map { ($0, 3) }
        }
        if leaderSecondGap <= 3 && maxScore > 0 {
            pool += rivalryLines.map { ($0, 5) }
        }
        if leaderSecondGap == 0 && maxScore > 0 {
            pool += tiedLines.map { ($0, 5) }
        }
        if maxScore > 5 && Double(leaderSecondGap) > Double(maxScore) * 0.5 {
            pool += blowoutLines.map { ($0, 4) }
        }

        let total = pool.reduce(0) { $0 + $1.weight }
        var roll = Int.random(in: 0..<total, using: &rng)
        var template = pool[0].template
        for item in pool {
            roll -= item.weight
            if roll < 0 { template = item.template; break }
        }

        let name = { (p: Player) in GameLogic.displayName(for: p, in: players) }
        let randomPlayer = sorted.randomElement(using: &rng)!
        return template
            .replacingOccurrences(of: "{leader}", with: name(leader))
            .replacingOccurrences(of: "{second}", with: name(second))
            .replacingOccurrences(of: "{last}", with: name(last))
            .replacingOccurrences(of: "{p1}", with: name(leader))
            .replacingOccurrences(of: "{p2}", with: name(second))
            .replacingOccurrences(of: "{player}", with: name(randomPlayer))
    }
}
