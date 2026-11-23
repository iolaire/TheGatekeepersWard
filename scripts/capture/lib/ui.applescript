-- System Events driver for the permission capture framework.
-- Run as: osascript ui.applescript <verb> <args...>
-- Every value arrives in argv. Nothing from a profile or prompt is ever spliced
-- into script source (requirement 13.10).
--
-- Verbs (bid = bundle identifier, pn = process name):
--   running <bid>                     prints true|false
--   frontmost <bid>                   raises the app; prints true when it is frontmost with a window
--   focus <bid> <locator> <secs>      focus the element, retrying up to secs; error 3 if never found
--   paste <bid>                       cmd+v into the frontmost app, then waits 0.3 s
--   type <bid> <text>                 keystroke text
--   send <bid> <spec> <secs>          spec = key:<combo> | ax:<element path> | find:<class>; retries up to secs
--   approve <bid> <spec> <secs>       same as send; used for approve_tool_call
--   disk-exists <name>                prints true|false (Finder disk named name)
--   read-prompt <pn>                  static text of the front window of process pn, one per line
--   buttons <pn>                      button names of the front window of process pn, one per line
--   click <pn> <label>                click the button named label in the front window of pn
--
-- Locator form: "ax:<class> <n> of <class> <n> of ... of window 1". Steps run
-- outermost first. A step is "<class> <index>" or "<class> \"<name>\"". Names
-- must not contain the text " of ". The path resolves against the app process;
-- when the outermost step is not a window, "window 1" is prepended.
-- Search form: "find:<class>" (for example "find:text area") picks the first
-- element of that class anywhere in window 1, depth first. "find:<class>
-- \"<label>\"" (for example find:button "Allow once") also requires the label to
-- equal the element's name, description or value. Use it when the path changes
-- with app state, as in Electron apps that reopen the last view.
-- Key combos: return, enter, tab, space, escape or one character, optionally
-- prefixed by cmd+, shift+, opt+, ctrl+ (for example cmd+return).

on run argv
	if (count of argv) < 1 then error "usage: ui.applescript <verb> args..." number 64
	set verb to item 1 of argv
	set args to rest of argv
	if verb is "running" then
		return my isRunning(item 1 of args)
	else if verb is "frontmost" then
		return my raiseFront(item 1 of args)
	else if verb is "focus" then
		return my doFocus(item 1 of args, item 2 of args, (item 3 of args) as integer)
	else if verb is "paste" then
		my raiseFront(item 1 of args)
		tell application "System Events" to keystroke "v" using command down
		delay 0.3
		return "ok"
	else if verb is "type" then
		my raiseFront(item 1 of args)
		set txt to item 2 of args
		tell application "System Events" to keystroke txt
		return "ok"
	else if verb is "send" or verb is "approve" then
		return my doSend(item 1 of args, item 2 of args, (item 3 of args) as integer)
	else if verb is "disk-exists" then
		set vn to item 1 of args
		tell application "Finder" to return (exists disk vn)
	else if verb is "read-prompt" then
		return my promptTexts(item 1 of args)
	else if verb is "buttons" then
		return my promptButtons(item 1 of args)
	else if verb is "click" then
		return my clickPromptButton(item 1 of args, item 2 of args)
	end if
	error "unknown verb: " & verb number 64
end run

on isRunning(bid)
	tell application "System Events"
		return (count of (processes whose bundle identifier is bid)) > 0
	end tell
end isRunning

on raiseFront(bid)
	tell application "System Events"
		set ps to processes whose bundle identifier is bid
		if (count of ps) is 0 then return false
		set p to item 1 of ps
		set frontmost of p to true
		return (frontmost of p) and ((count of windows of p) > 0)
	end tell
end raiseFront

-- Retry action (focus or click) on the locator until it works or secs pass.
on retryOnElement(bid, locator, secs, action)
	set findCls to ""
	set findName to ""
	if locator starts with "find:" then
		set findCls to my trimText(my stripPrefix(locator, "find:"))
		set q to offset of "\"" in locator
		if q > 0 then
			set findCls to my trimText(text 6 thru (q - 1) of locator)
			if not (locator ends with "\"") then error "bad locator: " & locator number 64
			set findName to text (q + 1) thru -2 of locator
		end if
		if findCls is "" then error "bad locator: " & locator number 64
	else
		set steps to my pathSteps(my stripPrefix(locator, "ax:"))
	end if
	set deadline to (current date) + secs
	repeat
		try
			if findCls is "" then
				set el to my locate(bid, steps)
			else
				set el to my findFirst(bid, findCls, findName)
			end if
			if action is "focus" then
				try
					tell application "System Events" to set focused of el to true
				on error
					tell application "System Events" to click el
				end try
			else
				tell application "System Events" to click el
			end if
			return "ok"
		end try
		if (current date) > deadline then error "locator not found: " & locator number 3
		delay 0.25
	end repeat
end retryOnElement

on doFocus(bid, locator, secs)
	my raiseFront(bid)
	return my retryOnElement(bid, locator, secs, "focus")
end doFocus

on doSend(bid, spec, secs)
	my raiseFront(bid)
	if spec starts with "key:" then
		my pressKey(my stripPrefix(spec, "key:"))
		return "ok"
	else if spec starts with "ax:" or spec starts with "find:" then
		return my retryOnElement(bid, spec, secs, "click")
	end if
	error "bad send spec: " & spec number 64
end doSend

on stripPrefix(s, prefix)
	if s starts with prefix then return text ((length of prefix) + 1) thru -1 of s
	return s
end stripPrefix

on pressKey(spec)
	set AppleScript's text item delimiters to "+"
	set parts to text items of spec
	set AppleScript's text item delimiters to ""
	set k to item -1 of parts
	set mods to {}
	if (count of parts) > 1 then
		repeat with i from 1 to ((count of parts) - 1)
			set m to item i of parts
			if m is "cmd" then
				set end of mods to command down
			else if m is "shift" then
				set end of mods to shift down
			else if m is "opt" or m is "alt" then
				set end of mods to option down
			else if m is "ctrl" or m is "control" then
				set end of mods to control down
			else
				error "bad modifier: " & m number 64
			end if
		end repeat
	end if
	set code to missing value
	if k is "return" then
		set code to 36
	else if k is "enter" then
		set code to 76
	else if k is "tab" then
		set code to 48
	else if k is "space" then
		set code to 49
	else if k is "escape" then
		set code to 53
	end if
	tell application "System Events"
		if code is missing value then
			if (count of mods) is 0 then
				keystroke k
			else
				keystroke k using mods
			end if
		else
			if (count of mods) is 0 then
				key code code
			else
				key code code using mods
			end if
		end if
	end tell
end pressKey

-- Split "a 1 of b \"x\" of window 1" into {{"window",1,""},{"b",0,"x"},{"a",1,""}}.
on pathSteps(path)
	set AppleScript's text item delimiters to " of "
	set parts to text items of path
	set AppleScript's text item delimiters to ""
	set steps to {}
	repeat with i from (count of parts) to 1 by -1
		set end of steps to my parseStep(item i of parts)
	end repeat
	set firstCls to item 1 of (item 1 of steps)
	if firstCls is not "window" then set steps to {{"window", 1, ""}} & steps
	return steps
end pathSteps

on parseStep(s)
	set q to offset of "\"" in s
	if q > 0 then
		set cls to my trimText(text 1 thru (q - 1) of s)
		set nm to text (q + 1) thru -2 of s
		return {cls, 0, nm}
	end if
	set AppleScript's text item delimiters to " "
	set ws to text items of s
	set idx to (item -1 of ws) as integer
	set cls to (items 1 thru -2 of ws) as text
	set AppleScript's text item delimiters to ""
	return {cls, idx, ""}
end parseStep

on trimText(s)
	set t to s
	repeat while t starts with " "
		set t to text 2 thru -1 of t
	end repeat
	repeat while t ends with " "
		set t to text 1 thru -2 of t
	end repeat
	return t
end trimText

on locate(bid, steps)
	tell application "System Events"
		set ps to processes whose bundle identifier is bid
		if (count of ps) is 0 then error "app not running: " & bid number 2
		set el to item 1 of ps
	end tell
	repeat with stp in steps
		set el to my pick(el, item 1 of stp, item 2 of stp, item 3 of stp)
	end repeat
	return el
end locate

-- First element of class cls in window 1 of the app, depth first.
on findFirst(bid, cls, nm)
	tell application "System Events"
		set ps to processes whose bundle identifier is bid
		if (count of ps) is 0 then error "app not running: " & bid number 2
		set w to window 1 of (item 1 of ps)
	end tell
	set found to my searchIn(w, cls, nm, 0)
	if found is missing value then error "no element " & cls & " " & nm number 3
	return found
end findFirst

-- True when nm is empty or equals the element's name, description or value.
on labelMatches(el, nm)
	if nm is "" then return true
	if (my nameOf(el)) is nm then return true
	try
		tell application "System Events" to set v to description of el
		if v is not missing value and (v as text) is nm then return true
	end try
	try
		tell application "System Events" to set v to value of el
		if v is not missing value and (v as text) is nm then return true
	end try
	return false
end labelMatches

on searchIn(parentEl, cls, nm, depth)
	if depth > 60 then return missing value
	tell application "System Events" to set kids to UI elements of parentEl
	repeat with k in kids
		set kk to contents of k
		if (my classOf(kk)) is cls then
			if my labelMatches(kk, nm) then return kk
		end if
		set r to my searchIn(kk, cls, nm, depth + 1)
		if r is not missing value then return r
	end repeat
	return missing value
end searchIn

-- Child of ref selected by class and index (or name when nm is not "").
on pick(parentEl, cls, idx, nm)
	tell application "System Events"
		if cls is "window" then
			set kids to windows of parentEl
		else
			set kids to UI elements of parentEl
		end if
	end tell
	set n to 0
	repeat with k in kids
		set kk to contents of k
		if cls is "UI element" or cls is "window" or (my classOf(kk)) is cls then
			if nm is "" then
				set n to n + 1
				if n is idx then return kk
			else if (my nameOf(kk)) is nm then
				return kk
			end if
		end if
	end repeat
	error "no element " & cls & " " & idx & nm number 3
end pick

on classOf(el)
	try
		tell application "System Events" to return (class of el) as text
	end try
	return ""
end classOf

on nameOf(el)
	try
		tell application "System Events" to set v to name of el
		if v is missing value then return ""
		return v as text
	end try
	return ""
end nameOf

on joinLines(items_)
	set AppleScript's text item delimiters to linefeed
	set t to items_ as text
	set AppleScript's text item delimiters to ""
	return t
end joinLines

on promptButtons(pn)
	tell application "System Events"
		set names_ to {}
		repeat with b in (every button of window 1 of process pn)
			set end of names_ to (name of b as text)
		end repeat
	end tell
	return my joinLines(names_)
end promptButtons

on promptTexts(pn)
	tell application "System Events"
		set vals to {}
		repeat with t in (every static text of window 1 of process pn)
			try
				set end of vals to (value of t as text)
			end try
		end repeat
	end tell
	return my joinLines(vals)
end promptTexts

on clickPromptButton(pn, label)
	tell application "System Events"
		click (first button of window 1 of process pn whose name is label)
	end tell
	return "ok"
end clickPromptButton
