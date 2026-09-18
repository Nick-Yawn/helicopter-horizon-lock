/*
 * hhl_x64.dll: Arma 3 extension for Helicopter Horizon Lock.
 *
 * SQF computes the head counter-rotation every frame and calls
 *   "hhl" callExtension ["pose", [yawMilliDeg, pitchMilliDeg, rollMilliDeg]]
 * (integers, so Arma never formats them in scientific notation). This DLL hands
 * the pose to FreeTrackClient64.dll, which the engine loaded as its head tracker.
 *
 * Built without the C runtime (/NODEFAULTLIB); the only imports are two
 * kernel32 functions, declared here by hand.
 */

int _fltused = 0;

__declspec(dllimport) void * __stdcall GetModuleHandleW(const unsigned short *name);
__declspec(dllimport) void * __stdcall GetProcAddress(void *module, const char *name);

typedef void (__stdcall *SetPoseFn)(float, float, float, float, float, float);
typedef unsigned int (__stdcall *GetPollsFn)(void);

/* An absolute address in initialised data forces the linker to emit a .reloc section.
 * Without one, the DLL cannot be moved off its default base address and the Windows
 * loader refuses it inside Arma with "Insufficient system resources". */
int __stdcall DllMain(void *inst, unsigned long reason, void *reserved);
void *const volatile g_relocAnchor = (void *)&DllMain;

static SetPoseFn g_setPose = 0;
static GetPollsFn g_getPolls = 0;
static int g_trackerState = 0; /* 0 unresolved, 1 ok, 2 not loaded, 3 foreign DLL */

#define VERSION "hhl 0.1.0"

static int streq(const char *a, const char *b)
{
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

static void put(char *out, int size, const char *s)
{
    int i = 0;
    if (size <= 0) return;
    while (s[i] && i < size - 1) { out[i] = s[i]; i++; }
    out[i] = 0;
}

static int strlen_(const char *s) { int n = 0; while (s[n]) n++; return n; }

static void putUint(char *out, int size, unsigned int v)
{
    char buf[12];
    int n = 0, i = 0;
    if (size <= 0) return;
    do { buf[n++] = (char)('0' + v % 10); v /= 10; } while (v);
    while (n > 0 && i < size - 1) out[i++] = buf[--n];
    out[i] = 0;
}

/* Parses an optionally signed integer; a fractional part is ignored. */
static int parseInt(const char *s)
{
    int neg = 0, v = 0;
    while (*s == ' ') s++;
    if (*s == '-') { neg = 1; s++; } else if (*s == '+') { s++; }
    while (*s >= '0' && *s <= '9') { v = v * 10 + (*s - '0'); s++; }
    return neg ? -v : v;
}

static int resolve(void)
{
    static const unsigned short dllName[] = {
        'F','r','e','e','T','r','a','c','k','C','l','i','e','n','t','6','4','.','d','l','l',0 };
    void *m;
    if (g_setPose) return 1;
    m = GetModuleHandleW(dllName);
    if (!m) { g_trackerState = 2; return 0; }
    g_setPose = (SetPoseFn)GetProcAddress(m, "HHL_SetPose");
    g_getPolls = (GetPollsFn)GetProcAddress(m, "HHL_GetPolls");
    if (!g_setPose) { g_trackerState = 3; return 0; }
    g_trackerState = 1;
    return 1;
}

static void status(char *out, int size)
{
    resolve();
    if (g_trackerState == 1) {
        put(out, size, "tracker=ok polls=");
        putUint(out + strlen_(out), size - strlen_(out), g_getPolls ? g_getPolls() : 0u);
    } else if (g_trackerState == 3) {
        put(out, size, "tracker=foreign");   /* some other FreeTrackClient64.dll is loaded */
    } else {
        put(out, size, "tracker=notloaded"); /* registry Path not set, or Arma not restarted */
    }
}

__declspec(dllexport) void __stdcall RVExtensionVersion(char *output, int outputSize)
{
    put(output, outputSize, VERSION);
}

__declspec(dllexport) void __stdcall RVExtension(char *output, int outputSize, const char *function)
{
    if (streq(function, "version")) { put(output, outputSize, VERSION); return; }
    if (streq(function, "status"))  { status(output, outputSize); return; }
    if (streq(function, "zero")) {
        if (resolve()) { g_setPose(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f); put(output, outputSize, "ok"); }
        else put(output, outputSize, "notracker");
        return;
    }
    put(output, outputSize, "unknown");
}

__declspec(dllexport) int __stdcall RVExtensionArgs(char *output, int outputSize,
                                                    const char *function, const char **argv, int argc)
{
    if (streq(function, "pose")) {
        const float k = 3.14159265358979f / 180000.0f; /* millidegrees to radians */
        int y, p, r, tx = 0, ty = 0, tz = 0;
        if (argc < 3) { put(output, outputSize, "badargs"); return 1; }
        y = parseInt(argv[0]); p = parseInt(argv[1]); r = parseInt(argv[2]);
        if (argc >= 6) { tx = parseInt(argv[3]); ty = parseInt(argv[4]); tz = parseInt(argv[5]); }
        if (!resolve()) { put(output, outputSize, "notracker"); return 2; }
        g_setPose(y * k, p * k, r * k, (float)tx, (float)ty, (float)tz);
        put(output, outputSize, "ok");
        return 0;
    }
    if (streq(function, "status")) { status(output, outputSize); return 0; }
    put(output, outputSize, "unknown");
    return 3;
}

int __stdcall DllMain(void *inst, unsigned long reason, void *reserved)
{
    (void)inst; (void)reason; (void)reserved;
    return 1;
}
