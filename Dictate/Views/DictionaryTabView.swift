import SwiftUI

struct DictionaryTabView: View {
    let dictionaryService: DictionaryService
    @State private var entries: [DictionaryEntry] = []
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var editingEntry: DictionaryEntry?
    @State private var newReading = ""
    @State private var newWord = ""

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search dictionary...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        refreshEntries(query: newValue)
                    }

                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
            .padding(8)

            Divider()

            // Entries list
            if entries.isEmpty {
                ContentUnavailableView("No Entries", systemImage: "book", description: Text("Add words to improve transcription accuracy"))
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.word).font(.headline)
                                Text(entry.reading).font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(entry.usageCount)x")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(entry.category.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(entry.category == .auto ? Color.blue.opacity(0.2) : Color.green.opacity(0.2)))
                        }
                        .contextMenu {
                            Button("Edit") { editingEntry = entry }
                            Button("Delete", role: .destructive) {
                                _ = dictionaryService.deleteEntry(id: entry.id)
                                refreshEntries(query: searchText)
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            addEntrySheet
        }
        .sheet(item: $editingEntry) { entry in
            editEntrySheet(entry)
        }
        .onAppear { refreshEntries(query: "") }
    }

    private var addEntrySheet: some View {
        VStack(spacing: 16) {
            Text("Add Dictionary Entry").font(.headline)
            TextField("Reading (ひらがな)", text: $newReading)
                .textFieldStyle(.roundedBorder)
            TextField("Word (変換後)", text: $newWord)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { showAddSheet = false; newReading = ""; newWord = "" }
                Spacer()
                Button("Add") {
                    _ = try? dictionaryService.addEntry(reading: newReading, word: newWord, category: .manual)
                    refreshEntries(query: searchText)
                    showAddSheet = false
                    newReading = ""
                    newWord = ""
                }
                .disabled(newReading.isEmpty || newWord.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }

    private func editEntrySheet(_ entry: DictionaryEntry) -> some View {
        EditEntrySheet(entry: entry, dictionaryService: dictionaryService) {
            refreshEntries(query: searchText)
            editingEntry = nil
        }
    }

    private func refreshEntries(query: String) {
        if query.isEmpty {
            entries = dictionaryService.getAll()
        } else {
            entries = dictionaryService.search(query: query)
        }
    }
}

private struct EditEntrySheet: View {
    let entry: DictionaryEntry
    let dictionaryService: DictionaryService
    let onDone: () -> Void
    @State private var reading: String
    @State private var word: String

    init(entry: DictionaryEntry, dictionaryService: DictionaryService, onDone: @escaping () -> Void) {
        self.entry = entry
        self.dictionaryService = dictionaryService
        self.onDone = onDone
        _reading = State(initialValue: entry.reading)
        _word = State(initialValue: entry.word)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Entry").font(.headline)
            TextField("Reading", text: $reading).textFieldStyle(.roundedBorder)
            TextField("Word", text: $word).textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { onDone() }
                Spacer()
                Button("Save") {
                    _ = dictionaryService.updateEntry(id: entry.id, reading: reading, word: word)
                    onDone()
                }
                .disabled(reading.isEmpty || word.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
}
