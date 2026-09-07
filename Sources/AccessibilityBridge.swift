import AppKit
import ApplicationServices

@MainActor
enum AXBridge {
    static func value(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(e, key as CFString, &v) == .success else { return nil }
        return v
    }
    static func text(_ e: AXUIElement, _ key: String) -> String { value(e, key) as? String ?? "" }
    static func element(_ e: AXUIElement, _ key: String) -> AXUIElement? {
        guard let v = value(e, key), CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(v, to: AXUIElement.self)
    }
    static func walk(_ root: AXUIElement, limit: Int = 2200) -> [AXUIElement] {
        var result: [AXUIElement] = []
        func visit(_ item: AXUIElement, _ depth: Int) {
            guard depth < 26, result.count < limit else { return }
            result.append(item)
            for child in value(item, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth + 1) }
        }
        visit(root, 0)
        return result
    }
    static func isTextInput(_ e: AXUIElement) -> Bool {
        [kAXTextAreaRole, kAXTextFieldRole].contains(text(e, kAXRoleAttribute)) && (value(e, kAXEnabledAttribute) as? Bool ?? true)
    }
    static func window(_ app: NSRunningApplication) -> AXUIElement? {
        element(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute)
    }
    static func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        for pressed in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: pressed)
            event?.flags = flags; event?.post(tap: .cghidEventTap)
        }
    }
    static func pause(_ seconds: Double) async throws { try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
}

@MainActor
final class PasteboardLease {
    private var items: [[NSPasteboard.PasteboardType: Data]] = []
    private var ownedChange: Int?
    init() {
        items = (NSPasteboard.general.pasteboardItems ?? []).map { item in
            var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types { if let bytes = item.data(forType: type) { snapshot[type] = bytes } }
            return snapshot
        }
    }
    func set(_ text: String) -> Bool {
        let board = NSPasteboard.general; board.clearContents()
        let result = board.setString(text, forType: .string); ownedChange = board.changeCount
        return result
    }
    func claimCurrentContents() { ownedChange = NSPasteboard.general.changeCount }
    func restore() {
        let board = NSPasteboard.general
        guard board.changeCount == ownedChange else { items = []; return }
        board.clearContents()
        let restored = items.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot { item.setData(data, forType: type) }
            return item
        }
        if !restored.isEmpty { board.writeObjects(restored) }
        items = []; ownedChange = nil
    }
}

enum AIBridgeError: LocalizedError {
    case inputUnavailable, focusChanged, failed
    var errorDescription: String? {
        switch self {
        case .inputUnavailable: return "没有找到可安全写入的空白聊天框。"
        case .focusChanged: return "窗口已经切换，这次没有继续输入。"
        case .failed: return "这次没有写入成功，确认草稿仍然保留。"
        }
    }
}
