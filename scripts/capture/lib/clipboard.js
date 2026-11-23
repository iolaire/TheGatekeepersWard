// Pasteboard helper for the permission capture framework.
// Run as: osascript -l JavaScript clipboard.js <verb> <arg>
//   snapshot <file>   write every item and type on the general pasteboard to file
//   restore <file>    put the snapshot back (clears the pasteboard first)
//   set <text>        replace the pasteboard with plain text
// The snapshot is JSON: [[{"type": "<uti>", "b64": "<base64 data>"}, ...], ...]
// (one inner array per pasteboard item). Images and rich text survive, which a
// pbcopy round trip would lose. Values arrive in argv only.
ObjC.import('AppKit');
ObjC.import('Foundation');

function run(argv) {
  if (argv.length < 2) throw new Error('usage: clipboard.js snapshot|restore|set <arg>');
  var verb = argv[0];
  var arg = argv[1];
  var pb = $.NSPasteboard.generalPasteboard;

  if (verb === 'set') {
    pb.clearContents;
    if (!pb.setStringForType($(arg), $.NSPasteboardTypeString)) throw new Error('set failed');
    return 'ok';
  }

  if (verb === 'snapshot') {
    var items = [];
    var src = pb.pasteboardItems;
    var n = src ? Number(src.count) : 0;
    for (var i = 0; i < n; i++) {
      var item = src.objectAtIndex(i);
      var types = item.types;
      var rec = [];
      for (var j = 0; j < Number(types.count); j++) {
        var t = types.objectAtIndex(j);
        var d = item.dataForType(t);
        if (!d || !(Number(d.length) > 0)) continue;
        rec.push({ type: ObjC.unwrap(t), b64: ObjC.unwrap(d.base64EncodedStringWithOptions(0)) });
      }
      items.push(rec);
    }
    var json = $(JSON.stringify(items));
    var err = $();
    if (!json.writeToFileAtomicallyEncodingError($(arg), true, $.NSUTF8StringEncoding, err)) {
      throw new Error('cannot write snapshot');
    }
    return 'ok';
  }

  if (verb === 'restore') {
    var text = $.NSString.stringWithContentsOfFileEncodingError($(arg), $.NSUTF8StringEncoding, $());
    if (typeof ObjC.unwrap(text) !== 'string') throw new Error('cannot read snapshot');
    var data = JSON.parse(ObjC.unwrap(text));
    pb.clearContents;
    var objs = [];
    for (var a = 0; a < data.length; a++) {
      var pbi = $.NSPasteboardItem.alloc.init;
      for (var b = 0; b < data[a].length; b++) {
        var raw = $.NSData.alloc.initWithBase64EncodedStringOptions($(data[a][b].b64), 0);
        pbi.setDataForType(raw, $(data[a][b].type));
      }
      objs.push(pbi);
    }
    if (objs.length > 0 && !pb.writeObjects($(objs))) throw new Error('restore failed');
    return 'ok';
  }

  throw new Error('unknown verb: ' + verb);
}
