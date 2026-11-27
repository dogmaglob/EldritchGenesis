import EldritchCore
import SwiftUI

@main struct EldritchGenesisApp: App {
    private let catalog: Result<Catalog, CatalogError>

    init() {
        do throws(CatalogError) {
            catalog = .success(try Catalog.bundled())
        } catch {
            catalog = .failure(error)
        }
    }

    var body: some Scene {
        WindowGroup {
            switch catalog {
            case .success(let catalog):
                RootTabView(catalog: catalog)
            case .failure(let error):
                CatalogUnavailableView(error: error)
            }
        }
    }
}
