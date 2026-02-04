//
//  ContentView.swift
//  myDay
//
//  Created by Shresth Jain on 03/02/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            TimeGridView(context: context)
        }
    }
}


// MARK: - TimeGridView
struct TimeGridView: View {
    private let context: ModelContext
    @StateObject private var viewModel: GridViewModel

    init(context: ModelContext) {
        self.context = context
        _viewModel = StateObject(wrappedValue: GridViewModel(context: context))
    }

    @State private var activeSlot: SelectedSlot = SelectedSlot(date: Date(), hour: 0)
    @State private var isShowingPicker: Bool = false
    @State private var isLegendVisible = false
    @State private var isMenuOpen = false
    @State private var isShowingAnalytics = false

    @State private var isMonthSelectorExpanded = false
    @State private var hasScrolledToInitialDate = false
    

    var body: some View {
        let dates = viewModel.daysInSelectedMonth

        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                if isLegendVisible {
                    LegendView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                monthSelector

                ScrollViewReader { proxy in
                    ScrollView {
                        ZStack(alignment: .topLeading) {

                            // MARK: - Shared horizontal scroll (hours + rows)
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 8) {

                                    // Hour header row (pinned vertically)
                                    HStack(spacing: GridMetrics.cellSpacing) {
                                        // Space for date column
                                        Color.clear
                                            .frame(width: DateLabelView.columnWidth)

                                        ForEach(0..<24, id: \.self) { hour in
                                            Text(hourFormatter(hour))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .frame(
                                                    width: GridMetrics.cellSize - 2,
                                                    height: GridMetrics.headerHeight,
                                                    alignment: .center
                                                )
                                        }
                                    }
                                    .padding(.bottom, 4)

                                    // Day rows
                                    ForEach(dates, id: \.self) { day in
                                        HStack(alignment: .top, spacing: 8) {

                                            // Reserved space for pinned date column
                                            Color.clear
                                                .frame(
                                                    width: DateLabelView.columnWidth,
                                                    height: GridMetrics.cellSize
                                                )

                                            DayRowView(
                                                date: day,
                                                viewModel: viewModel
                                            ) { d, h in
                                                activeSlot = SelectedSlot(date: d, hour: h)
                                                isShowingPicker = true
                                            }
                                        }
                                        .id(day)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.trailing, 16)
                            }

                            // MARK: - Pinned date column (left)
                            ZStack(alignment: .topLeading) {
                                // Full-height background for the entire pinned column area including left inset
                                Rectangle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: DateLabelView.columnWidth)
                                    .ignoresSafeArea(edges: .vertical)

                                // Column content
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    // Spacer to align below hour header
                                    Color.clear
                                        .frame(height: GridMetrics.headerHeight)

                                    ForEach(dates, id: \.self) { day in
                                        DateLabelView(
                                            date: day,
                                            isToday: Calendar.current.isDate(day, inSameDayAs: viewModel.today)
                                        )
                                        .id(day)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
//                            .padding(.top, 15)
                        }
                    }
                    .onAppear {
                        guard !hasScrolledToInitialDate,
                              dates.contains(viewModel.today) else { return }
                        hasScrolledToInitialDate = true
                        proxy.scrollTo(viewModel.today, anchor: .center)
                    }
                }

            }

            if isMenuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea(edges: .bottom)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isMenuOpen = false
                        }
                    }

                SideMenuView(onSelectAnalytics: {
                    withAnimation(.spring()) {
                        isMenuOpen = false
                    }
                    isShowingAnalytics = true
                })
                .frame(width: 260)
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
        }
        .navigationDestination(isPresented: $isShowingAnalytics) {
            AnalyticsView(context: context)
        }
.navigationTitle("myDay")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    withAnimation(.spring()) {
                        isMenuOpen.toggle()
                    }
                }) {
                    Image(systemName: "line.3.horizontal")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("?") {
                    withAnimation(.easeInOut) {
                        isLegendVisible.toggle()
                    }
                }
            }
        }
        .onAppear {
            hasScrolledToInitialDate = false
        }
        
        // Present
        
        .sheet(isPresented: $isShowingPicker) {
            ActivityPickerSheet(date: activeSlot.date, hour: activeSlot.hour) { category in
                viewModel.set(category: category, for: activeSlot.date, hour: activeSlot.hour)
                if activeSlot.hour < 23 {
                    // Advance to the next hour in the same day without dismissing the sheet
                    activeSlot = SelectedSlot(date: activeSlot.date, hour: activeSlot.hour + 1)
                } else {
                    // Last hour of the day – dismiss the sheet
                    isShowingPicker = false
                }
            }
            .presentationDetents([.medium, .large])
        }
        
    }

    // MARK: - Month selector

    private var monthSelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isMonthSelectorExpanded.toggle()
                }
            }) {
                HStack {
                    Text(monthYearTitle)
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Image(systemName: isMonthSelectorExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }

            if isMonthSelectorExpanded {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    .overlay(
                        HStack(spacing: 16) {
                            Picker(
                                "Month",
                                selection: $viewModel.selectedMonth
                            ) {
                                ForEach(1...12, id: \.self) { month in
                                    Text(monthSymbol(for: month))
                                        .tag(month)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .pickerStyle(.wheel)

                            Picker(
                                "Year",
                                selection: $viewModel.selectedYear
                            ) {
                                ForEach(allowedYears, id: \.self) { year in
                                    Text(String(year))
                                        .tag(year)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .pickerStyle(.wheel)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
    }
    private func monthSymbol(for month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1]
    }
    
    private var allowedYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((currentYear - 10)...(currentYear + 10))
    }

    private var monthYearTitle: String {
        var comps = DateComponents()
        comps.year = viewModel.selectedYear
        comps.month = viewModel.selectedMonth
        comps.day = 1
        let cal = Calendar.current
        let date = cal.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting grid types

/// Identifies a specific (date, hour) slot in the grid for sheet presentation.
private struct SelectedSlot: Identifiable, Equatable {
    let date: Date
    let hour: Int

    // Use date + hour as a stable identity so the same slot reuses the sheet when advanced.
    var id: String { "\(date.timeIntervalSince1970)-\(hour)" }
}

private enum GridMetrics {
    static let cellSize: CGFloat = 36
    static let cellSpacing: CGFloat = 6
    static let headerHeight: CGFloat = 20
}

private func hourFormatter(_ hour: Int) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "ha"
    let date = Calendar.current.date(
        bySettingHour: hour,
        minute: 0,
        second: 0,
        of: Date()
    )!
    return formatter.string(from: date)
}

struct DateLabelView: View {
    static let columnWidth: CGFloat = 80

    let date: Date
    var isToday: Bool = false

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()

    var body: some View {
        let labelText = Text(DateLabelView.dateFormatter.string(from: date))
            .font(.caption)
            .fontWeight(isToday ? .semibold : .regular)
            .foregroundStyle(isToday ? .primary : .secondary)
            .multilineTextAlignment(.center)

        ZStack {
            // Background capsule spanning the full width of the date column
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isToday ? Color(.tertiarySystemBackground) : Color.clear)

            // Centered label with symmetric horizontal padding
            labelText
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(
            width: DateLabelView.columnWidth,
            height: GridMetrics.cellSize,
            alignment: .center
        )
    }
}

// MARK: - DayRowView
/// A single row of hour tiles for a given day.
/// Horizontal scrolling is handled by the parent; this view only lays out cells.
struct DayRowView: View {
    let date: Date
    @ObservedObject var viewModel: GridViewModel
    let onTapCell: (Date, Int) -> Void

    private let hourRange = Array(0...23)

    var body: some View {
        LazyHStack(spacing: 4) {
            ForEach(hourRange, id: \.self) { hour in
                TimeCellView(
                    date: date,
                    hour: hour,
                    entry: viewModel.entry(for: date, hour: hour)
                ) {
                    onTapCell(date, hour)
                }
            }
        }
    }
}

// MARK: - TimeCellView
struct TimeCellView: View {
    let date: Date
    let hour: Int
    let entry: TimeEntry?
    let onTap: () -> Void

    private var size: CGFloat { GridMetrics.cellSize } // fixed square size

    var body: some View {
        let isFilled = entry != nil

        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .overlay {
                if let entry = entry {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(entry.category.color.opacity(0.75))
                        .padding(4)
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(.quaternaryLabel), lineWidth: 0.5)
                        .padding(4)
                }
            }
            .frame(width: size, height: size)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .onTapGesture { onTap() }
            .accessibilityLabel(Text(accessibilityDescription))
    }

    private var accessibilityDescription: String {
        let hourLabel = String(format: "%02d:00", hour)
        if let entry = entry {
            return "\(hourLabel) - \(entry.category.displayName)"
        } else {
            return "\(hourLabel) - empty"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimeEntry.self, inMemory: true)
}

