# 03 – Tooling, project structure and CBA APIs for a client-side Arma 3 (2013) SQF addon

Researched 2026-09-18 for a Windows 11 / Steam user building a CBA_A3-dependent helicopter camera mod ("horizoncam") with in-game settings and a toggle keybind. Arma 3 only, not Reforger.

## Verification legend

- **[V]** verified from the fetched primary page / source file (URL in section (e)).
- **[B]** the Bohemia wiki (community.bistudio.com and its community.bohemia.net mirror) rejected every access route during this session (HTTP 403 / Cloudflare challenge via HTTP, the browser pane, the MediaWiki API and the Wayback Machine). Facts marked [B] are quoted from search-engine excerpts of the named Biki page; the wording is the page's, but re-check the live page before relying on exact phrasing.
- **[U]** not verified; stated from experience or inferred. Treat as a hint, confirm before use.

Nothing below invents CLI flags, function signatures or config keys: every flag/key listed was seen in a fetched doc or source file, or is marked [U].

---

## (a) Recommended toolchain and why

| Role | Recommendation | Why |
|---|---|---|
| Build / lint / run | **HEMTT** v1.22.0 (released 2026-09-18) [V] | Installs in one command (`winget install hemtt`) [V]; `hemtt check` lints SQF/config/stringtables without writing files [V]; `hemtt dev` writes unbinarized PBOs to `.hemttout/dev` with links back to your source folders so file patching works [V]; `hemtt launch` builds and starts Arma 3 with CBA (by Workshop ID) and `-filePatching` for you [V]; `hemtt release` binarizes, **signs (.bisign + .bikey)** and zips [V]; `hemtt publish` uploads to Steam Workshop [V]. It is the tool ACE3 and CBA themselves use (`.hemtt/project.toml` in both repos) [V]. |
| Editor | VS Code + the official **HEMTT extension** (`BrettMayson.hemtt`, alpha) [V] | Error checking/highlighting; HEMTT docs say running it in VS Code's integrated terminal is "the recommended way" [V]. |
| Framework | **CBA_A3** v3.19.0 (GitHub release published 2026-08-11; Workshop item 450814997, "Updated Aug 11") [V] | Provides the settings menu (`CBA_fnc_addSetting`), rebindable keys (`CBA_fnc_addKeybind`), per-frame handlers, player events and XEH init hooks, so the mod needs no UI code of its own [V]. |
| Official tools | **Arma 3 Tools** (Steam, free) — install and run once [V] | HEMTT uses its `binarize` for p3d/rtm/wrp and reads its registry keys; ACE's guide says run Arma 3 and Arma 3 Tools once from Steam so registry entries exist [V]. A script-only mod has nothing to binarize, but you still want the Tools for **Publisher** (Workshop upload GUI) and `DSCreateKey`/`DSSignFile` if you ever sign manually [B]. |
| Alternatives (not recommended for this project) | Addon Builder (Arma 3 Tools GUI), Mikero's pboProject / MakePbo (mikero.bytex.digital) | Older PBO packers; no linting, no launch integration. Note the `$PBOPREFIX$` file-name differences in Appendix A.2 [B]. |
| Version control | git | HEMTT "works best when used in a Git based project" and appends the git hash to versions unless `[version] git_hash = 0` [V]. |

Why HEMTT over Addon Builder for a first mod: the whole edit → check → launch → debug loop is three commands, and the release step handles signing, which server owners running `verifySignatures = 2` require [B].

---

## (b) Minimal project tree for a single-component CBA addon ("horizoncam", prefix `hzc`)

Layout follows the CBA/ACE3 convention (`addons/<component>/…`, `script_component.hpp`, XEH files, `functions/fnc_*.sqf`) as seen in ACE3's `addons/goggles`, CBA's own addons, the 2025 `flufflesamy/CBA-Tutorial` template and the HEMTT docs [V]. For a one-feature mod the simplest shape is a **single addon named `main`** (HEMTT's default version-file path is `addons/main/script_version.hpp` [V]); it produces one PBO, `hzc_main.pbo`. If you later want more components, copy `addons/main` to `addons/<name>`, change `COMPONENT`, add `"hzc_main"` to that component's `requiredAddons[]` and keep the shared `script_mod.hpp`/`script_macros.hpp` in `main` (that is exactly how CBA-Tutorial's `mycomponent` does it) [V].

```
horizoncam/                          <- git repo; folder name = `hemtt new horizoncam`
├── .hemtt/
│   └── project.toml                 <- required by HEMTT [V]
├── include/
│   └── x/cba/addons/main/
│       └── script_macros_common.hpp <- copy of CBA's file so HEMTT can resolve \x\cba\... includes (ACE3, CBA-Tutorial, HEMTT-Example all ship this folder) [V]
├── addons/
│   └── main/
│       ├── $PBOPREFIX$              <- exactly one line: z\hzc\addons\main  [V]
│       ├── config.cpp
│       ├── CfgEventHandlers.hpp
│       ├── script_component.hpp
│       ├── script_mod.hpp
│       ├── script_macros.hpp
│       ├── script_version.hpp
│       ├── XEH_preStart.sqf
│       ├── XEH_preInit.sqf
│       ├── XEH_postInit.sqf
│       ├── XEH_PREP.hpp
│       ├── initSettings.inc.sqf     <- ACE naming; included from XEH_preInit.sqf [V]
│       ├── stringtable.xml          <- optional; CSTRING()/LSTRING() macros need it [V]
│       └── functions/
│           ├── fnc_toggle.sqf
│           └── fnc_onFrame.sqf
├── mod.cpp                          <- Launcher/Workshop presentation [B]
├── meta.cpp                         <- `protocol = 1; publishedid = 0;` until first Workshop upload [V]
├── LICENSE, README.md, CHANGELOG.md, .gitignore
└── .hemttout/                       <- generated: dev/, build/, release/, latest.log (git-ignore it) [V]
```

Naming that the CBA macros produce (all [V] from `script_macros_common.hpp`): `ADDON` = `hzc_main`; `GVAR(active)` = `hzc_main_active`; `QGVAR(active)` = `"hzc_main_active"`; `FUNC(toggle)` = `hzc_main_fnc_toggle`; `QPATHTOF(x)` = `"\z\hzc\addons\main\x"`.

### `.hemtt/project.toml`

```toml
# Keys documented at hemtt.dev/configuration/ and hemtt.dev/commands/launch [V]
name = "HorizonCam"
prefix = "hzc"          # required; must match $PBOPREFIX$ (z\hzc\addons\main)
author = "Your Name"
mainprefix = "z"        # optional; used by `hemtt launch`; the common convention

[files]
# copied to the mod root of every build; mod.cpp, meta.cpp, LICENSE, logo_ca.paa, logo_co.paa
# are included by default if present [V]
include = ["mod.cpp", "meta.cpp", "LICENSE", "README.md"]

[version]
# default path = addons/main/script_version.hpp; git_hash default 8 chars, 0 disables [V]
git_hash = 0

[hemtt.launch.default]        # or put profiles in .hemtt/launch.toml [V]
workshop = ["450814997"]      # CBA_A3 - must already be subscribed in Steam [V]
parameters = ["-skipIntro", "-noSplash", "-showScriptErrors", "-window", "-noPause"]
# executable default "arma3_x64"; file_patching default true (adds -filePatching);
# binarize default false; rapify default true; mission = "test.VR" is optional [V]

[hemtt.publish]               # used by `hemtt publish` [V]
description = "workshop/steam_description.md"
changelog = "CHANGELOG.md"

# [signing] authority defaults to "{prefix}_{version}", version = 3 [V]
# [hemtt.release] sign = true, archive = true are the defaults [V]
```

### `addons/main/$PBOPREFIX$`

```
z\hzc\addons\main
```
(No extension for HEMTT; pboProject wants `$PBOPREFIX$.txt` or `pboprefix.txt` — see A.2.) [V][B]

### `addons/main/script_version.hpp`

```cpp
#define MAJOR 0
#define MINOR 1
#define PATCH 0
#define BUILD 0
```
HEMTT reads MAJOR/MINOR/PATCH (or PATCHLVL)/BUILD from here [V].

### `addons/main/script_mod.hpp`

```cpp
#define MAINPREFIX z
#define PREFIX hzc
#define SUBPREFIX addons

#include "script_version.hpp"

#define VERSION     MAJOR.MINOR
#define VERSION_STR MAJOR.MINOR.PATCH.BUILD
#define VERSION_AR  MAJOR,MINOR,PATCH,BUILD

// minimum Arma 3 version written into CfgPatches; CBA main uses 2.22, CBA-Tutorial 2.20 [V]
#define REQUIRED_VERSION 2.18

// #define DEBUG_MODE_FULL          // uncomment while developing (verbose LOG()/TRACE macros) [V]
// #define DISABLE_COMPILE_CACHE    // uncomment to make file patching reload functions [V]

#ifdef COMPONENT_BEAUTIFIED
    #define COMPONENT_NAME QUOTE(HorizonCam - COMPONENT_BEAUTIFIED)
#else
    #define COMPONENT_NAME QUOTE(HorizonCam - COMPONENT)
#endif
```
Pattern taken from CBA-Tutorial's `script_mod.hpp` and ACE's `script_mod.hpp` (ACE additionally defines `REQUIRED_CBA_VERSION {3,18,5}`) [V].

### `addons/main/script_macros.hpp`

```cpp
#include "\x\cba\addons\main\script_macros_common.hpp"   // CBA's macro library [V]
// Optional convenience macros used by CBA-Tutorial: CFUNC(x) = CBA_fnc_x etc. [V]
#define CFUNC(function) TRIPLES(CBA,fnc,function)
#define QCFUNC(function) QUOTE(CFUNC(function))
```

### `addons/main/script_component.hpp`

```cpp
#define COMPONENT main
#define COMPONENT_BEAUTIFIED Main
#include "\z\hzc\addons\main\script_mod.hpp"

// #define DEBUG_MODE_FULL
// #define DISABLE_COMPILE_CACHE

#ifdef DEBUG_ENABLED_MAIN
    #define DEBUG_MODE_FULL
#endif
#ifdef DEBUG_SETTINGS_MAIN
    #define DEBUG_SETTINGS DEBUG_SETTINGS_MAIN
#endif

#include "\z\hzc\addons\main\script_macros.hpp"
```
Same shape as ACE's `addons/goggles/script_component.hpp` and HEMTT-Example's `script_component.hpp` [V]. `COMPONENT` must be defined before `script_mod.hpp` is included (CBA's `script_mod.hpp` comment) [V].

### `addons/main/config.cpp`

```cpp
#include "script_component.hpp"

class CfgPatches {
    class ADDON {                       // expands to hzc_main
        name = COMPONENT_NAME;
        units[] = {};
        weapons[] = {};
        requiredVersion = REQUIRED_VERSION;
        requiredAddons[] = {"cba_main"};   // "cba_main is all that is needed" since CBA 3.8.0 [V]
        author = "Your Name";
        url = "https://github.com/you/horizoncam";
        VERSION_CONFIG;                    // version = / versionStr = / versionAr[] = ... (CBA macro) [V]
    };
};

class CfgMods {                          // optional; CBA-Tutorial and ACE main use it [V]
    class PREFIX {
        dir = "@horizoncam";
        name = "HorizonCam";
    };
};

#include "CfgEventHandlers.hpp"
```
`CfgPatches` field meanings (Biki, [B]): `units[]`/`weapons[]` list CfgVehicles/CfgWeapons classes the PBO adds (empty for a script mod); `requiredVersion` = minimum game version (the Biki notes it "does effectively nothing" in practice); `requiredAddons[]` "makes sure the listed addons are loaded before the one this file belongs to" and a warning pops up if one is missing; `name`, `author`, `url` are metadata. Real-world files also carry `authors[]` and the `VERSION_CONFIG` triple (ACE, CBA) [V].

### `addons/main/CfgEventHandlers.hpp`

```cpp
class Extended_PreStart_EventHandlers {
    class ADDON {
        init = QUOTE(call COMPILE_SCRIPT(XEH_preStart));
    };
};

class Extended_PreInit_EventHandlers {
    class ADDON {
        init = QUOTE(call COMPILE_SCRIPT(XEH_preInit));
    };
};

class Extended_PostInit_EventHandlers {
    class ADDON {
        init = QUOTE(call COMPILE_SCRIPT(XEH_postInit));
    };
};
```
Verbatim pattern from ACE3 `addons/goggles/CfgEventHandlers.hpp` and CBA `addons/settings/CfgEventHandlers.hpp` [V]. `COMPILE_SCRIPT(x)` = `compileScript ['\z\hzc\addons\main\x.sqf']` [V]. The CBA wiki's plain-config equivalent is `init = "call compile preprocessFileLineNumbers 'XEH_preInit.sqf'";` inside any uniquely named class [V].

### `addons/main/XEH_PREP.hpp`

```cpp
PREP(toggle);
PREP(onFrame);
```
Each `PREP(x)` compiles `functions/fnc_x.sqf` into `hzc_main_fnc_x` (with CBA's function cache unless `DISABLE_COMPILE_CACHE` is defined) [V].

### `addons/main/XEH_preStart.sqf`

```sqf
#include "script_component.hpp"
#include "XEH_PREP.hpp"
```
(ACE goggles, verbatim) [V]. PreStart runs once per game session before the main menu, in `uiNamespace`, for function caching [V].

### `addons/main/XEH_preInit.sqf`

```sqf
#include "script_component.hpp"

ADDON = false;

#include "XEH_PREP.hpp"

// Settings must be registered on EVERY machine; CBA recommends doing it in XEH preInit
// so they also show up in the Eden editor's Addon Options [V]
#include "initSettings.inc.sqf"

ADDON = true;
```
ACE wraps the PREP include in `PREP_RECOMPILE_START; … PREP_RECOMPILE_END;` — those two macros (and `LINKFUNC`) are defined by ACE's own `script_macros.hpp` / CBA-Tutorial's `script_debug.hpp`, **not** verified to exist in CBA's `script_macros_common.hpp`; add the tutorial's `script_debug.hpp` block if you want `[] call hzc_PREP_RECOMPILE;` hot-reload [V].

### `addons/main/initSettings.inc.sqf`

```sqf
// ["name","TYPE",title|[title,tooltip], category|[category,sub], valueInfo, isGlobal, {onChange}, needRestart] [V]

[
    QGVAR(enabled), "CHECKBOX",
    ["Enable HorizonCam", "Master switch for the helicopter camera."],
    ["HorizonCam", "General"],
    true,                 // CHECKBOX valueInfo = default value
    0,                    // 0 = per-client setting (not synced)
    { GVAR(enabled) = _this; if (!_this && GVAR(active)) then { call FUNC(toggle) }; }
] call CBA_fnc_addSetting;

[
    QGVAR(smoothing), "SLIDER",
    ["Smoothing", "0 = raw, 1 = very smooth."],
    ["HorizonCam", "Camera"],
    [0, 1, 0.5, 2],       // SLIDER valueInfo = [min, max, default, trailingDecimals(, isPercentage)]
    0
] call CBA_fnc_addSetting;

[
    QGVAR(mode), "LIST",
    ["Horizon mode", "How the camera levels itself."],
    ["HorizonCam", "Camera"],
    [[0, 1, 2], ["Off", "Roll only", "Roll + pitch"], 1],   // LIST valueInfo = [values, labels, defaultIndex]
    0
] call CBA_fnc_addSetting;
```
The setting name doubles as the global variable (`hzc_main_enabled` etc.) [V]. Category `["HorizonCam","General"]` = category + sub-category [V]. The on-change script receives the new value in `_this` and the name in `_thisSetting` [V].

### `addons/main/XEH_postInit.sqf`

```sqf
#include "script_component.hpp"
#include "\a3\editor_f\Data\Scripts\dikCodes.h"   // DIK_* names; CBA wiki recommends this header [V]

if (!hasInterface) exitWith {};   // client with a UI only (skips dedicated server + headless) [V]

GVAR(active) = false;
GVAR(pfhID)  = -1;

// Rebindable in Options > Controls > Configure Addons > "HorizonCam" [V]
["HorizonCam", QGVAR(toggle), ["Toggle HorizonCam", "Turn the horizon-locked camera on/off."],
    {
        if (!GVAR(enabled)) exitWith { false };
        if (vehicle player == player) exitWith { false };   // only inside a vehicle
        call FUNC(toggle);
        true   // returning true blocks other actions bound to this key [V]
    },
    "",                                   // no key-up code
    [DIK_H, [false, true, false]]         // Ctrl+H default; DIK_H = 0x23 [V]
] call CBA_fnc_addKeybind;

// Auto-disable when the player leaves the vehicle. Params: [_unit, _newVehicle, _oldVehicle] [V]
["vehicle", {
    params ["_unit", "_newVehicle"];
    if (GVAR(active) && {_newVehicle == _unit}) then { call FUNC(toggle) };
}, true] call CBA_fnc_addPlayerEventHandler;

// Anything that needs final setting values should wait for this event [V]
["CBA_settingsInitialized", {
    INFO_1("HorizonCam ready, enabled=%1", GVAR(enabled));
}] call CBA_fnc_addEventHandler;
```
Where to register keybinds: the CBA Keybinding page says "in your `init.sqf` or XEH client-only event handler" [V]; ACE registers them in `XEH_postInit.sqf` behind `if (!hasInterface) exitWith {};` [V].

### `addons/main/functions/fnc_toggle.sqf`

```sqf
#include "..\script_component.hpp"
/*
 * Toggles the HorizonCam per-frame handler.
 * Arguments: none   Return: <BOOL> new state
 * Example: call hzc_main_fnc_toggle;
 */
if (GVAR(active)) then {
    GVAR(pfhID) call CBA_fnc_removePerFrameHandler;   // [V] takes the handle number
    GVAR(pfhID) = -1;
    GVAR(active) = false;
    // TODO: restore the engine camera here (see camera-research doc)
} else {
    GVAR(active) = true;
    // delay 0 = every frame; _args array is the same object every call [V]
    GVAR(pfhID) = [LINKFUNC(onFrame), 0, [vehicle player]] call CBA_fnc_addPerFrameHandler;
};
GVAR(active)
```
`fnc_onFrame.sqf` receives `[_args, _handle]` each frame and does the camera math (out of scope here). If you do not define `LINKFUNC`, write `{ _this call FUNC(onFrame) }` instead.

### `mod.cpp` (root)

```cpp
name        = "HorizonCam";
author      = "Your Name";
picture     = "logo_ca.paa";        // expansions menu; optimal 2048x1024 [B]
logo        = "logo_ca.paa";        // main menu
logoOver    = "logo_ca.paa";        // main menu, hovered
logoSmall   = "logo_ca.paa";        // next to entities the mod adds
tooltip     = "HorizonCam";
tooltipOwned= "HorizonCam";
actionName  = "GitHub";
action      = "https://github.com/you/horizoncam";
overview    = "Horizon-locked external camera for helicopters. Requires CBA_A3.";
hideName    = 0;
hidePicture = 0;
dlcColor[]  = {0.23, 0.39, 0.30, 1};
```
Field set and comments match the Biki "Mod Presentation" page as reproduced in the Andx667 template and ACE's `mod.cpp` [B][V]. If you have no logo, omit the image lines. HEMTT copies `mod.cpp` into every build automatically [V].

### `meta.cpp` (root)

```cpp
protocol = 1;
publishedid = 0;
```
Verbatim from the Andx667 template; `publishedid` becomes the Workshop item ID after the first upload (Publisher/`hemtt publish` write it) [V]. Other fields the Biki lists: `name`, `timestamp`, `hashOverride` [B].

---

## (c) First-run checklist (Windows 11, Steam)

1. **Install Arma 3 Tools** from Steam (Library filter "Tools"), launch it once so its registry keys exist; ACE's guide says run both Arma 3 and Arma 3 Tools once from Steam and repeat after updates [V]. Do **not** run "Prepare virtual P: drive" if you already have a P: drive (it wipes it) [B].
2. **Subscribe to CBA_A3** on the Workshop (ID 450814997) and let the Arma 3 Launcher download it; `hemtt launch` does not subscribe for you [V].
3. **Install HEMTT**: in a terminal run `winget install hemtt` (docs) or `winget install --id=BrettMayson.HEMTT -e` (winget listing); update later with `winget upgrade hemtt`. Alternatively download `windows-x64.zip` from the GitHub releases page and put `hemtt.exe` on your PATH [V]. Check with `hemtt --version` [U: flag assumed standard].
4. **Install VS Code** and the `BrettMayson.hemtt` extension [V].
5. **Create the project**: `hemtt new horizoncam` and answer the prompts (full mod name, author, prefix `hzc`, main prefix `z`, license) [V]. It creates `.hemtt/project.toml`, `addons/main/`, `LICENSE`, `.gitignore`, README [V]. Then add/overwrite the files from section (b). Copy CBA's `script_macros_common.hpp` into `include/x/cba/addons/main/` (from the CBA_A3 repo) so HEMTT can resolve the include [V, convention seen in ACE3/CBA-Tutorial].
6. **Lint**: `hemtt check` (same checks as `hemtt dev`, writes nothing) [V]. Fix anything red.
7. **Launch**: `hemtt launch` — it runs `hemtt dev` (unbinarized PBOs in `.hemttout/dev`), locates Arma 3 through Steam (`steamlocate`, app 107410), adds `-mod="…"` for your mod and every `workshop` ID, adds `-filePatching` (default) and your `parameters`, and starts `arma3_x64` [V]. The `launch/mod.rs` source also expects a link `<Arma 3>\z\hzc` pointing at `.hemttout/dev` (see `hemtt link create/remove`) [V, mechanism inferred from source].
8. **Verify CBA sees the mod**: in the main menu open Configure → Controls → **Configure Addons**, pick "HorizonCam" in the drop-down — the toggle key should be listed [V]. Open Eden Editor → Settings → **Addon Options** (Ctrl+Alt+S) — the "HorizonCam" category should show the three settings [V]. In a mission the same menu is ESC → OPTIONS → GAME → CONFIGURE ADDONS [V].
9. **Test flight**: Eden Editor → place a helicopter (it spawns with crew) and mark its pilot as Player (or place yourself and use `player moveInDriver heli` [U]) → PLAY button (bottom right) → press Ctrl+H [B: Eden intro page]. Watch `systemChat`/`hint`, and on-screen script errors (`-showScriptErrors`) [B].
10. **Iterate**: edit `fnc_*.sqf`, restart the mission (not the game) — with `-filePatching` and `#define DISABLE_COMPILE_CACHE` the new code is picked up; config.cpp changes need a game restart ("configs are not patched during run time, only at load time") [V].
11. **Read the log**: `%LOCALAPPDATA%\Arma 3\arma3_x64_YYYY-MM-DD_HH-MM-SS.rpt` (last 10 kept; `-noLogs` disables; `-profiles=` relocates) — `diag_log` and the `INFO()/WARNING()/ERROR()` macros write here [B][V].
12. **Release**: comment out `DEBUG_MODE_FULL`/`DISABLE_COMPILE_CACHE`, bump `script_version.hpp`, run `hemtt release` → `.hemttout/release` contains the mod with `.bisign` per PBO and a `.bikey` in `keys/`, plus `releases/horizoncam-latest.zip` and `horizoncam-<version>.zip` [V]. Test that zip once as a normal `-mod=` before publishing.
13. **Publish**: either `hemtt publish` (Steam client must be running and logged in; uses `meta.cpp` publishedid and `[hemtt.publish]` files) [V], or Arma 3 Tools → Publisher → SELECT MOD FOLDER (the folder whose root contains `addons/`, i.e. the contents of the @mod), tags (Data Type = Mod), description, preview image (.jpg/.jpeg/.png/.gif/.bmp, downscaled to 0.95 MB), visibility, change notes, accept the Steamworks terms [B]. Afterwards add CBA_A3 as a required item on the Workshop page [B].

---

## (d) CBA API reference (verified against CBA_A3 master sources and wiki)

### d.1 `CBA_fnc_addSetting` (`addons/settings/fnc_addSetting.sqf`) [V]

```
[_setting, _settingType, _title, _category, _valueInfo, _isGlobal, _script, _needRestart] call CBA_fnc_addSetting
```
Header, verbatim:
```
_setting     - Unique setting name. Matches resulting variable name <STRING>
_settingType - Type of setting. Can be "CHECKBOX", "EDITBOX", "LIST", "SLIDER", "COLOR" or "TIME" <STRING>
_title       - Display name or display name + tooltip (optional, default: same as setting name) <STRING, ARRAY>
_category    - Category for the settings menu + optional sub-category <STRING, ARRAY>
_valueInfo   - Extra properties of the setting depending of _settingType. See examples below (optional) <ANY>
_isGlobal    - 1: all clients share the same setting, 2: setting can't be overwritten (optional, default: 0) <BOOL, NUMBER>
_script      - Script to execute when setting is changed (_this contains value, _thisSetting contains name). (optional) <CODE>
_needRestart - Setting will be marked as needing mission restart after being changed. (optional, default false) <BOOL>
Returns: _return - Error code <BOOLEAN>  true: Success, no error / false: Failure, error
```
Examples, verbatim from the header (the comments give the `_valueInfo` shape per type):
```sqf
// CHECKBOX --- extra argument: default value
["Test_Setting_1", "CHECKBOX", ["-test checkbox-", "-tooltip-"], "My Category", true] call CBA_fnc_addSetting;
// LIST --- extra arguments: [_values, _valueTitles, _defaultIndex]
["Test_Setting_2", "LIST",     ["-test list-",     "-tooltip-"], "My Category", [[1, 0], ["enabled","disabled"], 1]] call CBA_fnc_addSetting;
// SLIDER --- extra arguments: [_min, _max, _default, _trailingDecimals, _isPercentage]
["Test_Setting_3", "SLIDER",   ["-test slider-",   "-tooltip-"], "My Category", [0, 10, 5, 0]] call CBA_fnc_addSetting;
// COLOR PICKER --- extra argument: _color
["Test_Setting_4", "COLOR",    ["-test color-",    "-tooltip-"], "My Category", [1, 1, 0]] call CBA_fnc_addSetting;
// EDITBOX --- extra argument: default value
["Test_Setting_5", "EDITBOX",  ["-test editbox-", "-tooltip-"], "My Category", "defaultValue"] call CBA_fnc_addSetting;
// TIME PICKER (time in seconds) --- extra arguments: [_min, _max, _default]
["Test_Setting_6", "TIME",     ["-test time-",    "-tooltip-"], "My Category", [0, 3600, 60]] call CBA_fnc_addSetting;
```
Wiki additions [V]: COLOR also accepts `[r,g,b,a]`; TIME is entered as HH:MM:SS and returns seconds; the LIST `values` array can hold any type and `valueTitles` entries may be `["label","tooltip"]` pairs; SLIDER's 5th element `_isPercentage` displays the value as a percentage; the wiki's LIST example is `[[false, true], ["DISABLED", "ENABLED"], 0]` and its SLIDER example `[0, 1, 0.5, 2, true]`. An EDITBOX may also get `["default", false, _fnc_sanitizeValue]` (search-index excerpt of the wiki, [B]-grade).

Where/when: "The function has to be executed on every machine. It is recommended to execute the function via a CBA XEH preInit event. This way you can make sure that the setting is available in the Eden-Editor." [V]

`_isGlobal` semantics (wiki) [V]: `true`/`1` = the setting always overwrites clients (same value everywhere, changeable in the server/mission tabs); `2` = can never overwrite clients (purely per-client, cannot be forced by mission or server); `0`/`false` = normal client setting that the mission/server *may* overwrite.

Where users see it [V]: pause menu ESC → OPTIONS → GAME → CONFIGURE ADDONS; briefing screen CONFIGURE ADDONS button; Eden Editor Settings → Addon Options… (Ctrl+Alt+S). Dialog has three tabs: server (left), mission (middle), client (right) [B: CBA wiki excerpt]. Settings can be exported to / imported from the clipboard in that menu [B].

Priority ("Setting Overwrite Cheat Sheet", verbatim) [V]:
```
On Server No Force:
    On Mission No Force:  Client > Mission > Server
    On Mission Force:     Mission > Client > Server
On Server 1 Force:
    On Mission No Force:  Server > Client > Mission
    On Mission Force:     Mission > Server > Client
On Server 2 Force:        Server > All
```
Files [V]: a mission can ship `cba_settings.sqf` in its root plus `cba_settings_hasSettingsFile = 1;` in `description.ext`; a server/client can use `Arma 3\userconfig\cba_settings.sqf` (needs `-filePatching`) or the `cba_settings_userconfig` addon template; `force` prefixes in those files lock values.

Events [V]: `CBA_beforeSettingsInitialized`, `CBA_settingsInitialized` (fired via `CBA_fnc_localEvent` after all settings are loaded in postInit; ACE wraps setting-dependent postInit code in it), `CBA_SettingChanged` with `params ["_setting", "_value"]`. Register with `["CBA_settingsInitialized", { … }] call CBA_fnc_addEventHandler;`.

### d.2 `CBA_fnc_addKeybind` (`addons/keybinding/fnc_addKeybind.sqf`) [V]

Description: "Adds or updates the keybind handler for a specified mod action, and associates a function with that keybind being pressed."
```
_addon          - Name of the registering mod + optional sub-category <STRING, ARRAY>
_action         - Id of the key action. <STRING>
_title          - Pretty name, or an array of pretty name and tooltip <STRING or ARRAY>
_downCode       - Code for down event, empty string for no code. <CODE or STRING>
_upCode         - Code for up event, empty string for no code. <CODE or STRING> (optional)
_defaultKeybind - The keybinding data in the format [DIK, [shift, ctrl, alt]] <ARRAY> (optional)
_holdKey        - Will the key fire every frame while down <BOOLEAN> (optional)
_holdDelay      - How long after keydown will the key event fire, in seconds. <NUMBER> (optional)
_overwrite      - Overwrite any previously stored default keybind <BOOLEAN> (optional)
Returns: the current keybind for the action <ARRAY> (or <NIL> on error)
```
Code defaults (params block, verbatim): `_downCode {}`, `_upCode {}`, `_defaultKeybind KEYBIND_NULL`, `_holdKey false`, `_holdDelay 0`, `_overwrite false`. (The generated cbateam.github.io page for `CBA_fnc_getKeybind` says hold "Default: true" — the source's `false` is authoritative.)

Wiki example, verbatim [V]:
```sqf
["My Awesome Mod","show_breathing_key", "Show Breathing", {_this call mymod_fnc_showGameHint}, "", [DIK_B, [true, true, false]]] call CBA_fnc_addKeybind;
```
ACE example (goggles, verbatim) [V]:
```sqf
["ACE3 Common", QGVAR(wipeGlasses), localize LSTRING(WipeGlasses), {
    if !(call FUNC(canWipeGlasses)) exitWith {false};
    call FUNC(clearGlasses);
    true
},
{false},
[20, [true, true, false]], false] call CBA_fnc_addKeybind;
```
Notes [V]: "If _downCode returns true, block all further actions bound to this key, including base game actions." Register in `init.sqf` or an XEH client-only handler. Mod name may be an array `[modName, subCategory]`. Keybinds persist across mission reloads and editor sessions.

Key codes: `#include "\a3\editor_f\Data\Scripts\dikCodes.h"` for `DIK_*` names [V]. DirectInput values (Wine `dinput.h`, identical constants) [V]: ESC 0x01, TAB 0x0F, RETURN 0x1C, LCONTROL 0x1D, LSHIFT 0x2A, LMENU(Alt) 0x38, RMENU 0xB8, RCONTROL 0x9D, RSHIFT 0x36, SPACE 0x39, GRAVE 0x29, LBRACKET 0x1A, RBRACKET 0x1B, SEMICOLON 0x27, APOSTROPHE 0x28, H 0x23, K 0x25, C 0x2E, V 0x2F, B 0x30, N 0x31, M 0x32, F1–F10 0x3B–0x44, F11 0x57, F12 0x58, NUMPAD0 0x52, NUMPAD1 0x4F, NUMPAD5 0x4C, NUMPAD9 0x49, HOME 0xC7, UP 0xC8, PRIOR 0xC9, LEFT 0xCB, RIGHT 0xCD, END 0xCF, DOWN 0xD0, NEXT 0xD1, INSERT 0xD2, DELETE 0xD3. CBA additionally maps mouse buttons (0xF0 left, 0xF1 right, 0xF2 middle …), `USER_1..USER_20` (0xFA–0x10D) and Xbox controller codes (327680–327703) [V wiki].

Rebinding UI [V]: main menu Configure → Controls → **Configure Addons** (button at lower right) → choose the addon in the drop-down → double-click an action; also reachable from the ESC menu in-game. The vanilla "Custom controls"/user-action mechanism is separate (Biki "Modded Keybinding", not fetched) [B].

### d.3 Per-frame handlers (`addons/common/fnc_addPerFrameHandler.sqf`) [V]

```
[_function, _delay, _args] call CBA_fnc_addPerFrameHandler
_function - The function you wish to execute <CODE>
_delay    - The amount of time in seconds between executions, 0 for every frame (optional, default: 0) <NUMBER>
_args     - Parameters passed to the function executing. This will be the same array every execution (optional)
Handler receives: [_args, _handle]
Returns: _handle - A number representing the handle of the function. Use this to remove the handler <NUMBER>
Example: _handle = [{player sideChat format ["every frame! _this: %1", _this];}, 0, ["some","params",1,2,3]] call CBA_fnc_addPerFrameHandler;
```
`_handle call CBA_fnc_removePerFrameHandler` → true/false [V]. Wiki: "PFEH executes at most once per frame"; recommended replacement for `waitUntil` loops in unscheduled code; keep state by mutating `_args` [V]. Implementation: CBA runs one `FUNC(onFrame)` dispatcher; delayed handlers are timed with `diag_tickTime`, zero-delay handlers run unconditionally every frame [V]; it is driven by the engine's `EachFrame` mission event handler: verified 2026-09-18 from `addons/common/XEH_postInit.sqf` on CBA master, which contains `addMissionEventHandler ["EachFrame", {call FUNC(onFrame)}];` [V]. ACE's scheduler guide: use a PFH for loops, remove it when done, and run visual feedback at delay 0 [V].

Comparison with engine handlers for camera work (Biki "Mission Event Handlers", [B]): `Draw3D` — fires every frame, intended for HUD/3D drawing, unscheduled (no suspension), does not fire on a dedicated server, and stops firing when you Alt-Tab unless the client runs with `-window -noPause`. `EachFrame` — "a stackable version of onEachFrame", fires every frame. Both are added with `addMissionEventHandler ["Draw3D"|"EachFrame", { … }]` and removed with `removeMissionEventHandler` and the returned index. A CBA PFH with delay 0 is functionally equivalent to EachFrame, is idiomatic in CBA mods, and returns a handle you can store in a GVAR; use `Draw3D` only if you need to draw icons/lines with `drawIcon3D`/`drawLine3D`. [Camera-specific timing (e.g. whether the handler runs before render) could not be verified — see the camera research doc.]

### d.4 Player event handlers (`addons/events/fnc_addPlayerEventHandler.sqf`, wiki "Player Events") [V]

```
[_type, _function, _applyRetroactively] call CBA_fnc_addPlayerEventHandler   -> ID <NUMBER>
_applyRetroactively - Call function immediately if player is defined already (optional, default: false) <BOOL>
remove: [_type, _id] call CBA_fnc_removePlayerEventHandler   [U: arg order assumed from the wiki's "returns an ID for later removal"]
```
Event → handler params:
- `"unit"` → `[_newPlayerUnit, _oldPlayerUnit]` (respawn, Zeus control, init)
- `"weapon"` → `[_playerUnit, _newSelectedWeapon, _oldSelectedWeapon]` (handheld only)
- `"turretWeapon"` → `[_playerUnit, _newSelectedWeapon, _oldSelectedWeapon]`
- `"muzzle"` → `[_playerUnit, _newSelectedMuzzle, _oldSelectedMuzzle]`
- `"weaponMode"` → `[_playerUnit, _newSelectedWeapon, _oldSelectedWeapon]`
- `"loadout"` → `[_playerUnit, _newUnitLoadout, _oldUnitLoadout]`
- `"vehicle"` → `[_playerUnit, _newVehicle, _oldVehicle]` — fires on enter/leave, also for `moveInDriver`/Zeus; on exit `_newVehicle` is the player object
- `"turret"` → `[_playerUnit, _newTurret, _oldTurret]`
- `"turretOpticsMode"` (source list) 
- `"visionMode"` → `[_playerUnit, _newVisionMode, _oldVisionMode]` (0 day, 1 NV, 2 thermal)
- `"cameraView"` → `[_playerUnit, _newCameraMode, _oldCameraMode]` — modes "INTERNAL", "EXTERNAL", "GUNNER", "GROUP"
- `"featureCamera"` → `[_playerUnit, _newCamera]` (Curator, Arsenal, Spectator …)
- `"visibleMap"` → `[_playerUnit, _isMapShown]`
- `"group"` → `[_playerUnit, _oldGroup, _newGroup]`, `"leader"` → `[_playerUnit, _oldLeader, _newLeader]`
No `"vehicleFeatureCamera"` event exists in the current list. ACE goggles uses `"cameraView"` and `"featureCamera"` to react to view changes [V].

### d.5 XEH init hooks [V]

- `Extended_PreStart_EventHandlers` → once per game session, before the main menu, in `uiNamespace` (function caching).
- `Extended_PreInit_EventHandlers` → once per mission, "before all the mission units and vehicles have their own init event handlers processed" (also runs in the main menu and in 3DEN, which is why settings go here).
- `Extended_PostInit_EventHandlers` → once per mission, "after all the units and vehicles have had both their init event handlers and the code in the mission editor 'init' lines processed".
- Execution order follows `requiredAddons` in `CfgPatches`. Client-/server-only variants: inside the same class use `clientInit = "…"` / `serverInit = "…"` instead of `init` (Advanced XEH page). All three run on every machine type unless you guard with `hasInterface`/`isServer`.

### d.6 Machine guards (Biki `hasInterface`/`isServer`/`isDedicated`, [B]; ACE/CBA usage [V])

`hasInterface` = all player clients incl. a player-hosted server; `isDedicated` = dedicated server only; `isServer` = dedicated or player host; `!hasInterface` = headless clients + dedicated server; `!hasInterface && !isDedicated` = headless only. Client-only files start with `if (!hasInterface) exitWith {};` (ACE goggles postInit) or `if (!hasInterface) exitWith { ADDON = true; };` in a preInit that must still mark the addon initialised (CBA keybinding). Settings registration must **not** be guarded (every machine).

### d.7 CBA macros (`addons/main/script_macros_common.hpp`) [V]

| Macro | Expands to | Notes |
|---|---|---|
| `QUOTE(x)` | `#x` | stringify |
| `DOUBLES(a,b)` / `TRIPLES(a,b,c)` | `a_b` / `a_b_c` | |
| `ADDON` | `DOUBLES(PREFIX,COMPONENT)` | `hzc_main` |
| `GVAR(v)` / `QGVAR(v)` / `QQGVAR(v)` | `ADDON_v` / `"ADDON_v"` / `"\"ADDON_v\""` | |
| `EGVAR(c,v)` / `QEGVAR(c,v)` | `TRIPLES(PREFIX,c,v)` | another component of your mod |
| `FUNC(f)` / `QFUNC(f)` | `TRIPLES(ADDON,fnc,f)` / quoted | `hzc_main_fnc_f` |
| `EFUNC(c,f)` / `QEFUNC(c,f)` | `PREFIX_c_fnc_f` | |
| `PREP(f)` | cache: `['\z\hzc\addons\main\functions\fnc_f.sqf','hzc_main_fnc_f'] call SLX_XEH_COMPILE_NEW`; with `DISABLE_COMPILE_CACHE`: `hzc_main_fnc_f = compile preprocessFileLineNumbers '…fnc_f.sqf'` | must run in preStart **and** preInit |
| `PATHTOF(x)` / `QPATHTOF(x)` | `\MAINPREFIX\PREFIX\SUBPREFIX\COMPONENT\x` | |
| `COMPILE_SCRIPT(x)` | `compileScript ['\z\hzc\addons\main\x.sqf']` | used in XEH init lines |
| `PATHTO_FNC(f)` | a CfgFunctions class entry | only if you use CfgFunctions |
| `LOG(m)` `INFO(m)` `WARNING(m)` `ERROR(m)` | `LOG_SYS('LEVEL',m)` → `CBA_fnc_log` (or `diag_log` with `DEBUG_SYNCHRONOUS`) | output `[PREFIX] (COMPONENT) LEVEL: msg`; `LOG` only with `DEBUG_MODE_FULL`, `WARNING` with `DEBUG_MODE_NORMAL`+; `_n` format variants exist (`ERROR_2("%1 %2",a,b)`) |
| `ERROR_MSG(m)` | `CBA_fnc_error` with file/line, on-screen | |
| `VERSION`, `VERSION_STR`, `VERSION_AR`, `VERSION_CONFIG` | from your `script_mod.hpp`; `VERSION_CONFIG` emits `version = …; versionStr = …; versionAr[] = …` | `VERSION_CONFIG` is used by CBA's own config.cpp, so it comes from the common macros [V, inferred] |
| `MAINPREFIX`, `SUBPREFIX` | default `x`, `addons` | override in `script_mod.hpp` (`z`) |
| `LINKFUNC`, `PREP_RECOMPILE_START/END` | **not** in CBA's file; defined by ACE `script_macros.hpp` / CBA-Tutorial `script_debug.hpp` | copy the tutorial block if wanted |

Debug switches: `DEBUG_MODE_FULL` (all LOG/TRACE output), `DEBUG_MODE_NORMAL` (default), `DEBUG_MODE_MINIMAL`; `DISABLE_COMPILE_CACHE` above the `script_component.hpp` include makes PREP compile from disk each time so file patching + `[] call <PREFIX>_PREP_RECOMPILE` reload functions without a mission restart (new functions still need a restart) [V].

### d.8 Versions and dependency declaration [V]

- CBA_A3 latest: **v3.19.0** (`published_at 2026-08-11T16:26:04Z`; 3.18.6 2026-04-01; 3.18.5 2025-12-23). Workshop item **450814997** ("Updated Aug 11", tag "Mod", no required items). ACE3 master pins `REQUIRED_CBA_VERSION {3,18,5}`.
- `requiredAddons[] = {"cba_main"};` is sufficient for load order after CBA and vanilla configs (CBA changelog 3.8.0; ACE `ace_main`, CBA-Tutorial use exactly this). Do not require `cba_settings`/`cba_keybinding` directly (a CBA issue reports keybinds "show but have no effect" after such misuse) [B].
- Optional version check at runtime: CBA "Versioning System" (`CBA[] = {"cba_main", {3,19,0}, "true"}` style) exists but was not fetched [U].
- Workshop dependency: add CBA_A3 under "Required items" on your Workshop page after upload [B]. `mod.cpp` has no dependency field.

---

## Appendix A – Addon anatomy details

### A.1 @Mod folder and PBOs
`@HorizonCam\addons\hzc_main.pbo` (+ `hzc_main.pbo.<authority>.bisign`), `@HorizonCam\keys\<authority>.bikey`, `mod.cpp`, `meta.cpp`, optional logo `.paa` files [V HEMTT release layout; B Biki]. The Workshop/Launcher creates the `@…` folder itself; Publisher wants you to select the folder whose root holds `addons` and warns if the structure is wrong [B].

### A.2 `$PBOPREFIX$` [B][V]
One line, no trailing whitespace/newline, e.g. `z\hzc\addons\main`; it becomes the virtual path prefix inside the PBO (`\z\hzc\addons\main\config.cpp`) and is what file patching uses to map the loose folder. Tool file names: HEMTT `$PBOPREFIX$` (no extension); Mikero pboProject `$PBOPREFIX$.txt` or `pboprefix.txt`; PBO Manager `$prefix$`; Addon Builder uses Options → "Addon prefix" instead (or `-prefix=`). HEMTT checks that the file matches `mainprefix\prefix\addons\<folder>` (addon.toml `ignore_pboprefix = true` disables the check) [V].

### A.3 CfgFunctions vs CBA PREP
Vanilla `class CfgFunctions { class TAG { class Category { file = "…"; class name { preInit = 1; postInit = 1; recompile = 1; }; }; }; }` yields `TAG_fnc_name` and is compiled by the engine [B]. CBA's `PREP()` in `XEH_PREP.hpp` instead compiles the file at preStart into a cache and re-links it at preInit, which "drastically speeds up load times" and gives you `DISABLE_COMPILE_CACHE` hot reload; CBA-Tutorial: "Instead of declaring functions in the CfgFunctions class, XEH uses its own functions and macros" [V]. Use PREP for a CBA mod.

### A.4 Signing [B][V]
`DSCreateKey <authority>` (Arma 3 Tools) makes `<authority>.bikey` (public, ship it in `keys\`) and `<authority>.biprivatekey` (keep secret); `DSSignFile <privatekey> <addon.pbo>` makes `addon.pbo.<authority>.bisign` next to the PBO. A server with `verifySignatures = 2` requires every client PBO to have a `.bisign` whose `.bikey` is in the server's `keys\` folder; otherwise the client is rejected. HEMTT does this for you in `hemtt release` with authority `{prefix}_{version}` by default (e.g. `hzc_0.1.0`), i.e. **a new key name per version** — the same convention ACE/CBA use, so server admins replace the bikey on each update. Whether HEMTT persists a private key between releases was not documented in the fetched pages [U]; `hemtt utils verify <PBO> <BIKEY>` checks a signed PBO [V]. `hemtt keys generate` is mentioned in the book but its page could not be fetched [U].

### A.5 mod.cpp / meta.cpp fields [B]
`mod.cpp`: `name`, `author`, `picture` (expansions menu, optimal 2048×1024), `logo`, `logoOver`, `logoSmall`, `tooltip`, `tooltipOwned`, `action` (URL), `actionName`, `overview` (structured text, `<br/>`), `overviewPicture` (ACE), `dlcColor[]`, `hideName`, `hidePicture`. Needed for the Launcher to show mod info. `meta.cpp`: `protocol`, `publishedid` (Workshop ID), `name`, `timestamp` (.NET ticks), `hashOverride`; written by Publisher/Launcher.

---

## Appendix B – HEMTT and build/run reference

### B.1 Commands (hemtt.dev "Commands" and book) [V]
- `hemtt new <name>` – interactive: full mod name, author, prefix, main prefix (e.g. `z`), license → `.hemtt/project.toml`, `addons/main/`, LICENSE, .gitignore, README. `<name>` is the folder name (letters/digits/underscores).
- `hemtt check` – all `dev` checks, writes nothing; `-p/--pedantic` (run lints disabled by default), `-e/--error-on-all`, `-L/--lints <name>` (repeatable), `-t/--threads`, `-v…`, `--no-color`.
- `hemtt dev` – unbinarized PBOs to `.hemttout/dev` with links to source folders; `-o/--optional <name>` (repeatable), `-O/--all-optionals`, `--no-rap`, `-b/--binarize`, `--just <addon>`; `[hemtt.dev] exclude = [...]`.
- `hemtt build` – binarized, rapified, **unsigned**, no folder links → `.hemttout/build`; `--no-bin`, `--no-rap`, `--just`.
- `hemtt release` – → `.hemttout/release` + `.bisign` per PBO + `.bikey`; zips `releases/{name}-latest.zip` and `{name}-{version}.zip`; `--no-bin`, `--no-rap`, `--no-sign` ("Do not use this unless you know what you are doing"), `--no-archive`; `[hemtt.release] sign = true`, `archive = true`, and `folder = "…"` (seen in CBA's project.toml, not in the doc summary).
- `hemtt launch [profile…] [-- passthrough]` – runs `hemtt dev`, then Arma 3: `-e/--executable` (default `arma3_x64`, no `.exe`), `-i/--instances N`, `-Q/--quick` (skip build), `-F/--no-filepatching`, plus `-o/-O/-b`. Profiles under `[hemtt.launch.<name>]` or `.hemtt/launch.toml` with keys `workshop`, `presets` (Launcher-exported `.html` in `.hemtt/presets/`), `dlc` (Contact/contact, Global Mobilization/gm, S.O.G. Prairie Fire/vn, CSLA Iron Curtain/csla, Western Sahara/ws, Spearhead 1944/spe, Reaction Forces/rf), `optionals`, `mission` (folder in `.hemtt/missions/` or path to `mission.sqm`, opens in the editor), `parameters`, `executable`, `file_patching` (true), `binarize` (false), `rapify` (true), `extends`. Source: Arma 3 found via `steamlocate` (`steam::find_app(107410)`), workshop items resolved under `<steam>\steamapps\workshop\content\107410`, every mod/DLC passed as `-mod="…"`. Example from ACE: `.hemtt/launch.toml` with `[default] workshop = ["450814997"]` and other profiles that `extends = "default"`.
- `hemtt publish` – release build + Workshop upload; needs `meta.cpp` with `publishedid` (0 creates a new item on first run per the docs; the Andx667 template says Steam must be running and logged in); `[hemtt.publish] description`, `changelog` (Markdown → BBCode); flags as `release`.
- `hemtt script <name>` – runs `.hemtt/scripts/<name>.rhai`; hooks live in `.hemtt/hooks/{pre_build,post_build,pre_release,archive,post_release}/*.rhai`.
- Others: `hemtt value`, `hemtt book`, `hemtt license`, `hemtt link create|remove` (symlink in the Arma 3 dir for file patching), `hemtt localization coverage|sort`, `hemtt utils {audio,bom,config,fnl,inspect,p3d,paa,pbo,sqf,verify}` (e.g. `utils pbo unpack`, `utils paa convert`, `utils sqf case`, `utils verify <PBO> <BIKEY>`).
- Global: `-t/--threads`, `-v`/`-vv`, `--just` (build/dev). Log: `.hemttout/latest.log`.

### B.2 project.toml keys [V]
Top level: `name` (required), `prefix` (required), `mainprefix`, `author`, `version` (Arma format). `[files] include` (defaults: mod.cpp, meta.cpp, LICENSE, logo_ca.paa, logo_co.paa), `exclude`. `[properties] author`, `url` (custom PBO properties). `[preprocessor] runtime_macros` (false). `[signing] authority` (`{prefix}_{version}`), `version` (3). `[version] path`, `major/minor/patch/build`, `git_hash` (8; 0 = off). `[hemtt.dev] exclude`; `[hemtt.build] optional_mod_folders` (true), `pdrive`; `[hemtt.check] pdrive`; `[hemtt.release] sign`, `archive`; `[hemtt.launch.*]` as above; `[hemtt.publish]`; `[hemtt.config] preset = "Hemtt"` (CBA's file); `[lints.<group>.<lint>] enabled|severity|options.*` or a separate `.hemtt/lints.toml` (ACE's shows `[sqf.banned_macros] options.release = ["DEBUG_MODE_FULL","DISABLE_COMPILE_CACHE"]`, `[sqf.undefined] enabled = true`, `[config.file_type] options.allow_no_extension = true`). Per-addon `addon.toml`: `[binarize] enabled/exclude`, `[rapify] enabled/exclude`, `[files] exclude`, `[properties]`, `ignore_pboprefix`.

### B.3 Arma 3 startup parameters (Biki "Startup Parameters", [B])
`-mod=@CBA_A3;@HorizonCam` (semicolon-separated, absolute paths allowed, quote if spaces; names case-insensitive); `-showScriptErrors` (show script errors on screen; suppressed by default in retail); `-filePatching` (load loose/unpacked files; off by default since 1.50; the Launcher exposes it as Parameters → Advanced → "Enable File Patching"); `-window` (windowed; resolution from arma3.cfg); `-noPause` (keep simulating/rendering without focus — the Draw3D note pairs `-window -noPause`); `-skipIntro` (skip main-menu world intro); `-noSplash`; `-noLogs` (no RPT!); `-profiles=<dir>` (moves profile + RPT); `-init=`, `-world=`, `-debug`, `-checkSignatures` not verified beyond names [U]. HEMTT's own example uses `-skipIntro -noSplash -showScriptErrors -debug -filePatching` [V].

### B.4 Logs and debugging output [B][V]
RPT: `%LOCALAPPDATA%\Arma 3\arma3_x64_YYYY-MM-DD_HH-MM-SS.rpt` (only the last 10 sessions are kept; `-profiles` changes the folder; `-noLogs` disables). `diag_log` writes a line to it; `systemChat "…"` prints to chat; `hint` overwrites the previous hint. CBA `INFO_1("x=%1", _x)` etc. log `[hzc] (main) INFO: x=…`. Other useful diag commands: `diag_frameNo`, `diag_tickTime`, `diag_deltaTime`, `diag_fps`, `diag_activeSQFScripts`.

### B.5 Alternatives [B]
Addon Builder (Arma 3 Tools): source/destination, "Binarize" (default; `-packonly` skips), Options → "Addon prefix", "Sign output PBO file" with a `.biprivatekey`, exclude/copy-directly file masks, "Clear temp folder". Mikero's pboProject/MakePbo from mikero.bytex.digital (free tools; pboProject is the packer historically used by ACE/CBA/CUP) — reads `$PBOPREFIX$.txt`/`pboprefix.txt`. Publisher: Arma 3 Tools → Publisher; new item or overwrite existing; tags (Data Type: Mod | Server | Scenario — Mod and Scenario are mutually exclusive; Mod Type sub-tags; "tag sparsely"); description; preview image `.jpg/.jpeg/.png/.gif/.bmp`, auto-downscaled to 0.95 MB; visibility; change notes; Steamworks agreement; Publisher auto-adds matching `.bisign` files and warns on bad structure.

---

## Appendix C – Testing in-game

- **Eden quick test** [B]: open Eden, choose a map, place a unit and set it as Player (red ring around its icon), place a helicopter from the Helicopters category (or place yourself as its pilot), PLAY (bottom right) previews the scenario; MP preview needs a hosted server. Save the mission as `test.VR` under `.hemtt/missions/` and set `mission = "test.VR"` in the launch profile to open it directly [V].
- **Debug Console** [B][V]: Eden → Tools → Debug Console, or ESC pause menu in SP/editor preview (in MP only for host/logged-in admin unless `enableDebugConsole = 2` in `description.ext`; `1` = SP + host/admin). Buttons LOCAL EXEC / GLOBAL EXEC / SERVER EXEC (remoteExec-based) and PERFORMANCE; expression field plus four Watch fields that re-evaluate live (evaluation >0.003 s turns the field orange); code runs unscheduled (no `sleep`). Type `utils` and LOCAL EXEC to open the utilities list (Config Viewer, Functions Viewer, Animation Viewer, GUI Editor, Splendid Camera). Useful watches for this mod: `hzc_main_active`, `hzc_main_enabled`, `cameraView`, `vehicle player`, `diag_fps`, `[] call hzc_main_fnc_toggle` (LOCAL EXEC) — CBA-registered functions are callable by their full name from here [V]. CBA's `cba_diagnostic` addon adds 8 target-aware watch fields ("Target Debugging") [B].
- **File patching** [V][B]: run with `-filePatching` (HEMTT default), mod built by `hemtt dev` (unbinarized, linked to source), `DISABLE_COMPILE_CACHE` defined; edit SQF → restart mission → `[] call hzc_PREP_RECOMPILE` if you added the recompile macros; configs need a game restart. Servers control it with `allowedFilePatching` in `server.cfg`: 0 = block, 1 = headless clients only, 2 = allow all (default 0; only 2 lets a patched client join).
- **Splendid Camera** [B]: Eden menu / Debug Console, or `[] spawn BIS_fnc_camera;` (LOCAL EXEC; the Biki warns that calling it without arguments from the pause-menu console can crash); Ctrl+0..9 store positions, M map, N vision mode, Ctrl+C exports the camera array, Esc exits. Handy for inspecting what your scripted camera should look like.
- **Checking CBA registration**: Configure Addons (keys) and Addon Options (settings) as in (c) step 8; `isNil "hzc_main_enabled"` in a watch field is `false` once preInit ran; `hzc_main` (the ADDON flag) is `true` after preInit.

---

## (e) Sources

Primary (fetched, [V]):
- https://github.com/CBATeam/CBA_A3/wiki/CBA-Settings-System (raw: https://raw.githubusercontent.com/wiki/CBATeam/CBA_A3/CBA-Settings-System.md)
- https://github.com/CBATeam/CBA_A3/wiki/Keybinding
- https://github.com/CBATeam/CBA_A3/wiki/Extended-Event-Handlers-(new)
- https://github.com/CBATeam/CBA_A3/wiki/Advanced-XEH
- https://github.com/CBATeam/CBA_A3/wiki/Per-Frame-Handlers
- https://github.com/CBATeam/CBA_A3/wiki/Player-Events
- https://github.com/CBATeam/CBA_A3/wiki/Custom-Events-System
- https://github.com/CBATeam/CBA_A3/blob/master/addons/settings/fnc_addSetting.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/keybinding/fnc_addKeybind.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/keybinding/XEH_preInit.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/events/fnc_addPlayerEventHandler.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/common/fnc_addPerFrameHandler.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/common/fnc_removePerFrameHandler.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/common/init_perFrameHandler.sqf
- https://github.com/CBATeam/CBA_A3/blob/master/addons/main/script_macros_common.hpp
- https://github.com/CBATeam/CBA_A3/blob/master/addons/main/script_mod.hpp
- https://github.com/CBATeam/CBA_A3/blob/master/addons/main/config.cpp
- https://github.com/CBATeam/CBA_A3/blob/master/addons/settings/CfgEventHandlers.hpp
- https://github.com/CBATeam/CBA_A3/blob/master/addons/xeh/CfgEventHandlers.hpp
- https://github.com/CBATeam/CBA_A3/blob/master/.hemtt/project.toml
- https://github.com/CBATeam/CBA_A3/releases and https://api.github.com/repos/CBATeam/CBA_A3/releases
- https://steamcommunity.com/sharedfiles/filedetails/?id=450814997
- https://hemtt.dev/ (installation, configuration, commands/new, check, dev, build, release, launch, publish, script, configuration/addon, configuration/lints, configuration/version, installation/arma3tools, print.html)
- https://github.com/BrettMayson/HEMTT (releases; `bin/src/commands/launch/mod.rs`, `bin/src/commands/launch/launcher.rs`, `libs/common/src/steam.rs`)
- https://api.github.com/repos/BrettMayson/HEMTT/releases
- https://marketplace.visualstudio.com/items?itemName=BrettMayson.hemtt
- https://github.com/acemod/ACE3 (`addons/goggles/*`, `addons/main/script_mod.hpp`, `script_macros.hpp`, `script_version.hpp`, `config.cpp`, `.hemtt/project.toml`, `.hemtt/launch.toml`, `.hemtt/lints.toml`, `mod.cpp`, `docs/wiki/development/setting-up-the-development-environment.md`)
- https://ace3.acemod.org/wiki/development/arma-3-scheduler-and-our-practices
- https://github.com/flufflesamy/CBA-Tutorial (README, `.hemtt/project.toml`, `addons/main/*`, `addons/mycomponent/*`, `docs/tutorials/*.md`)
- https://github.com/Andx667/arma-mod-template (`.hemtt/project.toml`, `SETUP.md`, `mod.cpp`, `meta.cpp`, `addons/main/*`)
- https://github.com/BrettMayson/HEMTT-Example (`addons/main/config.cpp`, `script_component.hpp`, `script_mod.hpp`)
- https://raw.githubusercontent.com/wine-mirror/wine/master/include/dinput.h (DIK_* constants)
- https://docs.rs/steamlocate/latest/steamlocate/

Bohemia wiki pages (blocked during this session; quoted from search-index excerpts, [B]):
- https://community.bistudio.com/wiki/CfgPatches
- https://community.bistudio.com/wiki/PBOPREFIX
- https://community.bistudio.com/wiki/Arma_3:_Creating_an_Addon
- https://community.bistudio.com/wiki/Arma_3:_Mod_Presentation and https://community.bistudio.com/wiki/Mod.cpp/bin_File_Format
- https://community.bistudio.com/wiki/Arma_3:_meta.cpp
- https://community.bistudio.com/wiki/Arma_3:_Startup_Parameters
- https://community.bistudio.com/wiki/Arma_3:_Launcher_-_Advanced_Parameters
- https://community.bistudio.com/wiki/Crash_Files and https://community.bistudio.com/wiki/arma.RPT
- https://community.bistudio.com/wiki/Debugging_Techniques
- https://community.bistudio.com/wiki/Arma_3:_Debug_Console
- https://community.bistudio.com/wiki/Arma_3:_Mission_Event_Handlers
- https://community.bistudio.com/wiki/hasInterface , /isServer , /isDedicated
- https://community.bistudio.com/wiki/Arma_3:_Functions_Library
- https://community.bistudio.com/wiki/Arma_3:_Publisher
- https://community.bistudio.com/wiki/Addon_Builder
- https://community.bistudio.com/wiki/DSCreateKey , /DSSignFile , /ArmA:_Addon_Signatures
- https://community.bistudio.com/wiki/Arma_3:_Server_Config_File
- https://community.bistudio.com/wiki/Arma_3:_Splendid_Camera
- https://community.bistudio.com/wiki/Arma_3:_Modded_Keybinding
- https://community.bistudio.com/wiki/Eden_Editor:_Introduction
- https://community.bistudio.com/wiki/P_drive

Secondary:
- https://mikero.bytex.digital/ , https://community.bistudio.com/wiki/pboProject
- https://github.com/CBATeam/CBA_A3/wiki/Target-Debugging
- https://www.misfit-company.com/arma3/mission_making/cba_settings/ (server/mission/client tabs)
