---
inclusion: auto
name: swiftui-hud-design
description: Guidelines for every UI component in Gatekeeper's Ward — Castle Keep palette tokens, NSPanel configuration, SwiftUI view conventions, spirit icon mapping, risk tag logic, and menu bar ghost states. Read before touching any HUD/, MenuBar/, or Resources/ file.
---

# SwiftUI & HUD Design Guidelines

Design is a formal 20% judging pillar. Every UI surface must feel like a single,
coherent product — not an assemblage of views. These rules are the single source
of truth for the Castle Keep aesthetic.

---

## 1. The Castle Keep colour palette

Never hard-code hex literals in view code. Always use the named `Color` assets
defined in `Resources/Colors.xcassets`. The canonical mapping:

| Asset name | Hex | Role |
|---|---|---|
| `SpectralEctoplasm` | `#E0E7FF` | Ghost figures (light end of the gradient), body text on dark backgrounds |
| `EctoplasmShade` | `#C7D2FE` | Ghost shading (dark end of the gradient), soft glow. In code: `CastleTone.ectoplasmShade` |
| `SpiritInk` | `#2E1065` | Spirit eyes, mouth and inner outline (AppKit: `CastleNSColors.spiritInk`) |
| `MidnightViolet` | `#3B185F` | Spirit outer outline (`CastleNSColors.midnightViolet`) |
| `BlushPink` | `#F472B6` | Spirit cheeks (`CastleNSColors.blushPink`) |
| `KiroViolet` | `#8B5CF6` | Portcullis bars, lineage tree nodes, primary headers, focus rings |
| `TorchlightAmber` | `#F59E0B` | Suspended status badge, lantern glow, elevated warnings |
| `ObsidianSlate` | `#0E1013` | Panel background (paired with `.ultraThinMaterial`) |
| `MischiefCrimson` | `#F43F5E` | Risk tag highlight for suspicious arguments |
| `WroughtIron` | `#2D3139` | Panel border, dividers, secondary chrome |

```swift
// ✅ Correct
Text("Spirit Paused at the Gate")
    .foregroundColor(Color("TorchlightAmber"))

// ❌ Hard-coded hex — breaks theming and is invisible to Xcode's color picker
Text("Spirit Paused at the Gate")
    .foregroundColor(Color(hex: "#F59E0B"))
```

---

## 2. NSPanel — FortressHUDWindow configuration

`FortressHUDWindow` must be configured exactly as follows. Any deviation risks
stealing key focus from Apple's TCC dialog or appearing behind it.

```swift
final class FortressHUDWindow: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // Must NOT steal key focus — TCC dialog retains control
        isFloatingPanel = true
        level = .floating          // above normal windows, below modal dialogs
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
    }
}
```

Rules:
- Never set `level` to `.modalPanel` or `.popUpMenu` — those can overlay the
  TCC dialog itself.
- Never call `makeKeyAndOrderFront(_:)` — use `orderFront(_:)` only.
- Position the panel near the upper-right corner of the screen that contains
  the menu bar for the active display. Use `NSScreen.main` as a fallback.
- Dismiss with a fade-out animation (0.25 s) when the TCC event resolves or
  after a 30-second auto-dismiss timeout.

---

## 3. FortressHUDView layout

The HUD card has three fixed zones. Keep them in this order; do not reorganise.

```
┌──────────────────────────────────────────────────────────┐
│ HEADER: ghost pair (vector, no emoji) · title · service  │  ← KiroViolet header bar
│ (see .kiro/specs/castle-keep-visual-theme for the full  │
│  illustrated layout: gate banner, audit banner, pills)   │
├──────────────────────────────────────────────────────────┤
│ LINEAGE TREE                                             │  ← spirit nodes
│  cursor (PID 14201)  ➔  node  ➔  zsh  ➔  rg (14582)    │
├──────────────────────────────────────────────────────────┤
│ COMMAND                                                  │  ← monospaced
│  $ rg "AWS_SECRET" ~/Documents/prod.env                  │
│                                                          │
│  Target: ~/Documents/prod.env         [🔴 .env file]     │  ← RiskTagView
│  Status: Spirit Paused at the Gate                       │  ← TorchlightAmber
└──────────────────────────────────────────────────────────┘
```

SwiftUI implementation rules:
- The root view uses `.ultraThinMaterial` as the background with a
  `Color("ObsidianSlate").opacity(0.85)` overlay so the frosted glass darkens
  to the Castle Keep tone without being fully opaque.
- The wrought-iron border: `.overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("WroughtIron"), lineWidth: 1))`.
- Fixed width: `360` points. Height is dynamic (content-sized), capped at `480`.
- All text uses `.system` font. Command line args: `.system(.callout, design: .monospaced)`.
- Minimum font size: 11pt (accessibility floor — do not go lower).

---

## 4. ProcessLineageView — spirit icon mapping

Each node in the lineage tree is rendered as a `HStack` of spirit icon + process name + PID.

**Spirit icon rules:**

| Process name pattern | SF Symbol | Colour |
|---|---|---|
| `rg`, `grep`, `find`, `fd` | `magnifyingglass` | `SpectralEctoplasm` |
| `bash`, `zsh`, `sh`, `fish` | `key.fill` | `KiroViolet` |
| `python`, `python3`, `ruby`, `node`, `bun` | `curlybraces` | `TorchlightAmber` |
| `curl`, `wget`, `nc`, `ncat` | `antenna.radiowaves.left.and.right` | `MischiefCrimson` |
| `git` | `arrow.triangle.branch` | `KiroViolet` |
| `ssh`, `scp`, `sftp` | `lock.open.fill` | `TorchlightAmber` |
| Any AI agent (`cursor`, `claude`, `kiro`, `copilot`) | `sparkles` | `KiroViolet` |
| Fallback (anything else) | `app.dashed` | `SpectralEctoplasm` |

The arrow between nodes (`➔`) uses `Image(systemName: "arrow.right")` in
`WroughtIron` colour at 10pt.

The final node (the requesting child process) is highlighted with a
`TorchlightAmber` glow: `.shadow(color: Color("TorchlightAmber").opacity(0.6), radius: 6)`.

---

## 5. RiskTagView — suspicious argument detection

`RiskTagView` scans `ProcessSnapshot.arguments` and applies `MischiefCrimson`
highlighting when any argument matches:

```swift
static let suspiciousPatterns: [String] = [
    // Credential / key files
    ".pem", ".env", "id_rsa", "id_ed25519", ".p12", ".pfx", "credentials",
    // Network exfiltration tools
    "curl", "wget", "nc", "ncat", "netcat",
    // Encoding / obfuscation
    "base64", "xxd",
    // Secrets paths
    ".aws", ".ssh", "keychain", "secret", "password", "token", "api_key",
]

func isRisky(_ argument: String) -> Bool {
    suspiciousPatterns.contains { argument.localizedCaseInsensitiveContains($0) }
}
```

Risky arguments render with:
- `MischiefCrimson` foreground
- A `MischiefCrimson.opacity(0.15)` capsule background
- A `⚠` prefix glyph

Non-risky arguments render in `SpectralEctoplasm`.

If **any** argument is risky, the status badge changes from `TorchlightAmber`
to `MischiefCrimson` and reads "Suspicious Spirit at the Gate".

---

## 6. Menu bar ghost — MenuBarController states

The status item uses a templated `NSImage` (so macOS applies the correct
light/dark tint). Two named image assets must exist in `Resources/`:

| Asset | State | Description |
|---|---|---|
| `ghost-idle` | No active TCC event | Ghost with half-closed eyes, gentle float |
| `ghost-alert` | TCC event in progress | Wide eyes, lantern raised, KiroViolet glow |

Animation:
- Idle → alert: crossfade 0.15 s, then cycle between two alert frames at 0.8 s
  interval using a `Timer` on the main run loop.
- Alert → idle: crossfade 0.5 s after HUD dismissal.

Use `NSStatusItem.button.image` for the icon; set `button.appearsDisabled = false`
at all times.

The dropdown menu sections (in order):
1. **Recent events** — last 10 TCC events, grouped by service key, formatted as
   `"rg → Documents (2 min ago)"`. Clicking opens a detail sheet.
2. Separator
3. **Clear History** — removes all in-memory events.
4. **About Gatekeeper's Ward** — version + GitHub link.
5. **Quit**

---

## 7. UI copy conventions

These are the canonical strings. Do not paraphrase them in code.

| Context | String |
|---|---|
| HUD status — process waiting | "Spirit Paused at the Gate" |
| HUD status — risky args | "Suspicious Spirit at the Gate" |
| HUD status — process exited early | "Spirit Slipped Through Before Inspection" |
| HUD status — inspection denied (EPERM) | "Spirit's Origins Are Veiled" |
| Allow button label | "Let Spirit Pass" |
| Deny button label | "Lower Portcullis" |
| History empty state | "No Spirits Detected" |
| Service: Documents | "Documents Vault" |
| Service: Contacts | "Contacts Registry" |
| Service: Camera | "Seeing-Glass" |
| Service: Microphone | "Voice Chamber" |
| Service: unknown | "Unknown Vault" |

Note: the Allow / Deny buttons are informational labels only — we do not and
cannot click Apple's TCC dialog programmatically. Display them as a reminder
of the choice the user is about to make on the native dialog.

---

## 8. Animation principles

Keep animations subtle and purposeful. This is a security utility, not a game.

- HUD slide-in: `AnyTransition.move(edge: .trailing).combined(with: .opacity)`,
  duration 0.2 s, `easeOut`.
- Spirit icon float (idle): `withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) { offset = -4 }` — 4-pt vertical float only.
- Risk tag appearance: `.transition(.scale(scale: 0.8).combined(with: .opacity))`, 0.15 s.
- No rotation, no spring overshoot on the HUD panel itself.
- Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`: when
  true, skip all animations and use instant alpha transitions.

---

## 9. Accessibility

- Every interactive element has an `.accessibilityLabel` and
  `.accessibilityHint`.
- Risk tags include `.accessibilityValue("Suspicious argument: \(arg)")`.
- The lineage tree is exposed as an `.accessibilityElement(children: .combine)`
  with label: "Process chain: \(chain.joined(separator: ", "))".
- Minimum contrast ratio: 4.5:1 for body text (WCAG AA). `SpectralEctoplasm`
  on `ObsidianSlate` passes; verify any new colour pair with Xcode's
  Accessibility Inspector before committing.
