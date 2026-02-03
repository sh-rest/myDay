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

    @State private var showingPicker = false
    @State private var selectedDate: Date? = nil
    @State private var selectedHour: Int? = nil
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
                            // Shared horizontal scroll for all rows
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 8) {
                                    ForEach(dates, id: \.self) { day in
                                        HStack(alignment: .top, spacing: 8) {
                                            // Reserved space for the overlaid date label
                                            Color.clear
                                                .frame(
                                                    width: DateLabelView.columnWidth,
                                                    height: GridMetrics.cellSize
                                                )

                                            DayRowView(
                                                date: day,
                                                viewModel: viewModel
                                            ) { d, h in
                                                selectedDate = d
                                                selectedHour = h
                                                showingPicker = true
                                            }
                                        }
                                        .id(day)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.trailing, 8)
                            }

                            // Pinned date column
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(dates, id: \.self) { day in
                                    DateLabelView(date: day)
                                        .id(day)
                                }
                            }
                            .padding(.vertical, 8)
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
                Button("Legend") {
                    withAnimation(.easeInOut) {
                        isLegendVisible.toggle()
                    }
                }
            }
        }
        .onAppear {
            viewModel.reloadMonth()
            hasScrolledToInitialDate = false
        }
        .sheet(isPresented: $showingPicker) {
            if let d = selectedDate, let h = selectedHour {
                ActivityPickerSheet(date: d, hour: h) { category in
                    viewModel.set(category: category, for: d, hour: h)
                    if h < 23 {
                        selectedHour = h + 1
                    } else {
                        showingPicker = false
                    }
                }
                .presentationDetents([.medium, .large])
            }
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

private enum GridMetrics {
    static let cellSize: CGFloat = 36
}

struct DateLabelView: View {
    static let columnWidth: CGFloat = 100

    let date: Date

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }()

    var body: some View {
        Text(DateLabelView.dateFormatter.string(from: date))
            .font(.caption)
            .frame(
                width: DateLabelView.columnWidth,
                height: GridMetrics.cellSize,
                alignment: .leading
            )
            .background(Color(.systemBackground))
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
        let bg = entry?.category.color ?? Color.gray.opacity(0.2)
        Rectangle()
            .fill(bg)
            .frame(width: size, height: size)
            .cornerRadius(6)
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

