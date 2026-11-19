# Showing I'm Still Learning: Modern iOS Practices (Nov 2026)

## What hiring managers can actually see

1. Recent, steady commits in a public repo.
2. An app they can actually install (App Store or a public TestFlight link).
3. Write-ups that explain what you built and why.

Those three matter more than which APIs you pick. A small demo app with no README that nobody can install won't prove much.

## What counts as current (iOS 27 shipped in September; WWDC26 was in June)

### Strongest signals right now

- **Foundation Models framework.** Apple's on-device language model, with `@Generable` structured output and tool calling. It's been the headline API at the last two WWDCs, and it's free to run. WWDC26 expanded it with cloud support built on Google's Gemini technology.
- **App Intents.** This is how apps plug into Siri, Shortcuts, Spotlight, interactive widgets and Control Center. WWDC26 coverage says App Intents is now the required way to integrate with Siri and SiriKit is deprecated.
- **Swift 6 language mode with strict concurrency.** This includes Swift 6.2's approachable concurrency, default MainActor isolation, `@concurrent`, and correct `Sendable` use.
- **Liquid Glass**, the iOS 26 design system: `glassEffect`, `GlassEffectContainer`, and the new tab bar and toolbar behavior.

### Expected baseline

Missing these looks dated; having them won't make you stand out:

- SwiftUI first, with `@Observable`, `NavigationStack` and the `Tab` API.
- SwiftData with versioned schemas and migration plans.
- Swift Testing (`@Test`, `#expect`, parameterized tests) instead of XCTest.
- `SpeechAnalyzer` (iOS 26), which replaces `SFSpeechRecognizer`.
- String Catalogs, accessibility and Dynamic Type.
- CI (Xcode Cloud's free tier or GitHub Actions) and code split into Swift packages.
- AI-assisted coding, which Xcode 27 now has built in. You still need to be able to explain every line in an interview.

> Note: the WWDC26 details come from news coverage rather than Apple's documentation. Check the APIs against Apple's docs before building.

## Architecture

**The core pattern:** SwiftUI views bind directly to `@Observable` models and services. That's often called "MV" (model–view). Use a thin view model only where a screen has real logic. Swift 6 strict concurrency runs through everything.

| Area | Modern | Dated for new code |
|---|---|---|
| UI | SwiftUI-first, wrapping UIKit only where needed | Storyboards, apps built UIKit-first |
| State | `@Observable` with `@State`, `@Bindable`, `@Environment` | `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` |
| Pattern | MV or thin MVVM. TCA (The Composable Architecture, a third-party framework) suits large teams that want strict one-way data flow | VIPER; MVVM built on Combine bindings |
| Concurrency | Swift 6 language mode with complete checking. Main actor as the default, `@concurrent` to move work off it, actors, `Sendable`, `async let`/`TaskGroup`, `AsyncSequence` | GCD, completion handlers, Combine pipelines |
| Persistence | SwiftData with `@ModelActor` for background work; GRDB when you need real SQL | Core Data is still common in industry, but it doesn't read as "current" |
| Navigation | `NavigationStack`/`NavigationSplitView` with value-based `navigationDestination`, plus an `@Observable` router for deep links | `NavigationView`, `NavigationLink(destination:)` |
| Dependency injection | Protocol-based services injected through the Environment (`@Entry`), or the swift-dependencies library | Singletons, Swinject/Resolver containers |
| Modularity | Local Swift packages per feature or layer (models, persistence, features, design system) | One monolithic target, CocoaPods |
| Testing | Swift Testing (`@Test`, `#expect`, parameterized tests), `#Preview` with `@Previewable`, XCUITest for key flows | XCTest-only unit tests |
| Platform | App Intents (Siri, Shortcuts, Spotlight), WidgetKit, Live Activities, Foundation Models (Apple's on-device AI), Liquid Glass design | SiriKit intent definition files |

### What it looks like

```swift
protocol ItemStore: Sendable {
    func items() async throws -> [Item]
}

extension EnvironmentValues {
    @Entry var itemStore: any ItemStore = LiveItemStore()   // swap in a mock for tests and previews
}

@Observable
final class ItemListModel {            // runs on the main actor by default
    var items: [Item] = []
    var error: Error?

    func load(using store: any ItemStore) async {
        do { items = try await store.items() } catch { self.error = error }
    }
}

struct ItemListView: View {
    @Environment(\.itemStore) private var store
    @State private var model = ItemListModel()

    var body: some View {
        List(model.items) { item in
            NavigationLink(value: item) { Text(item.name) }
        }
        .navigationDestination(for: Item.self) { ItemDetailView(item: $0) }
        .task { await model.load(using: store) }
    }
}
```

## What convinces a reviewer

Recruiters match keywords. Engineers who review your code look for these:

1. It builds in Swift 6 language mode with zero warnings. This is the easiest signal to check.
2. A README with an architecture diagram and a short section on why you chose MV over MVVM or TCA. Explaining your trade-offs matters more than which pattern you picked.
3. Swift Testing tests, plus automated builds and tests on every push (GitHub Actions is free for public repos), with a status badge.
4. At least one platform integration beyond basic data entry, such as an App Intent or a widget.
5. A TestFlight or App Store link.

Keep UIKit on your résumé. Many large companies still run mostly UIKit code.

## Sources

- [MacRumors – 2026 Platforms State of the Union](https://www.macrumors.com/2026/06/09/apple-outlines-major-ai-and-developer-tool-updates/)
- [Apple – WWDC26 session 122](https://developer.apple.com/videos/play/wwdc2026/122/)
- [Fone Arena – Foundation Models / Xcode 27](https://www.fonearena.com/blog/?p=484623)
- [DEV – What's new in SwiftUI (WWDC26)](https://dev.to/arshtechpro/wwdc26-whats-new-in-swiftui-a-developers-breakdown-1333)
- [Lushbinary – iOS 27 developer guide](https://lushbinary.com/blog/wwdc-2026-announcements-ios-27-siri-developer-guide/)
- [Tom's Guide – iOS 27 features](https://www.tomsguide.com/phones/iphones/ios-27-is-official-all-the-new-upgrades-and-features-announced-at-wwdc-2026)
- [swift-ios-skills – swift-architecture](https://tessl.io/registry/skills/github/dpearson2699/swift-ios-skills/swift-architecture)
- [3nsofts – SwiftUI production architecture patterns 2026](https://3nsofts-site.pages.dev/insights/swiftui-production-architecture-patterns-2026)
- [Fora Soft – iOS MVVM architecture](https://forasoft.com/blog/article/advanced-ios-app-architecture-explained-on-mvvm-977)
