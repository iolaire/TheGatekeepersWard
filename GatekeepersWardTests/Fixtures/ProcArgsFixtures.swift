import Foundation

/// Deterministic Xorshift64 pseudo-random number generator for reproducible
/// property-based test runs in CI.
///
/// Conforms to `RandomNumberGenerator`, so it can be used with `next(in:)`
/// range overloads anywhere a `SystemRandomNumberGenerator` would be used.
struct SeededRNG: RandomNumberGenerator {
    /// The current xorshift state. Must never be zero (a zero state is a
    /// fixed point of Xorshift64), so the initializer substitutes a non-zero
    /// seed constant.
    private var state: UInt64

    /// Creates a seeded generator. A zero seed is replaced with a non-zero
    /// constant because Xorshift64 cannot start from an all-zero state.
    ///
    /// - Parameter seed: Any 64-bit value; the same seed reproduces the same
    ///   input sequence.
    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    /// Produces the next 64 pseudo-random bits via the Xorshift64 recurrence.
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

/// Generates `count` random printable-ASCII strings (bytes `0x21...0x7E`,
/// lengths 1–12), suitable for round-tripping through the `KERN_PROCARGS2`
/// encoder/parser pair.
///
/// Strings are guaranteed non-empty and null-free so they survive the
/// null-terminated C-string encoding.
///
/// - Parameters:
///   - count: How many argument strings to generate.
///   - rng: The seeded random source driving the generation.
func generatePrintableASCIIArgv<R: RandomNumberGenerator>(
    count: Int,
    rng: inout R
) -> [String] {
    (0..<count).map { _ in
        let length = Int.random(in: 1...12, using: &rng)
        let bytes = (0..<length).map { _ in UInt8.random(in: 33...126, using: &rng) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Encodes an argv vector into a `KERN_PROCARGS2`-format byte buffer.
///
/// Layout: 4-byte little-endian `argc`, a fixed placeholder executable path
/// (null-terminated), null padding to 8-byte alignment relative to the start
/// of the path, then each argument as a null-terminated UTF-8 string.
///
/// - Parameter argv: The argument vector to encode. Elements must be non-empty
///   (an empty element is indistinguishable from padding in this format).
/// - Returns: The raw buffer, parseable by `parseProcArgsBuffer(_:)`.
func encodeProcArgsBuffer(argv: [String]) -> [UInt8] {
    var buffer: [UInt8] = []

    let argc = UInt32(argv.count)
    buffer.append(UInt8(truncatingIfNeeded: argc))
    buffer.append(UInt8(truncatingIfNeeded: argc >> 8))
    buffer.append(UInt8(truncatingIfNeeded: argc >> 16))
    buffer.append(UInt8(truncatingIfNeeded: argc >> 24))

    // Fixed placeholder executable path, as the real buffer carries the
    // process's own path separately from its argument vector.
    buffer += Array("/usr/local/bin/ward-trigger".utf8)
    buffer.append(0)

    // Null padding to word alignment relative to the start of the path,
    // mirroring the kernel's layout.
    while (buffer.count - 4) % 8 != 0 {
        buffer.append(0)
    }

    for argument in argv {
        buffer += Array(argument.utf8)
        buffer.append(0)
    }

    return buffer
}
