#!/usr/bin/env bash
# Human e2e checklist after Shell enable + logout (Wayland).
# This script does NOT automate hover (Shell.Eval disabled). Exit 2 = needs human.
set -euo pipefail

cat <<'EOF'
verify-e2e (human_gate) — after: gnome-extensions enable browser-tab-dock@alkitect + logout/in
Shell metadata version 16 (Chromium Snap matcher). Reload MV3 in each browser you use; Shell needs logout/in after metadata bumps.

[ ] browser-tabs-host cli status → peers include enabled browsers you loaded
[ ] Card header: favicon + title above thumb (not under)
[ ] Unvisited tab frame shows “No preview yet”; after visit, thumb appears
[ ] Scrub across dock without pausing on a browser icon → no peek flash
[ ] Pause ~100ms on Brave / Chrome / Opera / Vivaldi / Chromium → strip fades in
[ ] Move icon → app-name tooltip → strip without dismiss (leave corridor)
[ ] Leave sideways off dock → strip fades out
[ ] Click a card → tab activates; dock click still minimize-or-previews
[ ] Multi-window same browser: hover does NOT show peek strip
[ ] Vivaldi: `cli list --browser vivaldi` OK; hover Vivaldi dock icon (1 window, ≥2 tabs)
[ ] Chromium Snap: `cli list --browser chromium` OK; hover Chromium; isolation vs Chrome

Record PASS/FAIL in chat.
EOF
exit 2
