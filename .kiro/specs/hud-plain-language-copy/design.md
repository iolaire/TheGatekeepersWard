# Design Document

## Overview

Two copy changes to the Fortress HUD, each in one file, each shipped as its own commit so either can be reverted alone. Detection, inspection and `RiskTagger` are not touched.

| Change | File | Requirement |
|---|---|---|
| Banner_Title from the vault name | `HUD/AuditBannerView.swift` | 1 |
| Risk_Reason line per category | `HUD/RiskLegendView.swift` | 2 |

Design decisions:

- **Text lives in pure helpers, not in `body`.** `AuditBannerCopy.title(for:)` builds the title; `RiskLegendRow.reason` holds the reason. Both are unit tested without rendering.
- **The title is built from `TCCService.vaultName`.** Hard-coding "Documents" would be wrong for microphone, contacts and camera prompts.
- **The title wraps instead of shrinking.** The old heading used `minimumScaleFactor(0.8)` on 13 pt text, which can reach 10.4 pt, under the 11 pt floor. The new title uses `lineLimit(2)` with `fixedSize(horizontal: false, vertical: true)` and no scale factor. The longest title today ("A spirit is knocking at your Automation Vault", 45 characters) fits on one line or wraps to two.
- **Reasons are per category, not per pattern.** The legend shows one entry per `RiskCategory`, so a command with `.env` and `id_rsa` has one "CREDENTIAL FILE" entry. One reason per category has an obvious place and keeps the copy to four strings.
- **One line per category, label and reason side by side.** Measured on `origin/dev` before this change, the typical case in `HUDSectionTests.fitsTheBudget` was 665 pt of its 720 pt budget. A first version kept the chip row and added a reason line under it; it measured 703 pt typical, 870 pt long, and 936 pt for a long command with all four categories, over the 900 pt cap. Replacing the chips with one line per category (icon and label in crimson, reason after it, on a faint crimson panel) costs less height, so that is the design. The reasons are kept to 40 characters so each line stays on one line.

## Components

### `AuditBannerCopy` (new, in `AuditBannerView.swift`)

```swift
enum AuditBannerCopy {
    static func title(for service: TCCService) -> String  // "A spirit is knocking at your \(service.vaultName)"
}
```

`AuditBannerView` shows `AuditBannerCopy.title(for: service)` in place of the old heading, 13 pt bold rounded, Torchlight Amber, wrapping to at most two lines.

### `RiskLegendRow.reason` (new field)

`RiskLegend.row(for:)` returns the reason with the symbol and label. `RiskLegendView` renders one `RiskLegendLine` per row:

```
🔑 CREDENTIAL FILE  Usually holds passwords or API keys.
📡 NETWORK TOOL     Can send data off your Mac.
```

The VoiceOver label becomes "Risks: CREDENTIAL FILE, Usually holds passwords or API keys.; NETWORK TOOL, Can send data off your Mac." (`RiskLegend.accessibilityLabel(for:)`).

## Testing

- `HUDContentTests` / `HUDSectionTests` (Swift Testing):
  - The title for each of several services contains its vault name and never "TCC EVENT".
  - Every category in `RiskLegend.order` has a non-empty reason of at most 40 characters, and reasons are distinct.
  - Rows carry the reasons in legend order, and the VoiceOver label reads each label with its reason.
- The existing `fitsTheBudget` test is the height check. Its limits (720 pt typical, 900 pt cap) are not changed to make it pass. A case with all four categories and a long command is added to it. Measured heights are recorded in `tasks.md`.
- Manual check on a real Mac with `scripts/run_ward_trigger.sh docs curl base64 ~/.ssh/id_rsa .env`, which hits all four categories.
