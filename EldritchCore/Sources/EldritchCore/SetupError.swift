public enum SetupError: Error, Equatable, Sendable {
    case invalidIndex(Int)
    case invalidInvestigatorCount(Int)
    case notEnoughInvestigators(requested: Int, available: Int)
    case noAlternativeAncientOne
    case noAlternativeInvestigator
    case noAncientOnes
}
