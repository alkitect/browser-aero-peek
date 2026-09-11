#!/usr/bin/env bash
# Human e2e checklist after Shell enable + logout (Wayland).
# This script does NOT automate hover (Shell.Eval disabled). Exit 2 = needs human.
set -euo pipefail

cat <<'EOF'
verify-e2e (human_gate) — after: gnome-extensions enable browser-tab-dock@alkitect + logout/in
Shell metadata version 9 (peek polish). MV3 reload only if you changed the Brave extension.

[ ] browser-tabs-host cli status → extension_connected true
[ ] Card header: favicon + title above thumb (not under)
[ ] Unvisited tab frame shows “No preview yet”; after visit, thumb appears
[ ] Scrub across dock without pausing on Brave → no peek flash
[ ] Pause ~100ms on Brave → strip fades in
[ ] Move icon → app-name tooltip → strip without dismiss (leave corridor)
[ ] Leave sideways off dock → strip fades out
[ ] Click a card → tab activates; dock click still minimize-or-previews
[ ] Multi-window Brave: hover does NOT show peek strip

Record PASS/FAIL in chat.
EOF
exit 2
