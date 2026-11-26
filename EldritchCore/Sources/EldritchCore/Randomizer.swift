public enum Randomizer {
    public static func generate(investigatorCount: Int,
                                catalog: Catalog,
                                owned: Set<Expansion.ID>,
                                using rng: inout some RandomNumberGenerator) throws(SetupError) -> Setup {
        guard (1...8).contains(investigatorCount) else { throw .invalidInvestigatorCount(investigatorCount) }

        var ownedInvestigators = catalog.investigators.filter { owned.contains($0.expansion) }
        guard investigatorCount <= ownedInvestigators.count else { throw .notEnoughInvestigators(requested: investigatorCount, available: ownedInvestigators.count) }
        var chosenInvestigators: [Investigator] = []
        for _ in 1...investigatorCount {
            let randomPick = Int.random(in: 0..<ownedInvestigators.count, using: &rng)
            chosenInvestigators.append(ownedInvestigators.remove(at: randomPick))
        }

        let ownedAncientOnes = catalog.ancientOnes.filter { owned.contains($0.expansion) }
        guard let chosenAncientOne = ownedAncientOnes.randomElement(using: &rng) else { throw .noAncientOnes }

        return Setup(ancientOneID: chosenAncientOne.id,
                     investigatorIDs: chosenInvestigators.map { $0.id })
    }

    public static func rerollAncientOne(in setup: Setup,
                                        catalog: Catalog,
                                        owned: Set<Expansion.ID>,
                                        using rng: inout some RandomNumberGenerator) throws(SetupError) -> Setup {
        let ownedAncientOnes = catalog.ancientOnes.filter { owned.contains($0.expansion) }

        let remainingAncientOnes = ownedAncientOnes.filter { $0.id != setup.ancientOneID }
        guard let chosenAncientOne = remainingAncientOnes.randomElement(using: &rng) else { throw .noAlternativeAncientOne }

        return Setup(ancientOneID: chosenAncientOne.id,
                     investigatorIDs: setup.investigatorIDs)
    }

    public static func rerollInvestigator(at index: Int,
                                          in setup: Setup,
                                          catalog: Catalog,
                                          owned: Set<Expansion.ID>,
                                          using rng: inout some RandomNumberGenerator) throws(SetupError) -> Setup {
        guard setup.investigatorIDs.indices.contains(index) else { throw .invalidIndex(index) }

        let ownedInvestigators = catalog.investigators.filter { owned.contains($0.expansion) }

        let remainingInvestigators = ownedInvestigators.filter { !setup.investigatorIDs.contains($0.id) }
        guard let chosenInvestigator = remainingInvestigators.randomElement(using: &rng) else { throw .noAlternativeInvestigator }

        var newInvestigators = setup.investigatorIDs
        newInvestigators[index] = chosenInvestigator.id

        return Setup(ancientOneID: setup.ancientOneID,
                     investigatorIDs: newInvestigators)
    }

    public static func replacement(excluding used: Set<Investigator.ID>,
                                   catalog: Catalog,
                                   owned: Set<Expansion.ID>,
                                   using rng: inout some RandomNumberGenerator) -> Investigator.ID? {
        let ownedInvestigators = catalog.investigators.filter { owned.contains($0.expansion) }

        let remainingInvestigators = ownedInvestigators.filter { !used.contains($0.id) }
        return remainingInvestigators.randomElement(using: &rng)?.id
    }
}
