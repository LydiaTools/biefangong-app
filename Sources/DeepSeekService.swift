import Foundation
import LocalAuthentication
import Security

enum DeepSeekServiceError: LocalizedError {
    case missingKey
    case transport
    case unauthorized
    case rateLimited
    case server
    case emptyResult
    case invalidResult
    case serviceMessage(String)

    var errorDescription: String? {
        switch self {
        case .missingKey: return "分析服务还没连接。"
        case .transport: return "这次没连上分析服务，请稍后再试。"
        case .unauthorized: return "分析服务验证失败，请重新连接。"
        case .rateLimited: return "刚才请求太多了，稍后再试。"
        case .server: return "分析服务暂时没响应。"
        case .emptyResult: return "这次没有返回可用结果，请重试。"
        case .invalidResult: return "返回的变更结果不完整，请重试。"
        case .serviceMessage(let message): return message
        }
    }
}

enum DeepSeekCredentialStore {
    private static let service = "com.lydiahub.biefangong.ai-key.v1"
    private static let account = "openai-compatible"

    static func load() -> String? {
        if let environment = ProcessInfo.processInfo.environment["LYDIA_SCOPE_AI_API_KEY"]?
            .trimmingCharacters(in: .whitespacesAndNewlines), !environment.isEmpty {
            return environment
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: nonInteractiveContext()
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8), !value.isEmpty else { return nil }
        return value
    }

    static func save(_ raw: String) throws {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { throw DeepSeekServiceError.missingKey }
        let identity: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        var deleteQuery = identity
        deleteQuery[kSecUseAuthenticationContext as String] = nonInteractiveContext()
        SecItemDelete(deleteQuery as CFDictionary)
        var item = identity
        item[kSecValueData as String] = Data(value.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
            throw DeepSeekServiceError.transport
        }
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseAuthenticationContext as String: nonInteractiveContext()
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func nonInteractiveContext() -> LAContext {
        let context = LAContext()
        context.interactionNotAllowed = true
        return context
    }
}

struct DeepSeekService {
    private let apiKey: String
    private let endpoint: URL
    private let model: String
    private let session: URLSession

    init(apiKey: String,
         endpoint: URL = URL(string: "https://open.bigmodel.cn/api/paas/v4/chat/completions")!,
         model: String = "glm-4.5-air",
         session: URLSession = .shared) {
        self.apiKey = apiKey
        self.endpoint = endpoint
        self.model = model
        self.session = session
    }

    func compareRequirements(confirmedScope: String,
                             newMessage: String) async throws -> RequirementComparisonResult {
        let content = try await complete(
            system: PromptBuilder.requirementComparisonSystem(),
            user: PromptBuilder.requirementComparisonUser(
                confirmedScope: confirmedScope,
                newMessage: newMessage
            )
        )
        return try Self.decodeRequirementComparison(content)
    }

    private func complete(system: String, user: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DeepSeekServiceError.missingKey
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 50
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("Lydia-BieFanGong/0.1", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONEncoder().encode(ChatRequest(
            model: model,
            messages: [Message(role: "system", content: system), Message(role: "user", content: user)],
            responseFormat: ResponseFormat(type: "json_object"),
            stream: false,
            temperature: 0.2,
            maxTokens: 2_400
        ))

        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch { throw DeepSeekServiceError.transport }
        guard let http = response as? HTTPURLResponse else { throw DeepSeekServiceError.transport }
        switch http.statusCode {
        case 200..<300: break
        case 401, 402, 403: throw DeepSeekServiceError.unauthorized
        case 429: throw DeepSeekServiceError.rateLimited
        default: throw DeepSeekServiceError.server
        }
        if let payload = try? JSONDecoder().decode(ChatResponse.self, from: data),
           let content = payload.choices.first?.message.content?
            .trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty {
            return content
        }
        if let content = Self.flexibleAssistantContent(data), !content.isEmpty { return content }
        if let message = Self.serviceErrorMessage(data) {
            throw DeepSeekServiceError.serviceMessage(message)
        }
        throw DeepSeekServiceError.emptyResult
    }

    static func decodeRequirementComparison(_ raw: String) throws -> RequirementComparisonResult {
        let data = try jsonData(raw)
        guard let decoded = try? JSONDecoder().decode(RequirementComparisonPayload.self, from: data) else {
            throw DeepSeekServiceError.invalidResult
        }
        let summary = cleaned(decoded.summary, limit: 800)
        let updatedScope = cleaned(decoded.updatedScope, limit: PromptBuilder.maximumMessageLength)
        let confirmationReply = cleaned(decoded.confirmationReply, limit: 2_400)
        guard !summary.isEmpty, !updatedScope.isEmpty, !confirmationReply.isEmpty else {
            throw DeepSeekServiceError.invalidResult
        }
        return RequirementComparisonResult(
            summary: summary,
            added: cleanedList(decoded.added, itemLimit: 360, countLimit: 3),
            changed: cleanedList(decoded.changed, itemLimit: 480, countLimit: 3),
            removed: cleanedList(decoded.removed, itemLimit: 360, countLimit: 3),
            unclear: cleanedList(decoded.unclear, itemLimit: 360, countLimit: 3),
            updatedScope: updatedScope,
            confirmationReply: confirmationReply,
            addedCommitments: cleanedList(decoded.addedCommitments ?? [], itemLimit: 160, countLimit: 5)
        )
    }

    private static func jsonData(_ raw: String) throws -> Data {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("```") {
            value = value.replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = value.data(using: .utf8) else { throw DeepSeekServiceError.invalidResult }
        return data
    }

    private static func cleaned(_ value: String, limit: Int) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
    }

    private static func cleanedList(_ values: [String], itemLimit: Int, countLimit: Int) -> [String] {
        Array(values.map { cleaned($0, limit: itemLimit) }.filter { !$0.isEmpty }.prefix(countLimit))
    }

    private static func flexibleAssistantContent(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = root["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any] else { return nil }
        if let value = message["content"] as? String {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let parts = message["content"] as? [[String: Any]] {
            let text = parts.compactMap { part -> String? in
                if let value = part["text"] as? String { return value }
                if let value = part["content"] as? String { return value }
                return nil
            }.joined()
            if !text.isEmpty { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        }
        if let value = message["reasoning_content"] as? String, !value.isEmpty {
            return value.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private static func serviceErrorMessage(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let raw: String?
        if let error = root["error"] as? [String: Any] {
            raw = error["message"] as? String ?? error["msg"] as? String
        } else {
            raw = root["message"] as? String ?? root["msg"] as? String
        }
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return "分析服务返回：\(String(value.prefix(240)))"
    }
}

private struct Message: Codable { let role: String; let content: String }
private struct ResponseFormat: Codable { let type: String }
private struct ChatRequest: Codable {
    let model: String
    let messages: [Message]
    let responseFormat: ResponseFormat
    let stream: Bool
    let temperature: Double
    let maxTokens: Int
    enum CodingKeys: String, CodingKey {
        case model, messages, stream, temperature
        case responseFormat = "response_format"
        case maxTokens = "max_tokens"
    }
}
private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct AssistantMessage: Decodable { let content: String? }
        let message: AssistantMessage
    }
    let choices: [Choice]
}
private struct RequirementComparisonPayload: Decodable {
    let summary: String
    let added: [String]
    let changed: [String]
    let removed: [String]
    let unclear: [String]
    let updatedScope: String
    let confirmationReply: String
    let addedCommitments: [String]?
    enum CodingKeys: String, CodingKey {
        case summary, added, changed, removed, unclear
        case updatedScope = "updated_scope"
        case confirmationReply = "confirmation_reply"
        case addedCommitments = "added_commitments"
    }
}
