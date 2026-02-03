//
//  ContentView.swift
//  myDay
//
//  Created by Shresth Jain on 03/02/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TimeGridView()
        }
    }
}

// MARK: - TimeGridView
struct TimeGridView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var viewModel: GridViewModel

    @State private var showingPicker = false
    @State private var selectedDate: Date? = nil
    @State private var selectedHour: Int? = nil
    @State private var isLegendVisible = false
    @State private var isMenuOpen = false
    @State private var isShowingAnalytics = false

    init() {
        // We'll initialize with a temporary empty container, and then swap in onAppear.
        let temp = ModelContext(try! ModelContainer(for: TimeEntry.self))
        _viewModel = StateObject(wrappedValue: GridViewModel(context: temp))
    }

    var body: some View {
        let _ = updateViewModelContextIfNeeded()
        let dates = viewModel.datesInRange(start: viewModel.visibleStartDate, end: viewModel.visibleEndDate)

        ZStack(alignment: .leading) {
            VStack(spacing: 0) {
                if isLegendVisible {
                    LegendView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                ScrollView {
                    // We overlay a pinned date column on top of a single shared
                    // horizontally scrolling grid. Dates do not move horizontally,
                    // but rows stay visually aligned because we reserve leading space
                    // in the grid equal to the date column width.
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

                        // Pinned date column, vertically aligned with the grid rows
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(dates, id: \.self) { day in
                                DateLabelView(date: day)
                                    .id(day)
                            }
                        }
                        .padding(.vertical, 8)
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
                    withAnimation(.spring()) {
                        isLegendVisible.toggle()
                    }
                }
            }
        }
        .onAppear {
            viewModel.updateVisibleRange(start: viewModel.visibleStartDate, end: viewModel.visibleEndDate)
        }
        .sheet(isPresented: $showingPicker) {
            if let d = selectedDate, let h = selectedHour {
                ActivityPickerSheet(date: d, hour: h) { category in
                    // Save/update
                    viewModel.set(category: category, for: d, hour: h)
                    // Advance hour or dismiss
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
    private func updateViewModelContextIfNeeded() -> Bool { true }
}

// MARK: - DateLabelView
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
