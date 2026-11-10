# Implementation Plan: Castle Keep Visual Theme

## Overview

Swift 5.9+, macOS 13 target, Swift Testing. The plan first settles the palette and builds the pure geometry shared by both renderers, then the menu bar icon, then the HUD sections one by one, and finally assembles and verifies the HUD. Each task keeps files near 300 lines. Tests are seeded and deterministic, matching the existing suite.

## Tasks

- [x] 1. Palette decision and steering update
  - [x] 1.1 Add `CastleTone.ectoplasmShade` and its `#C7D2FE` value in `CastlePalette`
    - Update the `GhostIcon` comment to name `#C7D2FE` as the Ectoplasm_Shade
    - _Requirements: 1.1, 1.5_
  - [x] 1.2 Update `.kiro/steering/project.md` and `.kiro/steering/swiftui-hud-design.md`
    - Add the Ectoplasm_Shade row, replace the emoji header with the Ghost_Pair, describe the Instruction_Pills copy
    - _Requirements: 1.2, 1.3_
  - [x] 1.3 Mark ward-app task 8.9 done with a pointer to this spec
    - _Requirements: 1.1, 1.2_

- [x] 2. Pure ghost geometry
  - [x] 2.1 Create `HUD/Art/GhostGeometry.swift`
    - `FigureKind`, `FaceExpression`, `PathSegment`, `EyeSpec`, `FeatureSpec`; `eyes`, `features` in unit space
    - Ported from `solo_spirit.svg` and `cloaked_spirit.svg` (cloak 22% wider, drape lines removed): `FigureKind` is `.solo` / `.cloaked`, `bodyOutline`, gloss `highlights`
    - Import `Foundation` and `CoreGraphics` only, doc comments, no force-unwrap
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 7.3, 7.4_
  - [x] 2.2 Write `GatekeepersWardTests/HUD/GhostGeometryTests.swift`
    - Closed outlines, points inside the unit square, eyes inside the body, expressions differ, determinism
    - _Requirements: 2.1, 2.2, 2.4, 2.5_

- [x] 3. Larger two-figure menu bar icon
  - [x] 3.1 Update `MenuBar/GhostIcon.swift` to draw the pair from `GhostGeometry`
    - Canvas 24 by 22 pt, solo spirit left (in front), cloaked spirit right, sleepy idle eyes, wide alert eyes, lantern raised or lowered, `isTemplate = false`, fixed sRGB only; keep `Pose` and `image(_:)`
    - Compact detail drops the aura, glints and blush
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.7_
  - [x] 3.2 Update `MenuBar/MenuBarController.swift` to `NSStatusItem.variableLength`
    - Keep timing, tooltip and accessibility labels
    - _Requirements: 5.2, 5.8_
  - [x] 3.3 Update `GatekeepersWardTests/MenuBar/GhostIconTests.swift`
    - Size, non-template, colours, amber only in alert poses, transparent eyes, identical pixels in `.aqua` and `.darkAqua`, body pixels in both halves
    - _Requirements: 5.1, 5.2, 5.3, 5.5, 5.6, 5.7_

- [x] 4. Checkpoint - build and tests pass, review the menu bar icon on a real Mac at 1x and 2x, ask the user if questions arise.
  - Reviewed on a real Mac during the first live test; the feedback became task 9.

- [x] 5. SwiftUI art
  - [x] 5.0 Create `HUD/Art/FigureRenderer.swift` and `HUD/Art/CastleNSColors.swift`
    - One AppKit renderer for both figures with `compact` (menu bar) and `full` (HUD, drafts) detail; `GhostIcon` and `ArtDraftRenderer` use it
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_
  - [x] 5.0a Sweep the cloaked spirit to the right
    - `cloakSweep` and `cloakCurl` constants in `GhostGeometry`; the unit-square window is computed from the adjusted outline so the figure stays centred with a margin; head and face unchanged
    - _Requirements: 2.2, 2.7_
  - [x] 5.0b Add layered shading to `FigureRenderer`
    - Lavender interior, soft top highlight, violet hem bounce, inner rim light, main gloss and sparkle highlight (compact keeps base gradient, thin rim, main highlight)
    - _Requirements: 2.8_
  - [x] 5.0c Fade the tail to transparent at full detail
    - Transparency layer plus a `destinationOut` gradient over the lower body; compact stays opaque
    - _Requirements: 2.9_
  - [x] 5.0d Add `HUD/Art/Sparkles.swift`
    - Four-point sparkles and tapered wisps, deterministic positions; used by the draft pair render and later by the Gate_Banner
    - _Requirements: 3.1_
  - [x] 5.1 Create `HUD/Art/FigureImage.swift`
    - SwiftUI view wrapping an `NSImage` drawing handler around `FigureRenderer` (stays vector at any size)
    - _Requirements: 2.5, 2.6_
  - [x] 5.2 Create `HUD/Art/GhostPairView.swift` and `HUD/Art/NeonTextStyle.swift`
    - _Requirements: 1.4, 3.2, 6.1_
  - [x] 5.3 Create `HUD/Art/GateBanner.swift`
    - Brick wall, arch, violet portcullis with spikes and scrolls, two torches, three floating ghosts and sparkles (`Sparkles`); the faint wisps looked like stray arcs on the banner floor, so wisps stay in the review images only; flicker only when Reduce Motion is off and stopped on dismiss
    - _Requirements: 3.1, 6.1, 6.3, 6.4_

- [x] 6. HUD sections
  - [x] 6.1 Create `HUD/HUDHeader.swift` and `HUD/AuditBannerView.swift`
    - Neon_Title with Ghost_Pair, no emoji; audit heading, raw service key, status text; crimson border when suspicious
    - _Requirements: 1.3, 1.4, 3.2, 3.3, 3.4, 6.5_
  - [x] 6.2 Create `HUD/LineageTreeView.swift` with a pure layout helper
    - Indent per depth capped at 4, connector glyphs, terminal-style tiles holding the existing spirit icons, highlighted asker, "… N more" above five rows; keep the `ProcessLineageView` type name
    - _Requirements: 3.5, 3.6, 6.5_
  - [x] 6.3 Create `HUD/RiskLegendView.swift` with a pure row builder
    - Distinct `RiskCategory` rows in a fixed order; hidden when empty; single wrapped row when more than two
    - _Requirements: 3.7_
  - [x] 6.4 Create `HUD/CommandBoxView.swift`
    - Monospaced command, `vault:` line, working directory, risk argument capsules, amber or crimson border
    - _Requirements: 3.8_
  - [x] 6.5 Create `HUD/InstructionPillsView.swift` with a pure `InstructionCopy`
    - "Don't Allow → Lower Portcullis" in crimson, "Allow → Let Spirit Pass" in amber, "Answer in Apple's dialog"; hit testing off; one combined VoiceOver element; no "Block" or "Banish"
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_
  - [x] 6.6 Write `GatekeepersWardTests/HUD/` tests
    - `RiskLegendTests`, `LineageLayoutTests`, `InstructionCopyTests`
    - _Requirements: 3.5, 3.7, 4.1, 4.4_

- [x] 7. Assemble the HUD
  - [x] 7.1 Rewrite `HUD/FortressHUDView.swift` as a composition of the sections above
    - Width 400 pt, height at most 640 pt (unclamped height tested for no-process, typical and long-chain content; master app folded into the Lineage heading, five lineage rows, two command lines), keep material background, Wrought Iron edge and dark scheme
    - _Requirements: 3.9, 3.10, 7.2_
  - [x] 7.2 Write an `ImageRenderer` size test for typical and long-chain content
    - Assert size within 420 by 640 pt
    - _Requirements: 3.9_
  - [x] 7.3 Confirm `FortressHUDWindow` still uses `.nonactivatingPanel`, `.borderless`, `.floating`, and non-key, non-main
    - Existing `FortressHUDWindowTests` must pass unchanged
    - _Requirements: 7.1_

- [x] 8. Final checkpoint
  - Run `swift build` and `swift test --skip integration`; confirm no force-unwraps, doc comments on new types, files near 300 lines or less, and no new entitlements. Done: build clean, 157 tests pass, palette check passes, no entitlement changes.
  - Manual with WardTrigger on a real Mac: HUD beside Apple's alert, Apple's dialog keeps focus, light and dark menu bars match, long lineage fits. Done by the user in the live test ("works well") after the round 1 fixes.
  - Reduce Motion (animation paused) and two prompts at once were not separately confirmed; the two-prompt check stays open as ward-app task 8.10.
  - Add a `docs/devlog.md` entry (UTC heading format, no gendered pronouns). Done.
  - _Requirements: 6.2, 6.3, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6_
- [x] 9. Live-test feedback (round 1)
  - [x] 9.1 Simplify the menu bar icon for its real size
    - `FigureRenderer` compact detail: outline about 1.4 pt, eyes about 1.5x, bolder smile, no gloss, rim light or sparkle highlight
    - _Requirements: 5.7, 5.9_
  - [x] 9.2 Pulse the alert icon with an inverted palette
    - `FigureRenderer.Style` (`normal`, `inverted`); `GhostIcon.Pose.alertBlink` uses the inverted style; alert timer 0.5 s
    - _Requirements: 5.4, 5.6, 5.10_
  - [x] 9.3 Let the command box grow with the command
    - Remove the 2-line limit (12-line limit), raise the HUD hard cap to 900 pt, update the size test
    - _Requirements: 3.8, 3.9_
  - [x] 9.4 Show the plain-language request text
    - `PromptSummary` (pure sentence per service), `AppBundleInfo` (display name and usage description from `Info.plist`), `HUDContent.requestText`, shown in `AuditBannerView`
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 8.5, 8.6_
  - [x] 9.5 Tests, draft renders, devlog
    - Sentence for every service, plist reading from a temporary bundle, inverted icon pixels, command growth
    - _Requirements: 3.8, 5.9, 5.10, 8.1 to 8.6_

## Notes

- The HUD stays informational: the pills are labels, never controls.
- Task 3 comes before the HUD work so the shared geometry is proven at the smallest size first.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1"] },
    { "id": 1, "tasks": ["1.2", "1.3", "2.2", "3.1", "5.1"] },
    { "id": 2, "tasks": ["3.2", "3.3", "5.2", "6.2", "6.3", "6.5"] },
    { "id": 3, "tasks": ["5.3", "6.1", "6.4", "6.6"] },
    { "id": 4, "tasks": ["7.1"] },
    { "id": 5, "tasks": ["7.2", "7.3"] },
    { "id": 6, "tasks": ["9.1", "9.2", "9.3", "9.4"] },
    { "id": 7, "tasks": ["9.5"] }
  ]
}
```
