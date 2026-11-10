#!/usr/bin/env bash
# Castle Keep palette and copy check for HUD/ and MenuBar/ Swift files.
# Source of truth: docs/Planning/Styles/The Castle Keep & The Wandering Spirits.md
# (+ Wrought Iron #2D3139 from .kiro/steering/project.md for panel borders).
# Flags: hex colours outside the palette, and generic Allow/Deny button copy.
# A line containing "palette-ok" is exempt (for example, quoting Apple's own button names).
# Exit 2 on violations, 0 otherwise.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/_files.sh"

PALETTE="E0E7FF C7D2FE 8B5CF6 F59E0B 0E1013 F43F5E 2D3139 2E1065 3B185F F472B6"

if [ "$#" -gt 0 ]; then files=("$@"); else
  files=(); while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(
    target_files '/(HUD|MenuBar)/.*\.swift$' GatekeepersWard/HUD GatekeepersWard/MenuBar | grep -E '/(HUD|MenuBar)/' )
fi

status=0
for f in ${files[@]+"${files[@]}"}; do
  [ -f "$f" ] || continue
  perl -e '
    my ($file, $palette) = @ARGV; my %ok = map { $_ => 1 } split / /, $palette; my $bad = 0;
    open my $fh, "<", $file or exit 0;
    while (my $l = <$fh>) {
      next if $l =~ m{^\s*//};
      next if $l =~ /palette-ok/;
      while ($l =~ /(?:#|0x)([0-9A-Fa-f]{6})\b/g) {
        next if $ok{uc $1};
        print "palette: $file:$.: #" . uc($1) . " is not a Castle Keep token\n"; $bad = 1 }
      if ($l =~ /"(?:Allow|Deny|Block|Permit|Cancel)"/) {
        print "palette: $file:$.: use \"Let Spirit Pass\" / \"Lower Portcullis\" copy\n"; $bad = 1 }
    }
    exit($bad);
  ' "$f" "$PALETTE" >&2 || status=2
done

[ "$status" -eq 0 ] && echo "palette: ok (${#files[@]} file(s))"
exit "$status"
