import Foundation

/// Why an argument was flagged.
enum RiskCategory: String, Equatable, Sendable {
    /// Key or credential files (`.pem`, `id_rsa`, `.env`, …).
    case credentialFile
    /// Tools that can send data off the machine (`curl`, `nc`, …).
    case networkTool
    /// Encoding tools often used to smuggle data (`base64`, `xxd`).
    case encoding
    /// Paths or words that suggest secrets (`.ssh`, `token`, …).
    case secretPath
}

/// One flagged argument.
struct RiskTag: Equatable, Sendable {
    /// Index of the argument in `ProcessSnapshot.arguments`.
    let argumentIndex: Int
    /// The argument text.
    let argument: String
    /// The pattern that matched.
    let pattern: String
    /// The kind of risk.
    let category: RiskCategory
}

/// Flags suspicious arguments using the pattern list in
/// `.kiro/steering/swiftui-hud-design.md` §5.
///
/// File and secret patterns match anywhere in an argument, case-insensitive.
/// Tool names (`curl`, `nc`, `base64`, …) match only when the argument *is*
/// that program (its file name), so `nc` does not fire on words like `sync`.
/// This is informational only: Gatekeeper's Ward never blocks anything.
enum RiskTagger {
    /// Substring patterns, matched case-insensitively.
    static let substringPatterns: [(String, RiskCategory)] = [
        (".pem", .credentialFile), (".env", .credentialFile),
        ("id_rsa", .credentialFile), ("id_ed25519", .credentialFile),
        (".p12", .credentialFile), (".pfx", .credentialFile),
        ("credentials", .credentialFile),
        (".aws", .secretPath), (".ssh", .secretPath), ("keychain", .secretPath),
        ("secret", .secretPath), ("password", .secretPath),
        ("token", .secretPath), ("api_key", .secretPath),
    ]

    /// Program names, matched against an argument's file name exactly.
    static let toolPatterns: [(String, RiskCategory)] = [
        ("curl", .networkTool), ("wget", .networkTool), ("nc", .networkTool),
        ("ncat", .networkTool), ("netcat", .networkTool),
        ("base64", .encoding), ("xxd", .encoding),
    ]

    /// Returns one tag per risky argument (the first matching pattern wins).
    ///
    /// - Parameter arguments: The argv to scan.
    static func tags(for arguments: [String]) -> [RiskTag] {
        arguments.enumerated().compactMap { index, argument in
            match(argument).map { pattern, category in
                RiskTag(argumentIndex: index, argument: argument, pattern: pattern, category: category)
            }
        }
    }

    /// Tags for the inspected process's arguments.
    static func tags(for snapshot: ProcessSnapshot) -> [RiskTag] {
        tags(for: snapshot.arguments)
    }

    /// `true` when `argument` matches any pattern.
    static func isRisky(_ argument: String) -> Bool {
        match(argument) != nil
    }

    /// The first pattern `argument` matches, if any.
    private static func match(_ argument: String) -> (String, RiskCategory)? {
        if let hit = substringPatterns.first(where: { argument.localizedCaseInsensitiveContains($0.0) }) {
            return hit
        }
        // Shell one-liners like `sh -c "curl x | base64"` carry tool names as
        // words inside a single argument, so check each word's file name.
        let words = argument.split { $0.isWhitespace || "|;&()".contains($0) }
        for word in words {
            let name = (String(word) as NSString).lastPathComponent.lowercased()
            if let hit = toolPatterns.first(where: { $0.0 == name }) {
                return hit
            }
        }
        return nil
    }
}
