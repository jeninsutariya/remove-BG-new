import SwiftUI
import SwiftData

struct MoodOption: Identifiable {
    let value: Int
    let label: String
    let symbol: String
    var id: Int { value }

    static let all = [
        MoodOption(value: 1, label: "Awful", symbol: "cloud.heavyrain"),
        MoodOption(value: 2, label: "Low", symbol: "cloud"),
        MoodOption(value: 3, label: "Okay", symbol: "cloud.sun"),
        MoodOption(value: 4, label: "Good", symbol: "sun.max"),
        MoodOption(value: 5, label: "Great", symbol: "sparkles"),
    ]

    static func label(for value: Int) -> String {
        all.first { $0.value == value }?.label ?? ""
    }
}

/// S16. Mood, sleep or gratitude, with optional tags and a note.
struct CheckInView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var kind: CheckInKind = .mood
    @State private var value: Int?
    @State private var tags: Set<String> = []
    @State private var note = ""

    private let tagOptions = ["Work", "Sleep", "Family", "Friends", "Health", "Money", "Exercise", "Weather"]

    private var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        kind == .gratitude ? !trimmedNote.isEmpty : value != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Picker("Type", selection: $kind) {
                        ForEach(CheckInKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Text(kind.prompt)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.text)

                    if kind != .gratitude {
                        HStack(spacing: 8) {
                            ForEach(MoodOption.all) { option in
                                Button {
                                    value = option.value
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: option.symbol).font(.title2)
                                        Text(option.label).font(.caption)
                                    }
                                    .foregroundStyle(value == option.value ? Theme.accent : Theme.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        value == option.value ? Theme.accent.opacity(0.18) : Theme.surface,
                                        in: RoundedRectangle(cornerRadius: Theme.Radius.small)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.label)
                                .accessibilityAddTraits(value == option.value ? .isSelected : [])
                            }
                        }

                        Text("What's affecting it?")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        FlowLayout(spacing: 8) {
                            ForEach(tagOptions, id: \.self) { tag in
                                Chip(title: tag, isSelected: tags.contains(tag)) {
                                    if tags.contains(tag) { tags.remove(tag) } else { tags.insert(tag) }
                                }
                            }
                        }
                    }

                    Text(kind == .gratitude ? "I'm grateful for…" : "Anything else? (optional)")
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    TextField("Write a few words", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.small))

                    Button("Save", action: save)
                        .buttonStyle(.primary)
                        .disabled(!canSave)
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Check in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: kind) {
                value = nil
                tags = []
            }
        }
    }

    private func save() {
        context.insert(CheckInRecord(
            kind: kind,
            value: kind == .gratitude ? 0 : (value ?? 0),
            tags: kind == .gratitude ? [] : tags.sorted(),
            note: trimmedNote
        ))
        try? context.save()
        dismiss()
    }
}

/// S18.
struct CheckInHistoryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \CheckInRecord.createdAt, order: .reverse) private var checkIns: [CheckInRecord]

    var body: some View {
        Group {
            if checkIns.isEmpty {
                ContentUnavailableView(
                    "No check-ins yet",
                    systemImage: "face.smiling",
                    description: Text("Check in from the Home tab to see how you've been feeling.")
                )
            } else {
                List {
                    ForEach(checkIns) { checkIn in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(checkIn.kind.title).font(.headline)
                                if checkIn.kind != .gratitude {
                                    Text(MoodOption.label(for: checkIn.value)).foregroundStyle(Theme.accent)
                                }
                                Spacer()
                                Text(checkIn.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            if !checkIn.tags.isEmpty {
                                Text(checkIn.tags.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textMuted)
                            }
                            if !checkIn.note.isEmpty {
                                Text(checkIn.note).font(.subheadline)
                            }
                        }
                        .foregroundStyle(Theme.text)
                        .padding(.vertical, 4)
                        .listRowBackground(Theme.surface)
                    }
                    .onDelete { offsets in
                        for index in offsets { context.delete(checkIns[index]) }
                        try? context.save()
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Check-ins")
    }
}
