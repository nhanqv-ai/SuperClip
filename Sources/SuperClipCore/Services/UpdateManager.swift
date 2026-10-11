import Foundation
import AppKit
import Combine
import UserNotifications

/// Representation of a parsed semantic version (e.g. v1.0.1, 1.0.0, 1.0.0-beta.1).
public struct SemanticVersion: Comparable, Equatable, Sendable {
    public let components: [Int]
    public let prerelease: String?
    public let raw: String

    public init(_ versionString: String) {
        let trimmed = versionString.trimmingCharacters(in: .whitespacesAndNewlines)
        self.raw = trimmed

        var clean = trimmed
        if clean.lowercased().hasPrefix("v") {
            clean = String(clean.dropFirst())
        }

        // SemVer 2.0.0: strip build metadata (+...) first, as it must be ignored in precedence
        let buildParts = clean.split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true)
        let versionWithoutBuild = buildParts.first.map(String.init) ?? clean

        let parts = versionWithoutBuild.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let mainPart = parts.first ?? ""
        if parts.count > 1 {
            self.prerelease = String(parts[1])
        } else {
            self.prerelease = nil
        }

        let numParts = mainPart.split(separator: ".").compactMap { Int($0) }
        self.components = numParts.isEmpty ? [0] : numParts
    }

    public static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for i in 0..<maxCount {
            let left = i < lhs.components.count ? lhs.components[i] : 0
            let right = i < rhs.components.count ? rhs.components[i] : 0
            if left != right { return false }
        }
        return lhs.prerelease == rhs.prerelease
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for i in 0..<maxCount {
            let left = i < lhs.components.count ? lhs.components[i] : 0
            let right = i < rhs.components.count ? rhs.components[i] : 0
            if left < right { return true }
            if left > right { return false }
        }

        // Standard SemVer: version with prerelease has lower precedence than release without prerelease
        switch (lhs.prerelease, rhs.prerelease) {
        case (nil, nil):
            return false
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        case let (.some(lp), .some(rp)):
            return lp.localizedStandardCompare(rp) == .orderedAscending
        }
    }
}

/// Metadata model for a discovered GitHub Release.
public struct ReleaseInfo: Codable, Equatable, Sendable {
    public let tagName: String
    public let name: String
    public let releaseNotes: String
    public let htmlURL: URL
    public let zipAssetURL: URL?

    public var versionString: String {
        let trimmed = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    public init(
        tagName: String,
        name: String,
        releaseNotes: String,
        htmlURL: URL,
        zipAssetURL: URL? = nil
    ) {
        self.tagName = tagName
        self.name = name
        self.releaseNotes = releaseNotes
        self.htmlURL = htmlURL
        self.zipAssetURL = zipAssetURL
    }

    enum CodingKeys: String, CodingKey {
        case tagName
        case name
        case releaseNotes
        case htmlURL
        case zipAssetURL
    }
}

/// State of update checking, downloading, and staging.
public enum UpdateStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate(currentVersion: String)
    case updateAvailable(ReleaseInfo)
    case downloading(progress: Double)
    case readyToRestart(ReleaseInfo)
    case error(message: String)
}

/// Errors occurring during update operations.
public enum UpdateError: LocalizedError, Equatable {
    case invalidReleaseData
    case noAssetFound
    case noReleaseFound
    case rateLimitExceeded
    case httpError(Int)
    case downloadFailed(String)
    case unpackFailed(String)
    case appBundleNotFound
    case binaryNotExecutable
    case signatureVerificationFailed
    case stagingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidReleaseData:
            return "Failed to parse release information from GitHub API."
        case .noAssetFound:
            return "No compatible application zip asset found in release."
        case .noReleaseFound:
            return "No releases found on GitHub."
        case .rateLimitExceeded:
            return "GitHub API rate limit exceeded. Please try again later."
        case .httpError(let code):
            return "GitHub API returned HTTP status \(code)."
        case .downloadFailed(let reason):
            return "Failed to download update: \(reason)"
        case .unpackFailed(let reason):
            return "Failed to unpack application zip: \(reason)"
        case .appBundleNotFound:
            return "SuperClip.app bundle was not found in unpacked archive."
        case .binaryNotExecutable:
            return "SuperClip executable inside bundle is missing or not executable."
        case .signatureVerificationFailed:
            return "Code signature verification failed."
        case .stagingFailed(let reason):
            return "Failed to stage application into destination: \(reason)"
        }
    }
}

/// Centralized manager for GitHub releases update checking, silent download, and staging.
public final class UpdateManager: ObservableObject, @unchecked Sendable {
    public static let shared = UpdateManager()

    // MARK: - Published State

    @Published public var status: UpdateStatus = .idle
    @Published public var hasPendingUpdate: Bool = false
    @Published public var isBannerDismissedForSession: Bool = false
    @Published public var downloadProgress: Double = 0.0
    @Published public var latestRelease: ReleaseInfo? = nil
    @Published public var stagedAppURL: URL? = nil

    // MARK: - Configuration & Dependencies

    private var _customVersion: String? = nil
    public var currentVersion: String {
        get {
            _customVersion ?? (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
        }
        set {
            _customVersion = newValue
        }
    }

    public var apiURL: URL = URL(string: "https://api.github.com/repos/nhanqv-ai/SuperClip/releases/latest")!
    public var stagingTargetURL: URL = URL(fileURLWithPath: "/Applications/SuperClip.app")
    public var verifyCodeSignature: Bool = true
    public var appLauncher: (URL) -> Void = { targetURL in
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: targetURL, configuration: config, completionHandler: nil)
    }
    public var terminationHandler: () -> Void = {
        NSApp?.terminate(nil)
    }

    public var urlSession: URLSession
    public weak var storageManager: StorageManager?
    private var periodicTimer: Timer?
    private let lock = NSLock()

    // MARK: - Computed Properties

    public var isBusy: Bool {
        switch status {
        case .checking, .downloading:
            return true
        default:
            return false
        }
    }

    public var shouldShowBanner: Bool {
        guard !isBannerDismissedForSession else { return false }
        switch status {
        case .updateAvailable, .downloading, .readyToRestart:
            return true
        case .error:
            return latestRelease != nil
        default:
            return false
        }
    }

    // MARK: - Initialization

    public init(session: URLSession? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0
        config.timeoutIntervalForResource = 60.0
        self.urlSession = session ?? URLSession(configuration: config)
    }

    // MARK: - Semantic Version Comparison

    public static func isVersion(_ v1: String, greaterThan v2: String) -> Bool {
        let sem1 = SemanticVersion(v1)
        let sem2 = SemanticVersion(v2)
        return sem1 > sem2
    }

    // MARK: - GitHub Releases API Parsing

    public static func parseRelease(from data: Data) throws -> ReleaseInfo {
        struct GHAsset: Decodable {
            let name: String?
            let browserDownloadUrl: String?

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadUrl = "browser_download_url"
            }
        }

        struct GHRelease: Decodable {
            let tagName: String
            let name: String?
            let body: String?
            let htmlUrl: String?
            let assets: [GHAsset]?

            enum CodingKeys: String, CodingKey {
                case tagName = "tag_name"
                case name
                case body
                case htmlUrl = "html_url"
                case assets
            }
        }

        let decoder = JSONDecoder()
        let release = try decoder.decode(GHRelease.self, from: data)

        let releaseName = release.name ?? release.tagName
        let notes = release.body ?? ""
        let defaultURL = URL(string: "https://github.com/nhanqv-ai/SuperClip/releases")!
        let htmlURL: URL
        if let raw = release.htmlUrl, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let parsed = URL(string: raw) {
            htmlURL = parsed
        } else {
            htmlURL = defaultURL
        }

        var zipURL: URL? = nil
        if let assets = release.assets {
            // Find zip asset matching SuperClip or ending in .zip
            if let match = assets.first(where: {
                let n = $0.name?.lowercased() ?? ""
                return n.contains("superclip") && n.hasSuffix(".zip")
            }) ?? assets.first(where: { $0.name?.lowercased().hasSuffix(".zip") == true }) {
                if let raw = match.browserDownloadUrl, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let url = URL(string: raw) {
                    zipURL = url
                }
            }
        }

        return ReleaseInfo(
            tagName: release.tagName,
            name: releaseName,
            releaseNotes: notes,
            htmlURL: htmlURL,
            zipAssetURL: zipURL
        )
    }

    // MARK: - Checking for Updates

    public func checkForUpdates(userInitiated: Bool = false, completion: ((Result<ReleaseInfo?, Error>) -> Void)? = nil) {
        if case .downloading = status {
            completion?(.success(latestRelease))
            return
        }

        if case .checking = status {
            completion?(.success(latestRelease))
            return
        }

        // If an update is already downloaded and staged, background checks should not disturb it
        if !userInitiated, case .readyToRestart(let release) = status {
            completion?(.success(release))
            return
        }

        let previousStatus = self.status

        if Thread.isMainThread {
            self.status = .checking
        } else {
            DispatchQueue.main.async {
                self.status = .checking
            }
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        let sanitizedVersion = currentVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue("SuperClip/\(sanitizedVersion) (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15.0

        let task = urlSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    if case .readyToRestart = previousStatus {
                        self.status = previousStatus
                    } else {
                        self.status = .error(message: error.localizedDescription)
                    }
                    completion?(.failure(error))
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    let err = UpdateError.noReleaseFound
                    DispatchQueue.main.async {
                        if case .readyToRestart = previousStatus {
                            self.status = previousStatus
                        } else {
                            self.status = .error(message: err.localizedDescription)
                        }
                        completion?(.failure(err))
                    }
                    return
                } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 429 {
                    let err = UpdateError.rateLimitExceeded
                    DispatchQueue.main.async {
                        if case .readyToRestart = previousStatus {
                            self.status = previousStatus
                        } else {
                            self.status = .error(message: err.localizedDescription)
                        }
                        completion?(.failure(err))
                    }
                    return
                } else if !(200...299).contains(httpResponse.statusCode) {
                    let err = UpdateError.httpError(httpResponse.statusCode)
                    DispatchQueue.main.async {
                        if case .readyToRestart = previousStatus {
                            self.status = previousStatus
                        } else {
                            self.status = .error(message: err.localizedDescription)
                        }
                        completion?(.failure(err))
                    }
                    return
                }
            }

            guard let data = data else {
                let err = UpdateError.invalidReleaseData
                DispatchQueue.main.async {
                    if case .readyToRestart = previousStatus {
                        self.status = previousStatus
                    } else {
                        self.status = .error(message: err.localizedDescription)
                    }
                    completion?(.failure(err))
                }
                return
            }

            do {
                let release = try Self.parseRelease(from: data)
                let isNewer = Self.isVersion(release.tagName, greaterThan: self.currentVersion)

                DispatchQueue.main.async {
                    self.latestRelease = release
                    if isNewer {
                        // If this release is already staged, preserve readyToRestart state
                        if case .readyToRestart(let staged) = previousStatus, staged.tagName == release.tagName {
                            self.status = previousStatus
                            self.hasPendingUpdate = true
                            self.updateLastCheckDate()
                            completion?(.success(release))
                            return
                        }
                        if let stagedURL = self.stagedAppURL,
                           FileManager.default.fileExists(atPath: stagedURL.path),
                           self.latestRelease?.tagName == release.tagName {
                            self.status = .readyToRestart(release)
                            self.hasPendingUpdate = true
                            self.isBannerDismissedForSession = false
                            self.updateLastCheckDate()
                            completion?(.success(release))
                            return
                        }

                        self.status = .updateAvailable(release)
                        self.hasPendingUpdate = true
                        self.isBannerDismissedForSession = false
                        self.postUpdateNotification(release: release)
                        self.updateLastCheckDate()
                        completion?(.success(release))
                    } else {
                        if case .readyToRestart = previousStatus {
                            self.status = previousStatus
                            completion?(.success(nil))
                            return
                        }
                        self.status = .upToDate(currentVersion: self.currentVersion)
                        self.hasPendingUpdate = false
                        if userInitiated {
                            self.postUpToDateNotification(currentVersion: self.currentVersion)
                        }
                        self.updateLastCheckDate()
                        completion?(.success(nil))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    if case .readyToRestart = previousStatus {
                        self.status = previousStatus
                    } else {
                        self.status = .error(message: error.localizedDescription)
                    }
                    completion?(.failure(error))
                }
            }
        }
        task.resume()
    }

    private func updateLastCheckDate() {
        if let sm = storageManager {
            var s = sm.settings
            s.lastUpdateCheckDate = Date()
            sm.settings = s
        }
    }

    // MARK: - Banner Session Dismissal

    public func dismissBannerForSession() {
        isBannerDismissedForSession = true
    }

    // MARK: - Startup & Periodic Scheduling

    public func checkOnStartupIfNeeded(storageManager: StorageManager) {
        self.storageManager = storageManager
        guard storageManager.settings.automaticallyCheckForUpdates else { return }

        let now = Date()
        if let lastCheck = storageManager.settings.lastUpdateCheckDate {
            if now.timeIntervalSince(lastCheck) < 86400 {
                return
            }
        }

        checkForUpdates(userInitiated: false)
    }

    public func startPeriodicCheck(interval: TimeInterval = 86400, storageManager: StorageManager? = nil) {
        if let sm = storageManager {
            self.storageManager = sm
        }
        stopPeriodicCheck()

        periodicTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.storageManager?.settings.automaticallyCheckForUpdates ?? true {
                self.checkForUpdates(userInitiated: false)
            }
        }
    }

    public func stopPeriodicCheck() {
        periodicTimer?.invalidate()
        periodicTimer = nil
    }

    // MARK: - Native macOS Notifications

    public func postUpdateNotification(release: ReleaseInfo) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let send = {
                let content = UNMutableNotificationContent()
                content.title = "SuperClip Update Available"
                content.body = "SuperClip \(release.tagName) is now available."
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "com.superclip.update.\(release.tagName)",
                    content: content,
                    trigger: nil
                )
                center.add(request, withCompletionHandler: nil)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                send()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { send() }
                }
            default:
                break
            }
        }
    }

    public func postUpToDateNotification(currentVersion: String) {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            let send = {
                let content = UNMutableNotificationContent()
                content.title = "SuperClip is Up to Date"
                content.body = "SuperClip \(currentVersion) is currently the latest version."
                content.sound = .default

                let request = UNNotificationRequest(
                    identifier: "com.superclip.update.uptodate",
                    content: content,
                    trigger: nil
                )
                center.add(request, withCompletionHandler: nil)
            }

            switch settings.authorizationStatus {
            case .authorized, .provisional:
                send()
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    if granted { send() }
                }
            default:
                break
            }
        }
    }

    // MARK: - Silent Download & Safe Staging

    public func startDownloadAndInstall(
        release: ReleaseInfo,
        targetURL: URL? = nil,
        completion: ((Result<URL, Error>) -> Void)? = nil
    ) {
        guard let assetURL = release.zipAssetURL else {
            let err = UpdateError.noAssetFound
            self.status = .error(message: err.localizedDescription)
            completion?(.failure(err))
            return
        }

        self.status = .downloading(progress: 0.0)
        self.downloadProgress = 0.0

        downloadAsset(from: assetURL) { [weak self] progress in
            DispatchQueue.main.async {
                self?.downloadProgress = progress
                self?.status = .downloading(progress: progress)
            }
        } completion: { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .failure(let err):
                DispatchQueue.main.async {
                    self.status = .error(message: err.localizedDescription)
                    completion?(.failure(err))
                }

            case .success(let zipPath):
                DispatchQueue.global(qos: .userInitiated).async {
                    defer {
                        let downloadDir = zipPath.deletingLastPathComponent()
                        if downloadDir.lastPathComponent.hasPrefix("SuperClip-Update-") {
                            try? FileManager.default.removeItem(at: downloadDir)
                        } else {
                            try? FileManager.default.removeItem(at: zipPath)
                        }
                    }
                    do {
                        let stagedURL = try self.unpackAndVerify(
                            zipURL: zipPath,
                            destinationURL: targetURL ?? self.stagingTargetURL
                        )
                        DispatchQueue.main.async {
                            self.stagedAppURL = stagedURL
                            self.status = .readyToRestart(release)
                            self.isBannerDismissedForSession = false
                            completion?(.success(stagedURL))
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.status = .error(message: error.localizedDescription)
                            completion?(.failure(error))
                        }
                    }
                }
            }
        }
    }

    private func downloadAsset(
        from url: URL,
        progressHandler: @escaping (Double) -> Void,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        if url.isFileURL {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SuperClip-Update-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let dest = tempDir.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
                progressHandler(1.0)
                completion(.success(dest))
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                completion(.failure(error))
            }
            return
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SuperClip-Update-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let filename = url.lastPathComponent.isEmpty ? "SuperClip-update.zip" : url.lastPathComponent
        let dest = tempDir.appendingPathComponent(filename)

        let task = urlSession.downloadTask(with: url) { localURL, response, error in
            if let error = error {
                try? FileManager.default.removeItem(at: tempDir)
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                try? FileManager.default.removeItem(at: tempDir)
                completion(.failure(UpdateError.downloadFailed("HTTP error \(httpResponse.statusCode)")))
                return
            }
            guard let localURL = localURL else {
                try? FileManager.default.removeItem(at: tempDir)
                completion(.failure(UpdateError.downloadFailed("Downloaded file is missing.")))
                return
            }
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: localURL, to: dest)
                progressHandler(1.0)
                completion(.success(dest))
            } catch {
                try? FileManager.default.removeItem(at: tempDir)
                completion(.failure(error))
            }
        }
        task.resume()
    }

    public func unpackAndVerify(zipURL: URL, destinationURL: URL? = nil) throws -> URL {
        let fm = FileManager.default
        let unpackDir = fm.temporaryDirectory.appendingPathComponent("SuperClip-Unpacked-\(UUID().uuidString)")
        try fm.createDirectory(at: unpackDir, withIntermediateDirectories: true)

        defer {
            try? fm.removeItem(at: unpackDir)
        }

        // 1. Unpack with ditto to preserve bundle attributes & code signatures
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-xk", zipURL.path, unpackDir.path]
        let dittoPipe = Pipe()
        ditto.standardOutput = dittoPipe
        ditto.standardError = dittoPipe
        try ditto.run()
        ditto.waitUntilExit()

        if ditto.terminationStatus != 0 {
            // Fallback to unzip if ditto returns non-zero
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            unzip.arguments = ["-q", "-o", zipURL.path, "-d", unpackDir.path]
            let unzipPipe = Pipe()
            unzip.standardOutput = unzipPipe
            unzip.standardError = unzipPipe
            try unzip.run()
            unzip.waitUntilExit()
            if unzip.terminationStatus != 0 {
                throw UpdateError.unpackFailed("ditto and unzip failed to extract archive.")
            }
        }

        // 2. Discover .app bundle (top-level or in immediate subdirectories)
        var foundAppURL: URL? = nil
        let topItems = try fm.contentsOfDirectory(at: unpackDir, includingPropertiesForKeys: nil)
        if let topApp = topItems.first(where: { $0.pathExtension == "app" }) {
            foundAppURL = topApp
        } else {
            for item in topItems {
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let subItems = (try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil)) ?? []
                    if let subApp = subItems.first(where: { $0.pathExtension == "app" }) {
                        foundAppURL = subApp
                        break
                    }
                }
            }
        }

        guard let extractedAppURL = foundAppURL else {
            throw UpdateError.appBundleNotFound
        }

        // 3. Verify bundle integrity
        let binaryURL = Bundle(url: extractedAppURL)?.executableURL
            ?? extractedAppURL.appendingPathComponent("Contents/MacOS/SuperClip")
        guard fm.fileExists(atPath: binaryURL.path) && fm.isExecutableFile(atPath: binaryURL.path) else {
            throw UpdateError.binaryNotExecutable
        }

        // 4. Verify code signature
        if verifyCodeSignature {
            let codesign = Process()
            codesign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            codesign.arguments = ["-v", "--deep", "--strict", extractedAppURL.path]
            let codesignPipe = Pipe()
            codesign.standardOutput = codesignPipe
            codesign.standardError = codesignPipe
            try codesign.run()
            codesign.waitUntilExit()
            if codesign.terminationStatus != 0 {
                throw UpdateError.signatureVerificationFailed
            }
        }

        // 5. Atomically stage into destination
        let target = destinationURL ?? stagingTargetURL
        let targetParent = target.deletingLastPathComponent()

        if !fm.fileExists(atPath: targetParent.path) {
            try fm.createDirectory(at: targetParent, withIntermediateDirectories: true)
        }

        if fm.fileExists(atPath: target.path) {
            let backupName = "SuperClip.app.bak-\(UUID().uuidString)"
            let backupURL = targetParent.appendingPathComponent(backupName)
            do {
                _ = try fm.replaceItemAt(target, withItemAt: extractedAppURL, backupItemName: backupName, options: .usingNewMetadataOnly)
                try? fm.removeItem(at: backupURL)
            } catch {
                do {
                    try fm.moveItem(at: target, to: backupURL)
                } catch {
                    throw UpdateError.stagingFailed(error.localizedDescription)
                }
                do {
                    try fm.copyItem(at: extractedAppURL, to: target)
                    try? fm.removeItem(at: backupURL)
                } catch {
                    try? fm.moveItem(at: backupURL, to: target)
                    throw UpdateError.stagingFailed(error.localizedDescription)
                }
            }
        } else {
            do {
                try fm.copyItem(at: extractedAppURL, to: target)
            } catch {
                throw UpdateError.stagingFailed(error.localizedDescription)
            }
        }

        return target
    }

    // MARK: - Restart Application

    public func restartApp() {
        let target = stagedAppURL ?? stagingTargetURL
        appLauncher(target)
        terminationHandler()
    }
}
