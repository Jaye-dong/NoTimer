import SwiftUI

/// 手动编辑或新建一条时间记录。保存会置 `syncState = pendingPush`，让 SyncEngine 后续推到 Notion。
/// 新建记录没有 `notionPageId`，push 时走 POST；删除走 tombstone → archive。
struct TimeRecordEditView: View {
    enum Mode: Equatable {
        case edit(TimeRecord)
        case create
    }

    @Environment(AppDependencies.self) private var deps
    @Environment(\.dismiss) private var dismiss

    let mode: Mode

    @State private var title: String = ""
    @State private var startAt: Date = Date()
    @State private var endAt: Date = Date()
    @State private var endAtEnabled: Bool = true
    @State private var category: String?
    @State private var nextActionPageId: String?
    @State private var categoryOptions: [SelectOption] = []
    @State private var nextActions: [NextAction] = []
    @State private var errorMessage: String?
    @State private var showDeleteConfirm: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                titleSection
                timeSection
                categorySection
                nextActionSection
                if case .edit = mode {
                    deleteSection
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(mode.isEdit ? "编辑记录" : "补录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!isValid)
                }
            }
        }
        .task { load() }
        .confirmationDialog("删除这条记录？", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("删除", role: .destructive) { performDelete() }
            Button("取消", role: .cancel) { }
        } message: {
            Text("会从 Notion 里归档。")
        }
    }

    // MARK: - Sections

    private var titleSection: some View {
        Section("标题") {
            TextField("例如：写代码", text: $title)
                .textInputAutocapitalization(.never)
        }
    }

    private var timeSection: some View {
        Section("时间") {
            DatePicker("开始", selection: $startAt)
            Toggle("已结束", isOn: $endAtEnabled)
            if endAtEnabled {
                DatePicker("结束", selection: $endAt, in: startAt...)
            }
        }
    }

    private var categorySection: some View {
        Section("分类") {
            Picker("分类", selection: $category) {
                Text("未分类").tag(String?.none)
                ForEach(categoryOptions, id: \.name) { opt in
                    Text(opt.name).tag(String?.some(opt.name))
                }
            }
        }
    }

    private var nextActionSection: some View {
        Section("下一步行动") {
            Picker("下一步行动", selection: $nextActionPageId) {
                Text("无").tag(String?.none)
                ForEach(nextActions) { action in
                    if let pageId = action.notionPageId {
                        Text(action.title.isEmpty ? "（无标题）" : action.title)
                            .tag(String?.some(pageId))
                    }
                }
            }
        }
    }

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("删除记录", systemImage: "trash")
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Derived

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        if endAtEnabled && endAt < startAt { return false }
        return true
    }

    // MARK: - Actions

    private func load() {
        categoryOptions = (try? deps.selectOptions.options(
            kind: .timeRecords,
            property: NotionFieldNames.TimeRecord.category
        )) ?? []

        nextActions = ((try? deps.nextActions.all()) ?? []).filter { $0.notionPageId != nil }

        if case let .edit(record) = mode {
            title = record.title
            startAt = record.startAt
            if let end = record.endAt {
                endAt = end
                endAtEnabled = true
            } else {
                endAt = Date()
                endAtEnabled = false
            }
            category = record.category
            nextActionPageId = record.nextActionPageId
        } else {
            let now = Date()
            startAt = Calendar.current.date(byAdding: .hour, value: -1, to: now) ?? now
            endAt = now
        }
    }

    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let effectiveEnd: Date? = endAtEnabled ? endAt : nil

        do {
            switch mode {
            case let .edit(record):
                var updated = record
                updated.title = trimmed
                updated.startAt = startAt
                updated.endAt = effectiveEnd
                updated.category = category
                updated.nextActionPageId = nextActionPageId
                try deps.timeRecords.update(updated)
            case .create:
                var record = TimeRecord.new(
                    title: trimmed,
                    startAt: startAt,
                    nextActionPageId: nextActionPageId,
                    category: category
                )
                record.endAt = effectiveEnd
                try deps.timeRecords.insert(record)
            }
            Task { await deps.syncEngine.pushOnly() }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performDelete() {
        guard case let .edit(record) = mode else { return }
        do {
            try deps.timeRecords.delete(id: record.id)
            Task { await deps.syncEngine.pushOnly() }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension TimeRecordEditView.Mode {
    var isEdit: Bool {
        if case .edit = self { return true }
        return false
    }
}
