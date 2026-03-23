import SwiftUI

struct HistoryTabView: View {
    let historyService: HistoryService
    @State private var entries: [TranscriptionHistoryEntry] = []
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search history...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        refreshEntries(query: newValue)
                    }

                if !entries.isEmpty {
                    Button("Clear All", role: .destructive) {
                        historyService.deleteAll()
                        refreshEntries(query: searchText)
                    }
                    .foregroundColor(.red)
                }
            }
            .padding(8)

            Divider()

            if entries.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Transcription history will appear here"))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.formattedText)
                                .font(.body)
                                .lineLimit(3)
                            if entry.originalText != entry.formattedText {
                                Text(entry.originalText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Text(entry.createdAt, style: .relative)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .contextMenu {
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(entry.formattedText, forType: .string)
                            }
                            Button("Delete", role: .destructive) {
                                _ = historyService.deleteEntry(id: entry.id)
                                refreshEntries(query: searchText)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { refreshEntries(query: "") }
    }

    private func refreshEntries(query: String) {
        if query.isEmpty {
            entries = historyService.getAll()
        } else {
            entries = historyService.search(query: query)
        }
    }
}
