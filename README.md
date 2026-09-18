# arma3-horizoncam

An Arma 3 client-side mod that keeps the helicopter pilot's camera level with the
horizon, with a configurable pitch/roll limit beyond which the airframe drags the
camera along at a fixed offset. Goal: better attitude cues in a hover.

Status (2026-09-18): research complete, three in-game feasibility runs done. Every
camera-replacement route is dead; the mod now drives the engine's own head pose by
acting as a FreeTrack head tracker (two tiny DLLs in [native](native/README.md), no
external program). The harness in [tests/feasibility](tests/feasibility/README.md)
has a method for it (M5) awaiting its first run.
Start with [PLAN.md](PLAN.md) for the current plan, then
[docs/research/README.md](docs/research/README.md) for the research verdict and
[tests/feasibility/RESULTS.md](tests/feasibility/RESULTS.md) for the in-game evidence. The mod itself will be a CBA_A3 addon built with HEMTT.
