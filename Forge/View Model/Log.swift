import Foundation

/// Debug-only logging. In DEBUG builds forwards to `print`; in release builds
/// the @autoclosure means the message expression is never evaluated, so log
/// strings cost zero at runtime in shipped binaries.
///
/// Use for diagnostic traces (state transitions, handler entry/exit, caught
/// errors that are informational). For user-visible error surfaces, still
/// use a banner or alert — see the "Fail Loud, Never Fake" rule in CLAUDE.md.
enum Log {
    static func debug(_ message: @autoclosure () -> String) {
        #if DEBUG
        print(message())
        #endif
    }
}
