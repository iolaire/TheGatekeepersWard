Source of truth: the official rules at https://kiroween.devpost.com/rules (local copy: `docs/Planning/HackathonDetails/Rules.md`). If this document ever disagrees with the rules, the rules win.

To score at the top of the review panel for Kiroween 2026, align your execution with the **five equally weighted judging criteria** (each 20% / 10 points, 50 points total) and satisfy the repository and video submission requirements.

---

### 0. How Judging Works

* **Stage One (pass/fail):** The project must reasonably fit its category and reasonably apply the required tools (Kiro). Insufficient use of Kiro can result in disqualification.
* **Stage Two (scored):** The five criteria below, equally weighted. No single pillar is "more audited" than another; Technological Implementation is simply the one where a repo review can find hard evidence.
* **Tie-breaking:** Tied submissions are re-scored from scratch at 20 points per criterion, then +10 per extra round. Concrete evidence helps.
* Judging may use expert panels, peer review, AI-driven analysis, or a combination. Judges are not required to run the project or watch past 3 minutes, so the text description, images, and video must stand on their own.

---

### 1. Breakdown of the 5 Official Judging Criteria (20% Each)

#### Criterion 1: Potential Impact (20% — 10 Points)

*Official questions:* Does the project make a credible case for solving a real problem for a real audience? Does the solution address that problem based on what is demonstrated? How useful, intuitive, and accessible is it? Would someone actually use it?

* **Define the Developer Pain Point:** Blind permission prompts from AI coding agents leave developers unable to tell which command triggered a TCC dialog, which carries real exfiltration and supply-chain risk.
* **Deliver Working Utility:** A developer who clones the repo, runs `swift build`, and launches it should immediately get actionable forensics (PID, binary, cwd, args, lineage, risk tags).
* **Be honest about limits:** The app informs; Apple's dialog stays in control.

#### Criterion 2: Technological Implementation (20% — 10 Points)

*Official questions:* How thoroughly and skillfully does the project use Kiro? Was there a thoughtful strategy to AI development? Was a variety of Kiro tools used impactfully? Does it show a deep understanding of Kiro features? Was there experimentation?

* **Keep `/.kiro` committed at the repo root.** Never add `/.kiro` or its subfolders to `.gitignore`; the rules say this could disqualify the submission.
* **Populate the subdirectories:**
  * `.kiro/specs/`: structured, iterative specs (requirements, design, tasks). Contrast spec-driven development with vibe coding in the write-up.
  * `.kiro/steering/`: documents that visibly shaped generated code (Darwin C interop, raw pointer memory safety, macOS security boundaries, coding standards).
  * `.kiro/hooks/`: active hooks tied to real workflows (build and test enforcement).
* **Cover the features the rules ask about:** Kiro IDE vs CLI vs Web vs Crew, custom agents, hooks, spec-driven development, steering, MCP, property-based testing, and Kiro powers. Skipped features are fine if you say why; the write-up should address each one.
* **PBT targets:** the `KERN_PROCARGS2` buffer parser and the `log stream` NDJSON parser. Report any bug PBT caught that unit tests missed.
* **Show experimentation:** devlog entries, abandoned approaches, and course corrections.
* **Required write-up:** A "how Kiro was used" write-up is a mandatory submission item.

#### Criterion 3: Design (20% — 10 Points)

*Official questions:* Does the project deliver a complete, coherent product experience, not just a technical proof of concept? Is the design intuitive, polished, and intentional?

* **Cohesive Menu Bar and HUD UX:** An `NSStatusItem` menu bar ghost with state changes, plus an unobtrusive non-activating floating `NSPanel` HUD hosting SwiftUI views. Cover idle, alert, error, and "process already exited" states.
* **Functional theming:** The castle aesthetic should clarify function (distinct glyphs for the child process, the parent app, and the protected vault), not obscure it.
* **Accessibility:** VoiceOver labels, contrast, and reduced-motion handling.

#### Criterion 4: Innovation / Idea (20% — 10 Points)

*Official questions:* How creative and novel is the concept, and does it differ from existing concepts? Are unusual technologies or public resources leveraged or combined in a unique way?

* **Category choice:** Frankenstein fits the stitched-together story: low-level Darwin introspection (`sysctl KERN_PROCARGS2`, `proc_pidinfo`, unified-log TCC events) joined to agentic IDE workflows and a gothic UI. Costume Contest is the alternative if the UI is the strongest asset. Pick one and justify it in the write-up.
* **Zero-entitlement architecture:** No SIP bypass, no kernel extensions, no restricted entitlements.
* **Differentiate** from existing tools (Little Snitch, Santa, Objective-See utilities, hand-run `log stream`).

#### Criterion 5: Presentation (20% — 10 Points)

*Official questions:* Does the video clearly demonstrate the project working end to end? Does the pitch communicate what problem is solved, who it is for, and why it matters? Is it easy to follow, creative, and memorable?

* **Strict 3-minute limit:** Judges are not required to watch past 3:00.
* **Suggested video structure (advice, not a rule):**
  * 0:00 – 0:30 Hook and problem: an agent triggers an opaque "wants access to Documents" prompt. "What command actually caused this?"
  * 0:30 – 1:45 Live demo: the native prompt fires and the HUD shows the child binary, PID, and argument vector side by side.
  * 1:45 – 2:30 Kiro story: show `.kiro`, the specs, the steering doc behind the Darwin memory layout work, and the hooks.
  * 2:30 – 3:00 Impact, Apache 2.0 open-source availability, roadmap.

---

### 2. Submission Checklist and Technical Requirements

* **GitHub only:** public GitHub URL (GitLab and Bitbucket are not allowed).
* **Open source license:** a license file (this repo uses Apache 2.0; verify GitHub detects it, a modified license file can show as "Other") that GitHub detects and shows in the About section.
* **`/.kiro` at repo root**, not git-ignored.
* **Repo completeness:** all source, assets, and instructions needed to build and run.
* **Demo video:** under 3 minutes, shows the app running on a Mac, uploaded to **YouTube** and made **public** (the rules name YouTube only; do not rely on Vimeo or unlisted links). No copyrighted music or third-party trademarks without permission.
* **Text description** of features and functionality, plus the **Kiro write-up**.
* **Category and bonus categories** identified on the submission form.
* **Team:** up to 3 people, one appointed Representative.
* **New work only:** the project must be built during the Submission Period, **October 30, 2026 9:00 AM PT to December 4, 2026 2:00 PM PT**. Disclose any pre-existing code. No extensions.
* **Free Kiro credits:** 4,000 credits per entrant; request by **December 1, 2026 12:00 PM PT** and redeem by December 4.
* **Prize rule:** a project can win one Overall or one Category prize, not both, plus any number of bonus prizes.

---

### 3. Bonus Prizes to Target

1. **Bonus Blog Prize (100 winners, 2,000 Kiro credits):** Publish a public post on a third-party blog platform during the Submission Period. It must state that it is written as part of the Kiroween 2026 hackathon. Submit the URL. Awarded to the highest-scoring qualifying submissions.
2. **Social Blitz Prize (5 winners, 3-month Kiro Pro+):** Post on any social platform (X, LinkedIn, Instagram, TikTok) during the Submission Period. The post must **start** with `#KiroweenHackathon26`, share your favorite thing about Kiro, and describe how it changed your approach to development. Submit the URL. Judged on original thinking (not AI-sounding text), insight, and asset quality.
3. **Best Demo ($1,000):** No extra steps. Goes to the top Presentation score among submissions in the top 10% overall.
4. **Best Ghost of Kiroween Past ($2,000):** Only if you registered for Kiroween 2025; confirm on the form. Devpost verifies against 2025 records. The 2026 project must be newly created either way, so a new project alone does not qualify you.
5. **Best Student Project ($1,500 plus Kiro Pro Max, one per category):** Every team member must be a student; LinkedIn profiles, student emails, year, degree, and school are required.
6. **Best Startup Project ($10,000):** Only for founders; LinkedIn and startup website required.
7. **Best Kiro Crew App ($1,000):** Requires a separate public GitHub repo for a Kiro Crew app created during the Submission Period.

Confirm which of these apply to the team before submitting.
