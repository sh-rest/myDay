import SwiftUI
import SwiftData

// Allow URL to be used with `.sheet(item:)` in SwiftUI.
extension URL: Identifiable {
    public var id: String { absoluteString }
}

struct SideMenuView: View {
    let onSelectAnalytics: () -> Void

    @Environment(\.modelContext) private var modelContext

    @Query(sort: [
        SortDescriptor(\TimeEntry.date),
        SortDescriptor(\TimeEntry.hour)
    ])
    private var timeEntries: [TimeEntry]

    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var exportFile: ExportFile?
    @State private var showImportPicker = false
    @State private var importAlert: ImportAlert?

    struct ImportAlert: Identifiable {
        let id = UUID()
        let message: String
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Button(action: {
                onSelectAnalytics()
            }) {
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
                    exportFile = ExportFile(url: url)
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
        .fileImporter(
            isPresented: $showImportPicker,
            allowedContentTypes: [.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    let r = try CSVImporter.importTimeEntries(from: url, context: modelContext)
                    importAlert = ImportAlert(message: "Imported \(r.inserted) new + \(r.updated) updated entries.")
                } catch {
                    importAlert = ImportAlert(message: "Import failed: \(error.localizedDescription)")
                }
            case .failure(let error):
                importAlert = ImportAlert(message: "Could not open file: \(error.localizedDescription)")
            }
        }
        .alert(item: $importAlert) { alert in
            Alert(title: Text("CSV Import"), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $exportFile) { file in
            ShareLink(
                item: file.url,
                preview: SharePreview(
                    "myDay Data Export",
                    image: Image(systemName: "tablecells")
                )
            )
        }
    }
}

#Preview {
    SideMenuView(onSelectAnalytics: {})
}
