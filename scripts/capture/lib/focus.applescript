-- Focus (Do Not Disturb) control through the Control Center menu bar item.
-- Usage: osascript focus.applescript read        -> prints "on" or "off"
--        osascript focus.applescript set on|off  -> prints the resulting state
-- There is no public Focus API, so this drives System Events and depends on the
-- Control Center UI structure. Any macOS change should only touch this file.
-- Exits non-zero (with a message on stderr) whenever the state cannot be
-- determined, so callers fail closed. Needs Accessibility permission.

on run argv
	if (count of argv) < 1 then error "usage: focus.applescript read | set on|off" number 64
	set verb to item 1 of argv
	if verb is "read" then
		return my readFocus()
	else if verb is "set" then
		if (count of argv) < 2 then error "usage: focus.applescript set on|off" number 64
		set want to item 2 of argv
		if want is not "on" and want is not "off" then error "state must be on or off" number 64
		return my setFocus(want)
	else
		error "unknown verb: " & verb number 64
	end if
end run

-- Opens Control Center and returns the Focus checkbox, or raises an error.
on openFocusControl()
	tell application "System Events"
		if not (exists process "ControlCenter") then error "ControlCenter process not found" number 1
		tell process "ControlCenter"
			set mbItem to missing value
			repeat with mi in (menu bar items of menu bar 1)
				try
					if (description of mi) contains "Control Center" or (name of mi) contains "Control Center" then
						set mbItem to mi
						exit repeat
					end if
				end try
			end repeat
			if mbItem is missing value then error "Control Center menu bar item not found" number 1
			click mbItem
			delay 0.6
			set found to missing value
			repeat with e in (entire contents of window 1)
				try
					if class of e is checkbox then
						set n to (name of e) & " " & (description of e)
						if n contains "Focus" or n contains "Do Not Disturb" then
							set found to e
							exit repeat
						end if
					end if
				end try
			end repeat
			if found is missing value then error "Focus control not found in Control Center" number 1
			return found
		end tell
	end tell
end openFocusControl

on closeControlCenter()
	tell application "System Events" to key code 53
end closeControlCenter

on stateOf(ctl)
	tell application "System Events"
		set v to value of ctl
		if v is 1 or v is true or v is "1" then return "on"
		if v is 0 or v is false or v is "0" then return "off"
	end tell
	error "Focus value not recognised" number 1
end stateOf

on readFocus()
	try
		set ctl to my openFocusControl()
		set s to my stateOf(ctl)
		my closeControlCenter()
		return s
	on error msg number n
		try
			my closeControlCenter()
		end try
		error "cannot read Focus state: " & msg number 1
	end try
end readFocus

on setFocus(want)
	try
		set ctl to my openFocusControl()
		set s to my stateOf(ctl)
		if s is not want then
			tell application "System Events" to click ctl
			delay 0.6
			set ctl to my openFocusControl()
			set s to my stateOf(ctl)
		end if
		my closeControlCenter()
		if s is not want then error "state is still " & s
		return s
	on error msg number n
		try
			my closeControlCenter()
		end try
		error "cannot set Focus state: " & msg number 1
	end try
end setFocus
