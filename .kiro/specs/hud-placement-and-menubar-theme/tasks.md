# Implementation Plan: HUD Placement and Menu Bar Theme

## Overview

Implementation language is Swift 5.9+ (macOS 13 target), using Swift Testing. The plan first records the empirical TCC alert values, then builds the pure `PlacementCalculator` and `AlertMatcher`, then the async `AlertLocator`, then the full-colour `GhostIcon`, and finally wires placement into `FortressHUDWindow`. Property tests use a seeded generator loop of at least 100 iterations, matching the existing parser tests.

## Tasks

- [x] 1. Record the empirical TCC alert window values
  - [x] 1.1 Add a window list dump helper and record owner name and layer
    - Add a small dev script `scripts/dump_window_list.swift` that prints owner name, layer and bounds from `CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)` without reading `kCGWindowName`
    - Run it while a `WardTrigger` TCC dialog is on screen and note the owner name, layer and macOS version
    - Add an entry to `docs/devlog.md` (UTC heading format, no gendered pronouns) with the recorded values
    - _Requirements: 2.3, 5.4_

- [x] 2. Implement the pure placement calculator
  - [x] 2.1 Create `HUD/PlacementCalculator.swift`
    - Implement `PlacementCalculator.gap = 10` and `origin(alertCG:hudSize:primaryScreenHeight:visibleFrame:)`
    - Flip with `primaryScreenHeight - alertCG.minY`, prefer right of alert, flip left on overflow, then clamp horizontally (upper bound then lower bound) and vertically (min/max/min) so oversized HUDs align to top-left
    - Import `Foundation` only, add `///` doc comments, no force-unwrap
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 3.8, 3.9, 5.1, 5.2, 5.3_

  - [x] 2.2 Write property test for coordinate conversion and adjacency
    - Create `GatekeepersWardTests/HUD/PlacementCalculatorPropertyTests.swift`
    - **Property 1: Coordinate conversion and adjacency**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4**

  - [x] 2.3 Write property test for left flip
    - **Property 2: Left flip when the right side overflows**
    - **Validates: Requirements 3.5**

  - [x] 2.4 Write property test for containment
    - **Property 3: Result is contained in the visible frame**
    - **Validates: Requirements 3.6, 3.7, 4.4**

  - [x] 2.5 Write property test for oversized HUD
    - **Property 4: Oversized HUD aligns to top-left**
    - **Validates: Requirements 3.8**

  - [x] 2.6 Write unit tests for `PlacementCalculator`
    - Create `GatekeepersWardTests/HUD/PlacementCalculatorTests.swift`
    - Cover right-side, left-side, vertical clamp top and bottom, horizontal clamp, oversized HUD, known-screen coordinate conversion, and determinism
    - _Requirements: 3.9, 3.10_

- [x] 3. Implement alert matching and locating
  - [x] 3.1 Create `HUD/AlertMatcher.swift` with `WindowInfo` and `AlertMatcher`
    - Implement `WindowInfo` (optional `ownerName`, `layer`, `bounds`) and `WindowInfo.init(dictionary:)` using optional casts and `CGRect(dictionaryRepresentation:)`
    - Implement `AlertMatcher.match(_:ownerName:layer:)` returning the first entry with matching owner and layer and positive-size bounds
    - _Requirements: 2.2, 2.3, 2.7, 5.2, 5.3_

  - [x] 3.2 Create `HUD/AlertLocator.swift`
    - Implement `AlertLocator` with `timeout = 1.0`, `pollInterval = 0.1`, injectable `windowList` closure and the recorded `ownerName` and `layer` constants from task 1.1
    - Implement async `locate()` polling with `ContinuousClock` and `Task.sleep`, returning nil on timeout or cancellation
    - Default `windowList` calls `CGWindowListCopyWindowInfo` and maps entries through `WindowInfo.init(dictionary:)`; document the verified owner name, layer and macOS version in the doc comment
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.6, 2.7, 2.8, 5.2, 5.4_

  - [x] 3.3 Write property test for alert matching
    - Create `GatekeepersWardTests/HUD/AlertMatcherPropertyTests.swift`
    - **Property 5: Alert matching selects only valid matching windows**
    - **Validates: Requirements 2.2, 2.3, 2.7**

  - [x] 3.4 Write unit tests for `AlertLocator.locate()`
    - Create `GatekeepersWardTests/HUD/AlertLocatorTests.swift`
    - Found on third poll, never found returns nil after timeout, empty list returns nil, `pollInterval <= 0.1`
    - _Requirements: 2.4, 2.6, 2.7_

- [x] 4. Make the menu bar ghost full colour
  - [x] 4.1 Update `MenuBar/GhostIcon.swift` to palette colours
    - Fill body with a fixed-sRGB `NSGradient` from `#E0E7FF` to `#C7D2FE`, stroke outline in `#8B5CF6`, keep eyes as `.destinationOut` cut-outs
    - Draw the lantern in `#F59E0B` for `.alert` and `.alertBlink` only; set `isTemplate = false`
    - Use only fixed colours (reuse `CastlePalette` values where available), never system or dynamic colours; keep `Pose` and `image(_:)` signatures
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 5.2, 5.3_

  - [x] 4.2 Update `MenuBar/MenuBarController.swift`
    - Assign images from `GhostIcon.image(_:)` without mutation and remove any `contentTintColor` on the status button
    - Keep animation timing and pose sequencing unchanged
    - _Requirements: 1.1, 1.7, 1.8_

  - [x] 4.3 Write unit tests for `GhostIcon`
    - Create `GatekeepersWardTests/MenuBar/GhostIconTests.swift`
    - Per pose: `isTemplate == false`; bitmap contains body and outline colours; eye area transparent; amber present for `.alert` and `.alertBlink` and absent for `.idle`
    - Render under `.aqua` and `.darkAqua` with `performAsCurrentDrawingAppearance` and assert identical pixel buffers
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7_

- [x] 5. Wire placement into the Fortress HUD window
  - [x] 5.1 Update `HUD/FortressHUDWindow.swift` (and `FortressHUDWindow+Placement.swift` if size requires)
    - Keep `.nonactivatingPanel` and `.borderless`, `.floating` level, `canBecomeKey` and `canBecomeMain` false
    - In `present(_:)` recompute `fittingSize`, order front with `orderFrontRegardless()` at the fallback origin, start a stored `Task` awaiting `AlertLocator.locate()`, and on the main actor move the panel using `PlacementCalculator.origin`
    - Choose the target screen by alert centre, else `NSScreen.main`; use `NSScreen.screens.first?.frame.height` as primary height; keep `fallbackOrigin(size:)` top-right with 16 px margin
    - Cancel the locate task on a new `present` and on `dismiss()`; start at alpha 0 and fade in after the first locate result or timeout (alpha 1 under Reduce Motion)
    - Keep the file at or below roughly 300 lines
    - _Requirements: 2.1, 2.5, 2.6, 2.7, 2.8, 4.1, 4.2, 4.3, 4.4, 5.1, 5.2, 5.3_

  - [x] 5.2 Write unit tests for `FortressHUDWindow`
    - Create `GatekeepersWardTests/HUD/FortressHUDWindowTests.swift`
    - Assert style mask, floating level, `canBecomeKey` and `canBecomeMain` false; presenting twice with different content sizes produces frames using each size
    - _Requirements: 4.1, 4.2, 4.4_

- [x] 6. Final checkpoint - Ensure all tests pass
  - Run the build and the full existing test suite, confirm no regressions, and ask the user if questions arise.
  - _Requirements: 5.5_

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties; unit tests cover examples and edge cases
- Manual verification with `WardTrigger` (HUD beside the real alert, Apple's dialog keeps focus, main thread responsive) is done by the user and is not a coding task

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "4.1"] },
    { "id": 1, "tasks": ["2.2", "2.6", "3.1", "4.2", "4.3"] },
    { "id": 2, "tasks": ["2.3", "3.2", "3.3"] },
    { "id": 3, "tasks": ["2.4", "3.4", "5.1"] },
    { "id": 4, "tasks": ["2.5", "5.2"] }
  ]
}
```
