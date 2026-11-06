To score at the very top of the review panel for Kiroween 2026, you must align your execution directly with the **five formal judging criteria** (each worth 20% / 10 points for a total of 50 points) and satisfy the strict repository and video submission mandates.

---

### 1. Breakdown of the 5 Official Judging Pillars (20% Each)

#### Pillar 1: Technological Implementation (20% — 10 Points)

*The most heavily audited category.* Judges evaluate how deeply and thoughtfully you utilized Kiro, rather than simply writing code manually and dropping in a token prompt.

* **Keep `/.kiro` Committed at Repo Root:** Never put `/.kiro` in your `.gitignore` (the rules state this can disqualify you).
* **Populate Structured Subdirectories:**
* `.kiro/specs/`: Show structured, iterative spec files (e.g., system architecture, data models, API contracts). Explicitly contrast spec-driven development against pure "vibe coding" in your write-up.
* `.kiro/steering/`: Include steering documents that guided Kiro’s code generation (e.g., guidelines for Darwin C-interop, memory management for raw pointers in Swift, or macOS security boundaries).
* `.kiro/hooks/`: Implement active agent hooks (e.g., automated test-runner triggers, linting checks, or automatic build verification whenever a spec is updated).


* **Demonstrate Advanced Kiro Features:** Highlight if you leveraged **Model Context Protocol (MCP)** (e.g., pulling macOS system header docs or TCC schema references into Kiro) and **Property-Based Testing (PBT)** to test parser resilience on malformed `sysctl` buffers.

#### Pillar 2: Potential Impact (20% — 10 Points)

Judges look for a credible, accessible solution to a real problem faced by a defined audience.

* **Define the Developer Pain Point:** Start by highlighting how blind permission prompts in AI IDEs disrupt workflows and introduce real supply-chain/exfiltration security risks.
* **Deliver Working Utility:** The app must be immediately useful. If a developer clones the repo, runs `swift build`, and launches it, it should immediately begin providing actionable audit telemetry for real background tasks.

#### Pillar 3: Innovation / Idea (20% — 10 Points)

Judges reward creative, novel approaches and unusual technology pairings.

* **Submit Under Frankenstein:** Frame the project as an unexpected chimera: low-level Darwin kernel hooks (`sysctl KERN_PROCARGS2`, `tccd` unified logs) stitched into high-level agentic IDE workflows and presented through a gothic gatekeeper aesthetic.
* **Zero-Entitlement Architecture:** Emphasize that you solved an enterprise-level visibility problem without needing closed Apple kernel entitlements or disabling SIP—an uncommon, clever architectural route.

#### Pillar 4: Design (20% — 10 Points)

The project cannot just be a terminal script; it must be a coherent, polished product experience.

* **A Cohesive Menu Bar & HUD UX:** Build a clean SwiftUI interface (`MenuBarExtra` with a persistent history view) accompanied by an unobtrusive floating HUD card.
* **Functional Theming:** The castle/gatekeeper aesthetic should clarify function, not obscure it (e.g., distinct visual glyphs for "Intruding Minion / Child Process", "Master Summoner / Parent App", and "Targeted Vault / File Scope").

#### Pillar 5: Presentation (20% — 10 Points)

Judges watch hundreds of submissions; crisp pacing and narrative structure decide top honors.

* **Strict 3-Minute Limit:** Judges are not required to watch past the 3-minute mark.
* **The Winning Video Formula:**
* **0:00 – 0:30 (The Hook & Problem):** Show Cursor or Claude Code triggering an opaque *"App wants access to Documents"* modal. State the question: *"What command actually caused this?"*
* **0:30 – 1:45 (The Live Demo):** Run your test harness. Show the native prompt fire, and simultaneously show your Gatekeeper HUD pop up with the exact child binary, PID, and argument vector unmasked.
* **1:45 – 2:30 (The Kiro Story):** Show the IDE screen with your `.kiro` directory. Walk through the specs, the steering doc that guided Swift Darwin memory layout, and the agent hooks that automated testing.
* **2:30 – 3:00 (Impact & Outro):** Summary of open-source availability under Apache 2.0 and future roadmap.



---

### 2. Submission Checklist & Technical Requirements

* **GitHub Only:** Devpost requires a public **GitHub** URL (GitLab and Bitbucket are explicitly barred).
* **Visible Open Source License:** The repository must include an OSI-approved license file (such as `LICENSE` with Apache 2.0 or MIT) that GitHub's license detector parses into the repository "About" sidebar.
* **Public YouTube Video:** The demo must be uploaded to YouTube (or public Vimeo) and set to Public or Unlisted. Do not use copyrighted background music.
* **Timing & Freshness:** All code and commits must fall strictly within the official submission window (October 30, 2026 – December 4, 2026).

---

### 3. Bonus Categories to Target

Target these bonus prizes on your Devpost submission form to maximize total visibility:

1. **Best Ghost of Kiroween Past:** If you registered or participated in Kiroween 2025, check the confirmation box on the form (this project is completely new, which fulfills the eligibility rule).
2. **Social Blitz Prize:** Post a preview of your HUD on X/LinkedIn using `#KiroweenHackathon26`, detailing how Kiro’s spec-driven development accelerated building macOS system-level bindings. Include the post URL in your submission.
3. **Bonus Blog Prize:** Publish a write-up on Dev.to or Medium titled along the lines of *"Building a Zero-Entitlement macOS Security Gatekeeper with Kiro for Kiroween 2026"* and submit the link.