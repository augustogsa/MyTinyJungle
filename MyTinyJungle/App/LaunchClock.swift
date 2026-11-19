import Foundation
import os

/// Milliseconds from process start to the first frame and to the app being usable. Logged under
/// subsystem "launch"; with `-launchClock` also appended to Caches/launch.txt for simulator runs.
nonisolated enum LaunchClock {
    private static let log = Logger(subsystem: "com.simpleappscompany.mytinyjungle", category: "launch")
    private static let lock = NSLock()
    nonisolated(unsafe) private static var done: Set<String> = []

    static var sinceStart: Double {
        var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return 0 }
        let t = info.kp_proc.p_starttime
        let start = Double(t.tv_sec) + Double(t.tv_usec) / 1_000_000
        return (Date().timeIntervalSince1970 - start) * 1000
    }

    static func mark(_ name: String) {
        guard lock.withLock({ done.insert(name).inserted }) else { return }
        let ms = Int(sinceStart)
        log.info("\(name, privacy: .public) \(ms) ms")
        guard ProcessInfo.processInfo.arguments.contains("-launchClock") else { return }
        let url = URL.cachesDirectory.appending(path: "launch.txt")
        let line = Data("\(name) \(ms)\n".utf8)
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(line); try? h.close() }
        else { try? line.write(to: url) }
    }
}
