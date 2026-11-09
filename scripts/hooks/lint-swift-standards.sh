#!/usr/bin/env bash
# Enforce .kiro/steering/swift-coding-standards.md on production Swift files:
#   1. no force-unwrap / try! / as!
#   2. files stay near 300 lines (hard limit 320)
#   3. every public/open declaration has a /// doc comment
# Exit 2 on violations, 0 otherwise. Violations print to stderr.
# Usage: lint-swift-standards.sh [file ...]   (or Kiro hook JSON on stdin)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/_files.sh"

if [ "$#" -gt 0 ]; then files=("$@"); else
  files=(); while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(
    target_files '\.swift$' GatekeepersWard WardTrigger )
fi

status=0
for f in ${files[@]+"${files[@]}"}; do
  [ -f "$f" ] || continue
  case "$f" in */GatekeepersWardTests/*|*Tests.swift) continue ;; esac
  perl -e '
    my ($file, $max) = @ARGV; my ($prev, $bad) = ("", 0);
    open my $fh, "<", $file or exit 0;
    while (my $l = <$fh>) {
      chomp $l; my $raw = $l;
      (my $code = $l) =~ s{//.*$}{}; $code =~ s{"(?:[^"\\]|\\.)*"}{""}g;
      if ($code =~ /(?:[\w\)\]]!(?!=)|\btry!|\bas!)/) { print "standards: $file:$.: force-unwrap\n"; $bad = 1 }
      if ($raw =~ /^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public|open)\s+(?:final\s+|static\s+|class\s+|mutating\s+|override\s+)*(?:func|struct|class|enum|protocol|actor|init|var|let|typealias|extension)\b/
          && $prev !~ m{^\s*///|\*/\s*$}) {
        print "standards: $file:$.: public declaration without /// doc comment\n"; $bad = 1 }
      $prev = $raw unless $raw =~ /^\s*@\w+/ || $raw =~ /^\s*$/;
      $total = $.;
    }
    if ($total > $max) { print "standards: $file: $total lines (limit ~300); extract a type\n"; $bad = 1 }
    exit($bad);
  ' "$f" 320 >&2 || status=2
done

[ "$status" -eq 0 ] && echo "standards: ok (${#files[@]} file(s))"
exit "$status"
