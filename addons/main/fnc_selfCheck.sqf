#include "script_component.hpp"
/*
 * Once per game session, in the first mission with a player: is the extension loaded
 * and is the tracker registered. Passing that arms the poll check in fnc_onFrame.
 * Each problem gets one plain hint.
 */

if (isNull player || {uiNamespace getVariable [QGVAR(checked), false]}) exitWith {};
uiNamespace setVariable [QGVAR(checked), true];

if (("hhl" callExtension "version") isEqualTo "") exitWith {
    hint "Helicopter Horizon Lock: BattlEye or a missing DLL blocked the extension. Launch Arma 3 without BattlEye.";
};

private _status = "hhl" callExtension "status";
if (_status in ["tracker=notloaded", "tracker=foreign"]) exitWith {
    if (!GVAR(autoRegister)) exitWith {};
    private _reply = "hhl" callExtension "install";
    if ((_reply select [0, 8]) isEqualTo "foreign:") then {
        hint format ["Helicopter Horizon Lock: another head-tracking client is registered at %1. Leaving it alone.", _reply select [8]];
    } else {
        hint "Helicopter Horizon Lock: head tracker registered. Restart Arma 3 once.";
    };
};

uiNamespace setVariable [QGVAR(checkPolls), true];
