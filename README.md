# Helicopter Horizon Lock

Keeps the first-person pilot view level with the horizon in Arma 3 helicopters. The cockpit tilts around you while the horizon stays put. Cockpit, instruments, HUD symbology, flight controls and freelook are all vanilla; nothing else is changed.

**Motion sickness:** a view that stays level while the cockpit rolls around you is not the cue you are used to, and some people feel queasy at first. Start with short sessions and toggle the levelled view off (Ctrl+Shift+H by default) the moment you feel unwell. Lowering the pitch and roll limits does not help: a view that follows the aircraft only past the limit was worse in testing, so the defaults are the full range.

## How it works

Arma 3 has a built-in FreeTrack head-tracker input. This mod acts as that tracker. It ships two small DLLs: hhl_x64.dll, the extension the addon talks to, and FreeTrackClient64.dll, the tracker the engine loads at start-up. Every frame the addon reads the aircraft's pitch and roll and sends a head pose that cancels them, up to the limits you set, so the engine draws the view level.

## Requirements

- Arma 3, 64-bit (what the Launcher starts by default).
- CBA_A3.
- Windows.

Not for use together with a real head or eye tracker (TrackIR, Tobii, opentrack). The engine has one head-tracking slot and this mod occupies it.

## Install

**Steam Workshop:** subscribe, then enable the mod in the Launcher together with CBA_A3.

**Zip:** unpack the @HelicopterHorizonLock folder into your Arma 3 folder and add it as a local mod in the Launcher, together with CBA_A3.

## First run

The engine only loads a head tracker that is registered in the Windows registry, so the mod registers itself the first time it runs. In order:

- Start any mission. The mod writes the registry value HKCU\Software\Freetrack\FreetrackClient\Path, pointing at the mod folder, and remembers that folder under HKCU\Software\HelicopterHorizonLock so it never overwrites another tracker's value. It then shows the hint **Helicopter Horizon Lock: head tracker registered. Restart Arma 3 once.**
- Restart Arma 3.
- Enable FreeTrack under Options > Controls > Controllers. If it is off, the mod reminds you the first time you fly.
- Take a helicopter pilot seat. The view levels itself.

## BattlEye

The two DLLs are not yet on BattlEye's whitelist, and BattlEye blocks any DLL it does not know. For now, launch without BattlEye: Launcher > Parameters > untick BattlEye. When BattlEye has blocked the mod, it tells you with the hint **BattlEye or a missing DLL blocked the extension. Launch Arma 3 without BattlEye.**

A server that runs BattlEye cannot be joined with BattlEye off, so until the whitelisting is through the mod is for single player and for servers without BattlEye.

## Using it

The levelled view switches on when you get into a helicopter (setting **Start levelled when entering a helicopter**). Levelling itself only acts in the pilot seat, in first person. Yaw is never touched, so the view keeps pointing where the nose points, and the engine's V-shaped freelook nose marker still moves with the aircraft.

Toggle between the levelled and the vanilla view at any time:

- **Keyboard:** Ctrl+Shift+H by default. Change it under Configure Addons (CBA) > Helicopter Horizon Lock > **Toggle levelled view**.
- **Joystick button:** set the **Joystick toggle slot** setting to one of Arma's Use Action 1 to 20 custom controls, then bind that Use Action to your button under Configure > Controls > Custom.

Looking around is vanilla. While you look around (Alt freelook, held or toggled, or the look left, right and down keys) levelling pauses and the head recentres; it resumes when you stop.

## Settings

Options > Addon Options > Helicopter Horizon Lock. All settings are client-side.

- **Enabled** (default on): master switch. Off means the vanilla view.
- **Start levelled when entering a helicopter** (default on): switches the levelled view on whenever you take a helicopter seat.
- **Pitch limit** (0 to 90 degrees, default 90): degrees of nose pitch cancelled before the view starts following the aircraft. 90 keeps the horizon level at any pitch.
- **Roll limit** (0 to 45 degrees, default 45): degrees of bank cancelled before the view starts following the aircraft. The engine stops head roll at 45 degrees, so 45 keeps the horizon level at any bank it can.
- **View pitch offset** (-20 to +20 degrees, default 0): degrees added to the levelled view, positive looks up. 0 keeps the aircraft's default head angle.
- **Joystick toggle slot** (default None): the custom control, Use Action 1 to 20, that toggles the levelled view. Bind it to a joystick button under Configure > Controls > Custom.
- **Register the head tracker automatically** (default on): writes the registry value that makes Arma 3 load the mod's head tracker. Never overwrites another tracker's value.

## Multiplayer

The mod is client-side: nothing runs on the server, and the server does not need it. A server that verifies signatures needs the mod's key: copy keys/hhl_1.0.0.bikey from the mod folder into the server's keys folder. Each release is signed with a new key, so the key file changes with every version.

## Removing the mod

Unsubscribe, or delete the mod folder. The registry value stays behind and is harmless: Arma simply finds no tracker. To clean it up anyway, either run this in the debug console before removing the mod (start any scenario from the Eden editor with Play in Singleplayer, press Esc, open the Debug Console, type the command in the EXECUTE box and press LOCAL EXEC):

```
"hhl" callExtension "uninstall"
```

or afterwards run these two commands in a command prompt:

```
reg delete "HKCU\Software\Freetrack\FreetrackClient" /v Path /f
```

```
reg delete "HKCU\Software\HelicopterHorizonLock" /f
```

Then turn FreeTrack off again under Options > Controls > Controllers.

## Troubleshooting

The mod shows one hint per problem, once per game session:

- **BattlEye or a missing DLL blocked the extension. Launch Arma 3 without BattlEye.** The extension did not load. Launch without BattlEye (see above) and check that both DLLs are in the mod folder.
- **head tracker registered. Restart Arma 3 once.** The registry value was just written. Restart the game.
- **another head-tracking client is registered at ...** Another tracker program owns the registry value. The mod leaves it alone and does nothing; remove that tracker's registration first if you want this mod instead.
- **enable FreeTrack under Options > Controls > Controllers.** The engine is not polling the tracker. Enable FreeTrack there.

If the view does not level and there is no hint, check that FreeTrack is enabled, BattlEye is off and CBA_A3 is loaded. Then run this in the debug console (opened as described under Removing the mod):

```
"hhl" callExtension "status"
```

- **tracker=ok polls=N**: the tracker is loaded. Run it twice; if N does not rise, FreeTrack is off.
- **tracker=notloaded**: the registry value is missing, or Arma 3 was not restarted after it was written.
- **tracker=foreign**: another FreeTrackClient64.dll is loaded, from another tracker program.

## Development

Built with HEMTT; the addon is in addons/main and the DLL sources and their build are in native/, described in native/README.md. Source, issues and the DLL sources are at https://github.com/Nick-Yawn/helicopter-horizon-lock.

Licence: MIT.
