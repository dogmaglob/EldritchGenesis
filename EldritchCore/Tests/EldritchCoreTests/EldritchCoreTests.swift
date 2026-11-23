import Testing
@testable import EldritchCore

@Test func bundledCatalogLoads() throws {
    let catalog = try Catalog.bundled()
    #expect(!catalog.expansions.isEmpty)
}

@Test("Get display names of ancient ones", arguments: [
    ("azathoth", DisplayName.name("Azathoth")),
    ("stay-puff", DisplayName.unknown(id: "stay-puff")),
    ("", DisplayName.unknown(id: "")),
])
func namesOfAncientOnes(id: String, displayName: DisplayName) throws {
    let catalog = try Catalog.bundled()
    #expect(catalog.displayName(forAncientOne: id) == displayName)
}

@Test("Get display names of investigators", arguments: [
        ("dilettante", DisplayName.name("Dilettante")),
        ("cable-guy", DisplayName.unknown(id: "cable-guy")),
        ("", DisplayName.unknown(id: "")),
])
func namesOfInvestigators(id: String, displayName: DisplayName) throws {
    let catalog = try Catalog.bundled()
    #expect(catalog.displayName(forInvestigator: id) == displayName)
}
