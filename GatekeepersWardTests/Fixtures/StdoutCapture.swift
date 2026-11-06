import Foundation

/// Serializes `captureStdout` calls. Swift Testing runs tests in parallel and
/// stdout redirection is process-global, so concurrent captures would race
/// and lose each other's output.
private let stdoutCaptureLock = NSLock()

/// Runs `body` with the process's standard output redirected into a pipe and
/// returns everything written to stdout during the call.
///
/// Uses file-descriptor redirection (`dup`/`dup2`) so both Swift `print` and
/// Foundation writes are captured, not just `FileHandle` output. Intended for
/// test code asserting on WardTrigger's stdout contract; outputs are small,
/// so the pipe buffer cannot fill.
///
/// - Parameter body: The code whose stdout output should be captured.
/// - Returns: Everything written to standard output during `body`.
func captureStdout(_ body: () -> Void) -> String {
    stdoutCaptureLock.lock()
    defer { stdoutCaptureLock.unlock() }
    fflush(stdout)
    let original = dup(STDOUT_FILENO)
    let pipe = Pipe()
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
    body()
    fflush(stdout)
    // Restore the real stdout first, then close every write end of the pipe
    // (the dup2'd STDOUT_FILENO reference and the FileHandle's own) so that
    // readDataToEndOfFile observes EOF instead of blocking forever.
    dup2(original, STDOUT_FILENO)
    close(original)
    pipe.fileHandleForWriting.closeFile()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(decoding: data, as: UTF8.self)
}
