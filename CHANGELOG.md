# Changelog

All notable changes to Helicopter Horizon Lock are recorded here. The format follows Keep a Changelog and the version numbers follow Semantic Versioning.

## [1.0.0]

### Added

- Levelling of the first-person pilot view in helicopters: pitch and roll are cancelled up to the limits, yaw is never touched.
- Looking around stays vanilla: levelling pauses while a look action is held or freelook is toggled, and resumes when you stop.
- Toggle between the levelled and the vanilla view from the keyboard (CBA keybind, default Ctrl+Shift+H) or from a joystick button through one of the Use Action 1 to 20 custom controls.
- The levelled view switches on automatically when entering a helicopter.
- Seven client-side CBA settings: Enabled, Start levelled when entering a helicopter, Pitch limit, Roll limit, View pitch offset, Joystick toggle slot, Register the head tracker automatically.
- A self-check on the first mission of each session, with one plain hint per problem, and automatic registration of the mod as the engine's FreeTrack head tracker.
- Two mod-shipped DLLs: hhl_x64.dll, the extension, and FreeTrackClient64.dll, the tracker the engine loads at start-up. No external program.
- Packaging built and signed with HEMTT, with CBA_A3 as the only dependency.
