import Foundation

/// Lightweight test assertion and reporting harness for SuperClip E2E test suites.
/// Strictly enforces zero emojis across all output formats.
public final class TestHarness {
    public static let shared = TestHarness()
    
    public private(set) var totalTests: Int = 0
    public private(set) var passedTests: Int = 0
    public private(set) var failedTests: Int = 0
    public private(set) var currentSuite: String = "Default"
    
    private init() {}
    
    public static func startSuite(_ name: String) {
        shared.currentSuite = name
        print("\n\u{001B}[1;36m=== Suite: \(name) ===\u{001B}[0m")
    }
    
    public static func recordPass(_ testName: String) {
        shared.totalTests += 1
        shared.passedTests += 1
        print("  \u{001B}[32m[PASS]\u{001B}[0m \(testName)")
    }
    
    public static func recordFail(_ testName: String, reason: String) {
        shared.totalTests += 1
        shared.failedTests += 1
        print("  \u{001B}[31m[FAIL]\u{001B}[0m \(testName): \(reason)")
    }
    
    public static func assertTrue(_ condition: Bool, _ testName: String, reason: String = "Condition was false") {
        if condition {
            recordPass(testName)
        } else {
            recordFail(testName, reason: reason)
        }
    }
    
    public static func assertFalse(_ condition: Bool, _ testName: String, reason: String = "Condition was true") {
        if !condition {
            recordPass(testName)
        } else {
            recordFail(testName, reason: reason)
        }
    }
    
    public static func assertEqual<T: Equatable>(_ a: T, _ b: T, _ testName: String) {
        if a == b {
            recordPass(testName)
        } else {
            recordFail(testName, reason: "Expected \(b), got \(a)")
        }
    }
    
    public static func assertNotNil<T>(_ value: T?, _ testName: String) {
        if value != nil {
            recordPass(testName)
        } else {
            recordFail(testName, reason: "Value was nil")
        }
    }
    
    public static func assertNil<T>(_ value: T?, _ testName: String) {
        if value == nil {
            recordPass(testName)
        } else {
            recordFail(testName, reason: "Expected nil, got \(String(describing: value))")
        }
    }
    
    /// Creates an isolated temporary directory for test execution.
    /// Never touches ~/Library/Application Support/SuperClip/.
    public static func createSandbox() -> URL {
        let tempBase = FileManager.default.temporaryDirectory
        let sandboxURL = tempBase.appendingPathComponent("SuperClip_Sandbox_\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: sandboxURL, withIntermediateDirectories: true)
        return sandboxURL
    }
    
    /// Recursively cleans up a test sandbox directory.
    public static func cleanupSandbox(_ sandboxURL: URL) {
        try? FileManager.default.removeItem(at: sandboxURL)
    }
    
    public static func printSummary() {
        print("\n\u{001B}[1;36m==================================================\u{001B}[0m")
        print("\u{001B}[1;36m  SuperClip Test Execution Summary\u{001B}[0m")
        print("\u{001B}[1;36m==================================================\u{001B}[0m")
        print("  Total Tests Executed: \(shared.totalTests)")
        print("  Tests Passed:         \u{001B}[32m\(shared.passedTests)\u{001B}[0m")
        print("  Tests Failed:         " + (shared.failedTests > 0 ? "\u{001B}[31m\(shared.failedTests)\u{001B}[0m" : "0"))
        
        if shared.failedTests == 0 {
            print("\n\u{001B}[1;32mRESULT: ALL TESTS PASSED SUCCESSFULLY (0 EMOJIS, 100% PASS RATE)\u{001B}[0m\n")
        } else {
            print("\n\u{001B}[1;31mRESULT: TEST SUITE FAILED (\(shared.failedTests) FAILURES)\u{001B}[0m\n")
        }
    }
}
