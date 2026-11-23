# App_Profile for DeepSeek Harness (/Applications/DeepSeek Harness.app).
# Parsed by scripts/capture/lib/profile.sh, never sourced.

profile_id     = deepseek-harness
display_name   = DeepSeek Harness
bundle_id      = com.deepseek.dsh
launch         = open -b com.deepseek.dsh
# Electron app: the page reaches Accessibility only after AXManualAccessibility is set.
ax_manual_accessibility = true
# Start every session from an empty chat, so earlier runs never show.
prepare_action = find:button "New Session"
# The prompt box moves between the new-session and chat screens, so search by class.
input_locator  = find:text area
send_action    = key:return
send_method    = clipboard
launch_timeout = 20
# DeepSeek asks before running a command outside its workspace. It can think for about 45 s first.
approve_tool_call = find:button "Allow once"
approve_timeout   = 120

scenario.desktop.prompt         = List the files and folders on my Desktop (~/Desktop). Only read the names, and do not change, create, or delete anything.
scenario.desktop.service        = SystemPolicyDesktopFolder
scenario.desktop.prompt_timeout = 45
scenario.desktop.dwell          = 4

# Requires the volume /Volumes/Gold to be mounted; change it to any mounted external volume.
scenario.removable-volume.prompt         = List the files and folders at the top level of /Volumes/Gold. Only read the names, and do not change, create, or delete anything.
scenario.removable-volume.service        = SystemPolicyRemovableVolumes
scenario.removable-volume.prompt_timeout = 45
scenario.removable-volume.dwell          = 4
# Risk-tag demo: a single path inside Documents (raises the prompt) whose name RiskTagger flags as a credential file.
# `ls -l` on one file only stats it, which TCC does not gate. `wc -c` opens the file (raising the prompt) but prints only a byte count; the file is a .example template.
scenario.env-file.prompt         = Run exactly this one shell command and show its output: wc -c /Users/iolaire/Documents/temp_ai/vegurn/.env.prod.example. Do not display, change, create, or delete any file.
scenario.env-file.service        = SystemPolicyDocumentsFolder
scenario.env-file.prompt_timeout = 60
scenario.env-file.dwell          = 4
