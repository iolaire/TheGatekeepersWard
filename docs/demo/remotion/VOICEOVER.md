# Voiceover Script: Gatekeeper's Ward Demo

Scene IDs match the files in `public/audio/scratch/<scene-id>.wav` and the keys in `src/narration.json`. The spoken copy below is generated from that JSON, so edit the JSON first, then re-run `npm run audio:scratch`.

Total runtime of the scratch cut: **2:47** (limit 3:00). Timecodes are cumulative and include ~0.4 s lead-in and ~0.8 s tail per scene. Voice: macOS `say`, Samantha, 150 wpm.

The spoken copy uses spelled-out letters ("A I", "H U D", "T C C") so the scratch voice reads acronyms correctly. When you record yourself, say them naturally.

## Scene 1: Intro, Hook and Immediate Need
- **ID:** `scene-01-intro`
- **Timecode:** 0:00-0:26
- **Impact point:** Real-world need: opaque prompts, blind Allow, Apple's fix not shipped.
- **Visual cues:** Title card with the ghost mascot. Right column reveals: a generic macOS prompt, `$ ???` marked UNKNOWN, an amber "Apple: not released yet" card, then a violet "Gatekeeper's Ward: Today" card.

> Every day, autonomous A I coding tools and random Mac apps throw up a system permission popup. It names the app. It never says what that app is about to do. One blind click on Allow can hand an autonomous agent your Desktop, your Documents, even your camera. Apple is working on finer grained permissions for A I tools, but they are not released yet. Gatekeeper's Ward fills that gap today.

## Scene 2: Baseline Flow
- **ID:** `scene-02-baseline`
- **Timecode:** 0:26-0:47
- **Impact point:** Without the Ward the user decides blind.
- **Visual cues:** Real baseline capture (`baseline_deepseek_harness_desktop_flow.mov`, 15s-25.4s) beside two cards: what macOS tells you, and what it does not (command, arguments, lineage, target). Caption: "Allow or Don't Allow, and hope."

> Here is the standard macOS flow, without Gatekeeper's Ward. DeepSeek Harness asks to access files in your Desktop folder. That is all the dialog says. Is it a harmless listing, or a script copying your files out? You cannot tell. You can only click Allow or Don't Allow, and hope.

## Scene 3: Gatekeeper's Ward in Action
- **ID:** `scene-03-ward`
- **Timecode:** 0:47-1:42
- **Impact point:** Informed consent with the Ward's HUD. Strictly informational; Apple's buttons stay in charge.
- **Visual cues:** Real Ward capture (`ward_deepseek_harness_desktop_flow.mov`, 8s-23.4s), then the `pair.png` still. Right column reveals: TCC service and target, process lineage, exact command and cwd, risk flags, "Informs only / Never blocks".

> Now the same request, with Gatekeeper's Ward running. DeepSeek Harness asks for the Desktop folder, and the Fortress H U D slides in beside Apple's dialog. It shows the permission being requested and the target. It shows the full process lineage: DeepSeek Harness, a helper process, bash, and finally l s. And it shows the exact command and arguments, plus the working directory. Now you can tell a safe listing from a delete or a data grab, and risky arguments like dot env files or curl get flagged. Gatekeeper's Ward never blocks anything. It only informs. You stay in full control, and you still answer with Apple's own Allow or Don't Allow button. That matters most for developers running autonomous coding agents, and for anyone who gets a popup from an app they barely recognize. Informed consent, instead of a blind click.

## Scene 3b: A Second AI IDE: Qoder and the Microphone
- **ID:** `scene-03b-qoder`
- **Timecode:** 1:42-1:59
- **Impact point:** The Ward works for other AI IDEs and other permissions, not just one demo app.
- **Visual cues:** Real Ward still (`ward_qoder_microphone_pair.png`). Right column reveals: `kTCCServiceMicrophone` (target: Voice Chamber), the command shown as `swift-frontend -interpret …` with a note that a `swift -e` one-liner is harder to read, then the lineage Qoder (44386) → Qoder (44767) → zsh (63090) → swift-frontend (63093).
> It works for other A I tools and permissions too. Here Qoder asks for the microphone. The command is a Swift one liner, so it reads as the Swift compiler. The lineage still shows the source: Qoder, a z s h shell, then swift frontend.
## Scene 4: How It Works: Zero Dark Magic
- **ID:** `scene-04-how`
- **Timecode:** 1:59-2:29
- **Impact point:** Zero dark magic: unprivileged user space, no bypasses.
- **Visual cues:** Four-box flow: prompt, Unified Log (`com.apple.TCC`), `sysctl KERN_PROCARGS2`, Fortress HUD. Then four red "No" cards: kernel extensions, SIP changes, restricted entitlements, security bypasses.

> How does it work? With zero dark magic. Gatekeeper's Ward streams the macOS unified log and watches the com dot apple dot T C C subsystem. When a prompt fires, it reads the paused process's arguments with sysctl K E R N underscore PROCARGS two. That is all. It runs in unprivileged user space. No kernel extensions. No S I P changes. No restricted entitlements. No security bypasses.

## Scene 5: Outro and Kiro Wrap-Up
- **ID:** `scene-05-outro`
- **Timecode:** 2:29-2:47
- **Impact point:** Kiroween 2026 wrap-up and closing line.
- **Visual cues:** Gate-and-spirits art, Kiro badges (spec-driven development, agent hooks, property-based testing), repo link placeholder, tagline.

> We built Gatekeeper's Ward for Kiroween 2026 with Kiro, using spec driven development, agent hooks, and property based testing. It is open source under Apache 2.0. Gatekeeper's Ward. Know who knocks before you drop the castle gates.
