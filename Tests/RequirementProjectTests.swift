import Foundation

@main
struct RequirementProjectTests {
    static func main() {
        let suite = "com.lydiahub.biefangong.requirements.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        precondition(RequirementProjectStore.load(defaults: defaults).isEmpty)
        precondition(RequirementProjectStore.create(name: "", baseline: "范围", defaults: defaults) == nil)
        precondition(RequirementProjectStore.create(name: "网站改版", baseline: "", defaults: defaults) == nil)

        let start = Date(timeIntervalSince1970: 1_000)
        let project = RequirementProjectStore.create(
            name: "  网站改版  ",
            baseline: "首页和价格页，本周先确认方向。",
            now: start,
            defaults: defaults
        )!
        precondition(project.name == "网站改版")
        precondition(project.snapshots.count == 1)
        precondition(RequirementProjectStore.load(defaults: defaults).first?.id == project.id)

        let updated = RequirementProjectStore.apply(
            projectID: project.id,
            sourceMessage: "价格页先不做，新增移动端首页。",
            updatedScope: "首页增加移动端；价格页取消。",
            now: Date(timeIntervalSince1970: 2_000),
            defaults: defaults
        )!
        precondition(updated.confirmedScope == "首页增加移动端；价格页取消。")
        precondition(updated.snapshots.count == 2)
        precondition(updated.snapshots.last?.sourceMessage == "价格页先不做，新增移动端首页。")

        RequirementProjectStore.delete(projectID: project.id, defaults: defaults)
        precondition(RequirementProjectStore.load(defaults: defaults).isEmpty)

        print("RequirementProjectTests: 11 checks passed")
    }
}
