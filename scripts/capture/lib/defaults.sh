#!/usr/bin/env bash
# Measured/assumed window and label defaults for the capture framework.
# Each value can be overridden by an environment variable of the same name.
# Re-measure with: swift scripts/dump_window_list.swift while a prompt is showing.
# bash 3.2 compatible.

# Window owner of Apple's TCC prompt (macOS 27.0.1 measured; not re-measured on 27.2.1).
: "${CAPTURE_PROMPT_OWNER:=UserNotificationCenter}"
# Window layer of the TCC prompt.
: "${CAPTURE_PROMPT_LAYER:=8}"
# Minimum layer of the Ward menu bar item (menu bar Window Server is 24; item expected at 25).
: "${CAPTURE_WARD_MENUBAR_MIN_LAYER:=24}"
# Comma-separated, lower case, straight apostrophes. Not verified on 27.2.1.
: "${CAPTURE_ALLOW_LABELS:=ok,allow}"
# Default is assigned via a variable for bash 3.2 compatibility.
_deny_default="don't allow,deny"
: "${CAPTURE_DENY_LABELS:=$_deny_default}"
unset _deny_default

export CAPTURE_PROMPT_OWNER CAPTURE_PROMPT_LAYER CAPTURE_WARD_MENUBAR_MIN_LAYER
export CAPTURE_ALLOW_LABELS CAPTURE_DENY_LABELS
