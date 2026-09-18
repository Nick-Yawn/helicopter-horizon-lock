/*
 * hhl_x64.dll: Arma 3 extension for Helicopter Horizon Lock.
 *
 * SQF computes the head counter-rotation every frame and calls
 *   "hhl" callExtension ["pose", [yawMilliDeg, pitchMilliDeg, rollMilliDeg]]
 * (integers, so Arma never formats them in scientific notation). This DLL hands
 * the pose to FreeTrackClient64.dll, which the engine loaded as its head tracker.
 * "install" and "uninstall" manage the registry value that makes the engine load
 * that tracker from this DLL's own folder.
 *
 * Built without the C runtime (/NODEFAULTLIB); the only imports are three
 * kernel32 and six advapi32 functions, declared here by hand.
 */

int _fltused = 0;

__declspec(dllimport) void * __stdcall GetModuleHandleW(const unsigned short *name);
__declspec(dllimport) void * __stdcall GetProcAddress(void *module, const char *name);
__declspec(dllimport) unsigned long __stdcall GetModuleFileNameW(void *module, unsigned short *out, unsigned long size);

__declspec(dllimport) long __stdcall RegCreateKeyExW(void *key, const unsigned short *sub, unsigned long reserved, unsigned short *cls,
                                                     unsigned long options, unsigned long access, void *security, void **result,
                                                     unsigned long *disposition);
__declspec(dllimport) long __stdcall RegOpenKeyExW(void *key, const unsigned short *sub, unsigned long options, unsigned long access,
                                                   void **result);
__declspec(dllimport) long __stdcall RegQueryValueExW(void *key, const unsigned short *name, unsigned long *reserved, unsigned long *type,
                                                      unsigned char *data, unsigned long *size);
__declspec(dllimport) long __stdcall RegSetValueExW(void *key, const unsigned short *name, unsigned long reserved, unsigned long type,
                                                    const unsigned char *data, unsigned long size);
__declspec(dllimport) long __stdcall RegDeleteValueW(void *key, const unsigned short *name);
__declspec(dllimport) long __stdcall RegCloseKey(void *key);

#define HKEY_CURRENT_USER ((void *)(long long)-2147483647) /* 0x80000001, sign-extended to 64 bits */
#define KEY_QUERY_VALUE 0x0001
#define KEY_SET_VALUE   0x0002
#define REG_SZ          1

typedef void (__stdcall *SetPoseFn)(float, float, float, float, float, float);
typedef unsigned int (__stdcall *GetPollsFn)(void);

/* An absolute address in initialised data forces the linker to emit a .reloc section.
 * Without one, the DLL cannot be moved off its default base address and the Windows
 * loader refuses it inside Arma with "Insufficient system resources". */
int __stdcall DllMain(void *inst, unsigned long reason, void *reserved);
void *const volatile g_relocAnchor = (void *)&DllMain;

static void *g_module = 0; /* this DLL, for GetModuleFileNameW */
static SetPoseFn g_setPose = 0;
static GetPollsFn g_getPolls = 0;
static int g_trackerState = 0; /* 0 unresolved, 1 ok, 2 not loaded, 3 foreign DLL */

/* Path buffers are static: a frame over 4 KB would make the compiler call __chkstk,
 * which needs the C runtime. Arma calls extensions from one thread. */
#define PATH_CHARS 1024
static unsigned short g_folder[PATH_CHARS], g_path[PATH_CHARS], g_registered[PATH_CHARS];

static const unsigned short kFreetrackKey[] = L"Software\\Freetrack\\FreetrackClient";
static const unsigned short kPathValue[] = L"Path";
static const unsigned short kOwnKey[] = L"Software\\HelicopterHorizonLock";
static const unsigned short kRegisteredValue[] = L"RegisteredPath";

#define VERSION "hhl 1.0.0"

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
    if (*s == '-') { neg = 1; s++; }
    while (*s >= '0' && *s <= '9') { v = v * 10 + (*s - '0'); s++; }
    return neg ? -v : v;
}

static int wlen(const unsigned short *s) { int n = 0; while (s[n]) n++; return n; }

static int weq(const unsigned short *a, const unsigned short *b)
{
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

/* Narrow copy for the output buffer: ASCII as is, anything else as '?', so the reply stays valid UTF-8. */
static void putWide(char *out, int size, const unsigned short *s)
{
    int i = 0;
    if (size <= 0) return;
    while (s[i] && i < size - 1) { out[i] = (s[i] < 0x80) ? (char)s[i] : '?'; i++; }
    out[i] = 0;
}

static int resolve(void)
{
    static const unsigned short dllName[] = L"FreeTrackClient64.dll";
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
        putUint(out + strlen_(out), size - strlen_(out), g_getPolls());
    } else if (g_trackerState == 3) {
        put(out, size, "tracker=foreign");   /* some other FreeTrackClient64.dll is loaded */
    } else {
        put(out, size, "tracker=notloaded"); /* registry Path not set, or Arma not restarted */
    }
}

/* Reads a string value under HKCU into out; returns 0 (and an empty out) if it is absent. */
static int regRead(const unsigned short *subkey, const unsigned short *name, unsigned short *out)
{
    void *key;
    unsigned long size = (PATH_CHARS - 2) * 2;
    long rc;
    out[0] = 0;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, subkey, 0, KEY_QUERY_VALUE, &key) != 0) return 0;
    rc = RegQueryValueExW(key, name, 0, 0, (unsigned char *)out, &size);
    RegCloseKey(key);
    if (rc != 0) { out[0] = 0; return 0; }
    out[size / 2] = 0; /* the stored string need not carry its terminator */
    return 1;
}

static int regWrite(const unsigned short *subkey, const unsigned short *name, const unsigned short *value)
{
    void *key;
    long rc;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, subkey, 0, 0, 0, KEY_SET_VALUE, 0, &key, 0) != 0) return 0;
    rc = RegSetValueExW(key, name, 0, REG_SZ, (const unsigned char *)value, (unsigned long)(wlen(value) + 1) * 2);
    RegCloseKey(key);
    return rc == 0;
}

static void regDelete(const unsigned short *subkey, const unsigned short *name)
{
    void *key;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, subkey, 0, KEY_SET_VALUE, &key) != 0) return;
    RegDeleteValueW(key, name);
    RegCloseKey(key);
}

/* The folder this DLL was loaded from, without the file name or a trailing backslash. */
static int ownFolder(unsigned short *out)
{
    unsigned long n = GetModuleFileNameW(g_module, out, PATH_CHARS);
    if (n == 0 || n >= PATH_CHARS) return 0;
    while (n > 0 && out[n] != '\\') n--;
    out[n] = 0;
    return n > 0;
}

static void foreign(char *out, int size, const unsigned short *path)
{
    put(out, size, "foreign:");
    putWide(out + strlen_(out), size - strlen_(out), path);
}

/* Points the engine's FreeTrack client at our folder, unless another tracker is registered. */
static void install(char *out, int size)
{
    int hasPath = regRead(kFreetrackKey, kPathValue, g_path);
    regRead(kOwnKey, kRegisteredValue, g_registered);
    if (hasPath && !weq(g_path, g_registered)) { foreign(out, size, g_path); return; }
    if (!ownFolder(g_folder)
        || !regWrite(kFreetrackKey, kPathValue, g_folder)
        || !regWrite(kOwnKey, kRegisteredValue, g_folder)) { put(out, size, "error"); return; }
    put(out, size, "ok");
}

/* Removes the registration, but only the one we made. */
static void uninstall(char *out, int size)
{
    if (!regRead(kFreetrackKey, kPathValue, g_path)) { put(out, size, "ok"); return; }
    regRead(kOwnKey, kRegisteredValue, g_registered);
    if (!weq(g_path, g_registered)) { foreign(out, size, g_path); return; }
    regDelete(kFreetrackKey, kPathValue);
    regDelete(kOwnKey, kRegisteredValue);
    put(out, size, "ok");
}

__declspec(dllexport) void __stdcall RVExtensionVersion(char *output, int outputSize)
{
    put(output, outputSize, VERSION);
}

__declspec(dllexport) void __stdcall RVExtension(char *output, int outputSize, const char *function)
{
    if (streq(function, "version"))   { put(output, outputSize, VERSION); return; }
    if (streq(function, "status"))    { status(output, outputSize); return; }
    if (streq(function, "install"))   { install(output, outputSize); return; }
    if (streq(function, "uninstall")) { uninstall(output, outputSize); return; }
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
        int y, p, r;
        if (argc < 3) { put(output, outputSize, "badargs"); return 1; }
        y = parseInt(argv[0]); p = parseInt(argv[1]); r = parseInt(argv[2]);
        if (!resolve()) { put(output, outputSize, "notracker"); return 2; }
        g_setPose(y * k, p * k, r * k, 0.0f, 0.0f, 0.0f);
        put(output, outputSize, "ok");
        return 0;
    }
    put(output, outputSize, "unknown");
    return 3;
}

int __stdcall DllMain(void *inst, unsigned long reason, void *reserved)
{
    (void)reason; (void)reserved;
    g_module = inst;
    return 1;
}
