public struct Investigator: Codable, Hashable, Identifiable, Sendable {
    public let name: String
    public let expansion: Expansion.ID
//    var using: Bool
    public let id: String
}
