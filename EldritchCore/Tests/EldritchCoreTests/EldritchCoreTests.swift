import Testing
@testable import EldritchCore

@Test func bundledCatalogLoads() throws {
    let catalog = try Catalog.bundled()
    #expect(!catalog.expansions.isEmpty)
}
