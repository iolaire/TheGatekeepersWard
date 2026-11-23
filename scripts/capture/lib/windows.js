// JXA window and display lists for the permission capture framework.
// Usage: osascript -l JavaScript windows.js list|all|displays
//
// list:     one line per on-screen window, front to back, tab-separated:
//           <windowNumber> <owner> <layer> <alpha> <x> <y> <w> <h>
// all:      the same columns for every window, including off-screen ones
//           (an app's hidden panels), in window-server order.
// displays: one line per active display, main first, 1-based index:
//           <index> <x> <y> <w> <h>   (top-left origin, points)
//
// Never reads kCGWindowName, so no Screen Recording grant is needed.

ObjC.import('CoreGraphics');
ObjC.import('AppKit');

function clean(s) {
  return String(s).replace(/[\t\r\n]+/g, ' ');
}

function num(v) {
  var n = Number(v);
  return isFinite(n) ? n : 0;
}

function listWindows(all) {
  var opts = all ? $.kCGWindowListOptionAll
    : ($.kCGWindowListOptionOnScreenOnly | $.kCGWindowListExcludeDesktopElements);
  var ref = $.CGWindowListCopyWindowInfo(opts, $.kCGNullWindowID);
  var arr = ObjC.castRefToObject(ref);
  var out = [];
  var count = Number(arr.count);
  for (var i = 0; i < count; i++) {
    var w = arr.objectAtIndex(i);
    var b = w.objectForKey('kCGWindowBounds');
    var owner = w.objectForKey('kCGWindowOwnerName');
    var number = w.objectForKey('kCGWindowNumber');
    var layer = w.objectForKey('kCGWindowLayer');
    var alpha = w.objectForKey('kCGWindowAlpha');
    if (!b || !owner || !number) { continue; }
    out.push([
      num(ObjC.unwrap(number)),
      clean(ObjC.unwrap(owner)),
      num(ObjC.unwrap(layer)),
      alpha ? num(ObjC.unwrap(alpha)) : 1,
      num(ObjC.unwrap(b.objectForKey('X'))),
      num(ObjC.unwrap(b.objectForKey('Y'))),
      num(ObjC.unwrap(b.objectForKey('Width'))),
      num(ObjC.unwrap(b.objectForKey('Height')))
    ].join('\t'));
  }
  return out.join('\n');
}

function listDisplays() {
  var screens = $.NSScreen.screens;
  var n = Number(screens.count);
  if (n === 0) { return ''; }
  // Cocoa has a bottom-left origin; the main screen (index 0) defines the flip.
  var mainH = Number(screens.objectAtIndex(0).frame.size.height);
  var out = [];
  for (var i = 0; i < n; i++) {
    var f = screens.objectAtIndex(i).frame;
    var x = Number(f.origin.x), y = Number(f.origin.y);
    var w = Number(f.size.width), h = Number(f.size.height);
    out.push([i + 1, x, mainH - (y + h), w, h].join('\t'));
  }
  return out.join('\n');
}

function run(argv) {
  var cmd = argv[0];
  if (cmd === 'list') { return listWindows(false); }
  if (cmd === 'all') { return listWindows(true); }
  if (cmd === 'displays') { return listDisplays(); }
  throw new Error('usage: windows.js list|all|displays');
}
