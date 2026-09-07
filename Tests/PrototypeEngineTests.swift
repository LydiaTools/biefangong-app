import Foundation

@main
struct PrototypeEngineTests {
    static func main() {
        let comparison = PrototypeEngine.compareRequirements(
            confirmedScope: "首页桌面版和价格页",
            newMessage: "增加移动端，价格页不做了"
        )
        precondition(!comparison.summary.isEmpty)
        precondition(comparison.added == ["首页增加移动端适配"])
        precondition(comparison.changed.count == 1)
        precondition(comparison.removed == ["本期不再制作价格页"])
        precondition(comparison.unclear.count == 1)
        precondition(!comparison.updatedScope.isEmpty)
        precondition(!comparison.confirmationReply.isEmpty)
        precondition(comparison.addedCommitments.isEmpty)
        print("PrototypeEngineTests: 8 checks passed")
    }
}
