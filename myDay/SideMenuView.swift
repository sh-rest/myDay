import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Wrapper to use URL with `.sheet(item:)` without extending imported types.
private struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SideMenuView: View {
    let onSelectAnalytics: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\TimeEntry.date),
        SortDescriptor(\TimeEntry.hour)
    ])
    private var timeEntries: [TimeEntry]

    // Export
    @State private var exportFile: IdentifiableURL?

    // Import — step 1: file picker
    @State private var showImportPicker = false

    // Import — step 2: date range sheet
    @State private var pendingImportURL: URL?
    @State private var importFromDate: Date = Date().startOfDay
    @State private var importToDate: Date = Date().startOfDay

    // Result alert
    @State private var importAlert: ImportAlert?

    struct ImportAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: onSelectAnalytics) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                    Text("View Analytics")
                        .font(.headline)
                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Button {
                do {
                    let url = try CSVExporter.exportTimeEntries(timeEntries)
                    exportFile = IdentifiableURL(url: url)
                } catch {
                    print("CSV export failed:", error)
                }
            } label: {
                Label("Export CSV", systemImage: "square.and.arrow.up")
            }

            Button {
                showImportPicker = true
            } label: {
                Label("Import CSV", systemImage: "square.and.arrow.down")
            }

            Spacer()
        }
        .padding(.top, 32)
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.ultraThinMaterial)

        // Step 1 — pick file
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                // Scan the file for its available date range, then surface the picker
                if let range = try? CSVImporter.availableDateRange(in: url) {
                    importFromDate = range.from
                    importToDate   = range.to
                } else {
                    importFromDate = Date().startOfDay
                    importToDate   = Date().startOfDay
                }
                pendingImportURL = url
            case .failure(let error):
                importAlert = ImportAlert(message: "Could not open file: \(error.localizedDescription)")
            }
        }

        // Step 2 — choose date range (Cancel discards the import entirely)
        .sheet(item: $pendingImportURL) { item in
            DateRangePickerSheet(
                fromDate: $importFromDate,
                toDate: $importToDate
            ) {
                // Confirmed — run import
                pendingImportURL = nil
                do {
                    try CSVExporter.backupTimeEntries(timeEntries)
                    let range = importFromDate.startOfDay...importToDate.startOfDay
                    let r = try CSVImporter.importTimeEntries(from: item, context: modelContext,
                                                              dateRange: range)
                    importAlert = ImportAlert(
                        message: "Imported \(r.inserted) new + \(r.updated) updated entries.\nBackup saved to Files → myDay."
                    )
                } catch {
                    importAlert = ImportAlert(message: "Import failed: \(error.localizedDescription)")
                }
            } onCancel: {
                pendingImportURL = nil
            }
        }

        .alert(item: $importAlert) { alert in
            Alert(title: Text("CSV Import"), message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }

        // Export share sheet
        .sheet(item: $exportFile) { item in
            ShareLink(
                item: item.url,
                preview: SharePreview("myDay Data Export", image: Image(systemName: "tablecells"))
            )
        }
    }
}

// MARK: - Date range picker sheet

private struct DateRangePickerSheet: View {
    @Binding var fromDate: Date
    @Binding var toDate: Date
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Import range") {
                    DatePicker("From", selection: $fromDate, displayedComponents: .date)
                    DatePicker("To",   selection: $toDate,   in: fromDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("Select Date Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel, action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import", action: onConfirm)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// Make URL work with `.sheet(item:)` via a local conformance.
extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    SideMenuView(onSelectAnalytics: {})
}
