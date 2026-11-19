# Eldritch Genesis — Design

Status: v1 design, agreed 2026-11-09; modernized 2026-11-16 (how features are built changed, scope did not); reviewed 2026-11-18 against CLAUDE.md and the Swift skills. Decisions marked **FUTURE** are deliberately out of v1.

## 1. Overview

Eldritch Genesis sets up a game of Eldritch Horror. It randomly picks an Ancient One and N investigators from the content the user owns, lets the table reroll individual picks, and records the game once it starts.

### Goals

1. **Tool for my own table.** Faster than sorting and shuffling cards from several boxes.
2. **Publicly installable app.** Free, for anyone who owns some or all of the game, through the App Store or a public TestFlight link.
3. **Portfolio piece.** Shows current iOS practice: Swift 6 strict concurrency, SwiftUI with an MV architecture and `@Observable`, SwiftData with a versioned schema and CloudKit, value-based `NavigationStack` with a router, App Intents, Swift Testing with `#Preview`, Liquid Glass, a String Catalog, local Swift packages, and CI with a zero-warning gate. The README explains each choice (§7, §16).

v1's value is convenience. The randomizer is small on purpose. The engineering signal comes from data integrity, sync, testing and platform integration, not from clever selection logic.

### Non-goals (v1)

- Setup elements other than the Ancient One and investigators: Preludes, Mythos difficulty, side boards, starting items.
- Player names, or assigning investigators to players.
- Role-balanced teams (e.g. "make sure someone can fight").
- Card art, logos, or any game text beyond names.
- Stats screens.
- New platform features for their own sake. Modern APIs appear only where a v1 feature needs them; extra ones go to §2 FUTURE. The one exception is the App Intent (§9). It stays in v1 for the portfolio's platform-integration signal, and because starting a setup by voice is the one natural use of it.

## 2. Scope

### v1

- Pick 1 Ancient One + N investigators (N chosen by the user, 1–8) from owned products.
- Per-item reroll before the game starts.
- **Start game** writes a history entry.
- Mid-game random replacement when an investigator is eliminated.
- Outcome tracking: won / lost (with reason) / abandoned, plus notes.
- History list, detail and full edit.
- iCloud sync of history and owned expansions.
- Siri / Shortcuts intent that generates a setup.

### FUTURE

| Feature | Notes |
|---|---|
| "Avoid recent" toggle | Exclude Ancient Ones and investigators used in the last N games. Reads history. |
| "Favor unplayed" weighting | Weight picks toward rarely played content. Reads history. |
| Stats screen | Win rate overall and per Ancient One, loss reasons, play counts. The v1 data model already records what this needs. Compute off the main actor with `@ModelActor` if history grows (§7). |
| Log past game | Create a history entry by hand, without Generate. Reuses the edit screen. |
| Foundation Models recap | On-device model writes a one-line recap from a game's notes, using `@Generable` output. Settle the cloud question first (§15). |
| Spotlight, widget, Control Center | Expose games as `AppEntity` so Spotlight, a widget or a Control Center control can open a setup. Builds on §9. |
| Multiple windows | Needs a per-scene `Router` and an app-level inbox for intent hand-offs (§6). |

## 3. Content catalog

- Bundled, read-only JSON in the `EldritchCore` package. No network and no backend: Eldritch Horror content is static.
- Three collections: **products** (base game + 8 expansions), **Ancient Ones** and **investigators**. Each Ancient One and investigator belongs to exactly one product.
- Every entry has a **stable slug ID** (`"azathoth"`, `"jenny-barnes"`) and a display name. History stores IDs only, never names or array indexes, so fixing a typo in a name never breaks old games.
- **Names only.** No art, card text, stats or abilities.
- **Base game is always owned** and can't be toggled off. Expansions require it.
- **Source and verification:** Claude drafts the JSON. The developer checks every entry against the physical cards at the end of M1, before any history is saved (§13). M8 repeats a spot check before TestFlight. Integrity tests (§10) catch structural errors. Only a human check catches wrong names or wrong product assignments.

```json
{
  "products": [{ "id": "base", "name": "Eldritch Horror" }, { "id": "forsaken-lore", "name": "Forsaken Lore" }],
  "ancientOnes": [{ "id": "azathoth", "name": "Azathoth", "product": "base" }],
  "investigators": [{ "id": "jenny-barnes", "name": "Jenny Barnes", "product": "base" }]
}
```

## 4. Randomization rules

All picks are **uniformly random** over the eligible pool. Pools only ever contain content from owned products.

| Action | Pool |
|---|---|
| Generate | 1 Ancient One from owned; N distinct investigators from owned |
| Reroll Ancient One | Owned Ancient Ones other than the one shown |
| Reroll one investigator | Owned investigators not currently shown |
| Replace eliminated investigator (in-game) | Owned investigators **never used in this game**: not starting ones, not earlier replacements |

- The app doesn't track whether the Ancient One has awoken. The table knows whether replacement is allowed and just doesn't tap Replace.
- If a pool is empty, the action is disabled and the app explains why in text beside it ("No unused investigators left in your collection"). If Generate can't fill a setup at all, New Game shows a `ContentUnavailableView` with the same reason instead of the reveal.
- If owned investigators < N, Generate fails with a clear message. This shouldn't happen with the base game, but the randomizer guards against it and tests cover it.
- The RNG is injected: `SystemRandomNumberGenerator` in the app, a seeded generator (e.g. SplitMix64) in tests.

```swift
public enum Randomizer {
    public static func generate(investigatorCount: Int, catalog: Catalog, owned: Set<Product.ID>,
                                using rng: inout some RandomNumberGenerator) throws(SetupError) -> Setup
    public static func rerollAncientOne(in setup: Setup, catalog: Catalog, owned: Set<Product.ID>,
                                        using rng: inout some RandomNumberGenerator) -> Setup?
    public static func rerollInvestigator(at index: Int, in setup: Setup, catalog: Catalog, owned: Set<Product.ID>,
                                          using rng: inout some RandomNumberGenerator) -> Setup?
    public static func replacement(excluding used: Set<Investigator.ID>, catalog: Catalog, owned: Set<Product.ID>,
                                   using rng: inout some RandomNumberGenerator) -> Investigator.ID?
}
```

## 5. Game lifecycle and history

```
Generate ──► Reveal ──► (reroll any item, free, unsaved) ──► Start game ──► In progress
                                                                         │
                                       Replace eliminated investigator ◄─┤
                                                                         ▼
                                                        Won │ Lost (+reason) │ Abandoned
```

- **Nothing is saved as history until Start game.** Rerolled setups are throwaway. A revealed setup is encoded as JSON in `@SceneStorage`, so an app kill or a phone handed around the table doesn't lose it. Scene storage is not history: no SwiftData row exists until Start game.
- **Outcome:** `inProgress`, `won`, `lost`, `abandoned`. Abandoned games stay in history and will be left out of future win-rate stats.
- **Loss reason** (only when lost): `ancientOneAwakened`, `mythosDeckExhausted`, `allInvestigatorsEliminated`, `other`. Details go in notes.
- **Notes:** free text on every game.
- **Multiple in-progress games are allowed.** Two synced devices can each start one, so the app doesn't pretend otherwise. The Games tab lists every in-progress game at the top.
- **Everything is editable** after start: Ancient One, lineup, date, outcome, reason, notes. Edit pickers show owned content plus whatever is already selected, so a game survives un-toggling an expansion. Edits keep seats numbered `0..<N`, and each seat's sequence numbers count up from 0 with no gaps. Swipe to delete (§6 asks for confirmation).
- **Unknown IDs:** an ID missing from the catalog (removed entry, or synced from a newer app version) shows as "Unknown (id)" and never crashes or gets dropped. The same applies to an unknown outcome or loss-reason raw value. It displays as "Unknown", and an edit only rewrites a raw value the user changed.
- **Deleted while open:** if sync deletes a game while its detail screen is open, the screen pops back to the list.

## 6. Screens

`TabView` using the `Tab` API with `.sidebarAdaptable`: a tab bar on iPhone, a sidebar on iPad. Each tab owns a `NavigationStack` whose path lives in `Router`. Games uses a `NavigationSplitView` on iPad so the list and detail stay visible together.

**Single window (v1).** The scene is a single `Window`, not a `WindowGroup`, so each window doesn't get its own copy of tab state. Verify the scene type with `DocumentationSearch` at M2 (§15). Multiple windows are deferred (§2 FUTURE).

| Tab | Contents |
|---|---|
| **New Game** | Investigator-count stepper (1–8) → Generate → animated reveal → tap any item to reroll → Start game. Also receives a setup handed over from the App Intent. |
| **Games** | In-progress games at the top, then finished games newest first. Detail: lineup with replacement history, Replace on each active investigator, set outcome. Edit sheet for every field. Replace and swipe-delete ask for confirmation first; delete syncs to every device and can't be undone. An empty list shows a `ContentUnavailableView`. |
| **Settings** | Owned-expansion toggles (base shown locked on). About screen with the unofficial disclaimer and version. |

Reveal: investigators appear one at a time, then the Ancient One last, with a haptic. Under Reduce Motion or VoiceOver, everything appears at once; VoiceOver users get one announcement naming the full setup.

- **Navigation:** every destination is value-based: `navigationDestination(for:)` with `PersistentIdentifier` for games and a value type for setups. No `NavigationLink(destination:)`.
- **Router:** an `@Observable` `Router` holds the selected tab, each tab's path, `gamesSelection` (the split view's selection on iPad) and `pendingSetup`. The app creates it once, as root `@State`, and registers it with intents at launch. Intents and deep links change `Router`; views don't reach into each other.
- **Layout** follows the window's width and size class, not the device. Narrow windows, including iPhone Duo's outer display, stack list and detail; wider ones show them together. No feature disappears at any width (§12).
- **Haptics:** `.sensoryFeedback` on the last reveal card and on Start game.
- **Motion:** the reveal reads `accessibilityReduceMotion` from the environment.

## 7. Architecture

**MV (model–view).** SwiftUI views bind directly to `@Observable` models and SwiftData `@Query`. A screen with logic gets one `@Observable` screen model (`NewGameModel`, `GameListModel`, `GameDetailModel`) that owns that logic and is unit-tested. There is no pass-through layer: a model exists only where its screen has logic to hold. The Games tab's split of in-progress and finished games, and its sort order, are pure functions on `GameListModel`, not inside `@Query` in the view. Services are protocols injected through the Environment with `@Entry`, so previews and tests can use fakes.

```
EldritchGenesis (app target)               SwiftUI, MV, default MainActor
├── App/                                    Entry point, the single window, Router, root tabs
├── NewGame/                                NewGameModel, reveal, rerolls and their views
├── Games/                                  GameListModel, GameDetailModel, edit sheet and views
├── Settings/                               Owned toggles, About
├── Intents/                                GenerateSetupIntent, OpenSetupIntent, SetupEntity, AppShortcuts
├── Shared/                                 OwnedProductsStore, KeyValueStoring, Clock, RNG provider, design constants
└── Resources/                              String Catalog, assets
        │ depends on                       │ depends on
        ▼                                  ▼
EldritchCore (package)  ◄── depends on ──  EldritchData (package)
├── Catalog types + catalog.json           ├── SchemaV1: Game, Appearance (one file each)
│   Sendable, Codable                      └── SchemaMigrationPlan (empty in v1)
├── Randomizer: pure functions,
│   injected RNG
└── Display-name rule: returns .name or .unknown(id), never text
```

- `EldritchCore` and `EldritchData` have no SwiftUI dependency, so `swift test` runs both on the macOS host with no simulator. `EldritchData` tests use an in-memory `ModelContainer`.
- The package dependency runs one way: `EldritchData` imports `EldritchCore` (for `Setup`, IDs and the display-name rule). Core never imports Data.
- Test folders mirror the app's feature folders, so each feature's tests sit beside the same feature.
- **Build settings** (set per target, checked in CI):
  - App: Swift 6 language mode, complete concurrency checking, default actor isolation `MainActor`.
  - Packages: Swift 6 language mode in `Package.swift`, no default actor isolation. Types are `nonisolated` by default; public value types declare `Sendable` explicitly.
  - Zero warnings is a CI gate (§10). Pin the Swift and Xcode versions in CI and in the README.
- No third-party dependencies.

**Isolation by target**

| Target | Isolation | Contents |
|---|---|---|
| App | `@MainActor` (default) | Views, `@Observable` models, `Router`, `OwnedProductsStore`, intent `perform()` (verify at M6) |
| `EldritchData` | `nonisolated` | Schema and migration plan. `@Model` objects are used from the main actor |
| `EldritchCore` | `nonisolated` | `Sendable` value types, typed throws, pure functions |

Nothing in v1 runs off the main actor. `@ModelActor` and `@concurrent` are deliberately unused: history is one small row per game, and the randomizer finishes in microseconds. The stats screen (§2 FUTURE) is the first place `@ModelActor` would earn its place.

**Observation.** `OwnedProductsStore` is `@Observable`. It reads and writes through a `KeyValueStoring` protocol, which also exposes a change stream (`AsyncStream`, built with `makeStream(of:)`) that signals external changes. The live implementation feeds that stream from `NotificationCenter.default.notifications(named:)`. The test fake yields into it directly. The observing loop runs in a `.task` on the root view and ends when that view does. No `Task {}` in `init`. No Combine publishers.

**Dated patterns we avoid.** CI fails the build if these appear in app or package sources. A hit needs a comment giving the reason. The list covers the banned APIs in CLAUDE.md and the table below: `import Combine`, `ObservableObject`, `@Published`, `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, `DispatchQueue`, `NavigationView`, `NavigationLink(destination:`, `SiriKit`, `foregroundColor(`, `cornerRadius(`, `tabItem(`, `onTapGesture(`, `Task.sleep(nanoseconds`, `DateFormatter`, `NumberFormatter`, `String(format:`, `UIScreen.main`, `AnyView`, `@Attribute(.unique)`, `#Unique`.

| Avoid | Use |
|---|---|
| `ObservableObject`, `@Published`, `@StateObject`, `@EnvironmentObject` | `@Observable`, `@State`, `@Bindable`, `@Environment` |
| Combine pipelines, GCD | `async`/`await`, `AsyncSequence`, actors, `TaskGroup` |
| `NavigationView`, `NavigationLink(destination:)` | `NavigationStack` with value-based destinations |
| XCTest unit tests | Swift Testing (XCUITest stays for the one UI test) |
| SiriKit intent definitions | App Intents |
| Storyboards, Core Data | SwiftUI, SwiftData |

Why MV and not MVVM or TCA: the app's logic lives in `EldritchCore` as pure functions, and its state is mostly SwiftData records. A layer of view models that only forwards calls would add nothing. TCA would add a large dependency to a small app. The README will explain this trade-off.

## 8. Persistence and sync

### History: SwiftData + CloudKit (private database)

Designed for CloudKit's rules from day one: no `@Attribute(.unique)`, every property optional or defaulted, relationships optional with explicit inverses, enums stored as raw `String` so an unknown value from a newer version decodes safely.

```swift
enum SchemaV1: VersionedSchema {
    @Model final class Game {
        var startedAt: Date = Date.now
        var ancientOneID: String = ""
        var outcomeRaw: String = "inProgress"
        var lossReasonRaw: String?
        var notes: String = ""
        @Relationship(deleteRule: .cascade, inverse: \Appearance.game)
        var appearances: [Appearance]? = []
    }

    @Model final class Appearance {
        var seat: Int = 0          // 0..<N, the investigator's position at the table
        var sequence: Int = 0      // 0 = starting investigator, 1+ = replacements in that seat
        var createdAt: Date = Date.now  // orders duplicate seat/sequence pairs written on two devices
        var investigatorID: String = ""
        var eliminated: Bool = false
        var game: Game?
    }
}
```

Each `@Model` goes in its own file as an extension of `SchemaV1` (`Game.swift`, `Appearance.swift`), with `typealias Game = SchemaV1.Game` and `typealias Appearance = SchemaV1.Appearance` in the package, per CLAUDE.md's one-type-per-file rule. The snippet shows both together for reference.

A versioned schema and an empty `SchemaMigrationPlan` ship in v1, so the first real migration isn't also the first time migration code exists. Both live in `EldritchData`, which the app wires into a `ModelContainer`.

**Container and concurrency.** The app builds a CloudKit-backed `ModelConfiguration`. Tests and previews use an in-memory one. Reads and writes run on the main actor through the environment's `ModelContext`. No `@ModelActor` in v1 (§7).

**Saving and identity.**
- Save explicitly with `try context.save()` after Start game, Replace, an outcome change and each edit. Autosave timing isn't predictable, and sync depends on saves going out promptly.
- A `PersistentIdentifier` is temporary until the first save. Start game saves before the detail screen is pushed, so no route carries a temporary ID.

**Sync is eventually consistent.** A `Game` can arrive before its `Appearance`s, and two devices can replace the same seat at once, leaving two rows with the same `(seat, sequence)`.
- Detail renders a partial lineup and never assumes seats `0..<N` exist.
- Duplicate `(seat, sequence)` pairs sort by `createdAt`, then `investigatorID`, and both are shown. Nothing crashes or drops a row.
- A game deleted by sync while its detail is open pops back to the list (§5).

**Schema changes.** Within V1, changes are additive: new properties are optional or defaulted. The first breaking change adds `SchemaV2` and a migration stage. From M3 on, keep a saved V1 store file as a test fixture, so the migration test exists before it's needed. Once V1 is in the Production CloudKit environment, the schema is additive-only: no renames, and no deletes of deployed fields (§8 Release gate).

### Owned expansions: `NSUbiquitousKeyValueStore`

One key per product: `owned.<product-id>`, with a Bool value. The keys are synced through iCloud key-value storage and mirrored to `UserDefaults`, so the list works with iCloud signed out. The per-product keys matter. One array under a single key is last-writer-wins, so two devices toggling different expansions would drop one toggle. The base game is always owned and has no key. Keys for unknown product IDs are ignored. The app observes external changes through the store (§7). Not stored in SwiftData, because a single settings record under CloudKit duplicates when two devices merge and CloudKit can't enforce uniqueness. The store sits behind a `KeyValueStoring` protocol, so tests use an in-memory fake.

### Release gate

- Release builds, including internal TestFlight, run against the CloudKit **Production** environment. Before any TestFlight build, deploy the schema from Development to Production in the CloudKit console. Forgetting this makes sync fail silently.
- Before that deploy, run a Debug build on a real device signed into iCloud, so the Development schema exists to deploy.
- After the Production deploy, schema changes are additive-only (see Schema changes).

**Two-device sync checklist** (two real devices before M8, not simulators):
1. Start a game on A. It appears on B.
2. Toggle an expansion on B. It appears on A.
3. Put A in airplane mode, edit the game, reconnect. Both devices converge with no duplicate game.
4. Sign B out of iCloud. The app keeps working locally.

## 9. App Intents

- `GenerateSetupIntent(investigatorCount: Int)` picks from owned content and returns a **snippet**: the Ancient One and investigator names. **Nothing is committed** to history.
- The snippet offers **Open in Eldritch Genesis**, which hands the setup to the New Game tab for rerolls or Start game.
- **Hand-off:** the button runs `OpenSetupIntent`, which passes the setup as a `SetupEntity` (an `AppEntity`), not loose IDs, and sets `Router.pendingSetup`. New Game reads the value and clears it. Verify the cold-launch order at M6.
- An App Shortcut phrase uses the app name only, e.g. "Set up a game in Eldritch Genesis". Never "Eldritch Horror" (see §11).
- **Dependencies:** intents get `Router`, `OwnedProductsStore` and the catalog through `@Dependency`, registered with `AppDependencyManager` at launch. With a single window (§6), there is one `Router` to register.
- `GenerateSetupIntent` calls `Randomizer` with `SystemRandomNumberGenerator`, the same path as the app. Its logic is covered by `EldritchCore` tests; the intent wrapper stays thin.
- SiriKit is not used. WWDC26 coverage says App Intents is now the required path (verify).

## 10. Testing and CI

| Layer | What | How |
|---|---|---|
| `EldritchCore` | No duplicates; owned-only; reroll excludes current; replacement excludes all used; empty pools return nil; N > pool throws; display-name rule returns `.unknown(id)` for missing IDs | Swift Testing, parameterized over seeds and owned sets. Two argument collections form a Cartesian product, so keep the seed list short or pass `zip(seeds, ownedSets)` for pairs |
| Catalog integrity | Unique IDs; every item maps to an existing product; base product exists; names non-empty | Swift Testing against the real `catalog.json` |
| Models (`EldritchData`) | Start game creates the right appearances; replacement increments `sequence`; partial lineups render; duplicate `(seat, sequence)` pairs sort deterministically; edits keep seats and sequences gap-free | Swift Testing with an in-memory `ModelContainer` |
| Schema rules (CloudKit-safe) | No unique constraints; defaults or optionals; optional relationships with explicit inverses | Banned-pattern grep covers unique constraints. A model test covers the rest if SwiftData's `Schema` exposes the information (verify with `DocumentationSearch`) |
| Migration | Store written by the current schema reopens through the migration plan | Swift Testing with a saved store fixture (from M3) |
| Stores | `OwnedProductsStore` reflects external KVS changes; base game can't be toggled off; changes to two different products from two devices both survive; unknown product IDs are ignored | Swift Testing with a fake `KeyValueStoring` |
| Router | Intent hand-off sets `pendingSetup`; New Game consumes it once | Swift Testing on `Router` |
| Previews | Each screen has `#Preview`s built on fakes (`@Previewable` for state) | Checked by eye at largest Dynamic Type in M7 |
| UI | Generate → Start game → mark won | One XCUITest. Unit tests can't cover this flow, which crosses SwiftData, navigation and a sheet. CLAUDE.md allows UI tests only in that case |

**Isolation in tests.** Test targets inherit the default MainActor isolation if their build settings enable it. Suites for `Router` and `OwnedProductsStore` are marked `@MainActor` explicitly, so they don't rely on that setting.

CI runs on GitHub Actions on every push: `swift test` for both packages, and `xcodebuild test` for the app on an iOS 26 simulator, the minimum OS, with Xcode 27 pinned. Optionally add a latest-OS job. The banned-pattern grep from §7 runs as its own step. SwiftLint is not part of v1: CLAUDE.md uses it only when it's installed, and it's a third-party tool, so adding it needs approval. Warnings fail the build through `SWIFT_TREAT_WARNINGS_AS_ERRORS`, not by parsing logs. Before M0, confirm a GitHub Actions runner image with Xcode 27 exists (§15). A README badge shows status. The build fails on any warning.

**README (by M8):** an architecture diagram, why MV rather than MVVM or TCA, the package layout, how to run the tests, and an AI-assistance note saying what Claude drafted and how it was checked.

## 11. IP, App Store and privacy

- **Unofficial fan app.** All game names belong to Fantasy Flight Games / Asmodee. The app ships names only: no art, logos or card text. The About screen and README say "Unofficial. Not affiliated with or endorsed by Fantasy Flight Games or Asmodee."
- **The listing never names the game.** The name, subtitle, keywords and description all leave out "Eldritch Horror". Discoverability is deliberately close to zero. Word of mouth and the portfolio link are the distribution. The listing is the only place the game name is left out. Inside the app, Settings shows the base product's name and the expansion names, About names FFG, and the lists show investigators. §14 rates that review risk High.
- **Screenshots** show only public-domain Lovecraft entity names. Investigator names (FFG's own characters) are cropped or blurred.
- **Free.** No IAP, ads, analytics or tracking. Privacy label: **Data Not Collected** (CloudKit private database data belongs to the user's iCloud account). Re-check if any AI feature sends data off-device (§15).
- **Privacy manifest.** The app ships `PrivacyInfo.xcprivacy` declaring the UserDefaults required-reason API, because owned expansions are mirrored there (§8). App Store Connect also requires a privacy policy URL for a free app that collects nothing. Host it on any static page.
- **If Apple rejects under guideline 5.2.1,** fall back to a public TestFlight link, which covers both the portfolio and table goals.
- **Repo:** public on GitHub, MIT license for the code. The README notes that the game names in `catalog.json` belong to their owners.

## 12. Visual design and accessibility

- **Liquid Glass, system first.** Tab bars, toolbars and sheets use the system look, with `tabBarMinimizeBehavior` on scroll. Custom `glassEffect` only on the reveal cards, inside a `GlassEffectContainer`. No glass behind text-heavy lists.
- Restrained dark eldritch accent palette (deep green or purple) and a themed app icon. No custom parchment or occult chrome. Glass is checked against Reduce Transparency and increased contrast in M7.
- **Tokens, not literals.** Colors come from the asset catalog. Spacing, fonts, corner radii and animation timings come from one shared design-constants file. Views don't hard-code them.
- **Width, not device.** Layout follows the window's width and size class (§6). No feature disappears at any width.
- VoiceOver labels on every control. Each reroll is a `Button` labelled, for example, "Reroll Jenny Barnes". It is never a tap gesture, and its tap target is at least 44×44 pt.
- Dynamic Type up to the accessibility sizes. Lists reflow instead of truncating.
- Reduce Motion turns off the reveal animation. VoiceOver does too: the full setup appears at once, and VoiceOver gets one announcement naming it.
- **Strings.** Every user-facing string is a symbol key in the String Catalog with `extractionState` set to `manual`, used as `Text(.key)`. Packages return values, not text: `SetupError` cases and the display-name rule (§7) produce values such as `.unknown(id)`, and the app maps them to strings. "Unknown (id)" is therefore one catalog entry with an argument. A package that ever has to show text itself uses `bundle: #bundle`.
- English only. Every user-facing string goes through the String Catalog from day one.
- iPhone and iPad, minimum iOS 26. Built with Xcode 27, pinned in CI.
- **API check:** verify each iOS 26/27 API name with Xcode's `DocumentationSearch` (Xcode MCP, per CLAUDE.md) before it goes in code. The names in this document come from WWDC26 coverage and are unverified until then. Anything iOS 27-only sits behind `#available`, or waits.

## 13. Milestones

No deadline: ship when done. To keep that from becoming "never", milestones are strictly ordered and **public TestFlight is a hard checkpoint** before any App Store work.

| # | Milestone | Done when |
|---|---|---|
| M0 | Repo, Xcode project, `EldritchCore` and `EldritchData` packages, CI skeleton with the banned-pattern grep and warnings as errors | CI green on an empty test on the iOS 26 simulator, badge in README |
| M1 | Catalog draft + randomizer + tests | All §10 core and catalog tests pass, and the developer has checked every catalog entry against the physical cards |
| M2 | New Game tab (`NewGameModel`, `Router`), rerolls, owned toggles (local only), pending setup in `@SceneStorage` | Usable at the table from a phone; a revealed setup survives an app kill |
| M3 | SwiftData history: Start game, Games tab, outcome, edit, delete | A game can be played and recorded end to end |
| M4 | Mid-game replacement | Replace works; history shows seat sequence |
| M5 | CloudKit + KVS sync (`OwnedProductsStore` observes changes, per-product keys) | Game started on iPhone appears on iPad, and so do owned toggles; two-device checklist passes |
| M6 | App Intent + App Shortcut | Siri phrase returns a snippet; Open hands off the setup, including from a cold launch |
| M7 | Polish: reveal animation, haptics, icon, palette, accessibility audit | VoiceOver, largest Dynamic Type and Reduce Transparency pass on every screen |
| M8 | Developer spot-checks catalog against cards → **public TestFlight** | External testers install; CloudKit production schema deployed; privacy manifest and policy URL in place; README has the architecture diagram |
| M9 | App Store submission | Approved, or 5.2.1 fallback to TestFlight |

## 14. Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| App Store rejection for third-party IP (5.2.1) | High | Names only, disclaimer, no game name in the listing. The app still shows names (§11), so TestFlight fallback is the plan |
| Catalog errors (wrong name or product) | High until the M1 check | Full check against physical cards at the end of M1; spot check at M8; integrity tests |
| CloudKit sync bugs (duplicates, conflicts, silent failure, duplicate seat sequences) | Medium | CloudKit-safe schema from V1; deterministic sort for duplicate sequences; partial-lineup rendering; per-product KVS keys; production schema deploy on the release checklist |
| Setup lost before Start game (app killed, phone handed around the table) | Low | Pending setup kept in `@SceneStorage` (§5) |
| Scope creep with no deadline | High | Ordered milestones; FUTURE list is the only place new ideas go before TestFlight |
| Near-zero discoverability | Certain (by choice) | Accepted. Success is the table and the portfolio, not download counts |
| iOS 26 minimum shrinks the install base | Certain | Accepted (§16). The table and the portfolio are the goals, not reach |
| iOS 26/27 API names unverified (WWDC26 coverage, per MODERN.md) | Medium | Verify each with `DocumentationSearch` before use; list in §15; iOS 27-only APIs behind `#available` |
| Over-engineering in the name of "modern" | Medium | Adopt a practice only where v1 needs it; §7 lists what was skipped and why |
| Cloud AI inside Foundation Models conflicts with the privacy label | Low (AI is FUTURE) | Settle where cloud inference runs before any AI feature ships (§15) |

## 15. Open items

- Confirm "Eldritch Genesis" is available as an app name in App Store Connect.
- Using public-domain Lovecraft names in screenshots is a judgment call, not legal advice. Re-check before M9.
- Verify these API names with `DocumentationSearch` at the milestone that first uses them: `OpenSetupIntent`'s mode setting and cold-launch order (M6), `@Dependency` and `AppDependencyManager` (M6), `tabBarMinimizeBehavior` and `GlassEffectContainer` (M7), `@Previewable` (M2), and the `Window` scene type (M2). Each one's availability (iOS 26 or 27) decides whether it needs `#available`.
- Confirm a GitHub Actions runner image with the pinned Xcode 27 exists before M0 (§10).
- Confirm whether SwiftData's `Schema` exposes relationship inverses for the schema-rules test (§10), before M1.
- Where do Foundation Models cloud requests run, and what do they keep? Settle this before any AI feature ships and before the privacy label is final (§11).

## 16. Decision log

| Decision | Why |
|---|---|
| Investigator count chosen by the user, 1–8 | The count is set by who's at the table, not chance. |
| Owned-expansion filter in v1 | Without it, a public app picks content strangers don't own. |
| Per-item reroll | Rerolling everything throws away picks the table liked. |
| Uniform randomness | v1 is convenience. Biasing by history is FUTURE. |
| History saved only on Start game | Rerolls would fill history with junk. A revealed setup is kept in `@SceneStorage` instead. |
| Replacement excludes everyone used this game | Simple, testable, and matches play. Awakening isn't tracked to avoid extra state. |
| Multiple in-progress games | CloudKit can create them anyway, so handling it honestly is simpler than conflict logic. |
| Owned toggles in KVS, one key per product | A singleton record duplicates under CloudKit merges. One array under one key loses a toggle when two devices change it; a key per product merges cleanly. |
| App Intent never commits | Siri can't show rerolls well, and a voice command shouldn't write history. |
| MV, with one screen model per screen that has logic | Pure logic lives in `EldritchCore`. Screen models hold what's left, so it's testable. A layer that only forwards calls would add nothing. |
| Free, no IAP | Charging on unlicensed IP raises takedown risk and adds StoreKit work for little gain. |
| Two packages: `EldritchCore` (pure) and `EldritchData` (SwiftData, depends on Core) | Model tests run with `swift test` on the host and can use `Setup` and the display-name rule from Core. Features stay in the app until a second target needs them. |
| `Router` (`@Observable`) owns navigation and intent hand-off, single window | Intents and deep links change one place; views don't reach into each other. One window keeps that to one `Router`. Multiple windows are deferred (§6). |
| Isolation per target: app on MainActor, packages `nonisolated` | Pure code stays Sendable and testable; UI and SwiftData stay on the main actor. |
| No `@ModelActor` or `@concurrent` in v1 | Data and CPU work are too small to justify them. Revisit with the stats screen. |
| Catalog checked against the cards at the end of M1 | History stores slug IDs from M3 on. A correction after that would orphan saved games, so the check comes before any history exists. |
| iOS 26 minimum | Liquid Glass (iOS 26) is the design system in §12. Showcase over reach. Costs install base; accepted in §14. |
| Banned-pattern grep in CI | Keeps dated APIs (§7) out of new code. |
| Developer writes all code in Xcode; Claude reviews and advises | The developer has to explain every line in an interview (MODERN.md). Reviews stay checkable against this document (§17). |

## 17. Working agreement

The developer writes all app, package and test code in Xcode. Claude's role is mostly code reviewer, and sometimes a partner the developer comes to for help.

**Claude as reviewer (most of the time)**
- The developer shares a file, a diff, or a path. Claude reviews it against this document, CLAUDE.md and the Swift skills.
- Findings are grouped by file. Each names the line and the rule, and shows a short before/after fix. Claude reports real problems only, not style preferences.
- Each finding explains the why, so the developer can defend every line in an interview.
- When code contradicts this document, Claude says so. The developer decides whether the code or the document changes.
- Claude doesn't edit source during a review. The fixes are the developer's to apply.

**Claude as partner (when asked)**
- When the developer asks how to do something, Claude shows the pattern in a short snippet in the reply. The snippet isn't written into the project.
- Snippets stay small: the pattern, not a whole feature. Claude names the API and the minimum iOS version, and checks the API with `DocumentationSearch` before showing it (§12).
- Claude explains the trade-off, so the developer can apply the idea in their own code.

**Exceptions.** Claude writes files only when the developer asks. The planned exception is the catalog JSON (§3): Claude drafts it, and the developer verifies every entry against the cards.

**Tools and version control.** If the Xcode MCP is configured, Claude may read project files, build, and check the issue navigator to support a review. It doesn't write source through those tools unless asked. The developer makes the commits. Claude commits only when asked.

**Tone.** Short and direct. No praise padding. Weak logic gets called out, including in this document.
