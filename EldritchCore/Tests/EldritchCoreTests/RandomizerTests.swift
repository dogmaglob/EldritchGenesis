import Testing
@testable import EldritchCore

@Test func generateSetup() throws {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    let setup = try Randomizer.generate(investigatorCount: 1,
                                        catalog: catalog,
                                        owned: catalog.owned(),
                                        using: &rng)

    #expect(setup.ancientOneID == AncientOne.cthulhu().id)
    #expect(setup.investigatorIDs.count == 1)
    #expect(setup.investigatorIDs.first == Investigator.dickTracy().id)
}

@Test func rerollAncientOne() throws {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    let initialSetup = Setup(ancientOneID: AncientOne.cthulhu().id,
                             investigatorIDs: [Investigator.dickTracy().id])

    let setup = try Randomizer.rerollAncientOne(in: initialSetup,
                                                catalog: catalog,
                                                owned: catalog.owned(),
                                                using: &rng)

    #expect(setup.ancientOneID == AncientOne.yig().id)
    #expect(setup.investigatorIDs.count == 1)
    #expect(setup.investigatorIDs.first == Investigator.dickTracy().id)
}

@Test func rerollInvestigator() throws {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    let initialSetup = Setup(ancientOneID: AncientOne.cthulhu().id,
                             investigatorIDs: [Investigator.dickTracy().id])

    let setup = try Randomizer.rerollInvestigator(at: 0,
                                                  in: initialSetup,
                                                  catalog: catalog,
                                                  owned: catalog.owned(),
                                                  using: &rng)

    #expect(setup.ancientOneID == AncientOne.cthulhu().id)
    #expect(setup.investigatorIDs.count == 1)
    #expect(setup.investigatorIDs.first == Investigator.greenHornet().id)
}

@Test func replaceInvestigator() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    let initialSetup = Setup(ancientOneID: AncientOne.cthulhu().id,
                             investigatorIDs: [Investigator.dickTracy().id])

    let replacementId = Randomizer.replacement(excluding: Set(initialSetup.investigatorIDs),
                                               catalog: catalog,
                                               owned: catalog.owned(),
                                               using: &rng)

    #expect(replacementId == Investigator.greenHornet().id)
}

@Test func noReplacementInvestigators() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    let initialSetup = Setup(ancientOneID: AncientOne.cthulhu().id,
                             investigatorIDs: [Investigator.dickTracy().id, Investigator.greenHornet().id])

    let replacementId = Randomizer.replacement(excluding: Set(initialSetup.investigatorIDs),
                                               catalog: catalog,
                                               owned: catalog.owned(),
                                               using: &rng)

    #expect(replacementId == nil)
}

@Test func invalidIndex() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    let initialSetup = Setup(ancientOneID: AncientOne.cthulhu().id,
                             investigatorIDs: [Investigator.dickTracy().id])

    #expect(throws: SetupError.invalidIndex(3)) {
        try Randomizer.rerollInvestigator(at: 3,
                                          in: initialSetup,
                                          catalog: catalog,
                                          owned: catalog.owned(),
                                          using: &rng)
    }
}

@Test func invalidInvestigatorCount() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    #expect(throws: SetupError.invalidInvestigatorCount(42)) {
        try Randomizer.generate(investigatorCount: 42,
                                catalog: catalog,
                                owned: catalog.owned(),
                                using: &rng)
    }
}

@Test func notEnoughInvestigators() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()

    #expect(throws: SetupError.notEnoughInvestigators(requested: 8, available: 2)) {
        try Randomizer.generate(investigatorCount: 8,
                                catalog: catalog,
                                owned: catalog.owned(),
                                using: &rng)
    }
}

@Test func noAlternativeAncientOne() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog(expansions: Catalog.test().expansions,
                          ancientOnes: [.cthulhu()],
                          investigators: Catalog.test().investigators)

    let setup = Setup(ancientOneID: AncientOne.cthulhu().id,
                      investigatorIDs: [Investigator.dickTracy().id])

    #expect(throws: SetupError.noAlternativeAncientOne) {
        try Randomizer.rerollAncientOne(in: setup,
                                        catalog: catalog,
                                        owned: catalog.owned(),
                                        using: &rng)
    }
}

@Test func noAlternativeInvestigator() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog.test()
    let setup = Setup(ancientOneID: AncientOne.cthulhu().id,
                      investigatorIDs: [Investigator.dickTracy().id, Investigator.greenHornet().id])

    #expect(throws: SetupError.noAlternativeInvestigator) {
        try Randomizer.rerollInvestigator(at: 0,
                                          in: setup,
                                          catalog: catalog,
                                          owned: catalog.owned(),
                                          using: &rng)
    }
}

@Test func noAncientOnes() {
    var rng = CounterRNG(seed: 0)

    let catalog = Catalog(expansions: [.core()],
                          ancientOnes: [],
                          investigators: [.dickTracy()])

    #expect(throws: SetupError.noAncientOnes) {
        try Randomizer.generate(investigatorCount: 1,
                                catalog: catalog,
                                owned: catalog.owned(),
                                using: &rng)
    }
}

extension Expansion {
    static func core() -> Expansion {
        return Expansion(name: "core", id: "core")
    }
}

extension AncientOne {
    static func cthulhu() -> AncientOne {
        return AncientOne(name: "Cthulhu", expansion: "core", id: "cthulhu")
    }

    static func yig() -> AncientOne {
        return AncientOne(name: "Yig", expansion: "core", id: "yig")
    }
}

extension Investigator {
    static func dickTracy() -> Investigator {
        return Investigator(name: "Dick Tracy", expansion: "core", id: "dick-tracy")
    }

    static func greenHornet() -> Investigator {
        return Investigator(name: "Green Hornet", expansion: "core", id: "green-hornet")
    }
}

extension Catalog {
    static func test() -> Catalog {
        return Catalog(expansions: [.core()],
                       ancientOnes: [.cthulhu(), .yig()],
                       investigators: [.dickTracy(), .greenHornet()])
    }

    func owned() -> Set<Expansion.ID> {
        return Set(expansions.map { $0.id })
    }
}
