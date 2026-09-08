// The log Beacon brings with it.
//
// A reporting SDK cannot assume its host keeps a useful log, because most
// apps don't — and the ones that do usually write to the system log, which
// is unreadable by the time anyone asks for it and impossible to attach to
// a report. So Beacon ships its own: a bounded in-memory ring the host
// writes to like any logger, whose last few hundred lines ride along with
// every report automatically.
//
// Bounded on purpose. This is a ring, not a file: it costs a fixed amount
// of memory forever, it cannot fill a disk, and it holds exactly the window
// that matters — what the app was doing just before somebody decided to
// report something.
//
// Every line is also handed to the system log, so a developer with Console
// open sees the same stream live. Nothing is written to disk unless the
// host asks for it.

import Foundation
import OSLog
import BeaconCore

public final class BeaconLog: @unchecked Sendable {

    /// The one every host uses unless it wants its own.
    public static let shared = BeaconLog()

    private let lock = NSLock()
    private var ring: [LogLine]
    private var nextSlot = 0
    private var filled = false
    private let capacity: Int
    private let subsystem: String
    private var loggers: [String: Logger] = [:]

    /// Lines below this are dropped at the door. Debug is off by default:
    /// it is the level people leave in loops.
    public var minimumLevel: LogLevel

    public init(capacity: Int = 2000,
                subsystem: String = Bundle.main.bundleIdentifier ?? "beacon",
                minimumLevel: LogLevel = .info) {
        self.capacity = max(50, capacity)
        self.subsystem = subsystem
        self.minimumLevel = minimumLevel
        self.ring = []
        self.ring.reserveCapacity(self.capacity)
    }

    // MARK: Writing

    public func log(_ level: LogLevel, _ message: String,
                    category: String = "app", at date: Date = Date()) {
        guard level >= minimumLevel else { return }
        let line = LogLine(at: date, level: level, category: category, message: message)

        lock.lock()
        if ring.count < capacity {
            ring.append(line)
        } else {
            ring[nextSlot] = line
            nextSlot = (nextSlot + 1) % capacity
            filled = true
        }
        let logger = loggers[category] ?? {
            let made = Logger(subsystem: subsystem, category: category)
            loggers[category] = made
            return made
        }()
        lock.unlock()

        // The system log gets the same line, so Console and `log stream`
        // work for anyone who wants to watch live. Marked public because a
        // line already destined for a bug report is not a private one.
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .notice: logger.notice("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        case .fault: logger.fault("\(message, privacy: .public)")
        }
    }

    public func debug(_ message: String, category: String = "app") {
        log(.debug, message, category: category)
    }
    public func info(_ message: String, category: String = "app") {
        log(.info, message, category: category)
    }
    public func notice(_ message: String, category: String = "app") {
        log(.notice, message, category: category)
    }
    public func warning(_ message: String, category: String = "app") {
        log(.warning, message, category: category)
    }
    public func error(_ message: String, category: String = "app") {
        log(.error, message, category: category)
    }
    public func fault(_ message: String, category: String = "app") {
        log(.fault, message, category: category)
    }

    // MARK: Reading

    /// The whole ring, oldest first.
    public func lines() -> [LogLine] {
        lock.lock()
        defer { lock.unlock() }
        guard filled else { return ring }
        return Array(ring[nextSlot...]) + Array(ring[..<nextSlot])
    }

    /// The last `count` lines, oldest first — what rides on a report.
    public func tail(_ count: Int) -> [LogLine] {
        let all = lines()
        guard all.count > count else { return all }
        return Array(all.suffix(count))
    }

    /// Empty it. Offered because a reporter who is about to reproduce a bug
    /// deliberately gets a far more useful log if the noise before it goes.
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        ring.removeAll(keepingCapacity: true)
        nextSlot = 0
        filled = false
    }

    /// A named writer, so a module can hold one instead of repeating its
    /// own category on every call.
    public func category(_ name: String) -> BeaconLogCategory {
        BeaconLogCategory(log: self, name: name)
    }
}

public struct BeaconLogCategory: Sendable {
    let log: BeaconLog
    let name: String

    public func debug(_ message: String) { log.debug(message, category: name) }
    public func info(_ message: String) { log.info(message, category: name) }
    public func notice(_ message: String) { log.notice(message, category: name) }
    public func warning(_ message: String) { log.warning(message, category: name) }
    public func error(_ message: String) { log.error(message, category: name) }
    public func fault(_ message: String) { log.fault(message, category: name) }
}
