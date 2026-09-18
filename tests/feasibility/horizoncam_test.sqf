/*
    horizoncam_test.sqf
    Throwaway feasibility harness for a horizon-locked FIRST-PERSON helicopter camera.
    This is NOT the mod. It exists to answer the in-game questions in docs/research/README.md
    (T1 flight control, T2 head pose, T3 input actions, T4 HUD, T8 NVG, T11 eye anchor,
    T14 zoom) before any addon is built.

    HOW TO RUN
      1. Eden: place a helicopter, make yourself its pilot, save the mission, copy this
         file next to the mission.sqm, play the mission.
      2. Sit in the pilot seat in FIRST person, open the debug console (Esc) and run:
             [] execVM "horizoncam_test.sqf";
      3. Press Ctrl+Shift+H to take over the camera. Fly. Read the on-screen readout.

    TAKEOVER METHODS  (Ctrl+Shift+M cycles while the camera is off; default M4)
      M0  cameraEffect on a camera object. Runs 1 and 2 showed the engine stops delivering input to
          the vehicle while this is primary, even though inputAction still reads the keys.
      M1  as M0 plus camCommand "manual off" / "inertia off", in case the camera was eating input.
      M2  as M0 but effect "External".
      M3  a hidden Land_HandyCam_F is created, positioned and oriented every frame, and the
          engine's own switchCamera "INTERNAL" is used on it. Not a cutscene camera.
      M4  the engine pilot view stays primary (so input must work); our camera renders to a
          texture that is drawn over the whole screen. Costs PiP quality and view distance.
          Run 3: works, but the texture resolution and the missing instrument overlays rule it out.
      M5  no camera at all. The engine pilot view stays primary and the pilot's HEAD is
          counter-rotated through the engine's own FreeTrack head-tracking input: hhl_x64.dll
          (callExtension, in the Arma root or a mod folder) hands the pose every frame to our
          FreeTrackClient64.dll, which Arma loaded at start-up from the folder named in
          HKCU\Software\Freetrack\FreetrackClient\Path. Needs both DLLs in place and a restart
          of Arma after the registry value is set. See native/README.md.

    KEYS  (all Ctrl+Shift + key, chosen so they do not collide with flight bindings)
      H          toggle the scripted horizon camera on / off
      M          next takeover method (only while the camera is off)
      J          cycle head mode: 0 display only, 1 apply getCameraViewDirection, 2 apply eyeDirection
      K          cycle the pitch/roll limit: 90 -> 25 -> 15 -> 7 -> 0   (90 = no knee, 0 = camera fully follows airframe)
      (Use Action 1, any key or joystick button bound under Configure > Controls > Custom, also toggles on / off)
      ,   .      limit down / up by one degree (pitch and roll together)
      N          cycle strength 1 -> 0.75 -> 0.5 -> 0.25 (fraction of the tilt cancelled inside the limit)
      G          cycle soft knee 0 -> 2 -> 4 degrees
      P          cycle prediction lead 1 -> 0 -> 2 frames
      B          burst log: one [HZC-B] line per frame for 3 seconds (lag measurement)
      T          pitch trim: cancel the vehicle's default head pitch so the view is centred; again to clear
      W          cycle washout 0 -> 1 -> 2 -> 4 s (cancel only the fast wobble around a slow-moving reference attitude)
      Y          cycle the per-frame hook: EachFrame -> Draw3D
      U          toggle cameraEffectEnableHUD
      L          toggle the on-screen readout
      [   ]      narrow / widen the camera field of view
      Backspace  shut the harness down completely (camera released, all handlers removed)

    CONSOLE HELPERS once it is running
      call HZC_fnc_repairView;   (black screen after a mission restart: stray camera effect)
      call HZC_fnc_shutdown;        HZC_smoothTau = 0.15;        HZC_limitPitch = 20; HZC_limitRoll = 40;
      "hhl" callExtension "status";  (M5: is the tracker DLL loaded and being polled by the engine?)
      HZC_gainPitch = 6.25; HZC_gainRoll = 3.18;   (M5: engine degrees per degree sent; run 4 measured these)

    LOGGING
      Every second while active a line prefixed [HZC] goes to the RPT
      (%LOCALAPPDATA%\Arma 3\Arma3_x64_<date>.rpt). Key presses and state changes are
      logged too, and echoed to system chat.

    MATHS
      Airframe attitude is decomposed into yaw / pitch / roll from vectorDirVisual and
      vectorUpVisual. The camera uses the same yaw and, per axis,
          cam(a) = a - clamp(a, -L, +L)
      so it stays level inside +/-L and is dragged along at a fixed offset of L beyond.
      Orientation is written with setVectorDirAndUp (roll through the up vector, because
      camSetBank is non-functional). Position is the engine pilot-camera point sampled at
      activation, re-applied every frame from the render-scope model transform.
*/

if (!hasInterface) exitWith {};
if (!isNil "HZC_keyEH") then { call HZC_fnc_shutdown; };

// ------------------------------------------------------------------ settings
HZC_limitPitch = 90;        // degrees. 90 = no knee (horizon fully locked). Pilot feedback: crossing the knee at 5..7 in pitch caused motion sickness; 25 did not
HZC_limitRoll  = 90;        // degrees
HZC_limits     = [90, 25, 15, 7, 0];
HZC_limitIdx   = 0;
HZC_smoothTau  = 0;         // seconds of exponential smoothing on camera pitch/roll; 0 = none (adds lag, not recommended)
HZC_strength   = 1;         // fraction of the tilt cancelled inside the limit: 1 = horizon fully level, 0.5 = half; Ctrl+Shift+N cycles
HZC_knee       = 0;         // degrees of soft transition either side of the limit; 0 = hard knee; Ctrl+Shift+G cycles
HZC_leadFrames = 1;         // frames of attitude prediction to cover the tracker's one-frame lag; 0 = off; Ctrl+Shift+P cycles
HZC_pitchTrim  = 0;         // degrees added to the head pitch. 0 keeps the vehicle's default view angle (about -6 on the Huron); Ctrl+Shift+T sets it to centre the view, again to clear
HZC_toggleAction = "User1"; // Arma custom action that toggles the horizon camera (bind Configure > Controls > Custom > "Use Action 1" to any key or joystick button). "" = off
HZC_hideDirMarker = true;   // hide the engine's vehicle-direction marker (the V that appears whenever the head is turned off the nose) while active
HZC_hudMaskIndex = 4;       // index of that marker in the showHUD array ("direction"); change if the wrong element disappears
HZC_washout    = 0;         // seconds. 0 = level relative to the true horizon. > 0 = cancel only the FAST part of the tilt: the reference is a slow
                            // moving average of the attitude with this time constant, so sustained pitch changes (accelerating, decelerating)
                            // pass through gently and the limit is rarely reached; hover wobble is still removed. Ctrl+Shift+W cycles 0/1/2/4
HZC_headMode   = 0;         // 0 display only, 1 apply getCameraViewDirection, 2 apply eyeDirection, 3 experiment: player doWatch a levelled point (does the engine head turn?)
HZC_loopMode   = 0;         // 0 EachFrame, 1 Draw3D
HZC_hud        = true;      // cameraEffectEnableHUD
HZC_showHint   = true;
HZC_showHeliInput = true;   // set false from the console if the Heli* action names throw errors
HZC_fov        = 0.75;
HZC_method     = 5;         // takeover method; Ctrl+Shift+M cycles while inactive (see HZC_methodNames). M4 kept control in runs 2-3 but its picture is unusable; M5 is the head-tracker route
HZC_methodNames = [
    "M0 cameraEffect Internal",
    "M1 cameraEffect Internal + camCommand manual off",
    "M2 cameraEffect External",
    "M3 switchCamera onto hidden proxy object",
    "M4 engine view stays primary, scripted camera shown via full-screen render-to-texture",
    "M5 engine view stays primary, head counter-rotated through FreeTrack tracker input (hhl_x64.dll)"
];
HZC_signPitch  = 1;         // M5: sign of the head pitch sent to the tracker. FreeTrack: positive = look up. Confirmed correct in run 4
HZC_signRoll   = -1;        // M5: sign of the head roll sent. FreeTrack: positive = roll left. Confirmed correct in run 4
HZC_gainPitch  = 2 * pi;    // M5: engine head degrees per degree handed to the tracker. Measured run 4: 6.25 (pitch), i.e. the engine reads the FreeTrack value as turns, not radians
HZC_gainRoll   = pi;        // M5: measured 3.18 (roll), i.e. the engine reads it as half-turns. Adjust from the console if the horizon still over- or under-corrects
HZC_rttName    = "hzc_rtt";
HZC_rttSize    = 2048;      // requested render-to-texture size; the PiP video setting caps the real one. Try 1024 if the picture goes black
HZC_eyeForward = 0.00;      // metres the anchor is pushed forward (vehicle Y). Rejected as a fix for the head-in-view problem; left for experiments
HZC_eyeUp      = 0.00;      // metres up (vehicle Z); adjust from the console if the view sits too low or high
HZC_hidePilot  = true;      // M4 only: hide the pilot model while active, so the render-to-texture camera does not see the inside of the head

HZC_lookActions = ["lookAround", "lookAroundToggle", "lookLeftCont", "lookRightCont", "lookUpCont", "lookDownCont",
                   "zoomTemp", "zoomIn", "zoomOut", "nightVision", "personView"];
HZC_heliActions = ["HeliUp", "HeliDown", "HeliForward", "HeliBack", "HeliLeft", "HeliRight", "HeliRudderLeft", "HeliRudderRight"];

// ------------------------------------------------------------------ state
HZC_active     = false;
HZC_cam        = objNull;
HZC_proxy      = objNull;
HZC_viewObj    = objNull;   // whichever object carries the view this run: the camera or the proxy
uiNamespace setVariable ["HZC_pic", controlNull];   // controls cannot live in mission namespace globals
HZC_veh        = objNull;
HZC_eyeModel   = [0, 0, 0];
HZC_camPitch   = 0;
HZC_camRoll    = 0;
HZC_lastTick   = diag_tickTime;
HZC_lastLog    = 0;
HZC_lastHint   = 0;
HZC_lastVision = -1;
HZC_frames     = 0;
HZC_sentPitch  = 0;         // M5: head pitch handed to the tracker this frame (deg, after sign)
HZC_sentRoll   = 0;
HZC_extResult  = [];        // M5: last callExtension "pose" reply
HZC_extStatus  = "";        // M5: last callExtension "status" reply (tracker=ok polls=N proves the engine polls our DLL)
HZC_prevPitch  = 0;         // last frame's attitude, for the rate estimate behind the prediction
HZC_prevRoll   = 0;
HZC_burstUntil = 0;         // per-frame logging ([HZC-B] lines) runs while diag_tickTime < this; Ctrl+Shift+B starts 3 s
HZC_relPitch   = 0;         // engine head pitch relative to the airframe, last frame (for the trim key)
HZC_slowPitch  = 0;         // washout reference attitude (slow moving average)
HZC_slowRoll   = 0;
HZC_toggleHeld = false;     // edge detection for the custom-action toggle
HZC_savedHUD   = [];        // showHUD state before we hid the direction marker

// ------------------------------------------------------------------ helpers
HZC_fnc_msg = {
    params ["_text"];
    systemChat format ["[HZC] %1", _text];
    diag_log format ["[HZC] %1", _text];
};

HZC_fnc_fmtVec = {
    params ["_v", ["_d", 2]];
    (_v apply { _x toFixed _d }) joinString " "
};

// deadzone: 0 while |a| <= L, then follows the airframe at a fixed offset of L
HZC_fnc_deadzone = {
    params ["_a", "_l"];
    _a - ((_a max (-_l)) min _l)
};

// clamp(a, -L, +L) with an optional soft knee of half-width k degrees: inside L-k it is a, beyond L+k it is L,
// in between a quadratic blend with continuous slope. k = 0 gives the hard clamp
HZC_fnc_clampSoft = {
    params ["_a", "_l", "_k"];
    _k = (_k max 0) min _l;
    private _m = abs _a;
    private _g = if (_k <= 0 || {_m <= _l - _k}) then {
        _m min _l
    } else {
        if (_m >= _l + _k) then { _l } else { _l - ((_l + _k - _m) ^ 2) / (4 * _k) }
    };
    if (_a < 0) then { -_g } else { _g }
};

// signed shortest difference _new - _old in degrees
HZC_fnc_angDiff = {
    params ["_new", "_old"];
    private _d = _new - _old;
    _d - 360 * floor ((_d + 180) / 360)
};

// yaw / pitch / roll of the camera the engine is actually rendering. positionCameraToWorld's forward axis is
// picked at runtime by matching getCameraViewDirection; the other axis is up
HZC_fnc_renderedAttitude = {
    private _gcvd = getCameraViewDirection player;
    private _cO = positionCameraToWorld [0, 0, 0];
    private _cA = (positionCameraToWorld [0, 0, 1]) vectorDiff _cO;
    private _cB = (positionCameraToWorld [0, 1, 0]) vectorDiff _cO;
    if ((_cB vectorDotProduct _gcvd) > (_cA vectorDotProduct _gcvd)) then {
        [_cB, _cA] call HZC_fnc_attitudeDU
    } else {
        [_cA, _cB] call HZC_fnc_attitudeDU
    }
};

// wrap-aware exponential step from _cur toward _des
HZC_fnc_lerpAngle = {
    params ["_cur", "_des", "_t"];
    private _diff = _des - _cur;
    _diff = _diff - 360 * floor ((_diff + 180) / 360);
    _cur + _diff * _t
};

// yaw (deg, 0 = north, clockwise +), pitch (deg, nose up +), roll (deg, right wing down +)
HZC_fnc_attitude = {
    params ["_veh"];
    [vectorDirVisual _veh, vectorUpVisual _veh] call HZC_fnc_attitudeDU
};

// same decomposition from an arbitrary forward / up pair (used for the rendered camera too)
HZC_fnc_attitudeDU = {
    params ["_dIn", "_uIn"];
    private _d = vectorNormalized _dIn;
    private _u = vectorNormalized _uIn;
    private _yaw = (_d select 0) atan2 (_d select 1);
    private _pitch = asin (((_d select 2) min 1) max (-1));
    private _right0 = [cos _yaw, -(sin _yaw), 0];
    private _up0 = _right0 vectorCrossProduct _d;
    private _roll = (_u vectorDotProduct _right0) atan2 (_u vectorDotProduct _up0);
    [_yaw, _pitch, _roll]
};

// inverse of HZC_fnc_attitude: [fwd, right, up] unit vectors from yaw / pitch / roll
HZC_fnc_basis = {
    params ["_yaw", "_pitch", "_roll"];
    private _fwd = [(sin _yaw) * (cos _pitch), (cos _yaw) * (cos _pitch), sin _pitch];
    private _right0 = [cos _yaw, -(sin _yaw), 0];
    private _up0 = _right0 vectorCrossProduct _fwd;
    private _up = (_up0 vectorMultiply (cos _roll)) vectorAdd (_right0 vectorMultiply (sin _roll));
    private _right = _fwd vectorCrossProduct _up;
    [_fwd, _right, _up]
};

HZC_fnc_applyFov = {
    if (HZC_active && {!isNull HZC_cam}) then {
        HZC_cam camSetFov HZC_fov;
        HZC_cam camCommit 0;
    };
    [format ["fov %1", HZC_fov toFixed 2]] call HZC_fnc_msg;
};

// ------------------------------------------------------------------ view repair
// A mission restart while a camera is live skips the release code and can leave the engine
// pointing at a camera that no longer exists (black screen). Run on load and from the console.
HZC_fnc_repairView = {
    private _c = "camera" camCreate [0, 0, 0];
    _c cameraEffect ["Terminate", "BACK"];
    _c cameraEffect ["Terminate", "BACK", HZC_rttName];
    camDestroy _c;
    private _pic = uiNamespace getVariable ["HZC_pic", controlNull];
    if (!isNull _pic) then { ctrlDelete _pic; };
    uiNamespace setVariable ["HZC_pic", controlNull];
    player hideObject false;
    player doWatch objNull;
    showCinemaBorder false;
    cameraEffectEnableHUD true;
    if (!isNull objectParent player) then { (objectParent player) switchCamera "INTERNAL"; } else { player switchCamera "INTERNAL"; };
    "hhl" callExtension "zero";     // M5: recentre the tracker head if a restart skipped the release
    ["view repair: stray camera effects terminated, pilot unhidden, internal view restored"] call HZC_fnc_msg;
};

// ------------------------------------------------------------------ activate / release
HZC_fnc_activate = {
    if (HZC_active) exitWith {};
    private _veh = objectParent player;
    if (isNull _veh || {!(_veh isKindOf "Helicopter")} || {driver _veh != player}) exitWith {
        ["not activated: you must be the pilot of a helicopter"] call HZC_fnc_msg;
    };
    if (cameraView != "INTERNAL") exitWith {
        ["not activated: switch to first person (Num Enter) first so the eye anchor is sampled from the pilot view"] call HZC_fnc_msg;
    };
    if (HZC_method == 5 && {("hhl" callExtension "version") isEqualTo ""}) exitWith {
        ["not activated: extension hhl_x64.dll not found. Put it in the Arma root (or a loaded mod folder) and restart Arma"] call HZC_fnc_msg;
    };
    HZC_veh = _veh;

    // eye anchor: where the engine's pilot camera is right now, in vehicle model space
    HZC_eyeModel = (_veh worldToModelVisual (positionCameraToWorld [0, 0, 0])) vectorAdd [0, HZC_eyeForward, HZC_eyeUp];

    private _fovCfg = getNumber (configOf _veh >> "ViewPilot" >> "initFov");
    if (_fovCfg > 0) then { HZC_fov = _fovCfg; };

    // start from the current stabilised attitude so there is no jump
    ([_veh] call HZC_fnc_attitude) params ["_yaw", "_pitch", "_roll"];
    HZC_camPitch = [_pitch, HZC_limitPitch] call HZC_fnc_deadzone;
    HZC_camRoll  = [_roll,  HZC_limitRoll]  call HZC_fnc_deadzone;
    HZC_prevPitch = _pitch;
    HZC_prevRoll  = _roll;
    HZC_slowPitch = _pitch;
    HZC_slowRoll  = _roll;

    private _eyeASL = _veh modelToWorldVisualWorld HZC_eyeModel;
    private _eyeAGL = ASLToAGL _eyeASL;
    switch (HZC_method) do {
        case 3: {
            // hidden proxy object: the engine treats this as a real view, not a cutscene camera
            HZC_proxy = "Land_HandyCam_F" createVehicleLocal [0, 0, 0];
            HZC_proxy enableSimulation false;
            HZC_proxy allowDamage false;
            HZC_proxy hideObject true;
            HZC_proxy setPosASL _eyeASL;
            HZC_proxy switchCamera "INTERNAL";
            HZC_viewObj = HZC_proxy;
        };
        case 4: {
            // engine pilot view stays primary; our camera renders to a texture drawn over the whole screen
            HZC_cam = "camera" camCreate _eyeAGL;
            HZC_cam camSetFov HZC_fov;
            HZC_cam camSetFocus [-1, -1];
            private _aspect = getResolution select 4;
            private _pic = (findDisplay 46) ctrlCreate ["RscPicture", -1];
            _pic ctrlSetPosition [safeZoneX, safeZoneY, safeZoneW, safeZoneH];
            _pic ctrlSetText format ["#(argb,%3,%3,1)r2t(%1,%2)", HZC_rttName, _aspect, HZC_rttSize];
            _pic ctrlCommit 0;
            uiNamespace setVariable ["HZC_pic", _pic];
            HZC_cam cameraEffect ["Internal", "BACK", HZC_rttName];
            HZC_cam camCommit 0;
            if (HZC_hidePilot) then { player hideObject true; };
            HZC_viewObj = HZC_cam;
        };
        case 5: {
            // no camera: the engine pilot view stays; the head is driven through the tracker input every frame
            HZC_viewObj = objNull;
            HZC_extStatus = "hhl" callExtension "status";
            if (HZC_hideDirMarker) then {
                HZC_savedHUD = shownHUD;
                private _h = +HZC_savedHUD;
                if (HZC_hudMaskIndex < count _h) then { _h set [HZC_hudMaskIndex, false]; showHUD _h; };
            };
            if (HZC_extStatus find "tracker=ok" < 0) then {
                [format ["WARNING: extension reports '%1'. The engine has not loaded our FreeTrackClient64.dll: set HKCU\Software\Freetrack\FreetrackClient\Path to the bin folder and restart Arma", HZC_extStatus]] call HZC_fnc_msg;
            };
        };
        default {
            HZC_cam = "camera" camCreate _eyeAGL;
            HZC_cam camSetFov HZC_fov;
            HZC_cam camSetFocus [-1, -1];
            HZC_cam cameraEffect [["Internal", "Internal", "External"] select HZC_method, "BACK"];
            HZC_cam camCommit 0;
            if (HZC_method == 1) then {
                HZC_cam camCommand "manual off";
                HZC_cam camCommand "inertia off";
            };
            cameraEffectEnableHUD HZC_hud;
            showCinemaBorder false;
            HZC_viewObj = HZC_cam;
        };
    };

    HZC_lastVision = -1;
    HZC_lastTick = diag_tickTime;
    HZC_active = true;
    call HZC_fnc_update;

    [format ["ACTIVATED in %1 | %7 | eye anchor (model) [%2] | fov %3 | limits %4/%5 | hook %6",
        typeOf _veh, [HZC_eyeModel, 3] call HZC_fnc_fmtVec, HZC_fov toFixed 2,
        HZC_limitPitch, HZC_limitRoll, ["EachFrame", "Draw3D"] select HZC_loopMode,
        HZC_methodNames select HZC_method]] call HZC_fnc_msg;
    // the vehicle's configured pilot view: initAngleX is the default vertical head angle (the "default slightly negative pitch")
    private _vp = configOf _veh >> "ViewPilot";
    diag_log format ["[HZC] ViewPilot of %1: initAngleX=%2 minAngleX=%3 maxAngleX=%4 initAngleY=%5 minAngleY=%6 maxAngleY=%7 initFov=%8 | engine head pitch rel. airframe now %9",
        typeOf _veh, getNumber (_vp >> "initAngleX"), getNumber (_vp >> "minAngleX"), getNumber (_vp >> "maxAngleX"),
        getNumber (_vp >> "initAngleY"), getNumber (_vp >> "minAngleY"), getNumber (_vp >> "maxAngleY"), getNumber (_vp >> "initFov"),
        HZC_relPitch toFixed 1];
    diag_log format ["[HZC] allCameras at activation: %1", allCameras];
};

HZC_fnc_deactivate = {
    params [["_reason", "manual"]];
    if (!HZC_active && {isNull HZC_cam} && {isNull HZC_proxy}) exitWith {};
    if (!isNull HZC_cam) then {
        if (HZC_method == 4) then {
            HZC_cam cameraEffect ["Terminate", "BACK", HZC_rttName];
        } else {
            HZC_cam cameraEffect ["Terminate", "BACK"];
        };
        camDestroy HZC_cam;
    };
    if (HZC_method == 5) then { "hhl" callExtension "zero"; };   // recentre the tracker head
    if (count HZC_savedHUD > 0) then { showHUD HZC_savedHUD; HZC_savedHUD = []; };
    private _pic = uiNamespace getVariable ["HZC_pic", controlNull];
    if (!isNull _pic) then { ctrlDelete _pic; };
    uiNamespace setVariable ["HZC_pic", controlNull];
    player hideObject false;
    player doWatch objNull;
    if (!isNull objectParent player) then { (objectParent player) switchCamera "INTERNAL"; };
    if (!isNull HZC_proxy) then { deleteVehicle HZC_proxy; };
    HZC_cam = objNull;
    HZC_proxy = objNull;
    HZC_viewObj = objNull;
    HZC_active = false;
    [format ["released (%1)", _reason]] call HZC_fnc_msg;
};

HZC_fnc_shutdown = {
    ["shutdown"] call HZC_fnc_deactivate;
    if (!isNil "HZC_ehFrame") then { removeMissionEventHandler ["EachFrame", HZC_ehFrame]; HZC_ehFrame = nil; };
    if (!isNil "HZC_ehDraw")  then { removeMissionEventHandler ["Draw3D",    HZC_ehDraw];  HZC_ehDraw  = nil; };
    if (!isNil "HZC_keyEH")   then { (findDisplay 46) displayRemoveEventHandler ["KeyDown", HZC_keyEH]; HZC_keyEH = nil; };
    hintSilent "";
    ["harness shut down"] call HZC_fnc_msg;
};

// ------------------------------------------------------------------ per-frame update
HZC_fnc_update = {
    if (!HZC_active) exitWith {};
    private _veh = HZC_veh;
    if (!alive player || {objectParent player != _veh} || {driver _veh != player} || {!alive _veh}) exitWith {
        ["lifecycle: dead, left the seat, or vehicle destroyed"] call HZC_fnc_deactivate;
    };
    if (visibleMap) exitWith { ["map opened"] call HZC_fnc_deactivate; };

    private _now = diag_tickTime;
    private _dt = (_now - HZC_lastTick) max 0;
    HZC_lastTick = _now;
    HZC_frames = HZC_frames + 1;

    // airframe attitude -> stabilised camera attitude
    ([_veh] call HZC_fnc_attitude) params ["_yaw", "_pitch", "_roll"];
    // attitude rate from successive samples, then predict where the airframe will be when the tracker pose is rendered
    private _ratePitch = 0;
    private _rateRoll  = 0;
    if (_dt > 0 && {_dt < 0.5}) then {
        _ratePitch = ([_pitch, HZC_prevPitch] call HZC_fnc_angDiff) / _dt;
        _rateRoll  = ([_roll,  HZC_prevRoll]  call HZC_fnc_angDiff) / _dt;
    };
    HZC_prevPitch = _pitch;
    HZC_prevRoll  = _roll;
    private _lead   = HZC_leadFrames * _dt;
    private _pPred  = _pitch + _ratePitch * _lead;
    private _rPred  = _roll  + _rateRoll  * _lead;
    // washout: with a time constant set, the reference is a slow moving average of the attitude instead of the horizon,
    // so only the fast wobble around it is cancelled
    private _refP = 0;
    private _refR = 0;
    if (HZC_washout > 0) then {
        if (_dt > 0) then {
            private _a = 1 - exp (0 - (_dt / HZC_washout));
            HZC_slowPitch = [HZC_slowPitch, _pitch, _a] call HZC_fnc_lerpAngle;
            HZC_slowRoll  = [HZC_slowRoll,  _roll,  _a] call HZC_fnc_lerpAngle;
        };
        _refP = HZC_slowPitch;
        _refR = HZC_slowRoll;
    } else {
        HZC_slowPitch = _pitch;
        HZC_slowRoll  = _roll;
    };
    // head counter-rotation = -strength * clamp(predicted attitude relative to the reference); camera attitude = airframe + head
    private _headP  = HZC_pitchTrim - (HZC_strength * ([[_pPred, _refP] call HZC_fnc_angDiff, HZC_limitPitch, HZC_knee] call HZC_fnc_clampSoft));
    private _headR  = -(HZC_strength * ([[_rPred, _refR] call HZC_fnc_angDiff, HZC_limitRoll,  HZC_knee] call HZC_fnc_clampSoft));
    private _desPitch = _pitch + _headP;
    private _desRoll  = _roll  + _headR;
    if (HZC_smoothTau > 0 && {_dt > 0}) then {
        private _a = 1 - exp (0 - (_dt / HZC_smoothTau));
        HZC_camPitch = [HZC_camPitch, _desPitch, _a] call HZC_fnc_lerpAngle;
        HZC_camRoll  = [HZC_camRoll,  _desRoll,  _a] call HZC_fnc_lerpAngle;
    } else {
        HZC_camPitch = _desPitch;
        HZC_camRoll  = _desRoll;
    };
    ([_yaw, HZC_camPitch, HZC_camRoll] call HZC_fnc_basis) params ["_fwd", "_right", "_up"];

    private _eyeASLForWatch = _veh modelToWorldVisualWorld HZC_eyeModel;
    // head readings: always computed for the readout, applied only in head modes 1 / 2 (3 = doWatch experiment)
    private _gcvd = getCameraViewDirection player;
    private _eyeD = eyeDirection player;
    private _headWorld = [_gcvd, _eyeD] select (HZC_headMode == 2);
    private _hm = _veh vectorWorldToModelVisual _headWorld;          // model space: x right, y forward, z up
    private _hYaw = (_hm select 0) atan2 (_hm select 1);
    private _hPitch = asin (((_hm select 2) min 1) max (-1));
    HZC_relPitch = _hPitch;
    if (HZC_headMode == 3) then {
        // experiment: ask the engine to make the player's head watch a point 50 m along the levelled forward vector
        player doWatch (ASLToAGL (_eyeASLForWatch vectorAdd (_fwd vectorMultiply 50)));
    };
    if (HZC_headMode > 0 && {HZC_headMode < 3}) then {
        private _fwd1   = (_fwd   vectorMultiply (cos _hYaw))   vectorAdd  (_right vectorMultiply (sin _hYaw));
        private _right1 = (_right vectorMultiply (cos _hYaw))   vectorDiff (_fwd   vectorMultiply (sin _hYaw));
        private _fwd2   = (_fwd1  vectorMultiply (cos _hPitch)) vectorAdd  (_up    vectorMultiply (sin _hPitch));
        private _up2    = (_up    vectorMultiply (cos _hPitch)) vectorDiff (_fwd1  vectorMultiply (sin _hPitch));
        _fwd = _fwd2; _up = _up2; _right = _right1;
    };

    private _eyeASL = _veh modelToWorldVisualWorld HZC_eyeModel;
    if (HZC_method == 5) then {
        // head counter-rotation: what the engine head must add to the airframe attitude to reach the levelled camera attitude
        // (equals -clamp(a, -L, +L) per axis). Sent as integer millidegrees so Arma never formats the numbers in scientific notation.
        // HZC_sent* is the head rotation we want the engine to apply (degrees); the tracker value is scaled down by the measured engine gain
        HZC_sentPitch = HZC_signPitch * (HZC_camPitch - _pitch);
        HZC_sentRoll  = HZC_signRoll  * (HZC_camRoll  - _roll);
        HZC_extResult = "hhl" callExtension ["pose", [0, round (HZC_sentPitch * 1000 / HZC_gainPitch), round (HZC_sentRoll * 1000 / HZC_gainRoll)]];
        if (_now < HZC_burstUntil) then {
            // per-frame lag measurement: rendered head (camera minus airframe) against the head we asked for
            (call HZC_fnc_renderedAttitude) params ["", "_bP", "_bR"];
            diag_log format ["[HZC-B] t=%1 dt=%2 heli=[%3 %4] rate=[%5 %6] want=[%7 %8] got=[%9 %10]",
                _now toFixed 3, _dt toFixed 4, _pitch toFixed 2, _roll toFixed 2, _ratePitch toFixed 1, _rateRoll toFixed 1,
                HZC_sentPitch toFixed 2, HZC_sentRoll toFixed 2, (_bP - _pitch) toFixed 2, (_bR - _roll) toFixed 2];
        };
    } else {
        // write the view transform from render-scope reads
        if (!isNull HZC_viewObj) then {
            HZC_viewObj setPosASL _eyeASL;
            HZC_viewObj setVectorDirAndUp [_fwd, _up];
        };
    };
    if (HZC_method != 5 && {isNull HZC_viewObj}) exitWith { ["view object vanished"] call HZC_fnc_deactivate; };

    // mirror the player's vision mode onto the camera (T8); only meaningful when our camera is primary
    private _vm = currentVisionMode player;
    if (HZC_method <= 2 && {_vm != HZC_lastVision}) then {
        HZC_lastVision = _vm;
        camUseNVG (_vm == 1);
        if (_vm == 2) then { true setCamUseTI 0 } else { false setCamUseTI 0 };
        [format ["vision mode now %1, mirrored onto camera", _vm]] call HZC_fnc_msg;
    };

    // ---------------------------------------------------------------- diagnostics
    private _hintDue = HZC_showHint && {_now - HZC_lastHint > 0.1};
    private _logDue  = _now - HZC_lastLog > 1;
    if (_hintDue || _logDue) then {
        // self-test: rebuilding the airframe basis from its own yaw/pitch/roll must reproduce it (expect ~0)
        ([_yaw, _pitch, _roll] call HZC_fnc_basis) params ["_fI", "", "_uI"];
        private _err = (vectorMagnitude (_fI vectorDiff (vectorNormalized (vectorDirVisual _veh))))
                     + (vectorMagnitude (_uI vectorDiff (vectorNormalized (vectorUpVisual _veh))));
        // does positionCameraToWorld follow our camera? (expect ~0 m)
        private _pctwDist = (AGLToASL (positionCameraToWorld [0, 0, 0])) vectorDistance _eyeASL;
        // eyePos versus the sampled engine-camera anchor, in model space (T11)
        private _eyePosModel = _veh worldToModelVisual (ASLToAGL (eyePos player));
        private _eyeDiff = _eyePosModel vectorDistance HZC_eyeModel;
        private _fovP = getObjectFOV player;
        private _fovV = getObjectFOV _veh;
        // attitude of the camera the engine is actually rendering (M5: must equal cam pitch / roll when freelook is centred)
        (call HZC_fnc_renderedAttitude) params ["_cwYaw", "_cwPitch", "_cwRoll"];
        if (HZC_method == 5 && _logDue) then { HZC_extStatus = "hhl" callExtension "status"; };
        private _inLook = (HZC_lookActions apply { format ["%1=%2", _x, (inputAction _x) toFixed 2] }) joinString " ";
        private _inHeli = "off";
        if (HZC_showHeliInput) then {
            _inHeli = (HZC_heliActions apply { format ["%1=%2", _x, (inputAction _x) toFixed 2] }) joinString " ";
        };

        if (_hintDue) then {
            HZC_lastHint = _now;
            private _hintA = format [
                "HZC ACTIVE | hook %1 | head %2 | limit P%3 R%4 | smooth %5 | fov %6 | HUD %7\n"
                + "heli  yaw %8  pitch %9  roll %10\n"
                + "cam   pitch %11  roll %12  | basis err %13\n"
                + "rendered cam  yaw %14  pitch %15  roll %16  (head rel. airframe: pitch %23 roll %24)\n"
                + "M5 head wanted pitch %17 roll %18 (signs %19/%20, gains %25/%26) | ext %21 | %22\n",
                ["EachFrame", "Draw3D"] select HZC_loopMode, HZC_headMode, HZC_limitPitch, HZC_limitRoll,
                HZC_smoothTau, HZC_fov toFixed 2, HZC_hud,
                _yaw toFixed 1, _pitch toFixed 1, _roll toFixed 1,
                HZC_camPitch toFixed 1, HZC_camRoll toFixed 1, _err toFixed 5,
                _cwYaw toFixed 1, _cwPitch toFixed 1, _cwRoll toFixed 1,
                HZC_sentPitch toFixed 1, HZC_sentRoll toFixed 1, HZC_signPitch, HZC_signRoll,
                str HZC_extResult, HZC_extStatus,
                (_cwPitch - _pitch) toFixed 1, (_cwRoll - _roll) toFixed 1, HZC_gainPitch toFixed 2, HZC_gainRoll toFixed 2
            ];
            private _hintB = format [
                "cameraView %1 | freeLook %2 | visionMode %3\n"
                + "gCVD [%4]\neyeDir [%5]\nhead rel yaw %6 pitch %7\n"
                + "pCTW-cam %8 m | eyePos-anchor %9 m\n"
                + "getObjectFOV player %10 veh %11\n"
                + "%12\n%13",
                cameraView, freeLook, _vm,
                [_gcvd, 3] call HZC_fnc_fmtVec, [_eyeD, 3] call HZC_fnc_fmtVec,
                _hYaw toFixed 1, _hPitch toFixed 1,
                _pctwDist toFixed 3, _eyeDiff toFixed 3,
                _fovP toFixed 3, _fovV toFixed 3,
                _inLook, _inHeli
            ];
            private _hintS = format ["strength %1 | knee %2 deg | lead %3 frames | trim %6 | washout %7 s (ref P%8 R%9) | rate P%4 R%5 deg/s\n",
                HZC_strength, HZC_knee, HZC_leadFrames, _ratePitch toFixed 0, _rateRoll toFixed 0, HZC_pitchTrim toFixed 1,
                HZC_washout, HZC_slowPitch toFixed 1, HZC_slowRoll toFixed 1];
            hintSilent ((HZC_methodNames select HZC_method) + "\n" + _hintA + _hintS + _hintB);
        };
        if (_logDue) then {
            HZC_lastLog = _now;
            private _logA = format [
                "[HZC] t=%1 f=%2 hook=%3 head=%4 lim=%5/%6 heli=[%7] cam=[%8] err=%9 view=%10 free=%11 vm=%12",
                _now toFixed 2, HZC_frames, ["EachFrame", "Draw3D"] select HZC_loopMode, HZC_headMode,
                HZC_limitPitch, HZC_limitRoll,
                [[_yaw, _pitch, _roll], 1] call HZC_fnc_fmtVec,
                [[HZC_camPitch, HZC_camRoll], 1] call HZC_fnc_fmtVec,
                _err toFixed 5, cameraView, freeLook, _vm
            ];
            private _logB = format [
                " gcvd=[%1] eyeDir=[%2] rel=[%3] pctwCam=%4 eyeDiff=%5 fovP=%6 fovV=%7 look=[%8] heli=[%9]",
                [_gcvd, 3] call HZC_fnc_fmtVec, [_eyeD, 3] call HZC_fnc_fmtVec,
                [[_hYaw, _hPitch], 1] call HZC_fnc_fmtVec,
                _pctwDist toFixed 3, _eyeDiff toFixed 3, _fovP toFixed 3, _fovV toFixed 3,
                _inLook, _inHeli
            ];
            // headRel = rendered camera minus airframe, i.e. what the engine head actually did (includes the vehicle's default head angle, about -6 on the Huron)
            private _logC = format [
                " camW=[%1] headRel=[%2] sent=[%3] signs=[%4 %5] gains=[%6 %7] ext=%8 trk=[%9] str=%10 knee=%11 lead=%12 rate=[%13] wash=%14 ref=[%15] trim=%16",
                [[_cwYaw, _cwPitch, _cwRoll], 1] call HZC_fnc_fmtVec,
                [[_cwPitch - _pitch, _cwRoll - _roll], 1] call HZC_fnc_fmtVec,
                [[HZC_sentPitch, HZC_sentRoll], 1] call HZC_fnc_fmtVec,
                HZC_signPitch, HZC_signRoll, HZC_gainPitch toFixed 3, HZC_gainRoll toFixed 3, str HZC_extResult, HZC_extStatus,
                HZC_strength, HZC_knee, HZC_leadFrames, [[_ratePitch, _rateRoll], 0] call HZC_fnc_fmtVec,
                HZC_washout, [[HZC_slowPitch, HZC_slowRoll], 1] call HZC_fnc_fmtVec, HZC_pitchTrim toFixed 1
            ];
            diag_log (_logA + _logB + _logC + format [" m=%1 camOn=%2", HZC_method, typeOf cameraOn]);
        };
    };
};

// custom-action toggle (any key or joystick button bound to "Use Action 1"), polled every frame, rising edge
HZC_fnc_pollToggle = {
    if (HZC_toggleAction == "") exitWith {};
    private _v = inputAction HZC_toggleAction;
    if (_v > 0.5) then {
        if (!HZC_toggleHeld) then {
            HZC_toggleHeld = true;
            if (HZC_active) then { ["user action"] call HZC_fnc_deactivate; } else { call HZC_fnc_activate; };
        };
    } else {
        HZC_toggleHeld = false;
    };
};

// ------------------------------------------------------------------ hooks
HZC_ehFrame = addMissionEventHandler ["EachFrame", { call HZC_fnc_pollToggle; if (HZC_loopMode == 0) then { call HZC_fnc_update; }; }];
HZC_ehDraw  = addMissionEventHandler ["Draw3D",    { if (HZC_loopMode == 1) then { call HZC_fnc_update; }; }];

HZC_keyEH = (findDisplay 46) displayAddEventHandler ["KeyDown", {
    params ["", "_key", "_shift", "_ctrl", "_alt"];
    if (!(_ctrl && _shift) || _alt) exitWith { false };
    private _handled = true;
    switch (_key) do {
        case 35: {     // H
            if (HZC_active) then { ["key"] call HZC_fnc_deactivate; } else { call HZC_fnc_activate; };
        };
        case 36: {     // J
            HZC_headMode = (HZC_headMode + 1) mod 4;
            if (HZC_headMode != 3) then { player doWatch objNull; };
            [format ["head mode %1 (%2)", HZC_headMode,
                ["display only", "apply getCameraViewDirection", "apply eyeDirection", "experiment: doWatch levelled point"] select HZC_headMode]] call HZC_fnc_msg;
        };
        case 37: {     // K
            HZC_limitIdx = (HZC_limitIdx + 1) mod (count HZC_limits);
            HZC_limitPitch = HZC_limits select HZC_limitIdx;
            HZC_limitRoll = HZC_limitPitch;
            [format ["limit %1 deg on pitch and roll", HZC_limitPitch]] call HZC_fnc_msg;
        };
        case 21: {     // Y
            HZC_loopMode = (HZC_loopMode + 1) mod 2;
            [format ["hook %1", ["EachFrame", "Draw3D"] select HZC_loopMode]] call HZC_fnc_msg;
        };
        case 22: {     // U
            HZC_hud = !HZC_hud;
            if (HZC_active) then { cameraEffectEnableHUD HZC_hud; };
            [format ["cameraEffectEnableHUD %1", HZC_hud]] call HZC_fnc_msg;
        };
        case 38: {     // L
            HZC_showHint = !HZC_showHint;
            if (!HZC_showHint) then { hintSilent ""; };
        };
        case 26: {     // [
            HZC_fov = (HZC_fov * 0.9) max 0.1;
            call HZC_fnc_applyFov;
        };
        case 27: {     // ]
            HZC_fov = (HZC_fov / 0.9) min 2;
            call HZC_fnc_applyFov;
        };
        case 51: {     // ,
            HZC_limitPitch = (HZC_limitPitch - 1) max 0; HZC_limitRoll = HZC_limitPitch;
            [format ["limit %1 deg", HZC_limitPitch]] call HZC_fnc_msg;
        };
        case 52: {     // .
            HZC_limitPitch = (HZC_limitPitch + 1) min 90; HZC_limitRoll = HZC_limitPitch;
            [format ["limit %1 deg", HZC_limitPitch]] call HZC_fnc_msg;
        };
        case 50: {     // M
            if (HZC_active) then {
                ["release the camera (Ctrl+Shift+H) before changing method"] call HZC_fnc_msg;
            } else {
                HZC_method = (HZC_method + 1) mod (count HZC_methodNames);
                [format ["method %1", HZC_methodNames select HZC_method]] call HZC_fnc_msg;
            };
        };
        case 49: {     // N
            private _opts = [1, 0.75, 0.5, 0.25];
            HZC_strength = _opts select ((( _opts find HZC_strength) + 1) mod (count _opts));
            [format ["strength %1", HZC_strength]] call HZC_fnc_msg;
        };
        case 34: {     // G
            private _opts = [0, 2, 4];
            HZC_knee = _opts select (((_opts find HZC_knee) + 1) mod (count _opts));
            [format ["knee %1 deg", HZC_knee]] call HZC_fnc_msg;
        };
        case 25: {     // P
            private _opts = [1, 0, 2];
            HZC_leadFrames = _opts select (((_opts find HZC_leadFrames) + 1) mod (count _opts));
            [format ["lead %1 frames", HZC_leadFrames]] call HZC_fnc_msg;
        };
        case 20: {     // T
            if (!HZC_active) exitWith { ["activate the horizon camera first, then trim"] call HZC_fnc_msg; };
            if (HZC_pitchTrim == 0) then {
                // the engine head pitch (rel. airframe) = vehicle default + the head we are sending; keep only the default
                // and cancel it. Sample with freelook centred.
                private _sentNow = HZC_camPitch - HZC_prevPitch;
                HZC_pitchTrim = _sentNow - HZC_relPitch;
                [format ["pitch trim %1 deg (vehicle default head pitch was %2)", HZC_pitchTrim toFixed 1, (HZC_relPitch - _sentNow) toFixed 1]] call HZC_fnc_msg;
            } else {
                HZC_pitchTrim = 0;
                ["pitch trim cleared (vehicle default view angle)"] call HZC_fnc_msg;
            };
        };
        case 17: {     // W
            private _opts = [0, 1, 2, 4];
            HZC_washout = _opts select (((_opts find HZC_washout) + 1) mod (count _opts));
            HZC_slowPitch = HZC_prevPitch;
            HZC_slowRoll  = HZC_prevRoll;
            [format ["washout %1 s%2", HZC_washout, ["", " (off: level to the true horizon)"] select (HZC_washout == 0)]] call HZC_fnc_msg;
        };
        case 48: {     // B
            HZC_burstUntil = diag_tickTime + 3;
            [format ["burst log 3 s: str=%1 knee=%2 lead=%3 lim=%4", HZC_strength, HZC_knee, HZC_leadFrames, HZC_limitPitch]] call HZC_fnc_msg;
        };
        case 14: {     // Backspace
            call HZC_fnc_shutdown;
        };
        default { _handled = false; };
    };
    _handled
}];

call HZC_fnc_repairView;
[format ["harness loaded. Method: %1. Ctrl+Shift+H toggles the horizon camera; M method; J head mode; K limit; Y hook; U HUD; L readout; [ ] fov; Backspace shutdown", HZC_methodNames select HZC_method]] call HZC_fnc_msg;
hint format ["HZC harness loaded\nmethod: %1\n\nCtrl+Shift+H  toggle horizon camera (or Use Action 1)\nCtrl+Shift+M  next method (while off)\nCtrl+Shift+K  limit cycle 90/25/15/7/0\nCtrl+Shift+, .  limit -1 / +1 deg\nCtrl+Shift+N  strength\nCtrl+Shift+G  soft knee\nCtrl+Shift+P  prediction lead\nCtrl+Shift+B  burst log 3 s\nCtrl+Shift+T  pitch trim (centre view)\nCtrl+Shift+W  washout 0/1/2/4 s\nCtrl+Shift+J  head mode\nCtrl+Shift+Y  hook\nCtrl+Shift+U  HUD\nCtrl+Shift+L  readout\nCtrl+Shift+Backspace  shutdown", HZC_methodNames select HZC_method];
