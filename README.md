# myDay

myDay is a personal iOS time‑tracking app built with SwiftUI and SwiftData. It lets you quickly log how you spend each hour of the day using a color‑coded grid.

## Features

- **Calendar month view**
  - Shows one full calendar month at a time.
  - Each row is a day, each column is an hour (0–23).
  - Tapping a cell opens a bottom sheet to choose an activity category.
- **Activity categories**
  - Predefined categories such as Sleep, Work, Food, Exercise, etc., defined in `myDay/Models.swift` as `ActivityCategory`.
  - Each category has a stable identifier, display name, and associated color.
- **Month selector**
  - Collapsible month/year picker at the top of the grid.
  - Changing month or year updates the grid to show all days in that month.
- **Shared scrolling grid**
  - Left column shows pinned date labels.
  - Right side is a single horizontally scrolling grid shared across all days, so hours line up across rows.
- **Analytics (WIP)**
  - `AnalyticsViewModel` + `AnalyticsView` compute and display per‑activity averages for the current/previous week and a streak of consecutive days with at least one logged entry.

## Project structure

- `myDay.xcodeproj` – Xcode project.
- `myDay/myDayApp.swift` – App entry point.
- `myDay/Models.swift` – `ActivityCategory`, `TimeEntry` SwiftData model, and date helpers.
- `myDay/GridViewModel.swift` – Month‑based view model managing `TimeEntry` data and the days shown in the grid.
- `myDay/ContentView.swift` – Top‑level UI, including:
  - `TimeGridView` – main grid and month selector.
  - `DayRowView` / `TimeCellView` – individual rows and cells.
  - `DateLabelView` – pinned date column.
- `myDay/ActivityPickerSheet.swift` – bottom sheet for activity selection.
- `myDay/AnalyticsViewModel.swift` / `myDay/AnalyticsView.swift` – analytics screen.
- `myDay/SideMenuView.swift` – slide‑in side menu (currently exposes Analytics).
- `AGENTS.md` – guidance for AI agents working in this repo.

## Development

### Open in Xcode

```sh
open myDay.xcodeproj
# or
xed .
```

### Build for Simulator

Adjust the destination to a simulator that exists on your machine:

```sh
xcodebuild \
  -project myDay.xcodeproj \
  -scheme myDay \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### Run tests

Once you add a test target and attach it to the `myDay` scheme, you can run tests with:

```sh
xcodebuild \
  -project myDay.xcodeproj \
  -scheme myDay \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

If you create a test target named `myDayTests`, you can run a single test like:

```sh
xcodebuild \
  -project myDay.xcodeproj \
  -scheme myDay \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:myDayTests/SomeTestClass/testExample
```

At the time of writing there is no dedicated linting configuration (e.g. SwiftLint) in this repository. Add one and update this README if you introduce linting.
