import Foundation

struct RequirementComparisonResult: Equatable {
    let summary: String
    let added: [String]
    let changed: [String]
    let removed: [String]
    let unclear: [String]
    let updatedScope: String
    let confirmationReply: String
    let addedCommitments: [String]
}

struct RequirementSnapshot: Codable, Equatable, Identifiable {
    let id: UUID
    let createdAt: Date
    let sourceMessage: String
    let confirmedScope: String
}

struct RequirementProject: Codable, Equatable, Identifiable {
    let id: UUID
    var name: String
    var confirmedScope: String
    var snapshots: [RequirementSnapshot]
    var updatedAt: Date
}

enum RequirementProjectStore {
    private static let key = "pinnedProjectScopesV1"
    private static let maximumProjects = 20
    private static let maximumSnapshots = 30

    static func load(defaults: UserDefaults = .standard) -> [RequirementProject] {
        guard let data = defaults.data(forKey: key),
              let projects = try? JSONDecoder().decode([RequirementProject].self, from: data) else {
            return []
        }
        return projects
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func create(name rawName: String,
                       baseline rawBaseline: String,
                       now: Date = Date(),
                       defaults: UserDefaults = .standard) -> RequirementProject? {
        let name = cleaned(rawName, limit: 60)
        let baseline = PromptBuilder.normalize(rawBaseline)
        guard !name.isEmpty, !baseline.isEmpty else { return nil }

        let snapshot = RequirementSnapshot(
            id: UUID(),
            createdAt: now,
            sourceMessage: baseline,
            confirmedScope: baseline
        )
        let project = RequirementProject(
            id: UUID(),
            name: name,
            confirmedScope: baseline,
            snapshots: [snapshot],
            updatedAt: now
        )
        var projects = load(defaults: defaults).filter { $0.id != project.id }
        projects.insert(project, at: 0)
        save(Array(projects.prefix(maximumProjects)), defaults: defaults)
        return project
    }

    static func apply(projectID: UUID,
                      sourceMessage rawMessage: String,
                      updatedScope rawScope: String,
                      now: Date = Date(),
                      defaults: UserDefaults = .standard) -> RequirementProject? {
        var projects = load(defaults: defaults)
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return nil }
        let message = PromptBuilder.normalize(rawMessage)
        let scope = PromptBuilder.normalize(rawScope)
        guard !message.isEmpty, !scope.isEmpty else { return nil }

        let snapshot = RequirementSnapshot(
            id: UUID(),
            createdAt: now,
            sourceMessage: message,
            confirmedScope: scope
        )
        projects[index].confirmedScope = scope
        projects[index].snapshots.append(snapshot)
        projects[index].snapshots = Array(projects[index].snapshots.suffix(maximumSnapshots))
        projects[index].updatedAt = now
        let updated = projects.remove(at: index)
        projects.insert(updated, at: 0)
        save(projects, defaults: defaults)
        return updated
    }

    static func delete(projectID: UUID, defaults: UserDefaults = .standard) {
        save(load(defaults: defaults).filter { $0.id != projectID }, defaults: defaults)
    }

    private static func save(_ projects: [RequirementProject], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        defaults.set(data, forKey: key)
    }

    private static func cleaned(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }
}
