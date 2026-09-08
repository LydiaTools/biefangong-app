import Foundation

/// 无需联网即可使用的保守型规则核对。它只指出文字中能直接确认的变化，
/// 更复杂的口语、上下文和隐含意图交给可选的 AI 服务处理。
enum PrototypeEngine {
    private struct AdditionRule {
        let title: String
        let keywords: [String]
        let question: String
    }

    private static let additionRules = [
        AdditionRule(
            title: "移动端适配",
            keywords: ["移动端", "手机端", "手机版", "h5", "响应式"],
            question: "移动端需要覆盖哪些页面和交互？"
        ),
        AdditionRule(
            title: "后台数据导出",
            keywords: ["导出", "excel", "csv", "下载数据"],
            question: "后台要导出哪些数据、使用什么格式？"
        ),
        AdditionRule(
            title: "登录与账号功能",
            keywords: ["登录", "验证码", "注册"],
            question: "登录方式、账号来源和异常流程分别怎么处理？"
        ),
        AdditionRule(
            title: "支付功能",
            keywords: ["支付", "付款", "微信支付", "支付宝"],
            question: "需要接入哪些支付方式，退款和支付失败怎么处理？"
        ),
        AdditionRule(
            title: "角色权限",
            keywords: ["权限", "角色", "管理员"],
            question: "有哪些角色，每个角色能查看和修改哪些内容？"
        ),
        AdditionRule(
            title: "数据报表",
            keywords: ["报表", "统计", "看板"],
            question: "报表要看哪些指标、时间范围和统计口径？"
        ),
        AdditionRule(
            title: "搜索筛选",
            keywords: ["搜索", "筛选", "过滤"],
            question: "需要按哪些字段搜索或筛选？"
        ),
        AdditionRule(
            title: "消息提醒",
            keywords: ["提醒", "通知", "消息推送"],
            question: "哪些事件需要提醒，通过什么渠道发送？"
        )
    ]

    static func compareRequirements(confirmedScope: String,
                                    newMessage: String) -> RequirementComparisonResult {
        let baseline = PromptBuilder.normalize(confirmedScope)
        let message = PromptBuilder.normalize(newMessage)
        let lowercased = message.lowercased()

        let matchedRules = additionRules.filter { rule in
            rule.keywords.contains { lowercased.contains($0.lowercased()) }
        }
        let added = uniqued(matchedRules.map(\.title))

        let removalWords = ["不做", "取消", "删掉", "去掉", "不要了"]
        let removed = message
            .components(separatedBy: CharacterSet(charactersIn: "。！？!?；;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { sentence in removalWords.contains { sentence.contains($0) } }
            .map { "待确认取消：\($0)" }

        let keepsDeadline = ["还是周", "照旧", "时间不变", "按原时间", "一起给我", "一起交"]
            .contains { lowercased.contains($0) }
        let vagueWording = ["顺便", "看着办", "尽快", "简单改下", "小改", "挪一挪", "搞一下"]
            .contains { lowercased.contains($0) }

        var changed: [String] = []
        if !added.isEmpty {
            changed.append("原约定之外新增：\(added.joined(separator: "、"))")
        }
        if keepsDeadline {
            changed.append("工作内容有变化，但客户要求原交付时间不变")
        }

        var unclear = matchedRules.map(\.question)
        if keepsDeadline {
            unclear.append("增加这些工作后，原交付时间是否仍然不变？")
        }
        if vagueWording && unclear.count < 3 {
            unclear.append("“顺便改一下”的验收标准和完成范围是什么？")
        }
        if added.isEmpty && removed.isEmpty {
            unclear.append("这条消息会改变哪些已约定的工作？请客户指出具体内容。")
        }
        unclear = Array(uniqued(unclear).prefix(3))

        let summary: String
        if !added.isEmpty && keepsDeadline {
            summary = "客户新增了\(added.joined(separator: "、"))，同时要求沿用原交付时间。"
        } else if !added.isEmpty {
            summary = "客户提出了新增工作：\(added.joined(separator: "、"))。"
        } else if !removed.isEmpty {
            summary = "客户提出取消部分工作，具体边界仍需确认。"
        } else {
            summary = "这条消息存在变更意图，但没有写清具体工作范围。"
        }

        var scopeParts = [baseline]
        if !added.isEmpty {
            scopeParts.append("本次拟新增：\(added.joined(separator: "、"))。")
        }
        if !removed.isEmpty {
            scopeParts.append("拟取消内容待双方确认后生效。")
        }
        if keepsDeadline || !unclear.isEmpty {
            scopeParts.append("新增范围、验收标准和交付时间以双方确认结果为准。")
        }

        let changeText = added.isEmpty ? "这次提到的调整" : added.joined(separator: "、")
        let questionText = unclear.isEmpty ? "具体范围和验收标准" : unclear.joined(separator: "；")
        let reply = "收到。我先把边界确认清楚：原约定是\(baseline)；这次提到\(changeText)。麻烦再确认：\(questionText) 工作量确认后，我再同步调整后的时间和报价。"

        return RequirementComparisonResult(
            summary: summary,
            added: added,
            changed: changed,
            removed: removed,
            unclear: unclear,
            updatedScope: scopeParts.joined(separator: "\n"),
            confirmationReply: reply,
            addedCommitments: []
        )
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}
