# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Development and Tooling

This is a SwiftUI iOS app managed via the Xcode project `myDay.xcodeproj` and using SwiftData for persistence.

### Common commands

- Open the project in Xcode (primary way to run and debug the app):
  - `open myDay.xcodeproj`
  - or `xed .` (if Xcode command‑line tools are installed)
- Build the app for an iOS simulator from the command line (adjust the destination to a simulator that exists locally):
  - `xcodebuild -project myDay.xcodeproj -scheme myDay -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build`
- Run the full test suite from the command line (once a test target is configured for the `myDay` scheme):
  - `xcodebuild test -project myDay.xcodeproj -scheme myDay -destination 'platform=iOS Simulator,name=iPhone 16 Pro'`
- Run a single test via `xcodebuild` (example pattern, assuming a unit test target named `myDayTests` exists):
  - `xcodebuild test -project myDay.xcodeproj -scheme myDay -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:myDayTests/SomeTestClass/testExample`

At the time of writing there is no dedicated linting configuration (e.g., SwiftLint) checked into this repository; if you introduce one, update this section with the canonical lint command.

## High‑Level Architecture

### Entry point and persistence setup

- `myDay/myDayApp.swift` defines the `@main` `myDayApp` struct, which is the app entry point.
- It currently creates a shared `ModelContainer` with a schema containing only the sample `Item` model (`Schema([Item.self])`) and attaches it to the main `WindowGroup` via `.modelContainer(sharedModelContainer)`.
- The main time‑tracking feature, however, is built around the `TimeEntry` SwiftData model defined in `Models.swift` and a separate `ModelContext` created inside `TimeGridView` (see below). If you refactor persistence, be aware of this split and consider unifying on a single `ModelContainer` that includes `TimeEntry`.

### Domain models and utilities

- `myDay/Models.swift` contains the core domain types:
  - `ActivityCategory`: an `enum` conforming to `CaseIterable`, `Codable`, `Identifiable`, and `Sendable`, representing high‑level categories such as sleep, work, food, etc. Each case has a user‑facing `displayName` and an associated SwiftUI `Color` used throughout the UI.
  - `TimeEntry`: a SwiftData `@Model` representing a single hour block on a given day. It stores `date` (normalized to `startOfDay`), `hour` (0–23), and `categoryRaw` (backing storage for `ActivityCategory`). The computed `category` property wraps `categoryRaw` and defaults to `.misc` if decoding fails.
  - A `Date` extension adds `startOfDay` and `addingDays(_:)`, which are used across the view model and views to work with day‑based ranges.
- `myDay/Item.swift` contains the default template `Item` SwiftData model (a single `timestamp`). It is currently only referenced in `myDayApp`’s schema and not used by the main time‑grid feature.

### View model and data access

- `myDay/GridViewModel.swift` defines `GridViewModel`, the main `ObservableObject` backing the time grid.
  - It is annotated with `@MainActor` and holds a `ModelContext` used for all SwiftData operations related to `TimeEntry`.
  - It tracks a visible date window via `visibleStartDate` and `visibleEndDate`, initialized to a 7‑day range centered on today (`today.addingDays(-3)` to `today.addingDays(3)`).
  - It maintains an in‑memory cache `[String: TimeEntry]` keyed by `(day, hour)` to avoid repeated fetches for cells that are already loaded.
- Key responsibilities:
  - `datesInRange(start:end:)` produces a list of day‑granularity `Date` values between two endpoints; this is what drives the vertical list of days in the UI.
  - `preloadEntries()` issues a SwiftData `FetchDescriptor<TimeEntry>` for the current visible date range and repopulates the cache.
  - `entry(for:hour:)` looks up a cached `TimeEntry` for a given day/hour.
  - `set(category:for:hour:)` either updates an existing `TimeEntry` or inserts a new one, saves the context (`try? context.save()`), updates the cache, and manually triggers `objectWillChange` so SwiftUI refreshes the grid.
  - `updateVisibleRange(start:end:)` and `extendRangeIfNeeded(scrolledToTop:)` adjust the visible date window, call `preloadEntries()`, and notify observers, enabling an extensible, scrollable timeline.

### UI layer and composition

- `myDay/ContentView.swift` is the top‑level SwiftUI view used in production.
  - It embeds `TimeGridView` inside a `NavigationStack`, sets the navigation title to "myDay", and defines toolbar buttons for a side menu (currently just toggling `showMenu`) and a Legend sheet.
  - The Legend sheet presents a list of all `ActivityCategory` cases, each with its color dot and display name, so users can interpret the grid colors.
- `TimeGridView` (also in `ContentView.swift`) is the main screen for visualizing and editing the day/hour grid.
  - It owns a `@StateObject` `GridViewModel` and some UI state (`showingPicker`, `selectedDate`, `selectedHour`).
  - In its initializer, it constructs a temporary `ModelContext` from a `ModelContainer(for: TimeEntry.self)` and injects that into `GridViewModel`. The helper `updateViewModelContextIfNeeded()` is currently a stub returning `true`; it exists as a hook if you later want to reconcile the view model’s context with the environment’s `modelContext`.
  - The body builds a vertical `ScrollView` of `DayRowView` rows, one per date in the `visibleStartDate...visibleEndDate` range from the view model.
  - Each `DayRowView` exposes a callback `onTapCell` used to open the `ActivityPickerSheet` for the tapped date/hour.
  - On `onAppear`, `TimeGridView` calls `viewModel.updateVisibleRange(...)` to ensure the model preloads data for the initial window.
- `DayRowView` lays out a single day:
  - Left side: a formatted date label (e.g., "Mon, Feb 3") in a fixed‑width column.
  - Right side: a horizontally scrollable row of 24 `TimeCellView` instances (hours 0–23). Each cell queries `viewModel.entry(for:date:hour:)` to determine its background color.
- `TimeCellView` represents a single hour block:
  - It renders a colored square (`Rectangle`) whose fill color is based on the associated `TimeEntry.category.color`, or a gray placeholder if there is no entry.
  - It exposes a tap gesture that triggers the `onTap` callback and an accessibility label that announces the hour and selected activity category.
- `myDay/ActivityPickerSheet.swift` implements the sheet used to choose an activity for a given date/hour.
  - It presents the selected date and a human‑readable hour interval (e.g., "3 PM – 4 PM"), then lists all `ActivityCategory` values with their colors.
  - Tapping a row invokes the injected `onSelect(ActivityCategory)` closure, which in `TimeGridView` is wired to `GridViewModel.set(category:for:hour:)` and then optionally advances to the next hour or dismisses the sheet.

### Notable design considerations

- Persistence configuration is currently split:
  - `myDayApp` sets up a shared `ModelContainer` for `Item` only.
  - `TimeGridView` constructs its own `ModelContainer`/`ModelContext` for `TimeEntry` and passes it into `GridViewModel`.
  - If you evolve the data model or add more features, consider consolidating on a single `ModelContainer` that includes `TimeEntry` (and any future models) so previews, production, and tests all share consistent configuration.
- Error handling in `GridViewModel` is intentionally minimal (`try? context.save()` and ignoring fetch errors). If you introduce more advanced flows (sync, background processing, etc.), you may want to add structured error handling and logging around these operations.
