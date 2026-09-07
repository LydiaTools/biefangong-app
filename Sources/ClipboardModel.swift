import AppKit
import Foundation

@MainActor
final class ClipboardModel: ObservableObject {
    @Published private(set) var projects: [RequirementProject] = []
    @Published var selectedProjectID: UUID? {
        didSet {
            if let selectedProjectID {
                UserDefaults.standard.set(selectedProjectID.uuidString, forKey: "selectedProjectID")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedProjectID")
            }
        }
    }
    @Published var projectNameDraft = ""
    @Published var baselineDraft = ""
    @Published var newMessage = ""
    @Published var confirmationReply = ""
    @Published private(set) var comparison: RequirementComparisonResult?
    @Published private(set) var isWorking = false
    @Published private(set) var status = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var serviceConfigured = false

    var onResult: (() -> Void)?

    private var task: Task<Void, Never>?

    init() {
        let savedProjects = RequirementProjectStore.load()
        projects = savedProjects
        if let savedID = UserDefaults.standard.string(forKey: "selectedProjectID").flatMap(UUID.init),
           savedProjects.contains(where: { $0.id == savedID }) {
            selectedProjectID = savedID
        } else {
            selectedProjectID = savedProjects.first?.id
        }
        serviceConfigured = DeepSeekCredentialStore.load() != nil
    }

    var currentProject: RequirementProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }

    var canCreateProject: Bool {
        !projectNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !PromptBuilder.normalize(baselineDraft).isEmpty
    }

    var hasUsableNewMessage: Bool {
        !PromptBuilder.normalize(newMessage).isEmpty && !PromptBuilder.isGeneratedTask(newMessage)
    }

    var replyRisks: [String] {
        guard let project = currentProject, let comparison else { return [] }
        return CommitmentGuard.detect(
            intention: project.confirmedScope + "\n" + newMessage,
            reply: confirmationReply,
            reported: comparison.addedCommitments
        )
    }

    @discardableResult
    func acceptSelectedText(_ raw: String) -> Bool {
        let text = PromptBuilder.normalize(raw)
        guard !text.isEmpty, !PromptBuilder.isGeneratedTask(text) else {
            status = "没有读到可处理的文字"
            return false
        }
        if currentProject == nil {
            baselineDraft = text
            status = "已接住文字；还需要填一个项目名"
        } else {
            newMessage = text
            clearComparison()
            status = "已接住客户的新消息"
        }
        return true
    }

    func startNewProject() {
        cancel()
        selectedProjectID = nil
        projectNameDraft = ""
        baselineDraft = ""
        newMessage = ""
        clearComparison()
        status = "先保存这个项目当前的双方约定"
    }

    func selectProject(_ id: UUID) {
        guard projects.contains(where: { $0.id == id }) else { return }
        cancel()
        selectedProjectID = id
        newMessage = ""
        clearComparison()
        status = "已切换项目"
    }

    func createProject() {
        guard canCreateProject,
              let project = RequirementProjectStore.create(name: projectNameDraft, baseline: baselineDraft) else { return }
        projects = RequirementProjectStore.load()
        selectedProjectID = project.id
        projectNameDraft = ""
        baselineDraft = ""
        newMessage = ""
        clearComparison()
        status = "当前项目约定已保存，有新变更时直接来核对"
    }

    func deleteCurrentProject() {
        guard let selectedProjectID else { return }
        RequirementProjectStore.delete(projectID: selectedProjectID)
        projects = RequirementProjectStore.load()
        self.selectedProjectID = projects.first?.id
        newMessage = ""
        clearComparison()
        status = "项目和它的本机版本已删除"
    }

    func compare() {
        guard !isWorking, let project = currentProject, hasUsableNewMessage else { return }
        guard let key = DeepSeekCredentialStore.load() else {
            runPrototypeComparison(project: project)
            return
        }

        errorMessage = nil
        clearComparison()
        isWorking = true
        status = "正在和当前项目约定逐项核对…"
        let message = newMessage
        task = Task {
            do {
                let result = try await connectedService(key: key).compareRequirements(
                    confirmedScope: project.confirmedScope,
                    newMessage: message
                )
                try Task.checkCancellation()
                comparison = result
                confirmationReply = result.confirmationReply
                status = "对完了；还没有替你发送，也没有改本机记录"
            } catch {
                errorMessage = error is CancellationError ? "已取消" : error.localizedDescription
                status = "新消息还在，可以直接重试"
            }
            isWorking = false
            task = nil
            onResult?()
        }
    }

    func acceptComparison() {
        guard let project = currentProject,
              let comparison,
              let updated = RequirementProjectStore.apply(
                projectID: project.id,
                sourceMessage: newMessage,
                updatedScope: comparison.updatedScope
              ) else { return }
        projects = RequirementProjectStore.load()
        selectedProjectID = updated.id
        newMessage = ""
        clearComparison()
        status = "项目约定已更新，上一版仍保留"
    }

    func clearComparison() {
        comparison = nil
        confirmationReply = ""
        errorMessage = nil
    }

    func runPrimaryAction() {
        if currentProject != nil { compare() }
        else if canCreateProject { createProject() }
    }

    func loadPreview() {
        if let project = currentProject, hasUsableNewMessage {
            runPrototypeComparison(project: project)
            return
        }
        startNewProject()
        projectNameDraft = "官网改版"
        baselineDraft = "本期制作官网桌面端首页和价格页，周五交第一版。"
        status = "这是固定效果示例，先保存当前项目约定"
    }

    @discardableResult
    func saveServiceKey(_ raw: String) -> Bool {
        do {
            try DeepSeekCredentialStore.save(raw)
            serviceConfigured = true
            errorMessage = nil
            status = "真实 AI 已连接"
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func forgetServiceKey() {
        DeepSeekCredentialStore.delete()
        serviceConfigured = false
        status = "已断开开发用 AI，现在只能看固定效果示例"
    }

    func dismissServiceSetup() {}

    func copyDraft(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        if board.setString(text, forType: .string) {
            status = "已复制，回到聊天里粘贴即可"
        }
    }

    func showStatus(_ text: String) { status = text }

    func cancel() {
        task?.cancel()
        task = nil
        isWorking = false
    }

    private func runPrototypeComparison(project: RequirementProject) {
        errorMessage = nil
        clearComparison()
        isWorking = true
        status = "固定效果原型 · 正在核对本次变更…"
        let message = newMessage
        task = Task {
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            let result = PrototypeEngine.compareRequirements(
                confirmedScope: project.confirmedScope,
                newMessage: message
            )
            comparison = result
            confirmationReply = result.confirmationReply
            status = "固定效果示例 · 请勿当作对真实消息的分析"
            isWorking = false
            task = nil
            onResult?()
        }
    }

    private func connectedService(key: String) -> DeepSeekService {
        DeepSeekService(
            apiKey: key,
            endpoint: URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!,
            model: "glm-4.5-air"
        )
    }
}
