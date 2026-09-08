# The 2026-09-08 repeating wedge alarm on a healthy worker

End-to-end reproduction of the reported incident against the real
`bin/fm-watch.sh` supervision loop, driven by
[`incident-repro.sh`](incident-repro.sh).

Fixture is the incident verbatim: task `fm-orphan-task-detection-20260908`, window
`master:fm-fm-orphan-task-detection-20260908`, a NON-BUSY pane (turn finished,
monitor armed on the blocking call), the declared wait appended exactly as every
brief instructs, and `fm-crew-state` still attributing the no-mistakes run step
to the crew's code. Production cadences (`STALE_ESCALATE_SECS=240`,
`PAUSE_RESURFACE_SECS=3600`). Each round is one supervision round: the watcher
runs, whatever it queued is drained and acknowledged the way firstmate would,
then the simulated clock advances 250s (the observed inter-alarm gap) and the
successor is armed.

| scenario | watcher | firstmate wakes / 33 min | "possible wedge" alarms |
| --- | --- | --- | --- |
| the incident: healthy crew, declared wait, live agent | PRE-FIX (`b84e0e3`) | 4 | **4** (escalation 1 -> 4, reaching demand-deep-inspection) |
| the incident: healthy crew, declared wait, live agent | AFTER FIX (`16965e6`) | 1 (plain first-sight `stale:` row, fail-open) | **0** |
| safety A: same idle pane, NO declaration | AFTER FIX | 2 / 16 min | 2 (unchanged wedge ladder) |
| safety B: declaration standing, agent behind it GONE | AFTER FIX | 2 / 16 min | 2 (orphaned runner still wedges) |

Transcripts:

- [`incident-before-fix.txt`](incident-before-fix.txt) - the incident reproduced on the base commit
- [`incident-after-fix.txt`](incident-after-fix.txt) - the same fixture on this change
- [`after-fix-safety-A-undeclared.txt`](after-fix-safety-A-undeclared.txt) - the absorb did not widen into "idle is fine"
- [`after-fix-safety-B-dead-agent.txt`](after-fix-safety-B-dead-agent.txt) - a declaration with no author left keeps the ladder

The pre-fix rows are the reported alarm text verbatim:

```
stale: master:fm-fm-orphan-task-detection-20260908 (idle 261s, possible wedge, escalation 1)
stale: master:fm-fm-orphan-task-detection-20260908 (idle 261s, possible wedge, escalation 2)
stale: master:fm-fm-orphan-task-detection-20260908 (idle 260s, possible wedge, escalation 3, demand-deep-inspection: ...)
stale: master:fm-fm-orphan-task-detection-20260908 (idle 260s, possible wedge, escalation 4, demand-deep-inspection: ...)
```

After the change the same 33 minutes of the same healthy wait produce one plain
`stale: master:fm-fm-orphan-task-detection-20260908` on first sight and nothing
else - no wedge wording, no escalation ladder, no accumulated escalation count.
