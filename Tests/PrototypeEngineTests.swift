import Foundation

@main
struct PrototypeEngineTests {
    static func main() {
        let comparison = PrototypeEngine.compareRequirements(
            confirmedScope: "官网桌面端首页和价格页，周五交第一版",
            newMessage: "移动端也顺便做一下，后台再加个数据导出，还是周五一起给我"
        )
        precondition(!comparison.summary.isEmpty)
        precondition(comparison.added == ["官网增加移动端适配", "后台增加数据导出"])
        precondition(comparison.changed.count == 1)
        precondition(comparison.removed.isEmpty)
        precondition(comparison.unclear.count == 3)
        precondition(!comparison.updatedScope.isEmpty)
        precondition(comparison.confirmationReply.contains("时间和报价"))
        precondition(comparison.addedCommitments.isEmpty)
        print("PrototypeEngineTests: 8 checks passed")
    }
}
