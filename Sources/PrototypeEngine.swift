import Foundation

/// 只用于无服务时演示产品交互；不会将固定结果伪装成真实分析。
enum PrototypeEngine {
    static func compareRequirements(confirmedScope: String,
                                    newMessage: String) -> RequirementComparisonResult {
        RequirementComparisonResult(
            summary: "客户新增了移动端适配和后台导出，但仍要求周五一起交付。",
            added: ["官网增加移动端适配", "后台增加数据导出"],
            changed: ["原约定只做桌面端，现在增加移动端和后台功能"],
            removed: [],
            unclear: [
                "移动端需要覆盖哪些页面和交互？",
                "后台要导出哪些数据、使用什么格式？",
                "增加两项工作后，周五交付时间是否仍然不变？"
            ],
            updatedScope: "本期制作官网桌面端首页和价格页；新增移动端适配与后台数据导出。移动端覆盖范围、导出内容与格式、交付时间待确认。",
            confirmationReply: "收到，我先确认一下：原来定的是官网桌面端首页和价格页；这次新增移动端适配和后台数据导出。麻烦再确认移动端要覆盖哪些页面、后台要导出哪些数据和格式。工作量确认后，我再同步调整后的时间和报价。",
            addedCommitments: []
        )
    }
}
