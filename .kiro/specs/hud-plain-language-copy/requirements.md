# Requirements Document

## Introduction

This feature makes two copy changes to the Fortress HUD so that people who do not know macOS terms can read it. First, the Audit_Banner heading "SECURITY AUDIT: TCC EVENT DETECTED" is replaced by a sentence that names the requested vault, such as "A spirit is knocking at your Documents Vault". Second, the Risk_Legend gains one short line per risk category that says why the flagged arguments are risky. Both changes only change displayed text and layout; detection, inspection and risk tagging are unchanged. The feature amends Requirements 3.3 and 3.7 of `.kiro/specs/castle-keep-visual-theme` and closes the open item "a clearer title than TCC EVENT DETECTED" in `docs/devlog.md` (Day 6) and `docs/HACKATHON_REVIEW.md`.

## Glossary

- **Fortress_HUD**: The card shown beside Apple's TCC alert (`FortressHUDView`).
- **Audit_Banner**: The amber panel under the header (`AuditBannerView`).
- **Banner_Title**: The first line of the Audit_Banner.
- **Vault_Name**: The lore name of the requested service, `TCCService.vaultName` (for example "Documents Vault", "Contacts Registry", "Voice Chamber").
- **Risk_Legend**: The crimson chips for the `RiskCategory` values present in the event (`RiskLegendView`).
- **Risk_Reason**: A one-line, plain-language explanation of why a `RiskCategory` is risky.
- **Height_Budget**: Requirement 3.9 of `castle-keep-visual-theme`: typical content at most 720 pt tall, any content at most 900 pt.

## Requirements

### Requirement 1: Plain-language banner title

**User Story:** As a user who does not know what "TCC" means, I want the banner to say in plain words what is happening, so that I understand the alert at a glance.

#### Acceptance Criteria

1. THE Audit_Banner SHALL show the Banner_Title "A spirit is knocking at your " followed by the Vault_Name of the requested service.
2. THE Banner_Title SHALL be built from `TCCService.vaultName` for every service, including unknown services ("Unknown Vault"), and SHALL NOT hard-code a vault.
3. THE Fortress_HUD SHALL NOT show the string "TCC EVENT DETECTED".
4. THE Banner_Title SHALL be rendered at 11 pt or larger at all times; it SHALL wrap to a second line instead of shrinking below 11 pt.
5. THE Audit_Banner SHALL keep the plain-language request sentence, the app's stated reason, the status line and the raw service key unchanged.

### Requirement 2: Risk reasons

**User Story:** As a user, I want a short reason next to each risk category, so that I know why an argument was flagged before I answer Apple's dialog.

#### Acceptance Criteria

1. THE Risk_Legend SHALL show one Risk_Reason line for each `RiskCategory` it shows, in the same order as the chips.
2. THE Risk_Reasons SHALL be:
   - credential file: "Key and .env files usually hold passwords or API keys."
   - secret path: "This path or word often points to stored secrets."
   - network tool: "This tool can send data off your Mac."
   - encoding tool: "Encoding can disguise data before it is sent out."
3. EACH Risk_Reason SHALL be at most 60 characters, so that it fits on one line at the 400 pt card width.
4. THE Risk_Reason text SHALL be 11 pt in Spectral Ectoplasm at 75% opacity, with the category's icon in Mischief Crimson.
5. WHEN no argument is flagged, THE Risk_Legend SHALL show no chips and no Risk_Reason.
6. THE Risk_Legend's VoiceOver label SHALL include each category label and its Risk_Reason.
7. THE Fortress_HUD SHALL stay within the Height_Budget with the Risk_Reasons added.

### Requirement 3: Documentation

**User Story:** As a maintainer, I want the canonical copy recorded in one place, so that code and docs agree.

#### Acceptance Criteria

1. THE UI copy table in `.kiro/steering/swiftui-hud-design.md` §7 SHALL list the Banner_Title and the four Risk_Reasons.
2. Requirements 3.3 and 3.7 and the HUD sections list in `.kiro/specs/castle-keep-visual-theme` SHALL describe the new Banner_Title and Risk_Reasons.
