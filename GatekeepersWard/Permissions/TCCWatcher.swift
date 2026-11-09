import Foundation
import os

private let logger = Logger(subsystem: "com.gatekeepersward.app", category: "TCCWatcher")

/// A TCC permission prompt that is on screen now.
struct TCCPrompt: Equatable, Sendable {
    /// The protected service being requested.
    let service: TCCService
    /// PID of the process that touched the resource, when known.
    let clientPID: Int?
    /// PID of the app macOS holds responsible, when known.
    let responsiblePID: Int?
    /// The `msgID` shared by the request's log lines, when present.
    let messageID: String?
    /// When Gatekeeper's Ward saw the prompt.
    let detectedAt: Date
}

/// The outcome macOS logged for a prompt (`AUTHREQ_RESULT`).
struct TCCPromptResult: Equatable, Sendable {
    /// The request identifier.
    let messageID: String
    /// `true` when access was granted (`authValue=2`).
    let isAllowed: Bool
}

/// Something the watcher reports to the app.
enum TCCWatcherEvent: Equatable, Sendable {
    /// A prompt appeared.
    case prompt(TCCPrompt)
    /// A prompt was answered.
    case resolved(TCCPromptResult)
}

/// Turns parsed log lines into watcher events. Pure and synchronous so it can
/// be tested with captured logs; `TCCWatcher` feeds it the live stream.
struct TCCEventPipeline {
    private var correlator = TCCRequestCorrelator()

    /// Processes one NDJSON line.
    ///
    /// - Returns: `.prompt` for `AUTHREQ_PROMPTING` lines (and older one-line
    ///   wordings that carry a PID), `.resolved` for `AUTHREQ_RESULT` lines,
    ///   otherwise `nil`.
    mutating func process(_ line: String, now: Date = Date()) -> TCCWatcherEvent? {
        guard let event = correlator.ingest(line) else { return nil }
        let message = event.logEvent.eventMessage
        let messageID = extractTCCMessageID(from: message)

        if message.hasPrefix("AUTHREQ_RESULT:") {
            guard let messageID,
                  let value = message.firstMatch(of: #/\bauthValue=(\d+)/#)
            else { return nil }
            return .resolved(TCCPromptResult(messageID: messageID, isAllowed: value.1 == "2"))
        }

        let isPrompt = message.hasPrefix("AUTHREQ_PROMPTING:")
        // Older wordings (patterns A/B) are single lines that already carry
        // the client PID; treat those as prompts too.
        let isLegacyPrompt = !message.hasPrefix("AUTHREQ_") && event.clientPID != nil
        guard isPrompt || isLegacyPrompt else { return nil }
        return .prompt(TCCPrompt(
            service: event.service,
            clientPID: event.clientPID,
            responsiblePID: event.responsiblePID,
            messageID: messageID,
            detectedAt: now
        ))
    }
}

/// Streams TCC prompts by running `/usr/bin/log stream` as a child process.
///
/// Reads the public unified log only; needs no entitlement. Restarts the
/// subprocess if it exits unexpectedly (e.g. after sleep): after 2 seconds
/// first, then with doubling delays up to 60 seconds if it keeps failing.
actor TCCWatcher {
    /// Arguments for `/usr/bin/log`, per `.kiro/steering/log-stream-parsing.md`.
    static let logArguments = [
        "stream", "--style", "ndjson", "--level", "info",
        "--predicate", #"subsystem == "com.apple.TCC""#,
    ]

    /// Watcher events, in log order.
    nonisolated let events: AsyncStream<TCCWatcherEvent>
    private let continuation: AsyncStream<TCCWatcherEvent>.Continuation
    private var process: Process?
    private var isRunning = false
    private var restartTask: Task<Void, Never>?
    /// Restarts since the subprocess last ran steadily; drives the backoff.
    private var consecutiveFailures = 0
    private var startedAt: Date?

    /// A subprocess that ran at least this long counts as healthy.
    static let healthyRunTime: TimeInterval = 30

    /// Seconds to wait before restart number `failures` (1-based): 2, 4, 8, ...
    /// capped at 60, so a broken `log` binary is not relaunched in a tight loop.
    static func restartDelay(afterFailures failures: Int) -> TimeInterval {
        let exponent = min(max(failures - 1, 0), 5)
        return min(2 * Double(1 << exponent), 60)
    }

    /// Creates a stopped watcher. Call `start()` to begin streaming.
    init() {
        (events, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(64))
    }

    /// Starts `log stream`. Does nothing if already running.
    func start() {
        guard process == nil else { return }
        isRunning = true
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/log")
        proc.arguments = Self.logArguments
        proc.qualityOfService = .userInitiated
        let output = Pipe()
        let errors = Pipe()
        proc.standardOutput = output
        proc.standardError = errors
        // Always drain stderr so it can never fill the pipe, and log what
        // `log stream` says (bad predicate, permission problems) for diagnosis.
        errors.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            let text = String(decoding: data.prefix(500), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                logger.error("log stream stderr: \(text, privacy: .public)")
            }
        }
        // FileHandle calls this handler serially, one chunk at a time, so
        // the reader below sees chunks in order. Hopping into the actor with
        // a Task per chunk would not guarantee that order.
        let reader = StreamReader(continuation: continuation)
        output.fileHandleForReading.readabilityHandler = { handle in
            reader.receive(handle.availableData)
        }
        proc.terminationHandler = { [weak self] _ in
            guard let self else { return }
            Task { await self.processDidExit() }
        }
        do {
            try proc.run()
            process = proc
            startedAt = Date()
            logger.info("log stream started")
        } catch {
            logger.error("could not start log stream: \(error.localizedDescription, privacy: .public)")
            clearHandlers(of: proc)
            consecutiveFailures += 1
            scheduleRestart()
        }
    }

    /// Stops streaming and cancels any pending restart.
    func stop() {
        isRunning = false
        restartTask?.cancel()
        restartTask = nil
        if let process {
            clearHandlers(of: process)
            process.terminate()
        }
        process = nil
    }

    /// Handles an unexpected subprocess exit by scheduling a restart.
    private func processDidExit() {
        guard let process else { return }
        clearHandlers(of: process)
        self.process = nil
        guard isRunning else { return }
        if let startedAt, Date().timeIntervalSince(startedAt) >= Self.healthyRunTime {
            consecutiveFailures = 0   // it ran fine for a while; this is a fresh failure
        }
        consecutiveFailures += 1
        scheduleRestart()
    }

    private func scheduleRestart() {
        let delay = Self.restartDelay(afterFailures: consecutiveFailures)
        logger.info("log stream not running; restarting in \(Int(delay)) s")
        restartTask?.cancel()
        restartTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.start()
        }
    }

    private func clearHandlers(of process: Process) {
        (process.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        (process.standardError as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        process.terminationHandler = nil
    }
}

/// Per-subprocess parsing state. Used only from one `readabilityHandler`,
/// which FileHandle never runs concurrently with itself, so it needs no lock.
/// A fresh reader per subprocess means a restart starts with clean state.
private final class StreamReader: @unchecked Sendable {
    private var lineBuffer = LineBuffer()
    private var pipeline = TCCEventPipeline()
    private let continuation: AsyncStream<TCCWatcherEvent>.Continuation

    /// Creates a reader that yields into `continuation`.
    init(continuation: AsyncStream<TCCWatcherEvent>.Continuation) {
        self.continuation = continuation
    }

    /// Splits a stdout chunk into lines and yields any resulting events.
    func receive(_ chunk: Data) {
        guard !chunk.isEmpty else { return }
        for line in lineBuffer.append(chunk) {
            if let event = pipeline.process(line) {
                continuation.yield(event)
            }
        }
    }
}
