---
name: tempo
description: Set or report the session gear. Tempo is the shape of the session, the ratio and rhythm of divergent and convergent pulses plus the checkpoint policy. Five gears: espresso, craft, ballmer, freefall, ferment. Use when the user says "tempo", "gear", "shift gears", "downshift", "upshift", or names the session shape.
disable-model-invocation: true
---

# Tempo

The session has a gear. Tempo is the shape of the session: the ratio and
rhythm of divergent and convergent pulses, and when to checkpoint. It is a
gear ratio, never a fuel tank; slow output means wrong gear, not empty tank.

## Usage

- `/clutch:tempo <gear>` engages the named gear.
- `/clutch:tempo` bare reports: read `.clutch/tempo`; if it holds one of the
  five gears, report it in one line naming the shape, e.g.
  "Tempo: craft. Converge-dominant, regular divergent pulses; checkpoint at
  each commit point." If it is missing or holds anything else, list the five
  gears and ask which one to engage.

On engagement (explicit invocation or accepted offer), confirm in one line
naming the shape, then write the marker (POSIX, silent on any failure):

```sh
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
mkdir -p "$ROOT/.clutch" 2>/dev/null || exit 0
printf '%s\n' "<gear>" 2>/dev/null > "$ROOT/.clutch/tempo" || exit 0
```

<!-- ponytail: one shared .clutch/tempo per repo, so concurrent sessions on
     the same repo share a gear -- the same accepted ceiling as sprint-start.
     Per-session state only if it ever bites. -->

If the write fails, skip silently: the declaration still governs the live
session; only the long-session re-injection (the heartbeat's tempo line) is
lost.

## The five gears

| Gear | Shape | Checkpoints | For |
|------|-------|-------------|-----|
| **espresso** | tight convergence, ONE divergent pulse (blast-radius check) | continuous | bug fixes, review, mechanical edits |
| **craft** | converge-dominant, regular divergent pulses: explore, then commit | at each commit point | architecture, design, planning |
| **ballmer** | fast divergence, periodic convergence checkpoints | periodic, to avoid a noise spiral | ideation, exploration |
| **freefall** | pure divergence | none during; rate afterwards | unattended cross-referencing, wandering |
| **ferment** | SLOW divergence: deliberate wandering, long pulses | none; downstream rating only | the cellar: slow pre-crafting that stocks later craft sessions |

All five gears ship now. The protocols that drive the three divergent gears
(ballmer, freefall, ferment) arrive in a later version; the gears themselves
already govern pacing.

For the rest of the session, pace divergent and convergent pulses to the
engaged gear. A gear mismatch degrades the output class (a review run in
espresso treats the design question as friction), so we shift gears rather
than push through.

## Shift offers

A sustained shape mismatch, where the work's shape has changed and held
across turns, is a dispatch-table row (see rules/constitution.md). The
constraints are hard:

- Offers ride the shared budget: at most 2 uninvited lines per session
  across every channel. Record first, then speak: append
  "emit model <epoch seconds>" to `.clutch/session-state`, then say the one
  ignorable line. When the budget is spent, stay silent even on a matched
  mismatch.
- A declined offer closes the question until the user raises it.
- A downshift offer (toward tighter convergence) asks triage's
  wall-versus-inattention question first (`/clutch:triage`) and engages
  nothing until it is answered. The same short replies can mean "land this"
  or interest death, and those want opposite gears.
- An explicit `/clutch:tempo <gear>` or an accepted offer is the only thing
  that changes the engaged gear. Never shift silently on your own read.

## Gearbox rules (hard constraints)

1. **Gearbox, not a fuel tank.** Never introduce an effort reservoir, a
   willpower budget, or a recharge mechanic; the quarantine ledger bars the
   depletion model, and motivation is not gas in the tank. Slow output means
   wrong gear.
2. **Mismatch is lock or stall, not laziness.** Hyperfocus is a locked gear
   (can't downshift); the wall is a disengaged clutch (no gear helps). The
   job is shifting, not judging.
3. **Drift signals are affective data.** Shortening replies may be interest
   death, not "land this"; respond with a gear offer, never push-through, and
   disambiguate wall versus inattention before any downshift. Convergence is
   invitation-only.
4. **Saltatory leaps are native gait.** A sudden jump across the terrain is
   how this cognition moves: capture the leap (one line, then return) and
   trace the path back afterwards; never correct it back onto the rails.

Why this works: see "Tempo / the gearbox", "The five gears", and "Shape
mismatch" under the design rules in [GLOSSARY.md](../../GLOSSARY.md), and
"Motivation is not gas in the tank" (Brown) and "Saltatory cognition /
feel-first foresight (Dodson)" for the canon underneath.
