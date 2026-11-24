public enum SetupError: Error, Equatable, Sendable {
    case notEnoughInvestigators(requested: Int, available: Int)
    case noAncientOnes
    case invalidInvestigatorCount(Int)
}
