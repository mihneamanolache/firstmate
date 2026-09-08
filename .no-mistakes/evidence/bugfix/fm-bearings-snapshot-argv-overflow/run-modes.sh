#!/usr/bin/env bash
# Run /bearings step 1 the way each mode invokes it, against the reproduced home.
set -u
BIN=$1; H=$2
export PATH="$H/fakebin:$PATH" FM_HOME="$H" FM_BEARINGS_NOW=2026-09-08T12:00:00Z
banner() { printf '\n===== %s =====\n' "$*"; }

banner "home under test"
printf 'FM_HOME=%s\ndata/backlog.md: %s bytes, %s open captain holds\ntasks: %s\n' \
  "$H" "$(wc -c < "$H/data/backlog.md")" "$(grep -c 'hold-kind: captain' "$H/data/backlog.md")" \
  "$(ls "$H"/state/*.meta | wc -l)"

banner '/bearings (plain mode) -> bin/fm-bearings-snapshot.sh'
"$BIN/fm-bearings-snapshot.sh"; printf 'exit=%s\n' "$?"

banner '/bearings with a reduced --fields list'
"$BIN/fm-bearings-snapshot.sh" --fields home,decisions_open,in_flight; printf 'exit=%s\n' "$?"

banner '/bearings file + lavish mode step 1 -> bin/fm-bearings-snapshot.sh --json'
out=$("$BIN/fm-bearings-snapshot.sh" --json); rc=$?
printf 'exit=%s bytes=%s\n' "$rc" "$(printf '%s' "$out" | wc -c)"
printf '%s' "$out" | jq '{schema, home, in_flight:(.in_flight|length),
  decisions_open:(.decisions_open|length), gates:(.gates|length),
  landed:(.landed|length), reports:(.reports|length),
  secondmates:(.secondmates|length), omitted:(.omitted|length)}'
printf 'first three Captain'"'"'s Call rows:\n'
printf '%s' "$out" | jq -c '.decisions_open[:3][]'
printf 'secondmate row:\n'
printf '%s' "$out" | jq -c '.secondmates[]'

banner '/bearings include PRs -> bin/fm-bearings-snapshot.sh --include-prs --json'
out=$(FAKE_GH_PRS=60 FM_BEARINGS_PR_LIMIT=60 "$BIN/fm-bearings-snapshot.sh" --include-prs --json); rc=$?
printf 'exit=%s\n' "$rc"
printf '%s' "$out" | jq '{prs, candidate_prs:(.candidate_prs|length)}'
