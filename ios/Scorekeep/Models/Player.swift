import Foundation

struct Player: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var score: Int
    var color: String

    init(id: String = UUID().uuidString, name: String = "", score: Int = 0, color: String = "#AAAAAA") {
        self.id = id
        self.name = name
        self.score = score
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        score = try c.decodeIfPresent(Int.self, forKey: .score) ?? 0
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#AAAAAA"
    }
}
