import Foundation

struct SavedGame: Identifiable, Codable {
    let id: String
    var name: String
    let date: Date
    var players: [Player]
    var increment: Int

    init(id: String = UUID().uuidString, name: String, date: Date = Date(), players: [Player], increment: Int = 1) {
        self.id = id
        self.name = name
        self.date = date
        self.players = players
        self.increment = increment
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Untitled"
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        players = try c.decodeIfPresent([Player].self, forKey: .players) ?? []
        increment = try c.decodeIfPresent(Int.self, forKey: .increment) ?? 1
    }
}
