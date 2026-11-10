# Requirements Document

## Introduction

This feature restyles Gatekeeper's Ward to match the reference mock `docs/Planning/Styles/The Castle Keep & The Wandering Spirits.jpg`. It replaces the emoji in the HUD header with vector-drawn characters, gives the Fortress HUD a themed illustrated look, and enlarges the menu bar icon so that it shows two figures: a smaller solo spirit and a larger cloaked spirit, in the style of the pair at the top right of the mock. All art is drawn in code as vectors (SwiftUI `Shape` and `Canvas`, AppKit `NSBezierPath`). No raster assets are used. The HUD stays compact and informational. The two action buttons in the mock become instruction pills that repeat the wording the HUD already uses to tell the user what to press in Apple's dialog. This feature extends `.kiro/specs/ward-app` and `.kiro/specs/hud-placement-and-menubar-theme`, and closes ward-app task 8.9.

## Glossary

- **Ward**: The Gatekeeper's Ward menu bar application.
- **Fortress_HUD**: The SwiftUI card in `FortressHUDView.swift`, hosted by the non-activating `Fortress_HUD_Window`.
- **Castle_Keep_Palette**: The colour tokens in `CastlePalette.swift` and the steering file `project.md`.
- **Ectoplasm_Shade**: The secondary Spectral Ectoplasm tone `#C7D2FE`, used for ghost shading.
- **Ghost_Figure**: The smaller vector spirit with a swooping tail, ported from `docs/Planning/Styles/solo_spirit.svg` (code name `solo`).
- **Spirit_Figure**: The larger vector cloaked spirit, ported from `docs/Planning/Styles/cloaked_spirit.svg` with a wider cloak and no drape lines (code name `cloaked`), drawn beside the Ghost_Figure.
- **Ghost_Pair**: The Ghost_Figure together with the Spirit_Figure, as in the mock's title logo.
- **Gate_Banner**: A vector illustration strip at the top of the Fortress_HUD showing the violet portcullis, torches, brick wall and floating ghosts.
- **Neon_Title**: The "GATEKEEPER'S WARD" title drawn with a violet outline and layered glow.
- **Audit_Banner**: The amber panel that shows the event heading and the raw TCC service key.
- **Lineage_Tree**: The process chain drawn as an indented tree with connector arrows and terminal tiles.
- **Risk_Legend**: The list of `RiskCategory` values present in the event, explaining the flagged arguments.
- **Instruction_Pills**: Two non-interactive pills that tell the user which button to press in Apple's dialog and what it means in Ward wording.
- **Menu_Bar_Icon**: The status item image drawn by `GhostIcon.swift`.
- **Idle_Pose** and **Alert_Pose**: As defined in `.kiro/specs/hud-placement-and-menubar-theme`.
- **Reduce_Motion**: The macOS accessibility setting that asks apps to limit animation.

## Requirements

### Requirement 1: Palette decision and emoji removal

**User Story:** As a designer, I want one agreed palette and no emoji in the interface, so that the Ward looks consistent and hand-made.

#### Acceptance Criteria

1. THE Ward SHALL adopt the Ectoplasm_Shade `#C7D2FE` as a named role in `CastlePalette`, next to Spectral Ectoplasm `#E0E7FF`.
2. THE Ward SHALL update `.kiro/steering/project.md` and `.kiro/steering/swiftui-hud-design.md` so that the palette tables list the Ectoplasm_Shade and describe the Ghost_Pair in place of the emoji header.
3. THE Fortress_HUD SHALL contain no emoji characters in its header or titles.
4. THE Fortress_HUD SHALL draw the Ghost_Pair as vector art in the header.
5. THE Ward SHALL keep all hex values in `CastlePalette.swift` and `GhostIcon.swift` (the AppKit copy), and views SHALL use palette roles only.

### Requirement 2: Vector characters

**User Story:** As a user, I want playful ghost characters, so that the tool feels friendly instead of alarming.

#### Acceptance Criteria

1. THE Ward SHALL provide a vector Ghost_Figure with the body outline of `solo_spirit.svg`, round dark eyes with glints, blush cheeks, a smile and a gloss highlight, filled with a vertical gradient from `#E0E7FF` to the Ectoplasm_Shade with a deeper violet tint at the bottom edge.
2. THE Ward SHALL provide a vector Spirit_Figure with the body outline and face of `cloaked_spirit.svg`, except that the lower body (hem and flare) is about 22% wider than in the SVG and the SVG's three vertical drape lines (two folds and a centre crease) are omitted, in the same gradient.
3. THE Ward SHALL draw each figure with a two-tone dark purple outline (Midnight Violet outside, Spirit Ink inside) and, at full detail, a soft Kiro Violet aura behind it.
4. THE Ghost_Figure SHALL support at least the expressions: happy, sleepy and surprised.
5. THE figures SHALL scale cleanly from 16 pt to 120 pt without raster assets.
6. THE Ward SHALL draw the figures with one shared renderer, at a compact detail level for the menu bar and a full detail level for the HUD and review images, so the characters look the same everywhere.
7. THE Spirit_Figure SHALL lean gently to the right: its lower body SHALL sweep to the right of the head's centre line, with the right end of the hem curling up slightly, while the head and face stay as in the SVG. The Ghost_Figure keeps the shape of `solo_spirit.svg`.
8. THE Ward SHALL shade each figure at full detail with layered gradients: a lavender interior that is darker than the edges, a soft white highlight near the top of the head, a violet bounce light at the hem, a bright inner rim light along the contour, a main gloss highlight and a small sparkle highlight. At compact detail it SHALL keep the base gradient, a thin rim light and the main highlight.
9. WHERE the figures are drawn at full detail, THE Ward SHALL fade the lower body and its outline toward transparent so the tail looks translucent. THE Menu_Bar_Icon SHALL stay opaque so it looks the same on light and dark bars.

### Requirement 3: Illustrated Fortress HUD

**User Story:** As a user, I want the HUD to look like the Castle Keep, so that the forensics feel part of the story.

#### Acceptance Criteria

1. THE Fortress_HUD SHALL show a Gate_Banner at the top, drawn with `Canvas` or `Shape`, containing a violet portcullis with spikes and scroll work, two torches with amber flames, a brick wall in Obsidian Slate tones, at least two floating Ghost_Figures, and small sparkles around the figures.
2. THE Fortress_HUD SHALL show the Neon_Title with the Ghost_Pair at its right.
3. THE Fortress_HUD SHALL show an Audit_Banner with the heading "SECURITY AUDIT: TCC EVENT DETECTED" and the raw TCC service key, on an amber-tinted background with an amber border.
4. THE Fortress_HUD SHALL keep the status text "Spirit Paused at the Gate" visible.
5. THE Fortress_HUD SHALL draw the Lineage_Tree with indentation per depth, a connector arrow between parent and child, and a rounded terminal-style tile holding the spirit icon for each process, and SHALL highlight the asking process.
6. THE Fortress_HUD SHALL keep the per-process spirit icons that the lineage already shows.
7. THE Fortress_HUD SHALL show a Risk_Legend that lists only the `RiskCategory` values present in the current event's risk tags (credential file, network tool, encoding, secret path), each with an icon and a short label, and SHALL show no legend when there are no risk tags.
8. THE Fortress_HUD SHALL show the executed command in a monospaced box with an amber border (crimson when the status is suspicious) and a `vault:` line naming the requested vault, and a working directory line when known. THE command box SHALL grow taller to show the whole command, up to 12 lines, and the full text SHALL stay available as a tooltip and by text selection.
9. THE Fortress_HUD SHALL be 400 pt wide. Its height SHALL grow with its content: at most 720 pt for typical content, and never more than 900 pt (the hard cap), so that it fits beside Apple's alert.
10. THE Fortress_HUD SHALL keep the Obsidian Slate frosted background, the Wrought Iron edge and the dark colour scheme.

### Requirement 4: Instruction pills

**User Story:** As a user, I want to be told which button to press in Apple's dialog, so that I do not look for controls the Ward does not have.

#### Acceptance Criteria

1. THE Fortress_HUD SHALL show two Instruction_Pills: one reading "Don't Allow" with the meaning "Lower Portcullis" in Mischief Crimson, and one reading "Allow" with the meaning "Let Spirit Pass" in Torchlight Amber.
2. THE Fortress_HUD SHALL show the line "Answer in Apple's dialog" with the pills.
3. THE Instruction_Pills SHALL NOT be buttons, SHALL NOT respond to clicks, and SHALL be excluded from hit testing and from the accessibility actions list.
4. THE Fortress_HUD SHALL NOT use the words "Block" or "Banish" as button labels.
5. THE Fortress_HUD SHALL expose the instruction text to VoiceOver as one static text element.

### Requirement 5: Larger two-figure menu bar icon

**User Story:** As a user, I want a bigger, more characterful menu bar icon, so that I notice it and enjoy it.

#### Acceptance Criteria

1. THE Menu_Bar_Icon SHALL show the Ghost_Pair: a smaller Ghost_Figure and a larger Spirit_Figure side by side.
2. THE Menu_Bar_Icon SHALL be about 22 pt tall and at most 40 pt wide, and the status item SHALL use a variable length to fit it.
3. THE Menu_Bar_Icon SHALL stay a full-colour, non-template image that renders identical pixels under light and dark appearances.
4. THE Menu_Bar_Icon SHALL keep the existing three poses, idle, alert and alertBlink, and the existing animation timing.
5. WHILE in the Idle_Pose, THE Menu_Bar_Icon SHALL show both figures with half-closed or sleepy eyes and no lantern.
6. WHILE in an Alert_Pose, THE Menu_Bar_Icon SHALL show wide eyes on both figures and a Torchlight Amber lantern raised in the alert pose and lowered in the alertBlink pose.
7. THE Menu_Bar_Icon SHALL stay legible at 1x and 2x, with the eyes cut out as transparent areas or drawn in fixed colours.
8. THE Menu_Bar_Controller SHALL keep the accessibility label and tooltip text for both states.
9. THE Menu_Bar_Icon SHALL stay readable at its real size: its outline SHALL be strong (about 1.4 pt), its eyes and smile SHALL be drawn larger than in the full-detail art, and details that do not survive at that size (gloss highlight, rim light, blush) SHALL be left out.
10. WHILE in an Alert_Pose, THE Menu_Bar_Icon SHALL pulse: the two alert frames SHALL alternate between the normal palette (light body, dark outline) and an inverted palette (dark body, light outline and features), about every 0.5 s, with the lantern raised in the normal frame and lowered in the inverted frame.

### Requirement 6: Accessibility and motion

**User Story:** As a user with accessibility needs, I want the new visuals to respect my settings, so that the HUD stays usable.

#### Acceptance Criteria

1. THE Fortress_HUD SHALL mark decorative art (Gate_Banner, glows, figures) as hidden from VoiceOver.
2. THE Fortress_HUD SHALL keep body text at a contrast ratio of at least 4.5:1 against its background.
3. WHERE Reduce_Motion is enabled, THE Fortress_HUD SHALL show no looping animation, and the torch flames and glows SHALL be static.
4. WHERE Reduce_Motion is not enabled, THE Fortress_HUD MAY animate torch flames and ghost bobbing at a low, steady rate, and the animation SHALL stop when the HUD is dismissed.
5. THE Fortress_HUD SHALL keep the accessibility labels already provided for the header, lineage and risk tags.

### Requirement 7: Non-intrusive behaviour and standards

**User Story:** As a maintainer, I want the restyle to keep the existing safety and quality rules, so that nothing regresses.

#### Acceptance Criteria

1. THE Fortress_HUD_Window SHALL keep the `.nonactivatingPanel` and `.borderless` style mask, the `.floating` level, and `canBecomeKey` and `canBecomeMain` returning false.
2. THE Ward SHALL keep each Swift source file at or below roughly 300 lines, splitting views into new files under `HUD/` and `HUD/Art/`.
3. THE Ward SHALL provide a `///` doc comment on every new type and function.
4. THE Ward SHALL contain no force-unwrap in new production code.
5. THE Ward SHALL add no entitlements, permissions or network access.
6. THE Ward SHALL compile and pass the existing test suite after the change.

### Requirement 8: Plain-language request text

**User Story:** As a user, I want the HUD to say in plain words what is being asked, in the same words as Apple's dialog, so that I do not have to decode service names.

#### Acceptance Criteria

1. THE Fortress_HUD SHALL show one sentence that names the app asking and the resource, in the wording of Apple's dialog, for example `Allow “WardTrigger” to access your microphone?`, for every `TCCService` case; unknown services SHALL use a generic sentence.
2. THE app named SHALL be the responsible app when it differs from the process that asked, otherwise the process that asked, and SHALL be "an app" when neither could be identified.
3. THE app name SHALL be the display name from the app bundle's `Info.plist` (`CFBundleDisplayName`, else `CFBundleName`) when the executable is inside an `.app`, otherwise the process name.
4. WHEN the app's `Info.plist` has the usage description for the requested service, THE Fortress_HUD SHALL show it under the sentence. This is the same purpose text Apple's dialog shows.
5. THE Ward SHALL read only the `Info.plist` file for this, and SHALL need no new permission.
6. THE Fortress_HUD SHALL keep the raw service key visible but small and secondary to the sentence.
