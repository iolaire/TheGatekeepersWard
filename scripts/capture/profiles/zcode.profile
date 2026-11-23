# App_Profile for ZCode (/Applications/ZCode.app).
# Parsed by scripts/capture/lib/profile.sh, never sourced.

profile_id     = zcode
display_name   = ZCode
bundle_id      = dev.zcode.app
launch         = open -b dev.zcode.app
input_locator  = ax:text area 1 of scroll area 1 of group 1 of window 1
send_action    = key:return
send_method    = clipboard
launch_timeout = 20

scenario.desktop.prompt         = List the files and folders on my Desktop (~/Desktop). Only read the names, and do not change, create, or delete anything.
scenario.desktop.service        = SystemPolicyDesktopFolder
scenario.desktop.prompt_timeout = 45
scenario.desktop.dwell          = 4

# Requires the volume /Volumes/Gold to be mounted; change it to any mounted external volume.
scenario.removable-volume.prompt         = List the files and folders at the top level of /Volumes/Gold. Only read the names, and do not change, create, or delete anything.
scenario.removable-volume.service        = SystemPolicyRemovableVolumes
scenario.removable-volume.prompt_timeout = 45
scenario.removable-volume.dwell          = 4
