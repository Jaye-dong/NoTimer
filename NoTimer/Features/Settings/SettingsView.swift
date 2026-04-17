import SwiftUI

struct SettingsView: View {
    @Environment(AppDependencies.self) private var deps
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    form(viewModel: viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("设置")
        }
        .task {
            if viewModel == nil {
                viewModel = SettingsViewModel(
                    auth: deps.notionAuth,
                    client: deps.notionClient,
                    pull: deps.pullStrategy
                )
            }
        }
    }

    @ViewBuilder
    private func form(viewModel: SettingsViewModel) -> some View {
        @Bindable var vm = viewModel

        Form {
            Section {
                SecureField("paste 以 secret_ 或 ntn_ 开头", text: $vm.tokenInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if deps.notionAuth.hasToken {
                    Button("清除 Token", role: .destructive) { vm.clearToken() }
                }
            } header: {
                Text("Integration Token")
            } footer: {
                Text("在 notion.so/profile/integrations 创建 Internal Integration，复制 Secret 粘贴到这里。Token 将保存在 iOS Keychain。")
            }

            Section("时间记录数据库") {
                TextField("粘贴 Notion 页面链接或 32 位 ID", text: $vm.timeRecordsInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("下一步行动数据库") {
                TextField("粘贴 Notion 页面链接或 32 位 ID", text: $vm.nextActionsInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section {
                Button {
                    Task { await vm.validate() }
                } label: {
                    HStack {
                        Text("验证连接")
                        Spacer()
                        if case .checking = vm.state {
                            ProgressView()
                        }
                    }
                }
                .disabled(!vm.canValidate || vm.state == .checking)
            }

            statusSection(state: vm.state)

            Section("数据同步") {
                Button {
                    Task { await vm.syncNow() }
                } label: {
                    HStack {
                        Text("立即从 Notion 拉取")
                        Spacer()
                        if vm.syncState == .running {
                            ProgressView()
                        }
                    }
                }
                .disabled(!vm.canSync)

                syncStatusRow(state: vm.syncState)
            }

            Section("指引") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. 创建 Internal Integration 并复制 Secret")
                    Text("2. 在每个数据库页面 ··· → Connections → 添加这个 Integration")
                    Text("3. 粘贴数据库 URL，点击验证连接")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func syncStatusRow(state: SettingsViewModel.SyncState) -> some View {
        switch state {
        case .idle:
            EmptyView()
        case .running:
            Text("正在拉取…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .success(let timeRecords, let nextActions, let finishedAt):
            VStack(alignment: .leading, spacing: 4) {
                Label("拉取成功", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("时间记录 \(timeRecords) 条 · 下一步行动 \(nextActions) 条")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(finishedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .failure(let msg):
            VStack(alignment: .leading, spacing: 4) {
                Label("拉取失败", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
                Text(msg)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func statusSection(state: SettingsViewModel.ValidationState) -> some View {
        switch state {
        case .idle, .checking:
            EmptyView()
        case .success(let timeTitle, let actionsTitle):
            Section("连接成功") {
                Label(timeTitle, systemImage: "clock")
                Label(actionsTitle, systemImage: "checklist")
            }
        case .failure(let message):
            Section("连接失败") {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environment(AppDependencies.bootstrap())
}
