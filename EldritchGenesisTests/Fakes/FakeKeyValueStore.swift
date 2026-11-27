@testable import EldritchGenesis

class FakeKeyValueStore: KeyValueStoring {
    var keyValues: [String: Bool] = [:]

    func bool(forKey key: String) -> Bool {
        return keyValues[key] ?? false
    }

    func set(_ value: Bool, forKey key: String) {
        keyValues[key] = value
    }
}
