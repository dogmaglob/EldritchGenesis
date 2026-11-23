import Testing
@testable import EldritchCore

@Test func bundledCatalogLoads() throws {
    let catalog = try Catalog.bundled()
    #expect(!catalog.expansions.isEmpty)
}

@Test("Get display names of ancient ones", arguments: zip(
    ["azathoth", "stay-puff", ""],
    [.name("Azathoth"), .unknown(id: "stay-puff"), .unknown(id: "")] as [DisplayName]))
      func namesOfAncientOnes(ID: String, displayName: DisplayName) throws {
    let catalog = try Catalog.bundled()
    #expect(catalog.displayName(forAncientOne: ID) == displayName)
}

@Test("Get display names of investigators", arguments: zip(
    ["dilettante", "cable-guy", ""],
    [.name("Dilettante"), .unknown(id: "cable-guy"), .unknown(id: "")] as [DisplayName]))
      func namesOfInvestigators(ID: String, displayName: DisplayName) throws {
    let catalog = try Catalog.bundled()
    #expect(catalog.displayName(forInvestigator: ID) == displayName)
}
