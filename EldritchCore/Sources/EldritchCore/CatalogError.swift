public enum CatalogError: Error, Equatable, Sendable {
    case resourceMissing
    case decodingFailed(String)
}
