import Foundation

@main
struct DeepSeekServiceTests {
    static func main() throws {
        let comparison = try DeepSeekService.decodeRequirementComparison("""
        {"summary":"新增移动端并取消价格页。","added":["移动端首页","第二项","第三项","应截断"],"changed":["首页从桌面版改为响应式"],"removed":["价格页"],"unclear":["移动端验收尺寸未说明"],"updated_scope":"首页改为响应式；价格页取消。","confirmation_reply":"确认一下：本次增加移动端并取消价格页，对吗？","added_commitments":[]}
        """)
        precondition(comparison.summary == "新增移动端并取消价格页。")
        precondition(comparison.added.count == 3)
        precondition(comparison.changed.count == 1)
        precondition(comparison.removed == ["价格页"])
        precondition(comparison.unclear.count == 1)
        precondition(comparison.updatedScope.contains("价格页取消"))
        precondition(comparison.addedCommitments.isEmpty)

        let fenced = try DeepSeekService.decodeRequirementComparison("""
        ```json
        {"summary":"无明确变更。","added":[],"changed":[],"removed":[],"unclear":[],"updated_scope":"保持原约定。","confirmation_reply":"收到，当前按原约定执行。","added_commitments":[]}
        ```
        """)
        precondition(fenced.added.isEmpty)

        do {
            _ = try DeepSeekService.decodeRequirementComparison("""
            {"summary":"","added":[],"changed":[],"removed":[],"unclear":[],"updated_scope":"","confirmation_reply":"","added_commitments":[]}
            """)
            preconditionFailure("缺少核心字段必须被拒绝")
        } catch DeepSeekServiceError.invalidResult {
            // Expected.
        }

        print("DeepSeekServiceTests: 9 checks passed")
    }
}
