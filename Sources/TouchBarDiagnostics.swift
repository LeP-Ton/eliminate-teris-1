import Foundation

enum TouchBarDiagnostics {
    static let environmentKey = "ELIMINATE_TOUCHBAR_DIAGNOSTICS"

    static let isEnabled: Bool = {
        let rawValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch rawValue {
        case "1", "true", "yes", "on", "debug":
            return true
        default:
            return false
        }
    }()

    static func log(
        _ message: @autoclosure () -> String,
        function: StaticString = #function
    ) {
        guard isEnabled else { return }
        NSLog("[TouchBarDiag] \(function): \(message())")
    }

    static func describe(size: CGSize) -> String {
        return String(format: "%.1fx%.1f", size.width, size.height)
    }

    static func describe(rect: CGRect) -> String {
        return String(
            format: "(x:%.1f,y:%.1f,w:%.1f,h:%.1f)",
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height
        )
    }
}
