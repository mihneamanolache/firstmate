#!/usr/bin/env bash
# Build an FM_HOME that reproduces the reported /bearings home: a ~130 KB
# data/backlog.md carrying 73 open captain holds with long multi-sentence
# reasons, live crewmate tasks whose status logs have accumulated a week of
# needs-decision entries, a scout report, and one local secondmate home.
set -eu
HOME_DIR=$1
rm -rf "$HOME_DIR"
mkdir -p "$HOME_DIR/state" "$HOME_DIR/data" "$HOME_DIR/projects" "$HOME_DIR/config" "$HOME_DIR/fakebin"
MATE="$HOME_DIR-secondmate-home"
rm -rf "$MATE"
mkdir -p "$MATE/state" "$MATE/data" "$MATE/config" "$MATE/projects" "$MATE/bin"
printf '# Firstmate\n' > "$MATE/AGENTS.md"
printf 'mate\n' > "$MATE/.fm-secondmate-home"
printf -- '- mate - fleet domain (home: %s; scope: fleet work; projects: firstmate; added 2026-08-20)\n' \
  "$MATE" > "$HOME_DIR/data/secondmates.md"

long_reason() {  # <n>
  printf 'the captain has to choose between keeping the current adapter contract and re-cutting it for run %s. ' "$1"
  printf 'The queued follow-up depends on that choice and cannot be briefed until it is made. '
  printf 'Both routes were costed and neither is reversible cheaply once a worker starts on it.'
}

{
  printf '## In flight\n'
  printf -- '- [ ] ship-task - Ship the fleet snapshot transport fix (repo: firstmate) (kind: ship) (since 2026-09-01)\n'
  printf -- '- [ ] scout-x - Investigate the bearings failure data/scout-x/report.md (repo: firstmate) (kind: scout) (since 2026-09-01)\n'
  printf -- '- [ ] mate - Decide subscription order (repo: firstmate) (kind: ship) (since 2026-09-01)\n'
  printf '\n## Queued\n'
  i=1
  while [ "$i" -le 73 ]; do
    printf -- '- [ ] hold-%02d - Captain decision %02d on fleet route %02d (repo: firstmate) (kind: captain) (hold: %s) (hold-kind: captain)\n' \
      "$i" "$i" "$i" "$(long_reason "$i")"
    printf '  Context kept with the row: %s\n' "$(long_reason "$i")"
    i=$((i + 1))
  done
  i=1
  while [ "$i" -le 90 ]; do
    printf -- '- [ ] queued-%03d - Queued fleet work %03d blocked-by: ship-task (repo: firstmate) (kind: ship)\n' "$i" "$i"
    printf '  Body prose kept for the captain: %s\n' "$(long_reason "$i")"
    i=$((i + 1))
  done
  printf '\n## Done\n'
  i=1
  while [ "$i" -le 105 ]; do
    printf -- '- [x] done-%03d - Landed fleet work %03d https://github.com/kunchenguid/firstmate/pull/%s (repo: firstmate) (kind: ship) (merged 2026-08-%02d)\n' \
      "$i" "$i" "$((3000 + i))" "$(( (i % 28) + 1 ))"
    printf '  Outcome note: %s\n' "$(long_reason "$i")"
    i=$((i + 1))
  done
} > "$HOME_DIR/data/backlog.md"

mkdir -p "$HOME_DIR/projects/ship-wt" "$HOME_DIR/data/scout-x"
printf '# Scout X\n\nThe bearings snapshot fails before field projection.\n' > "$HOME_DIR/data/scout-x/report.md"

write_meta() {  # <file> <kv...>
  local f=$1; shift; : > "$f"; for kv in "$@"; do printf '%s\n' "$kv" >> "$f"; done
}

write_meta "$HOME_DIR/state/ship-task.meta" \
  "window=firstmate:fm-ship-task" \
  "worktree=$HOME_DIR/projects/ship-wt" \
  "project=firstmate" "harness=claude" "kind=ship" "mode=no-mistakes" \
  "pr=https://github.com/kunchenguid/firstmate/pull/9"
write_meta "$HOME_DIR/state/scout-x.meta" \
  "window=firstmate:fm-scout-x" \
  "worktree=$HOME_DIR/projects/ship-wt" \
  "project=firstmate" "harness=claude" "kind=scout" "mode=scout"
write_meta "$HOME_DIR/state/mate.meta" \
  "window=firstmate:fm-mate" "worktree=$MATE" "project=$MATE" \
  "harness=codex" "kind=secondmate" "mode=secondmate" "home=$MATE" "projects=firstmate"

# One extra ship task per additional repo, each with its own recorded PR, so
# `/bearings include PRs` enumerates a fleet-sized repo set.
r=1
while [ "$r" -le "${PR_REPOS:-0}" ]; do
  mkdir -p "$HOME_DIR/projects/repo-$r-wt"
  write_meta "$HOME_DIR/state/ship-repo-$r.meta" \
    "window=firstmate:fm-ship-repo-$r" \
    "worktree=$HOME_DIR/projects/repo-$r-wt" \
    "project=service-$r" "harness=claude" "kind=ship" "mode=no-mistakes" \
    "pr=https://github.com/kunchenguid/service-$r/pull/$((100 + r))"
  printf 'working: rebuilding service-%s ingestion\n' "$r" > "$HOME_DIR/state/ship-repo-$r.status"
  r=$((r + 1))
done

# A week of accumulated status-log lines on the live crewmates, including the
# keyed needs-decision entries the classifier folds into hints.open_decisions.
status_log() {  # <file> <decisions> <progress>
  local file=$1 decisions=$2 progress=$3 i=1
  : > "$file"
  while [ "$i" -le "$decisions" ]; do
    printf 'needs-decision [key=route-%03d]: choose whether run %03d keeps the current adapter contract or re-cuts it, because the queued follow-up depends on the answer and neither route is cheap to reverse once a worker starts\n' \
      "$i" "$i" >> "$file"
    i=$((i + 1))
  done
  i=1
  while [ "$i" -le "$progress" ]; do
    printf 'working: phase %03d of the transport rework - rewrote the component composition, re-ran the focused suite, and recorded the result for the captain\n' "$i" >> "$file"
    i=$((i + 1))
  done
}
status_log "$HOME_DIR/state/ship-task.status" "${DECISIONS:-90}" 400
printf 'done: report ready for the captain, the failure reproduces on every invocation\n' > "$HOME_DIR/state/scout-x.status"
printf 'needs-decision [key=race]: pick the subscribe order for the fleet adapter, the answer gates the queued follow-up\n' > "$HOME_DIR/state/mate.status"
i=1
while [ "$i" -le "${MATE_DECISIONS:-0}" ]; do
  printf 'needs-decision [key=domain-%03d]: %s\n' "$i" "$(long_reason "$i")" >> "$HOME_DIR/state/mate.status"
  i=$((i + 1))
done
printf 'done: an unrelated subtask finished\n' >> "$HOME_DIR/state/mate.status"

cat > "$MATE/data/backlog.md" <<EOF
## In flight
- [ ] mate - Decide subscription order (repo: firstmate) (kind: ship) (since 2026-09-01)

## Queued
- [ ] mate-decision-race - Choose subscription order (repo: firstmate) (kind: captain) (hold: captain choice pending) (hold-kind: captain)

## Done
- [x] mate-landed - Secondmate-managed fix https://github.com/kunchenguid/firstmate/pull/50 (repo: firstmate) (kind: ship) (merged 2026-09-01)
EOF
mkdir -p "$MATE/projects/mate"
write_meta "$MATE/state/mate.meta" \
  "window=firstmate:fm-mate" "worktree=$MATE/projects/mate" "project=firstmate" \
  "harness=claude" "kind=ship" "mode=no-mistakes"

# PATH fakes: local tooling the snapshot may reach for, plus a gh that returns a
# realistic fleet-sized open-PR page.
FB="$HOME_DIR/fakebin"
cat > "$FB/no-mistakes" <<'SH'
#!/usr/bin/env bash
exit 0
SH
cat > "$FB/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  display-message) printf '%%1\n' ;;
  capture-pane) printf 'all quiet\n> \n' ;;
esac
exit 0
SH
cat > "$FB/gh" <<'SH'
#!/usr/bin/env bash
n=${FAKE_GH_PRS:-40}
printf '['
i=1
while [ "$i" -le "$n" ]; do
  [ "$i" -eq 1 ] || printf ','
  printf '{"number":%s,"title":"Open fleet PR %s - rework the component transport so oversized inventories stop failing the exec","url":"https://github.com/kunchenguid/firstmate/pull/%s","headRefName":"fm/fleet-transport-%s","reviewDecision":"","mergeable":"MERGEABLE","statusCheckRollup":[{"conclusion":"SUCCESS","status":"COMPLETED"}]}' \
    "$i" "$i" "$i" "$i"
  i=$((i + 1))
done
printf ']\n'
SH
cat > "$FB/gh-axi" <<'SH'
#!/usr/bin/env bash
exit 0
SH
chmod +x "$FB/no-mistakes" "$FB/tmux" "$FB/gh" "$FB/gh-axi"

printf 'home: %s\nbacklog bytes: %s\ncaptain holds: %s\nship-task status bytes: %s\n' \
  "$HOME_DIR" "$(wc -c < "$HOME_DIR/data/backlog.md")" \
  "$(grep -c 'hold-kind: captain' "$HOME_DIR/data/backlog.md")" \
  "$(wc -c < "$HOME_DIR/state/ship-task.status")"
