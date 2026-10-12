import AppKit

/// Protocol defining previous frontmost application tracking for direct auto-paste.
public protocol PreviousAppTracking: AnyObject {
    var previousApp: NSRunningApplication? { get }
    func captureFrontmostApplication()
    func setPreviousApp(_ app: NSRunningApplication?)
    func clear()
}

/// Thread-safe tracker retaining reference to the frontmost application
/// before SuperClip window or status item gains key focus.
public final class PreviousAppTracker: PreviousAppTracking, @unchecked Sendable {
    public static let shared = PreviousAppTracker()

    private let lock = NSLock()
    private weak var _previousApp: NSRunningApplication?
    private var _processIdentifier: pid_t?

    public init() {}

    /// The captured previous application, verifying it has not terminated.
    public var previousApp: NSRunningApplication? {
        lock.lock()
        defer { lock.unlock() }

        if let app = _previousApp, !app.isTerminated {
            return app
        }
        if let pid = _processIdentifier,
           let app = NSRunningApplication(processIdentifier: pid),
           !app.isTerminated {
            return app
        }
        return nil
    }

    /// Sets the previous application explicitly, ignoring SuperClip itself.
    public func setPreviousApp(_ app: NSRunningApplication?) {
        lock.lock()
        defer { lock.unlock() }

        if let app = app {
            if app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
                self._previousApp = app
                self._processIdentifier = app.processIdentifier
            }
        } else {
            self._previousApp = nil
            self._processIdentifier = nil
        }
    }

    /// Captures the currently active frontmost application from NSWorkspace.shared,
    /// ignoring SuperClip if SuperClip is already frontmost.
    public func captureFrontmostApplication() {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return }
        if frontmost.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return
        }
        setPreviousApp(frontmost)
    }

    /// Clears any cached target application reference.
    public func clear() {
        setPreviousApp(nil)
    }
}
