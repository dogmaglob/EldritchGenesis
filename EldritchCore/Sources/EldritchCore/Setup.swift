public struct Setup: Codable, Hashable, Sendable {
    public let ancientOneID: AncientOne.ID
    public let investigatorIDs: [Investigator.ID]

    public init(ancientOneID: AncientOne.ID,
                investigatorIDs: [Investigator.ID]) {
        self.ancientOneID = ancientOneID
        self.investigatorIDs = investigatorIDs
    }
}
