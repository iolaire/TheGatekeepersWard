# Requirements Document

## Introduction

This feature makes two refinements to Gatekeeper's Ward. First, the menu bar ghost becomes a full-colour, non-template image in the Castle Keep palette that looks identical on light and dark menu bars. Second, the Fortress HUD is placed beside Apple's TCC alert instead of at a fixed screen corner. The Ward locates the alert through the window server's public window list, which needs no Accessibility permission. The Ward aligns the HUD top with the alert top and puts the HUD 10 px to the right of the alert. If the alert cannot be found, the Ward falls back to the existing top-right placement. The geometry is computed by a pure, unit-tested type. This feature extends `.kiro/specs/ward-app`.

## Glossary

- **Ward**: The Gatekeeper's Ward menu bar application.
- **Ghost_Icon**: The menu bar status item image drawn by `GhostIcon.swift`.
- **Menu_Bar_Controller**: The component in `MenuBarController.swift` that owns the status item and sets the Ghost_Icon image.
- **Alert_Pose**: Any Ghost_Icon pose shown while a TCC event is active, in which the ghost raises a lantern.
- **Idle_Pose**: The Ghost_Icon pose shown when no TCC event is active.
- **Castle_Keep_Palette**: The colour tokens defined in the project steering: Spectral Ectoplasm `#E0E7FF` and `#C7D2FE`, Kiro Violet `#8B5CF6`, Torchlight Amber `#F59E0B`, Obsidian Slate `#0E1013`.
- **TCC_Alert**: The on-screen permission dialog that macOS displays for a TCC request.
- **Alert_Locator**: The component that queries the window server's window list (`CGWindowListCopyWindowInfo`) and returns the bounds of the TCC_Alert.
- **Placement_Calculator**: A pure type with no AppKit or CoreGraphics window-server dependency. It maps alert bounds, HUD size, primary screen height and screen visible frame to a HUD origin.
- **Fortress_HUD_Window**: The non-activating `NSPanel` in `FortressHUDWindow.swift` that hosts the Fortress HUD.
- **CG_Bounds**: A rectangle in Core Graphics global display coordinates, with the origin at the top-left of the primary screen and y increasing downward.
- **AppKit_Frame**: A rectangle in AppKit screen coordinates, with the origin at the bottom-left of the primary screen and y increasing upward.
- **Gap**: The 10 px horizontal distance between the TCC_Alert and the HUD.
- **Locate_Timeout**: The maximum polling duration for the Alert_Locator, 1 second.
- **Fallback_Placement**: The existing placement of the Fortress_HUD_Window at the top-right of the main screen's visible frame, with a 16 px margin.

## Requirements

### Requirement 1: Full-colour menu bar ghost

**User Story:** As a user, I want the menu bar ghost to look the same on light and dark menu bars, so that I can recognise the Ward at a glance.

#### Acceptance Criteria

1. THE Menu_Bar_Controller SHALL set the Ghost_Icon image with `isTemplate` equal to false.
2. THE Ghost_Icon SHALL render the ghost body in Spectral Ectoplasm, using `#E0E7FF` and `#C7D2FE`.
3. THE Ghost_Icon SHALL render the ghost outline in Kiro Violet `#8B5CF6`.
4. THE Ghost_Icon SHALL render the ghost eyes either as transparent cut-outs or in Obsidian Slate `#0E1013`.
5. WHILE the Ghost_Icon is in an Alert_Pose, THE Ghost_Icon SHALL render the lantern in Torchlight Amber `#F59E0B`.
6. WHILE the Ghost_Icon is in the Idle_Pose, THE Ghost_Icon SHALL render no Torchlight Amber lantern.
7. WHEN the system menu bar appearance changes between light and dark, THE Ghost_Icon SHALL keep its rendered pixel colours unchanged.
8. THE Ghost_Icon SHALL retain the existing Idle_Pose and Alert_Pose set and their animation behaviour.

### Requirement 2: HUD placement beside the TCC alert

**User Story:** As a user, I want the Fortress HUD to appear next to Apple's permission dialog, so that I can read the forensics and the prompt together.

#### Acceptance Criteria

1. WHEN the Fortress_HUD_Window is asked to present content, THE Alert_Locator SHALL search the window server's on-screen window list for the TCC_Alert.
2. THE Alert_Locator SHALL read each window's owner name, layer and CG_Bounds without requiring the Accessibility permission.
3. THE Alert_Locator SHALL identify the TCC_Alert using the owner name and window layer values recorded from an empirical check on a real macOS system.
4. WHILE the TCC_Alert has not been found and less than the Locate_Timeout has elapsed, THE Alert_Locator SHALL repeat the search at a fixed polling interval of no more than 100 ms.
5. WHEN the Alert_Locator finds the TCC_Alert, THE Fortress_HUD_Window SHALL be placed at the origin returned by the Placement_Calculator.
6. IF the Alert_Locator does not find the TCC_Alert within the Locate_Timeout, THEN THE Fortress_HUD_Window SHALL use the Fallback_Placement.
7. IF the window list query returns no entries or entries without bounds, THEN THE Fortress_HUD_Window SHALL use the Fallback_Placement.
8. WHILE the Alert_Locator is polling, THE Fortress_HUD_Window SHALL leave the main thread unblocked.

### Requirement 3: Pure placement calculation

**User Story:** As a developer, I want the placement geometry in a pure type, so that it can be unit tested without a screen or a real alert.

#### Acceptance Criteria

1. THE Placement_Calculator SHALL accept the alert CG_Bounds, the HUD size, the primary screen height and the target screen visible frame as inputs and return an AppKit_Frame origin.
2. THE Placement_Calculator SHALL convert a CG_Bounds top edge to an AppKit_Frame top edge as the primary screen height minus the CG_Bounds minY.
3. THE Placement_Calculator SHALL set the HUD top edge equal to the TCC_Alert top edge, subject to clamping.
4. THE Placement_Calculator SHALL set the HUD left edge equal to the TCC_Alert right edge plus the Gap, subject to clamping.
5. IF the HUD frame would extend beyond the right edge of the visible frame, THEN THE Placement_Calculator SHALL place the HUD right edge at the TCC_Alert left edge minus the Gap.
6. IF the left-of-alert placement would extend beyond the left edge of the visible frame, THEN THE Placement_Calculator SHALL clamp the HUD frame horizontally inside the visible frame.
7. IF the HUD frame would extend above the top edge or below the bottom edge of the visible frame, THEN THE Placement_Calculator SHALL shift the HUD frame vertically so that it lies inside the visible frame.
8. IF the HUD size is larger than the visible frame in a dimension, THEN THE Placement_Calculator SHALL align the HUD frame to the visible frame top or left edge in that dimension.
9. THE Placement_Calculator SHALL return identical outputs for identical inputs.
10. THE Placement_Calculator SHALL be covered by unit tests for the right-side case, the left-side case, vertical clamping, horizontal clamping, an oversized HUD and the coordinate conversion.

### Requirement 4: Non-intrusive panel behaviour

**User Story:** As a user, I want the HUD never to interfere with Apple's dialog, so that I can answer the prompt normally.

#### Acceptance Criteria

1. THE Fortress_HUD_Window SHALL keep the `.nonactivatingPanel` and `.borderless` style mask and the `.floating` level.
2. THE Fortress_HUD_Window SHALL return false from `canBecomeKey` and `canBecomeMain`.
3. WHEN the Fortress_HUD_Window is positioned, THE Fortress_HUD_Window SHALL be ordered front without making it key.
4. WHEN the HUD size changes between presentations, THE Fortress_HUD_Window SHALL recompute the placement using the new size.

### Requirement 5: Project standards

**User Story:** As a maintainer, I want the change to follow project standards, so that the codebase stays consistent for the hackathon review.

#### Acceptance Criteria

1. THE Ward SHALL keep each modified or new Swift source file at or below roughly 300 lines.
2. THE Ward SHALL provide a `///` doc comment on every new public or internal type and function.
3. THE Ward SHALL contain no force-unwrap in new production code.
4. THE Ward SHALL document the empirically verified TCC_Alert owner name and window layer in the Alert_Locator doc comment and in `docs/devlog.md`.
5. THE Ward SHALL compile and pass the existing test suite after the change.
