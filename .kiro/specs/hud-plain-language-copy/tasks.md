# Implementation Plan: HUD Plain-Language Copy

## Overview

Swift 6, Swift Testing. The banner title ships first, then the risk reasons, as separate commits. Each task ends with `swift build && swift test --skip integration` passing.

## Tasks

- [x] 1. Plain-language banner title
  - [x] 1.1 Add `AuditBannerCopy.title(for:)` and use it in `AuditBannerView`
    - Build the title from `TCCService.vaultName`; remove "SECURITY AUDIT: TCC EVENT DETECTED"
    - 13 pt bold rounded, Torchlight Amber, `lineLimit(2)`, wraps vertically, no `minimumScaleFactor`
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_
  - [x] 1.2 Unit tests for the title
    - Title contains the vault name for documents, contacts, microphone and an unknown key; never contains "TCC EVENT"
    - _Requirements: 1.1, 1.2, 1.3_
  - [x] 1.3 Update the copy docs
    - Add the title to steering §7; amend `castle-keep-visual-theme` Requirement 3.3 and the `AuditBannerView` line in its design
    - _Requirements: 3.1, 3.2_

- [ ] 2. Risk reasons
  - [ ] 2.1 Add `reason` to `RiskLegendRow` and render reason lines in `RiskLegendView`
    - Keep the `FlowLayout` chip row; add one 11 pt line per category below it, icon in Mischief Crimson, text in Spectral Ectoplasm at 75%
    - Include label and reason in the VoiceOver label
    - _Requirements: 2.1, 2.2, 2.4, 2.5, 2.6_
  - [ ] 2.2 Unit tests for the reasons
    - Every category has a distinct, non-empty reason of at most 60 characters; rows keep chip order
    - _Requirements: 2.1, 2.2, 2.3, 2.5_
  - [ ] 2.3 Check the Height_Budget
    - Run `fitsTheBudget` unchanged and record the measured heights below
    - _Requirements: 2.7_
  - [ ] 2.4 Update the copy docs
    - Add the four reasons to steering §7; amend `castle-keep-visual-theme` Requirement 3.7 and the `RiskLegendView` line in its design
    - _Requirements: 3.1, 3.2_

- [ ] 3. Final checkpoint
  - Full `swift build && swift test --skip integration`; manual check with `scripts/run_ward_trigger.sh docs curl base64 ~/.ssh/id_rsa .env`
  - _Requirements: 1.4, 2.7_

## Measured heights (`fitsTheBudget`)

| Case | Before | After task 1 | After task 2 | Limit |
|---|---|---|---|---|
| no process | 375 pt | 375 pt | | 720 pt |
| typical | 665 pt | 665 pt | | 720 pt |
| long chain and command | 832 pt | 832 pt | | 900 pt |

## Notes

- Manual verification on a real Mac (`WardTrigger`) is done by the user and is not a coding task.
