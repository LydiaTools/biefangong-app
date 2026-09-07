import Foundation

/// 只用于无服务时演示产品交互；不会将固定结果伪装成真实分析。
enum PrototypeEngine {
    static func compareRequirements(confirmedScope: String,
                                    newMessage: String) -> RequirementComparisonResult {
        RequirementComparisonResult(
            summary: "客户新增了移动端适配，并明确取消价格页；首页的“高级感”仍没有验收标准。",
            added: ["首页增加移动端适配"],
            changed: ["首页从只做桌面版，改为同时覆盖移动端"],
            removed: ["本期不再制作价格页"],
            unclear: ["“更高级”的具体参考和验收标准是什么？"],
            updatedScope: "本期制作首页的桌面版和移动端；价格页取消。首页视觉需要更高级，但具体参考和验收标准待确认。",
            confirmationReply: "收到，我确认一下：这次新增首页移动端，价格页本期取消；首页还需要调整得更高级。为避免方向做偏，麻烦再确认一下“更高级”以哪张参考或哪项标准为准？",
            addedCommitments: []
        )
    }
}
