# App_Profile for Qoder (/Applications/Qoder.app).
# Parsed by scripts/capture/lib/profile.sh, never sourced.
profile_id     = qoder
display_name   = Qoder
bundle_id      = com.qoder.app
launch         = open -b com.qoder.app
# Electron app: the page reaches Accessibility only after AXManualAccessibility is set.
ax_manual_accessibility = true
input_locator  = find:text area
send_action    = key:return
send_method    = clipboard
launch_timeout = 20
scenario.microphone.prompt         = Run this shell command in the terminal: swift -e 'import AVFoundation; let g = DispatchSemaphore(value: 0); AVCaptureDevice.requestAccess(for: .audio) { ok in print("microphone access:", ok); g.signal() }; g.wait()' Run it exactly once without changing it. It waits for a macOS permission dialog, which is expected, so let it keep running until it prints a result.
scenario.microphone.service        = Microphone
scenario.microphone.prompt_timeout = 120
scenario.microphone.dwell          = 4
