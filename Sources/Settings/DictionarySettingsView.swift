import SwiftUI

struct DictionarySettingsView: View {
    @State private var userEntries: [DictionaryEntry] = []
    @State private var newFrom = ""
    @State private var newTo = ""
    @State private var editingEntry: DictionaryEntry?
    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsSectionContainer(title: "System Dictionary") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built-in corrections for common ASR recognition errors.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("AIGC, LLM, API, vibe coding, sub-agents, etc.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            SettingsSectionContainer(title: "User Dictionary") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Custom corrections")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Button {
                            showAddSheet = true
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }

                    if userEntries.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "text.book.closed")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                            Text("No custom entries")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Add words that ASR often misrecognizes")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else {
                        ForEach(userEntries, id: \.self) { entry in
                            HStack {
                                Text(entry.from)
                                    .foregroundStyle(.secondary)
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                Text(entry.to)
                                Spacer()
                                Button {
                                    deleteEntry(entry)
                                } label: {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .font(.system(size: 13))
                            Divider()
                        }
                    }
                }
            }

            Spacer()
        }
        .onAppear {
            loadEntries()
        }
        .sheet(isPresented: $showAddSheet) {
            AddDictionaryEntrySheet(
                from: $newFrom,
                to: $newTo,
                onAdd: addEntry
            )
        }
    }

    private func loadEntries() {
        userEntries = TextDictionaries.loadUserDictionary()
    }

    private func addEntry() {
        let from = newFrom.trimmingCharacters(in: .whitespacesAndNewlines)
        let to = newTo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !from.isEmpty, !to.isEmpty else { return }

        let entry = DictionaryEntry(from: from, to: to)
        if !userEntries.contains(entry) {
            userEntries.append(entry)
            TextDictionaries.saveUserDictionary(userEntries)
        }
        newFrom = ""
        newTo = ""
        showAddSheet = false
    }

    private func deleteEntry(_ entry: DictionaryEntry) {
        userEntries.removeAll { $0 == entry }
        TextDictionaries.saveUserDictionary(userEntries)
    }
}

struct AddDictionaryEntrySheet: View {
    @Binding var from: String
    @Binding var to: String
    let onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Dictionary Entry")
                .font(.headline)

            Form {
                TextField("ASR output (incorrect)", text: $from)
                TextField("Correct text", text: $to)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Add") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(from.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    to.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
