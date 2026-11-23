// JXA read-only probes for the preflight step. No prompts, no permissions needed.
// Usage: osascript -l JavaScript preflight.js installed <bundle-id>
//        osascript -l JavaScript preflight.js display
// installed: prints "true" when macOS knows an app with that bundle ID, else "false".
// display:   prints "true" when the main display is awake and the session is unlocked.
ObjC.import('AppKit');
ObjC.import('CoreGraphics');
function run(argv) {
  var verb = argv[0];
  if (verb === 'installed') {
    var url = $.NSWorkspace.sharedWorkspace.URLForApplicationWithBundleIdentifier($(String(argv[1])));
    return url.isNil() ? 'false' : 'true';
  }
  if (verb === 'display') {
    if ($.CGDisplayIsAsleep($.CGMainDisplayID())) { return 'false'; }
    var dict = $.CGSessionCopyCurrentDictionary();
    if (dict === null || dict === undefined) { return 'false'; }
    var info = ObjC.deepUnwrap(ObjC.castRefToObject(dict)) || {};
    if (info.CGSSessionScreenIsLocked) { return 'false'; }
    return 'true';
  }
  throw new Error('unknown verb: ' + verb);
}
