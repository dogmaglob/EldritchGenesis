public enum DisplayName: Equatable, Sendable {
    case name(String)
    case unknown(id: String)
}

extension Catalog {
    public func displayName(forAncientOne id: AncientOne.ID) -> DisplayName {
        guard let item = ancientOnes.first(where: { $0.id == id }) else { return .unknown(id: id) }
        return .name(item.name)
    }

    public func displayName(forInvestigator id: Investigator.ID) -> DisplayName {
        guard let item = investigators.first(where: { $0.id == id }) else { return .unknown(id: id) }
        return .name(item.name)
    }
}
