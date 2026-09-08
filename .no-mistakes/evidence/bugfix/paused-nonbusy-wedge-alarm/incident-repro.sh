#!/usr/bin/env bash
# Reproduces the 2026-09-08 supervision incident end to end against whatever
# bin/fm-watch.sh the worktree currently holds, and prints the transcript
# firstmate actually sees: the wake rows drained per supervision round.
#
# Fixture is the incident verbatim - task fm-orphan-task-detection-20260908,
# window master:fm-fm-orphan-task-detection-20260908, a NON-BUSY pane (finished
# turn, monitor armed), the declared wait appended exactly as every brief
# instructs, and fm-crew-state still attributing the no-mistakes run step to the
# crew's code. Production cadences: FM_STALE_ESCALATE_SECS=240,
# FM_PAUSE_RESURFACE_SECS=3600.
#
# Each round = one supervision round: launch the watcher, see whether it wakes
# firstmate, drain + acknowledge what it queued, then advance the simulated
# clock by 250s (the observed inter-alarm gap) and arm the successor exactly as
# fm-watch-arm.sh does after firstmate handled a wake.
set -u
WT=${FM_WT:?set FM_WT to the worktree root}
. "$WT/tests/wake-helpers.sh"
WATCH="$ROOT/bin/fm-watch.sh"
DRAIN="$ROOT/bin/fm-wake-drain.sh"
TMP_ROOT=$(fm_test_tmproot fm-incident-repro)

LABEL=${1:-current}
ROUNDS=${2:-6}
# declared   - the incident: healthy crew, declared wait, live agent
# undeclared - the same idle pane with NO declaration (must still wedge)
# dead-agent - the same declaration but the agent behind it is gone, an orphaned
#              runner rather than a wait (must still wedge)
MODE=${3:-declared}
STEP=250

reap() { kill "$1" 2>/dev/null || true; wait "$1" 2>/dev/null || true; }
file_mtime() { stat -c %Y "$1" 2>/dev/null; }
set_mtime() { touch -t "$(date -d "@$1" +%Y%m%d%H%M.%S)" "$2"; }

wait_poll_cycle() {
  local state=$1 pid=$2 limit=${3:-300} beat first now i=0
  beat="$state/.last-watcher-beat"; rm -f "$beat"; first=""
  while [ "$i" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || return 1
    first=$(file_mtime "$beat"); [ -n "$first" ] && break
    sleep 0.1; i=$((i + 1))
  done
  while [ "$i" -lt "$limit" ]; do
    kill -0 "$pid" 2>/dev/null || return 1
    now=$(file_mtime "$beat")
    [ -n "$now" ] && [ "$now" != "$first" ] && return 0
    sleep 0.1; i=$((i + 1))
  done
  return 1
}

drain_and_ack() {  # <state>  -> prints queued wake rows
  local state=$1 err seq gen
  err="$state/.drain.err"
  FM_STATE_OVERRIDE="$state" "$DRAIN" 2> "$err" \
    | awk -F '\t' 'NF>=5 { print "      " $5 }'
  seq=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through \([0-9][0-9]*\) --recovery-generation [A-Za-z0-9._-][A-Za-z0-9._-]*$/\1/p' "$err")
  gen=$(sed -n 's/^WAKE_ACK_REQUIRED:.*--ack-through [0-9][0-9]* --recovery-generation \([A-Za-z0-9._-][A-Za-z0-9._-]*\)$/\1/p' "$err")
  [ -n "$seq" ] && [ -n "$gen" ] && \
    FM_STATE_OVERRIDE="$state" "$DRAIN" --ack-through "$seq" --recovery-generation "$gen" >/dev/null 2>&1
  rm -f "$err"
}

age_state() {  # <state> <key> <secs>
  local state=$1 key=$2 by=$3 f v now
  now=$(date +%s)
  for f in "$state/.stale-since-$key" "$state/.paused-rechecked-$key"; do
    [ -e "$f" ] || continue
    v=$(cat "$f" 2>/dev/null || true)
    case "$v" in ''|*[!0-9]*) ;; *) echo $((v - by)) > "$f" ;; esac
    set_mtime $(( $(file_mtime "$f") - by )) "$f"
  done
  for f in "$state/.paused-resurfaced-$key"; do
    [ -e "$f" ] && set_mtime $(( $(file_mtime "$f") - by )) "$f"
  done
}

task=fm-orphan-task-detection-20260908
window="master:fm-fm-orphan-task-detection-20260908"
# The fixture dir name must stay shell-and-PATH safe: it is prepended to PATH so
# the hermetic fake tmux/fm-crew-state are found, and a colon there silently
# splits PATH and takes the whole fake backend out of the run.
dir=$(make_case "incident-$(printf '%s' "$LABEL" | tr -c 'A-Za-z0-9._-' '-')"); state="$dir/state"; fakebin="$dir/fakebin"
pane="$dir/pane.txt"; out="$dir/watch.out"
statusf="$state/$task.status"
key=$(printf '%s' "$window" | tr ':/.' '___')

# A finished turn: the composer is idle, the monitor is armed on the blocking call.
cat > "$pane" <<'PANE'
> monitor armed on the no-mistakes review fix round
  (idle)
PANE
printf 'window=%s\nkind=ship\nharness=claude\nbackend=tmux\n' "$window" > "$state/$task.meta"
{
  printf 'working: implementing orphan-task detection\n'
  [ "$MODE" = undeclared ] \
    || printf 'paused: [key=nm-review-fix] waiting on the no-mistakes review fix round, monitor armed\n'
} > "$statusf"
# The pane command is the backend's liveness evidence: the agent itself for a
# live worker, a bare shell once the agent is gone.
pane_cmd=claude
[ "$MODE" = dead-agent ] && pane_cmd=zsh
set_mtime $(( $(date +%s) - 400 )) "$statusf"
prime_status_seen "$state" "$statusf"
printf '%s' "$(hash_text "$(cat "$pane")")" > "$state/.hash-$key"
printf '1\n' > "$state/.count-$key"
export FM_FAKE_CREW_STATE='state: working · source: run-step · validating (running)'

echo "=============================================================="
echo " firstmate supervision transcript - $LABEL bin/fm-watch.sh"
echo " worker: $task"
echo " mode:   $MODE (pane command: $pane_cmd)"
echo " pane:   NON-BUSY (turn finished, monitor armed)"
echo " status: $(tail -1 "$statusf")"
echo " crew-state: $FM_FAKE_CREW_STATE"
echo " cadence: STALE_ESCALATE_SECS=240  PAUSE_RESURFACE_SECS=3600"
echo "=============================================================="
wakes=0; wedges=0; elapsed=0
round=1
while [ "$round" -le "$ROUNDS" ]; do
  succ=""; [ "$round" -gt 1 ] && succ=1
  : > "$out"
  env PATH="$fakebin:$PATH" FM_FAKE_TMUX_WINDOW="$window" FM_FAKE_TMUX_CAPTURE="$pane" \
    FM_FAKE_TMUX_CURRENT_COMMAND="$pane_cmd" ${succ:+FM_WATCH_HANDLING_SUCCESSOR=1} \
    FM_FAKE_CREW_STATE="$FM_FAKE_CREW_STATE" FM_ROOT_OVERRIDE="$FM_ROOT_OVERRIDE" \
    FM_STATE_OVERRIDE="$state" FM_CREW_STATE_BIN="$fakebin/fm-crew-state.sh" \
    FM_STALE_ESCALATE_SECS=240 FM_PAUSE_RESURFACE_SECS=3600 \
    FM_POLL=1 FM_SIGNAL_GRACE=1 FM_CHECK_INTERVAL=999999 FM_HEARTBEAT=999999 \
    "$WATCH" > "$out" 2>&1 &
  pid=$!
  printf 'round %d  (t+%4ds of the wait)\n' "$round" "$elapsed"
  # An actionable wake makes the watcher EXIT so firstmate's LLM re-arms; a
  # benign one is absorbed in bash and the watcher stays in its poll loop.
  # A round ends when the watcher exits, or after three COMPLETE poll cycles - a
  # wall-clock budget can reap a loaded watcher before its first stale scan and
  # then report a quiet round that was never classified at all.
  cycles=0; alive=1
  while [ "$cycles" -lt 3 ]; do
    if ! wait_poll_cycle "$state" "$pid" 600; then alive=0; break; fi
    cycles=$((cycles + 1))
  done
  [ "$alive" = 1 ] && reap "$pid"
  rows=$(drain_and_ack "$state")
  if [ -n "$rows" ]; then
    wakes=$((wakes + 1))
    echo "  WOKE FIRSTMATE -> a supervision turn spent draining, inspecting, acknowledging:"
    printf '%s\n' "$rows"
    printf '%s\n' "$rows" | grep -qF "possible wedge" && wedges=$((wedges + 1))
  elif [ "$alive" = 1 ]; then
    echo "  quiet - stayed in the poll loop, absorbed in bash, firstmate not woken"
  else
    echo "  watcher exited without queueing a wake; stdout was: $(cat "$out")"
  fi
  [ -n "${FM_KEEP:-}" ] && printf '    [debug] cycles=%s alive=%s stale-since=%s (age %ss) escalations=%s\n' \
    "$cycles" "$alive" "$(cat "$state/.stale-since-$key" 2>/dev/null || echo none)" \
    "$( [ -e "$state/.stale-since-$key" ] && echo $(( $(date +%s) - $(file_mtime "$state/.stale-since-$key") )) || echo - )" \
    "$(cat "$state/.wedge-escalations-$key" 2>/dev/null || echo none)"
  age_state "$state" "$key" "$STEP"
  elapsed=$((elapsed + STEP))
  round=$((round + 1))
done
[ -n "${FM_KEEP:-}" ] && { echo " state dir: $state"; ls -la "$state" | sed "s/^/   /"; echo " triage log:"; cat "$state/.watch-triage.log" | sed "s/^/   /"; }
echo "--------------------------------------------------------------"
printf ' RESULT: firstmate woken %d time(s) in %d simulated minutes; %d of those were "possible wedge" alarms\n' \
  "$wakes" "$((elapsed / 60))" "$wedges"
echo "--------------------------------------------------------------"
