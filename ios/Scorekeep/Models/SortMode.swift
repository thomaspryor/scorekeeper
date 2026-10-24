import Foundation

/// Sort button cycles none → high-to-low → low-to-high → none (matches the web app).
enum SortMode: String, Codable, CaseIterable {
    case none
    case desc
    case asc

    var next: SortMode {
        switch self {
        case .none: return .desc
        case .desc: return .asc
        case .asc: return .none
        }
    }

    /// Label for the sort button, describing what the next tap does.
    var buttonLabel: String {
        switch self {
        case .none: return "Sort"
        case .desc: return "Sort ↑"
        case .asc: return "Unsort"
        }
    }

    var buttonIcon: String {
        switch self {
        case .none: return "line.3.horizontal.decrease"
        case .desc: return "arrow.up"
        case .asc: return "arrow.uturn.backward"
        }
    }
}
