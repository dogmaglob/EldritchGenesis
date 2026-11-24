import Foundation

public struct Catalog: Codable, Sendable {
    public let expansions: [Expansion]
    public let ancientOnes: [AncientOne]
    public let investigators: [Investigator]
}

extension Catalog {
    public static func bundled() throws(CatalogError) -> Catalog {
        guard let url = Bundle.module.url(forResource: "catalog", withExtension: "json") else {
            throw .resourceMissing
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Catalog.self, from: data)
        } catch {
            throw .decodingFailed(String(describing: error))
        }
    }
}
