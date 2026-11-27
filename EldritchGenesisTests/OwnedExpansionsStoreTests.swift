import EldritchCore
import Testing
@testable import EldritchGenesis

@MainActor
@Suite("OwnedExpansionsStore")
struct OwnedExpansionsStoreTests {

    @Test func isOwned() {
        let keyValueStore = FakeKeyValueStore()
        keyValueStore.keyValues = [
            "owned.core": true,
            "owned.mountains": true,
            "owned.carcosa": false
        ]
        let store = OwnedExpansionsStore(expansionIDs: ["core", "mountains", "carcosa"], store: keyValueStore)

        #expect(store.isOwned("core"))
        #expect(store.isOwned("mountains"))
        #expect(!store.isOwned("carcosa"))

        #expect(store.ownedIDs.count == 2)
        #expect(store.ownedIDs.contains("core"))
        #expect(store.ownedIDs.contains("mountains"))
        #expect(!store.ownedIDs.contains("carcosa"))
    }

    @Test func setPersistsChange() {
        let keyValueStore = FakeKeyValueStore()
        keyValueStore.keyValues = [
            "owned.core": true,
            "owned.mountains": true,
            "owned.carcosa": false
        ]
        let store = OwnedExpansionsStore(expansionIDs: ["core", "mountains", "carcosa"], store: keyValueStore)

        store.set(owned: true, forExpansionID: "carcosa")
        #expect(store.isOwned("carcosa"))
        #expect(keyValueStore.keyValues["owned.carcosa"] == true)

        store.set(owned: false, forExpansionID: "carcosa")
        #expect(!store.isOwned("carcosa"))
        #expect(keyValueStore.keyValues["owned.carcosa"] == false)

        store.set(owned: true, forExpansionID: "forbidden")
        #expect(!store.isOwned("forbidden"))
        #expect(keyValueStore.keyValues["owned.forbidden"] == nil)
    }

    @Test func coreGameAlwaysOwned() {
        let keyValueStore = FakeKeyValueStore()
        let store = OwnedExpansionsStore(expansionIDs: ["core", "mountains", "carcosa"], store: keyValueStore)

        #expect(store.isOwned("core"))

        store.set(owned: false, forExpansionID: "core")
        #expect(store.isOwned("core"))
    }

    @Test func changesSurviveRecreatingTheStore() {
        let keyValueStore = FakeKeyValueStore()
        let ids: Set<Expansion.ID> = ["core", "mountains", "carcosa"]

        let first = OwnedExpansionsStore(expansionIDs: ids, store: keyValueStore)
        first.set(owned: true, forExpansionID: "carcosa")

        let second = OwnedExpansionsStore(expansionIDs: ids, store: keyValueStore)

        #expect(second.isOwned("carcosa"))
        #expect(!second.isOwned("mountains"))
    }
}
