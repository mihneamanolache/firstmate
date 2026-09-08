#!/usr/bin/env bash
# Add a parked crewmate whose accumulated keyed decisions survive lifecycle
# clearing (parked tasks keep their open captain decisions).
set -eu
H=$1; HB=/home/tavi/.no-mistakes/worktrees/28f6a8cebf51/01M20KT54F10J3R74XM6XA1GD4
: > "$H/state/ship-parked.status"
i=1
while [ "$i" -le 520 ]; do
  printf 'needs-decision [key=route-%03d]: choose whether run %03d keeps the current adapter contract or re-cuts it for the queued follow-up, because the queued work depends on that answer and neither route reverses cheaply once a worker starts on it\n' "$i" "$i" >> "$H/state/ship-parked.status"
  i=$((i + 1))
done
printf 'paused: parked waiting on the captain to pick a route\n' >> "$H/state/ship-parked.status"
{ printf 'window=firstmate:fm-ship-parked\n'; printf 'worktree=%s/projects/ship-wt\n' "$H"; printf 'project=firstmate\nharness=claude\nkind=ship\nmode=no-mistakes\n'; } > "$H/state/ship-parked.meta"
export PATH="$H/fakebin:$PATH"
gen=$("$HB/bin/fm-busy-event.sh" arm "$H/state" ship-parked)
"$HB/bin/fm-busy-event.sh" apply "$H/state" ship-parked idle --gen "$gen" --source claude-hook --event stop
python3 - "$H/data/backlog.md" <<'PY'
import sys
p=sys.argv[1]
s=open(p).read()
s=s.replace('## In flight\n','## In flight\n- [ ] ship-parked - Rework the adapter route (repo: firstmate) (kind: ship) (since 2026-09-02)\n',1)
open(p,'w').write(s)
PY
printf 'ship-parked status bytes: %s\n' "$(wc -c < "$H/state/ship-parked.status")"
