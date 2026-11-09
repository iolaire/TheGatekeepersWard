---
description: Kiroween 2026 submission review based on the official Devpost rules and judging criteria
---

Perform a comprehensive review of this repository as a Kiroween 2026 submission for Gatekeeper's Ward. Judge it the way the official panel would, then save the review to `docs/HACKATHON_REVIEW.md`.

Source of truth: https://kiroween.devpost.com/rules (local copy: `docs/Planning/HackathonDetails/Rules.md`). If any planning doc disagrees with the rules, the rules win. Strategy notes live in `docs/Planning/ScoringWell.md`.

## How Judging Works

**Stage One (pass/fail):** The project reasonably fits its chosen category and reasonably applies the required tools (Kiro). Insufficient use of Kiro can result in disqualification.

**Stage Two:** Five equally weighted criteria, 20% each, 10 points each, 50 points total.

1. **Potential Impact (10)**: Credible case for solving a real problem for a real audience? Does the solution address it based on what is demonstrated? Useful, intuitive, accessible? Would someone actually use it?
2. **Technological Implementation (10)**: How thoroughly and skillfully is Kiro used? Thoughtful strategy for AI development? Variety of Kiro tools used impactfully? Deep understanding of Kiro features? Evidence of experimentation?
3. **Design (10)**: A complete, coherent product experience rather than a technical proof of concept? Intuitive, polished, intentional?
4. **Innovation / Idea (10)**: Creative and novel? Different from existing concepts? Unusual technologies or public resources combined in a unique way?
5. **Presentation (10)**: Does the video show the project working end to end? Does the pitch say what problem is solved, for whom, and why it matters? Easy to follow, creative, memorable?

**Ties:** Tied submissions are re-scored from scratch at 20 points per criterion, then +10 per round until broken. Strong, specific evidence matters.

## Hard Requirements (Disqualification Risks)

Check each one and report pass/fail with evidence. Any failure is a Critical Issue.

- [ ] Public GitHub repo (not GitLab or Bitbucket)
- [ ] Open source license file at the repo root, detectable by GitHub and shown in the About section (`LICENSE`, Apache 2.0; confirm with `gh repo view --json licenseInfo` that GitHub detects it)
- [ ] `/.kiro` directory committed at the repo root; not in `.gitignore` (check `.gitignore` and `git ls-files .kiro`)
- [ ] Repo contains all source, assets, and instructions needed to build and run (`swift build`, run steps in README)
- [ ] Project was built during the Submission Period (Oct 30, 2026 9:00 AM PT to Dec 4, 2026 2:00 PM PT); check `git log` dates; any pre-existing code is disclosed
- [ ] Runs as depicted in the video and text description (try the documented build and test commands)
- [ ] Demo video: under 3 minutes, public on YouTube, shows the project running on a Mac, no copyrighted music or third-party trademarks
- [ ] Text description of features and functionality
- [ ] Write-up on how Kiro was used (see Technological Implementation checklist)
- [ ] Category selected (Frankenstein or Costume Contest are the likely fits; justify the choice)
- [ ] Team of 3 or fewer, one appointed Representative
- [ ] All materials in English
- [ ] No third-party IP issues; third-party dependencies are licensed for use

## Review Process

### 1. Project Discovery
```bash
ls -la
git log --format='%h %ad %s' --date=iso | head -40
git ls-files .kiro | head -80
cat .gitignore
find docs -name '*.md' | head -30
```

### 2. Technological Implementation Evidence
Look for concrete, specific use of each Kiro feature the rules name. Note what is present, what is missing, and how well it is documented:
- **Specs** (`.kiro/specs/`): requirements, design, tasks. Are they structured and iterative? Do tasks map to real commits? Is there a spec-driven vs vibe-coding comparison?
- **Steering** (`.kiro/steering/`): quality, scope, inclusion modes (always, fileMatch, auto, manual). Did steering visibly shape the code (no force-unwrap, Darwin interop, memory safety, TCC boundaries)?
- **Hooks** (`.kiro/hooks/`): are they valid, active, and tied to a real workflow (build, test, lint on save or task completion)? Do they run?
- **MCP** (`.kiro/settings/`): servers configured and a clear story on what they enabled (for example Darwin header or TCC docs lookup).
- **Property-based testing**: present for the `KERN_PROCARGS2` buffer parser and the `log stream` NDJSON parser? Do tests run and pass (`swift test`)? Did PBT find real bugs?
- **Custom agents, Kiro powers, Kiro IDE vs CLI vs Web vs Crew**: used or not; if used, the impact on the build.
- **Experimentation**: evidence of trying approaches, iterating, and course-correcting (devlog, commit history, abandoned specs).
- **Write-up**: does it answer the questions in the rules (IDE/CLI/Crew differences, agents, hooks, spec-driven vs vibe, steering strategy, MCP, PBT, powers)?

### 3. Potential Impact
- Real developer pain: AI coding agents trigger opaque TCC prompts and users cannot tell which command caused them.
- Does the HUD deliver actionable forensics (PID, binary, cwd, args, lineage, risk tags)?
- Is it installable and useful on a clean Mac (macOS 13+)? Are permissions and first-run steps clear? Accessibility (VoiceOver labels, contrast, reduced motion)?
- Is the target audience named and the limits honest ("we inform, we don't intercept")?

### 4. Design
- Is the product coherent: menu bar ghost, floating HUD, history, states (idle, alert, error, process exited)?
- Castle Keep palette and copy used consistently? Does the theme clarify function instead of hiding it?
- Does the NSPanel stay non-activating so Apple's dialog keeps focus?
- Polish: spacing, typography, animation, empty and error states.

### 5. Innovation / Idea
- Novelty versus existing tools (Little Snitch, Santa, Objective-See, `log stream` by hand).
- Unusual combination: Darwin kernel introspection (`sysctl`, `proc_pidinfo`), unified log streaming, and agentic IDE workflows with a gothic UI.
- Zero-entitlement, no SIP bypass architecture.
- Fit for the chosen category (Frankenstein: seemingly incompatible elements stitched together; Costume Contest: a haunting, polished UI that enhances function).

### 6. Presentation
- Video: hook and problem, live end-to-end demo with the real TCC prompt and HUD side by side, Kiro story (`.kiro` walkthrough), impact; under 3:00; clear audio; no copyrighted music.
- README: what it is, why it matters, build, run, test, screenshots or GIF, link to video.
- Devpost text: problem, audience, features, how Kiro was used.
- Is it easy to follow and memorable?

### 7. Code Quality (supports every criterion)
- Matches project standards: no force-unwrap in production paths, files near 300 lines or less, `///` docs on public types, value types preferred.
- Error handling, graceful degradation when the process has already exited, regex fallback for log wording changes.
- Build passes (`swift build`), tests pass (`swift test`), no stray secrets or large binaries committed.

### 8. Bonus Prize Eligibility
Report eligibility and missing items for each:
- **Best Demo**: no extra steps; judged on the Presentation score, must be in the top 10% overall.
- **Bonus Blog Prize**: public post on a third-party platform, published during the Submission Period, states it was written as part of the Kiroween 2026 hackathon, URL in the submission. Top 100 scoring submissions win.
- **Social Blitz Prize**: post starts with `#KiroweenHackathon26`, published during the Submission Period, shares a favorite thing about Kiro and how it changed development, URL in the submission. Judged on original thought and insight, plus quality of assets. 5 winners.
- **Best Ghost of Kiroween Past**: only if someone on the team registered for Kiroween 2025 (verified by Devpost); the 2026 project must be new.
- **Best Student Project**: only if every team member is a student; needs LinkedIn profiles, student emails, year, degree, and school.
- **Best Startup Project**: only if a founder; needs LinkedIn and startup website.
- **Best Kiro Crew App**: needs a separate public GitHub repo for a Kiro Crew app, created during the Submission Period.
- Note: a project can win one Overall or one Category prize, not both, but any number of bonus prizes.

## Scoring Framework

For each of the five criteria provide:
- **Score**: X/10
- **Justification**: specific evidence (file paths, commits, video timestamps)
- **Strengths**
- **Areas for Improvement**: concrete, ranked by points gained per hour of effort

Be honest. Do not inflate scores. If something could not be verified (for example the video does not exist yet), say so and score what is observable.

## Output Format

**IMPORTANT**: Save the review to `docs/HACKATHON_REVIEW.md` using this structure.

```markdown
# Kiroween 2026 Submission Review: Gatekeeper's Ward

Review date: YYYY-MM-DD
Days until deadline (Dec 4, 2026 2:00 PM PT): N

## Overall Score: X/50

## Stage One: Category and Kiro Fit
Pass/Fail with reasoning. Chosen category: ...

## Hard Requirements
| Requirement | Status | Evidence |
|---|---|---|

## Stage Two Scoring

### Potential Impact (X/10)
### Technological Implementation (X/10)
Include a table: Kiro feature | Present? | Evidence | Gap
### Design (X/10)
### Innovation / Idea (X/10)
### Presentation (X/10)

## Bonus Prize Eligibility
| Prize | Eligible? | Missing items |
|---|---|---|

## Summary

**Top Strengths:**
- ...

**Critical Issues (disqualification or major score risk):**
- ...

**Prioritized Recommendations (highest score gain per effort first):**
1. ...

**Hackathon Readiness:** Ready / Needs Work / Major Issues
```
