/*
 * FreeTrackClient64.dll for Helicopter Horizon Lock (Arma 3).
 *
 * Arma 3 has a built-in FreeTrack head-tracking client: at start-up it reads
 * HKCU\Software\Freetrack\FreetrackClient\Path, loads FreeTrackClient64.dll from
 * that folder and polls FTGetData every frame for the head pose. This file is
 * that DLL. It does no tracking of its own; the pose is pushed in by hhl_x64.dll
 * (the callExtension side) through HHL_SetPose.
 *
 * Built without the C runtime (/NODEFAULTLIB), so no headers and no libc.
 */

int _fltused = 0; /* MSVC wants this symbol whenever floats are used */

typedef struct FTData {
    unsigned int DataID;   /* must change between polls or the game treats data as stale */
    int CamWidth;
    int CamHeight;
    float Yaw, Pitch, Roll;          /* radians */
    float X, Y, Z;                   /* millimetres */
    float RawYaw, RawPitch, RawRoll; /* unfiltered copies */
    float RawX, RawY, RawZ;
    float X1, Y1, X2, Y2, X3, Y3, X4, Y4; /* point-tracker blobs, unused */
} FTData;

/* An absolute address in initialised data forces the linker to emit a .reloc section.
 * Without one, the DLL cannot be moved off its default base address and the Windows
 * loader refuses it inside Arma with "Insufficient system resources". */
int __stdcall DllMain(void *inst, unsigned long reason, void *reserved);
void *const volatile g_relocAnchor = (void *)&DllMain;

static volatile float g_yaw = 0.0f, g_pitch = 0.0f, g_roll = 0.0f;
static volatile float g_x = 0.0f, g_y = 0.0f, g_z = 0.0f;
static unsigned int g_dataId = 0;
static volatile unsigned int g_polls = 0;

#define EXPORT __declspec(dllexport)

EXPORT int __stdcall FTGetData(FTData *d)
{
    if (!d) return 0;
    d->DataID = ++g_dataId;
    d->CamWidth = 320;
    d->CamHeight = 240;
    d->Yaw = g_yaw;    d->Pitch = g_pitch;    d->Roll = g_roll;
    d->X = g_x;        d->Y = g_y;            d->Z = g_z;
    d->RawYaw = g_yaw; d->RawPitch = g_pitch; d->RawRoll = g_roll;
    d->RawX = g_x;     d->RawY = g_y;         d->RawZ = g_z;
    d->X1 = 0.0f; d->Y1 = 0.0f; d->X2 = 0.0f; d->Y2 = 0.0f;
    d->X3 = 0.0f; d->Y3 = 0.0f; d->X4 = 0.0f; d->Y4 = 0.0f;
    g_polls++;
    return 1;
}

EXPORT const char * __stdcall FTGetDllVersion(void) { return "1.0.0.0"; }
EXPORT void __stdcall FTReportName(int name) { (void)name; }
EXPORT const char * __stdcall FTProvider(void) { return "hhl"; }

/* Called by hhl_x64.dll. Rotations in radians, translations in millimetres. */
EXPORT void __stdcall HHL_SetPose(float yaw, float pitch, float roll, float x, float y, float z)
{
    g_yaw = yaw; g_pitch = pitch; g_roll = roll;
    g_x = x; g_y = y; g_z = z;
}

/* How many times the engine has polled us: proves the engine loaded this DLL. */
EXPORT unsigned int __stdcall HHL_GetPolls(void) { return g_polls; }

int __stdcall DllMain(void *inst, unsigned long reason, void *reserved)
{
    (void)inst; (void)reason; (void)reserved;
    return 1;
}
