import Foundation

@main
struct PrototypeEngineTests {
    static func main() {
        let comparison = PrototypeEngine.compareRequirements(
            confirmedScope: "官网桌面端首页和价格页，周五交第一版",
            newMessage: "移动端也顺便做一下，后台再加个数据导出，还是周五一起给我"
        )
        precondition(!comparison.summary.isEmpty)
        precondition(comparison.added == ["移动端适配", "后台数据导出"])
        precondition(comparison.changed.count == 2)
        precondition(comparison.removed.isEmpty)
        precondition(comparison.unclear.count == 3)
        precondition(!comparison.updatedScope.isEmpty)
        precondition(comparison.confirmationReply.contains("时间和报价"))
        precondition(comparison.addedCommitments.isEmpty)
        let login = PrototypeEngine.compareRequirements(
            confirmedScope: "产品介绍页，本月底交付",
            newMessage: "再加一个手机验证码登录，时间照旧"
        )
        precondition(login.added == ["登录与账号功能"])
        precondition(!login.added.contains("后台数据导出"))
        precondition(login.confirmationReply.contains("登录方式"))

        let vague = PrototypeEngine.compareRequirements(
            confirmedScope: "首页视觉改版",
            newMessage: "这里再顺便处理一下"
        )
        precondition(vague.added.isEmpty)
        precondition(vague.unclear.contains { $0.contains("哪些已约定的工作") })
        precondition(vague.confirmationReply.contains("首页视觉改版"))

        print("PrototypeEngineTests: 14 checks passed")
    }
}
