import EldritchCore
import Observation

@MainActor
@Observable
final class OwnedExpansionsStore {
    private enum Constants {
        static let coreID = "core"
    }

    private let expansionIDs: Set<Expansion.ID>
    private let store: KeyValueStoring

    private(set) var ownedIDs: Set<Expansion.ID>

    init(expansionIDs: Set<Expansion.ID>,
         store: KeyValueStoring) {
        self.expansionIDs = expansionIDs
        self.store = store

        let baseline: Set<Expansion.ID> = [Constants.coreID]
        ownedIDs = baseline.union(expansionIDs.filter { store.bool(forKey: $0.key) })
    }

    func isOwned(_ expansionID: Expansion.ID) -> Bool {
        ownedIDs.contains(expansionID)
    }

    func set(owned: Bool, forExpansionID expansionID: Expansion.ID) {
        guard expansionID != Constants.coreID,
              expansionIDs.contains(expansionID) else { return }
        if owned {
            ownedIDs.insert(expansionID)
        } else {
            ownedIDs.remove(expansionID)
        }
        store.set(owned, forKey: expansionID.key)
    }
}

fileprivate extension Expansion.ID {
    var key: String {
        String("owned.\(self)")
    }
}
