import Foundation

protocol KeyValueStoring {
    func bool(forKey key: String) -> Bool
    func set(_ value: Bool, forKey key: String)
}

extension UserDefaults: KeyValueStoring { }
