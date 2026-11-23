// JXA helper: build, check, re-serialize and compare manifest JSON.
// Usage: osascript -l JavaScript json.js <verb> <args...>
//   build <scratch-dir>   merge key files into manifest JSON on stdout
//   check <file>          prints "ok" or "invalid: <reason>"
//   reserialize <file>    parse and print the JSON again
//   equal <a> <b>         prints "equal" or "different"
// Every value arrives through argv or a file, never through script source.
ObjC.import('Foundation');

var OUTCOMES = ['ok', 'no_prompt', 'no_hud', 'error'];
var MODES = ['baseline', 'ward'];
var RESOLUTIONS = ['dismissed', 'still present', 'skipped', 'failed'];
var VIDEO_STATUS = ['ok', 'failed'];
var REQUIRED = ['profile_id', 'bundle_id', 'scenario', 'mode', 'started_at', 'ended_at',
  'macos_version', 'artifacts', 'outcome', 'failed_step', 'error'];
var KEY_ORDER = ['profile_id', 'bundle_id', 'scenario', 'mode', 'started_at', 'ended_at',
  'macos_version', 'artifacts', 'outcome', 'ward_commit', 'prompt', 'hud', 'video',
  'reset_failed', 'failed_step', 'error'];
var NUMERIC_LEAVES = ['bytes', 'duration_s', 'x', 'y', 'w', 'h'];
var BOOL_LEAVES = ['reset_failed'];
var NULLABLE = ['failed_step', 'error'];
var SECS_RE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T([01]\d|2[0-3]):[0-5]\d:[0-5]\d(\.\d{3})?Z$/;
var MS_RE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])T([01]\d|2[0-3]):[0-5]\d:[0-5]\d\.\d{3}Z$/;
var COMMIT_RE = /^[0-9a-f]{40}$/;

function readFile(path) {
  var err = $();
  var s = $.NSString.stringWithContentsOfFileEncodingError($(path), $.NSUTF8StringEncoding, err);
  if (s.isNil()) { throw new Error('cannot read ' + path); }
  return ObjC.unwrap(s);
}

function cpLen(s) { return Array.from(s).length; }
function cpTruncate(s, n) { return Array.from(s).slice(0, n).join(''); }

function convert(leaf, raw) {
  if (NUMERIC_LEAVES.indexOf(leaf) >= 0) {
    var n = Number(raw);
    if (raw === '' || !isFinite(n)) { throw new Error('field ' + leaf + ' is not a number: ' + raw); }
    return n;
  }
  if (BOOL_LEAVES.indexOf(leaf) >= 0 || leaf === 'service_match') {
    if (raw === 'true') { return true; }
    if (raw === 'false') { return false; }
    if (leaf === 'service_match') { return raw; }
    throw new Error('field ' + leaf + ' is not a boolean: ' + raw);
  }
  return raw;
}

function setPath(obj, path, value) {
  var parts = path.split('.');
  for (var i = 0; i < parts.length - 1; i++) {
    if (typeof obj[parts[i]] !== 'object' || obj[parts[i]] === null) { obj[parts[i]] = {}; }
    obj = obj[parts[i]];
  }
  obj[parts[parts.length - 1]] = value;
}

function ordered(doc) {
  var out = {};
  KEY_ORDER.forEach(function (k) { if (k in doc) { out[k] = doc[k]; } });
  Object.keys(doc).sort().forEach(function (k) { if (!(k in out)) { out[k] = doc[k]; } });
  return out;
}

function build(dir) {
  var fm = $.NSFileManager.defaultManager;
  var names = ObjC.deepUnwrap(fm.contentsOfDirectoryAtPathError($(dir), $())) || [];
  var doc = { artifacts: [] };
  names.sort().forEach(function (name) {
    var path = dir + '/' + name;
    if (name === 'artifacts') {
      var text = readFile(path);
      doc.artifacts = text === '' ? [] : text.split('\n').filter(function (l) { return l !== ''; });
    } else if (name.indexOf('f.') === 0) {
      var key = name.slice(2);
      var leaf = key.split('.').pop();
      var raw = readFile(path);
      if (NULLABLE.indexOf(key) >= 0) {
        if (raw === '') { return; }
        if (key === 'error') { raw = cpTruncate(raw, 1000); }
      }
      setPath(doc, key, convert(leaf, raw));
    }
  });
  NULLABLE.forEach(function (k) { if (!(k in doc)) { doc[k] = null; } });
  return JSON.stringify(ordered(doc), null, 2);
}

function isObj(v) { return v !== null && typeof v === 'object' && !Array.isArray(v); }

function checkBounds(b, label) {
  if (!isObj(b)) { return label + ' must be an object'; }
  var ks = ['x', 'y', 'w', 'h'];
  for (var i = 0; i < ks.length; i++) {
    if (typeof b[ks[i]] !== 'number') { return label + '.' + ks[i] + ' must be a number'; }
  }
  return null;
}

function validate(m) {
  var i;
  if (!isObj(m)) { return 'manifest is not an object'; }
  for (i = 0; i < REQUIRED.length; i++) {
    if (!(REQUIRED[i] in m)) { return 'missing key ' + REQUIRED[i]; }
  }
  var strs = ['profile_id', 'bundle_id', 'scenario', 'macos_version'];
  for (i = 0; i < strs.length; i++) {
    if (typeof m[strs[i]] !== 'string' || m[strs[i]] === '') { return strs[i] + ' must be a non-empty string'; }
  }
  if (MODES.indexOf(m.mode) < 0) { return 'mode must be baseline or ward: ' + JSON.stringify(m.mode); }
  if (OUTCOMES.indexOf(m.outcome) < 0) { return 'outcome not in enum: ' + JSON.stringify(m.outcome); }
  var ts = ['started_at', 'ended_at'];
  for (i = 0; i < ts.length; i++) {
    if (typeof m[ts[i]] !== 'string' || !SECS_RE.test(m[ts[i]])) {
      return ts[i] + ' is not a UTC ISO-8601 timestamp: ' + JSON.stringify(m[ts[i]]);
    }
  }
  if (!Array.isArray(m.artifacts)) { return 'artifacts must be an array'; }
  if (m.artifacts.length > 50) { return 'artifacts has more than 50 entries'; }
  for (i = 0; i < m.artifacts.length; i++) {
    var a = m.artifacts[i];
    if (typeof a !== 'string' || a === '' || a === '.' || a === '..' ||
        a.indexOf('/') >= 0 || a.indexOf('\\') >= 0 || /[\u0000-\u001f]/.test(a)) {
      return 'artifact is not a plain relative file name: ' + JSON.stringify(a);
    }
  }
  if (m.mode === 'ward') {
    if (typeof m.ward_commit !== 'string' || (m.ward_commit !== 'unknown' && !COMMIT_RE.test(m.ward_commit))) {
      return 'ward_commit must be 40 lowercase hex characters or unknown';
    }
  } else if ('ward_commit' in m) {
    return 'ward_commit is only allowed in ward mode';
  }
  if (m.outcome === 'ok') {
    if (m.failed_step !== null || m.error !== null) { return 'failed_step and error must be null when outcome is ok'; }
  } else {
    if (typeof m.failed_step !== 'string' || m.failed_step === '') { return 'failed_step must be set when outcome is not ok'; }
    if (typeof m.error !== 'string' || cpLen(m.error) < 1 || cpLen(m.error) > 1000) {
      return 'error must be 1 to 1000 characters when outcome is not ok';
    }
  }
  var sec;
  var secs = ['prompt', 'hud'];
  for (i = 0; i < secs.length; i++) {
    sec = m[secs[i]];
    if (sec === undefined) { continue; }
    if (!isObj(sec)) { return secs[i] + ' must be an object'; }
    if ('detected_at' in sec && (typeof sec.detected_at !== 'string' || !MS_RE.test(sec.detected_at))) {
      return secs[i] + '.detected_at must be UTC ISO-8601 with milliseconds';
    }
    if ('bounds' in sec) {
      var be = checkBounds(sec.bounds, secs[i] + '.bounds');
      if (be) { return be; }
    }
  }
  if (m.prompt && 'service_match' in m.prompt) {
    var sm = m.prompt.service_match;
    if (sm !== true && sm !== false && sm !== 'unknown') { return 'prompt.service_match must be true, false or "unknown"'; }
  }
  if (m.prompt && 'resolution' in m.prompt && RESOLUTIONS.indexOf(m.prompt.resolution) < 0) {
    return 'prompt.resolution not in enum';
  }
  if (m.video !== undefined) {
    if (!isObj(m.video) || VIDEO_STATUS.indexOf(m.video.status) < 0) { return 'video.status must be ok or failed'; }
  }
  if ('reset_failed' in m && typeof m.reset_failed !== 'boolean') { return 'reset_failed must be a boolean'; }
  return null;
}

function canon(v) {
  if (Array.isArray(v)) { return '[' + v.map(canon).join(',') + ']'; }
  if (isObj(v)) {
    return '{' + Object.keys(v).sort().map(function (k) { return JSON.stringify(k) + ':' + canon(v[k]); }).join(',') + '}';
  }
  return JSON.stringify(v);
}

function run(argv) {
  var verb = argv[0];
  if (verb === 'build') { return build(argv[1]); }
  if (verb === 'check') {
    var doc;
    try { doc = JSON.parse(readFile(argv[1])); } catch (e) { return 'invalid: not valid JSON: ' + e.message; }
    var why = validate(doc);
    return why === null ? 'ok' : 'invalid: ' + why;
  }
  if (verb === 'reserialize') { return JSON.stringify(JSON.parse(readFile(argv[1])), null, 2); }
  if (verb === 'equal') {
    return canon(JSON.parse(readFile(argv[1]))) === canon(JSON.parse(readFile(argv[2]))) ? 'equal' : 'different';
  }
  throw new Error('unknown verb: ' + verb);
}
