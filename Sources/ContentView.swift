import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ClipboardModel
    let returnDraft: (String) -> Void

    @State private var showSettings = false
    @State private var showHelp = false
    @State private var showServiceSetup = false
    @State private var serviceKey = ""
    @State private var showDeleteConfirmation = false

    private let ink = Color(red: 0.16, green: 0.13, blue: 0.25)
    private let violet = Color(red: 0.47, green: 0.28, blue: 0.91)
    private let orange = Color(red: 0.96, green: 0.43, blue: 0.18)

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            header
            Divider()

            projectStage
                .frame(maxHeight: .infinity, alignment: .top)

            statusLine
            Divider()
            bottomBar
        }
        .padding(18)
        .frame(width: 440, height: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showServiceSetup, onDismiss: model.dismissServiceSetup) {
            serviceSetup
        }
        .confirmationDialog(
            "删除“\(model.currentProject?.name ?? "这个项目")”？",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("删除项目和所有本机版本", role: .destructive) {
                model.deleteCurrentProject()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法恢复。")
        }
    }

    @ViewBuilder
    private var projectStage: some View {
        if let project = model.currentProject {
            if let comparison = model.comparison {
                comparisonStage(project: project, comparison: comparison)
            } else {
                newMessageStage(project: project)
            }
        } else {
            setupStage
        }
    }

    private var setupStage: some View {
        VStack(alignment: .leading, spacing: 12) {
            painBadge("先建立项目约定")

            Text("客户一句“顺便改下”，\n可能就是一轮免费返工。")
                .font(.system(size: 21, weight: .bold))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Text("保存当前约定。下次客户改需求，自动识别新增工作、原约定变更、取消项和待确认问题。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                valueChip("新增工作不漏")
                valueChip("模糊要求先问")
                valueChip("每次约定留痕")
            }

            TextField("项目名，例如：张总官网改版", text: $model.projectNameDraft)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13.5))

            editor(
                text: $model.baselineDraft,
                placeholder: "粘贴已确认的交付内容、数量、时间、价格和标准…",
                height: 190,
                label: "当前双方约定"
            )

            primaryButton("保存当前约定", icon: "pin.fill") {
                model.createProject()
            }
            .disabled(!model.canCreateProject || model.isWorking)

            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                Text("只保存在这台 Mac，不会自动读取聊天。")
            }
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)

            if !model.projects.isEmpty {
                Menu("回到正在做的项目") {
                    ForEach(model.projects) { project in
                        Button(project.name) { model.selectProject(project.id) }
                    }
                }
                .menuStyle(.borderlessButton)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func newMessageStage(project: RequirementProject) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                projectMenu(project)

                stageLabel("当前项目约定", icon: "pin.fill", color: .green)
                card {
                    ScrollView {
                        Text(project.confirmedScope)
                            .font(.system(size: 12.5))
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("客户发来新需求或修改？")
                        .font(.system(size: 19, weight: .bold))
                    Text("先看清本次变更和新增工作，再决定怎么回。")
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }

                editor(
                    text: $model.newMessage,
                    placeholder: "粘贴客户新发的需求、修改意见或补充消息…",
                    height: 145,
                    label: "客户的新消息"
                )

                primaryButton("识别本次变更", icon: "arrow.left.arrow.right") {
                    model.compare()
                }
                .disabled(!model.hasUsableNewMessage || model.isWorking)

                Text("先看差异，再决定怎么回；不会替你答应。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.trailing, 2)
        }
    }

    private func comparisonStage(project: RequirementProject,
                                 comparison: RequirementComparisonResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        painBadge("本次变更已识别")
                        Text(comparison.summary)
                            .font(.system(size: 17, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("换段消息") { model.clearComparison() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }

                changeList("新增工作", icon: "plus.circle.fill", color: .blue, items: comparison.added)
                changeList("原约定变更", icon: "pencil.circle.fill", color: orange, items: comparison.changed)
                changeList("明确取消", icon: "minus.circle.fill", color: .red, items: comparison.removed)
                changeList("待确认，先别开工", icon: "questionmark.circle.fill", color: orange, items: comparison.unclear)

                VStack(alignment: .leading, spacing: 7) {
                    stageLabel("边界确认回复", icon: "bubble.left.and.text.bubble.right.fill", color: violet)
                    editor(
                        text: $model.confirmationReply,
                        placeholder: "正在整理确认话术…",
                        height: 118,
                        label: "发给客户的确认草稿"
                    )
                }

                if model.replyRisks.isEmpty {
                    Label("只在核对，没替你多答应", systemImage: "checkmark.shield.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(Color.green)
                } else {
                    Label("先别发，这句可能多答应了：\(model.replyRisks.joined(separator: "、"))",
                          systemImage: "exclamationmark.shield.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(orange)
                }

                HStack(spacing: 8) {
                    Button("放回聊天框") { returnDraft(model.confirmationReply) }
                        .buttonStyle(.bordered)
                        .disabled(model.confirmationReply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                  !model.replyRisks.isEmpty || model.isWorking)

                    Button("确认并更新项目约定") { model.acceptComparison() }
                        .buttonStyle(.borderedProminent)
                        .tint(violet)
                        .disabled(model.isWorking)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Text("确认回复不会自动发送；项目约定也只在你确认后更新。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.trailing, 2)
        }
    }

    private func projectMenu(_ project: RequirementProject) -> some View {
        HStack {
            Menu {
                ForEach(model.projects) { item in
                    Button(item.name) { model.selectProject(item.id) }
                }
                Divider()
                Button("新建项目") { model.startNewProject() }
                Button("删除当前项目", role: .destructive) { showDeleteConfirmation = true }
            } label: {
                Label(project.name, systemImage: "folder.fill")
                    .font(.system(size: 13, weight: .bold))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()
            Text("已钉住 \(project.snapshots.count) 版")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func changeList(_ title: String, icon: String, color: Color, items: [String]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                stageLabel(title, icon: icon, color: color)
                card {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            Text("• \(item)")
                                .font(.system(size: 12.5))
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let url = Bundle.main.url(forResource: "LydiaLogo", withExtension: "png"),
               let logo = NSImage(contentsOf: url) {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 0) {
                Text("LYDIA")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.65)
                Text("别返工")
                    .font(.system(size: 22, weight: .bold))
            }
            Spacer()
            Text("变更有记录 · 追加有依据")
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(orange)
                .padding(.horizontal, 9)
                .frame(height: 25)
                .background(orange.opacity(0.10), in: Capsule())

            Button { showSettings.toggle() } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("设置")
            .popover(isPresented: $showSettings, arrowEdge: .bottom) { settingsContent }
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        if model.isWorking {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(model.status)
            }
            .font(.system(size: 11.5))
            .foregroundStyle(.secondary)
        } else if let error = model.errorMessage {
            Label(error, systemImage: "exclamationmark.circle.fill")
                .font(.system(size: 11.5))
                .foregroundStyle(orange)
                .lineLimit(2)
        } else if !model.status.isEmpty {
            Text(model.status)
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    private var bottomBar: some View {
        HStack {
            Button("另一个项目") { model.startNewProject() }
                .buttonStyle(.bordered)
                .controlSize(.small)
            Spacer()
            Label("本机保存 · 手动确认", systemImage: "lock.fill")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private var serviceSetup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("接入真实分析能力", systemImage: "sparkles")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(violet)
            Text("本机核对已经可用。连接 AI 后，可以处理更复杂、更口语化的客户消息。")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            SecureField("智谱 API Key", text: $serviceKey)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("继续用本机核对") {
                    model.loadPreview()
                    showServiceSetup = false
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("连接并对比") {
                    if model.saveServiceKey(serviceKey) {
                        serviceKey = ""
                        showServiceSetup = false
                        model.compare()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(violet)
                .disabled(serviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 370)
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(.system(size: 15, weight: .bold))
            HStack {
                Circle()
                    .fill(model.serviceConfigured ? Color.green : orange)
                    .frame(width: 7, height: 7)
                Text(model.serviceConfigured ? "真实 AI 已连接" : "本机核对已就绪")
                Spacer()
                Button(model.serviceConfigured ? "重新连接" : "连接") {
                    showSettings = false
                    showServiceSetup = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Divider()
            Label("本机有 \(model.projects.count) 个项目，每个项目最多保留 30 个版本。", systemImage: "externaldrive.fill")
                .foregroundStyle(.secondary)
            Divider()
            Button("怎么用") { showHelp.toggle() }
                .buttonStyle(.plain)
            if model.serviceConfigured {
                Button("断开开发用 AI") { model.forgetServiceKey() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.red)
            }
        }
        .font(.system(size: 12))
        .padding(16)
        .frame(width: 310)
        .popover(isPresented: $showHelp, arrowEdge: .trailing) { helpContent }
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("别急着开工")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
            Text("1. 先保存双方当前的项目约定。")
            Text("2. 每次只粘贴客户新发的那段话。")
            Text("3. 看清新增工作和变更点，先发确认草稿，再决定是否更新约定。")
            Divider()
            Text("只有点击对比时，当前记录和新消息才会发给已连接的 AI。草稿不会自动发送。")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(17)
        .frame(width: 310)
    }

    private func painBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .bold))
            .foregroundStyle(orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(orange.opacity(0.10), in: Capsule())
    }

    private func valueChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(violet)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func editor(text: Binding<String>, placeholder: String, height: CGFloat, label: String) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .font(.system(size: 13.5))
                .scrollContentBackground(.hidden)
                .padding(7)
                .accessibilityLabel(label)
                .disabled(model.isWorking)
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: height)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.14)))
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.08)))
    }

    private func stageLabel(_ title: String, icon: String, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 12.5, weight: .bold))
            .foregroundStyle(color)
    }

    private func primaryButton(_ title: String, icon: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(LinearGradient(colors: [violet, ink], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
