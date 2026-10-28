import SwiftUI

/// Every task write goes through here so Hoy, Próximas, Listas and Inicio reload together.
struct TaskActions {
    let api: APIClient

    private func changed() {
        NotificationCenter.default.post(name: .tasksChanged, object: nil)
    }

    private func task(_ path: String, _ body: Patch? = nil) async throws {
        if let body {
            let _: Empty = try await api.post("v1/tasks/\(path)", body: body)
        } else {
            let _: Empty = try await api.post("v1/tasks/\(path)")
        }
        changed()
    }

    func complete(_ item: TaskItem) async throws { try await task("tasks/\(item.id)/complete") }
    func reopen(_ item: TaskItem) async throws { try await task("tasks/\(item.id)/reopen") }
    func skip(_ item: TaskItem) async throws { try await task("tasks/\(item.id)/skip") }

    func postpone(_ item: TaskItem, to date: Date) async throws {
        try await task("tasks/\(item.id)/postpone", Patch(["date": .string(CarliDate.isoDay(date))]))
    }

    func update(_ id: String, _ fields: [String: JSONValue]) async throws {
        let _: Empty = try await api.patch("v1/tasks/tasks/\(id)", body: Patch(fields))
        changed()
    }

    func create(_ fields: [String: JSONValue]) async throws {
        let _: Empty = try await api.post("v1/tasks/tasks", body: Patch(fields))
        changed()
    }

    func delete(_ item: TaskItem) async throws {
        try await api.delete("v1/tasks/tasks/\(item.id)")
        changed()
    }

    func setSubtask(_ item: TaskItem, _ subtask: Subtask, done: Bool) async throws {
        let _: Empty = try await api.patch("v1/tasks/tasks/\(item.id)/subtasks/\(subtask.id)", body: Patch(["done": .bool(done)]))
        changed()
    }

    func addSubtask(_ item: TaskItem, title: String) async throws {
        let _: Empty = try await api.post("v1/tasks/tasks/\(item.id)/subtasks", body: Patch(["title": .string(title)]))
        changed()
    }

    func deleteSubtask(_ item: TaskItem, _ subtask: Subtask) async throws {
        try await api.delete("v1/tasks/tasks/\(item.id)/subtasks/\(subtask.id)")
        changed()
    }

    func skipOccurrence(templateId: String, date: String) async throws {
        try await task("templates/\(templateId)/skip", Patch(["date": .string(date)]))
    }

    func unskipOccurrence(templateId: String, date: String) async throws {
        try await task("templates/\(templateId)/unskip", Patch(["date": .string(date)]))
    }

    func createList(_ name: String) async throws {
        let _: Empty = try await api.post("v1/tasks/lists", body: Patch(["name": .string(name)]))
        changed()
    }

    func updateList(_ id: String, _ fields: [String: JSONValue]) async throws {
        let _: Empty = try await api.patch("v1/tasks/lists/\(id)", body: Patch(fields))
        changed()
    }

    func reorderLists(_ ids: [String]) async throws {
        let _: Empty = try await api.put("v1/tasks/lists/order", body: Patch(["ids": .array(ids.map(JSONValue.string))]))
        changed()
    }

    func deleteList(_ id: String) async throws {
        try await api.delete("v1/tasks/lists/\(id)")
        changed()
    }
}

/// Round checkbox: ink ring, filled with a tick when done.
struct TaskCheck: View {
    var done: Bool
    var size: CGFloat = 24
    var label: String
    var toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .strokeBorder(done ? CarliColor.text : CarliColor.text3, lineWidth: 1.5)
                    .background(Circle().fill(done ? CarliColor.text : .clear))
                if done {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.5, weight: .bold))
                        .foregroundStyle(CarliColor.bg)
                }
            }
            .frame(width: size, height: size)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.success, trigger: done) { _, new in new }
        .accessibilityLabel(label)
    }
}

/// A task in a list: check, title, meta line, flag; swipe to postpone.
struct TaskRowView: View {
    enum DateStyle { case hidden, relative }

    var item: TaskItem
    var date: DateStyle = .hidden
    var showList = true
    var postponable = true
    var toggle: () -> Void
    var postpone: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CarliSpace.s4) {
            TaskCheck(done: item.isDone, label: item.isDone ? "Desmarcar \(item.title)" : "Marcar \(item.title) como hecha",
                      toggle: toggle)
                .padding(.top, -10)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .foregroundStyle(item.isDone ? CarliColor.text2 : CarliColor.text)
                    .strikethrough(item.isDone, color: CarliColor.text3)
                    .lineLimit(2)
                if !meta.isEmpty || item.isOverdue || item.repeats {
                    HStack(spacing: 4) {
                        if item.repeats {
                            Image(systemName: "repeat").font(.caption2).accessibilityLabel("Se repite")
                        }
                        if item.isOverdue, let due = item.dueDate.flatMap(CarliDate.day) {
                            Text(TaskDates.dueLabel(due)).fontWeight(.semibold).foregroundStyle(CarliColor.negative)
                            if !meta.isEmpty { Text("·") }
                        }
                        Text(meta).lineLimit(1)
                    }
                    .font(.footnote)
                    .foregroundStyle(CarliColor.text2)
                }
            }
            Spacer(minLength: CarliSpace.s8)
            if item.isImportant {
                Image(systemName: "flag.fill")
                    .font(.footnote)
                    .foregroundStyle(CarliColor.brandInk)
                    .accessibilityLabel("Importante")
            }
        }
        .padding(.vertical, CarliSpace.s4)
        .contentShape(.rect)
        .swipeActions(edge: .trailing) {
            if postponable && item.isOpen {
                Button("Posponer", systemImage: "calendar", action: postpone).tint(CarliColor.warning)
            }
        }
    }

    private var meta: String {
        var parts: [String] = []
        if date == .relative, let due = item.dueDate.flatMap(CarliDate.day), !item.isOverdue { parts.append(TaskDates.dueLabel(due)) }
        if showList, let list = item.list?.name { parts.append(list) }
        if let time = item.dueTime { parts.append(time) }
        if !item.steps.isEmpty { parts.append("\(item.stepsDone)/\(item.steps.count)") }
        return parts.joined(separator: " · ")
    }
}

/// Postpone choices: quick dates, or a calendar.
struct PostponeSheet: View {
    var from: Date?
    var includeToday: Bool
    var pick: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var custom = Date.now
    @State private var choosing = false

    var body: some View {
        NavigationStack {
            List {
                ForEach([QuickDate.today, .tomorrow, .weekend, .nextWeek].filter { $0 != .today || includeToday }) { option in
                    if let date = option.resolve() {
                        Button {
                            pick(date)
                            dismiss()
                        } label: {
                            LabeledContent {
                                Text(TaskDates.weekdayShort(date))
                            } label: {
                                Label(option.label, systemImage: option == .today ? "sun.max" : "calendar")
                            }
                        }
                        .foregroundStyle(CarliColor.text)
                    }
                }
                Section {
                    DatePicker("Elegir fecha", selection: $custom, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    Button("Posponer a \(TaskDates.weekdayShort(custom))") {
                        pick(custom)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Posponer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { custom = from ?? .now }
    }
}
