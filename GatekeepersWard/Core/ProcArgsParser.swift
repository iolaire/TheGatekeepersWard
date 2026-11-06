import Foundation

/// Structured result of decoding a `KERN_PROCARGS2` byte buffer.
struct ProcArgsResult: Equatable {
    /// The null-terminated executable path that follows the argc header.
    let executablePath: String
    /// The argument vector (argv) recovered from the buffer.
    let arguments: [String]
}

/// Parses a raw `KERN_PROCARGS2` byte buffer into its executable path and
/// argument vector.
///
/// Buffer layout (see the ward-trigger design document):
///
/// ```
/// Offset 0 : argc (CInt, 4 bytes, little-endian)
/// Offset 4 : executable path (null-terminated UTF-8 C string)
///            + null padding to word alignment
/// Offset N : argv[0], argv[1], ... (null-terminated UTF-8 C strings)
///            env[0], env[1], ... (ignored — parsing stops after argc args)
/// ```
///
/// The parser bounds-checks every access and never traps: any input that does
/// not conform to the layout (too short, missing null terminators, or fewer
/// than `argc` argument strings before end-of-buffer) yields `nil`.
///
/// - Parameter buffer: Raw bytes as returned by `sysctl(KERN_PROCARGS2)`.
/// - Returns: A `ProcArgsResult`, or `nil` when the buffer is not a valid
///   `KERN_PROCARGS2` layout.
func parseProcArgsBuffer(_ buffer: [UInt8]) -> ProcArgsResult? {
    guard buffer.count >= MemoryLayout<CInt>.size else { return nil }

    let argc = Int(buffer[0])
        | Int(buffer[1]) << 8
        | Int(buffer[2]) << 16
        | Int(buffer[3]) << 24

    var offset = 4

    /// Reads one null-terminated UTF-8 C string starting at `offset`,
    /// advancing `offset` past the terminating null. Returns `nil` when the
    /// string region is empty or no null terminator exists before end-of-buffer.
    func scanCString() -> String? {
        guard offset < buffer.count else { return nil }
        let start = offset
        while offset < buffer.count && buffer[offset] != 0 {
            offset += 1
        }
        guard offset < buffer.count else { return nil }
        let bytes = buffer[start..<offset]
        offset += 1
        return String(decoding: bytes, as: UTF8.self)
    }

    guard let executablePath = scanCString(), !executablePath.isEmpty else {
        return nil
    }

    // Skip the null padding that follows the executable path so the next
    // read starts at argv[0].
    while offset < buffer.count && buffer[offset] == 0 {
        offset += 1
    }

    var arguments: [String] = []
    arguments.reserveCapacity(min(argc, 64))
    for _ in 0..<argc {
        guard let argument = scanCString() else { return nil }
        arguments.append(argument)
    }

    return ProcArgsResult(executablePath: executablePath, arguments: arguments)
}
