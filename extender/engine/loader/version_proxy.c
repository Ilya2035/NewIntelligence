/*
 * New Intelligence engine loader, stage E1 - a version.dll proxy for Europa Universalis V.
 *
 * The extender puts this file next to eu5.exe ("apply") and removes it ("factory").
 * eu5.exe imports VERSION.dll and Windows looks in the game folder first, so the game
 * loads this file instead of the system one. What it does:
 *   - forwards all 17 exports of the system version.dll unchanged (jump thunks);
 *   - checks that the host is the exact eu5.exe build it was built for (SHA-256);
 *   - E1 changes NOTHING in the game: it only writes Documents\NewIntelligence\engine.log;
 *   - kill switch: the file Documents\NewIntelligence\engine_off leaves forwarding only.
 * It never touches Steam, DLC ownership, saves, multiplayer or achievements.
 *
 * Build: extender\engine\build.ps1 (w64devkit gcc). NI_EXPECTED_SHA256 is baked in per build.
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <bcrypt.h>
#include <shlobj.h>
#include <stdarg.h>
#include <stdio.h>
#include <wchar.h>

#ifndef NI_EXPECTED_SHA256
#define NI_EXPECTED_SHA256 ""
#endif
#define NI_LOADER_VERSION "0.1.0"

/* ------------------------------------------------------------------ forwarding */

#define NI_EXPORTS(X) \
    X(GetFileVersionInfoA) X(GetFileVersionInfoByHandle) X(GetFileVersionInfoExA) \
    X(GetFileVersionInfoExW) X(GetFileVersionInfoSizeA) X(GetFileVersionInfoSizeExA) \
    X(GetFileVersionInfoSizeExW) X(GetFileVersionInfoSizeW) X(GetFileVersionInfoW) \
    X(VerFindFileA) X(VerFindFileW) X(VerInstallFileA) X(VerInstallFileW) \
    X(VerLanguageNameA) X(VerLanguageNameW) X(VerQueryValueA) X(VerQueryValueW)

/* If the system version.dll cannot be loaded, every export fails cleanly instead of crashing:
 * returning 0 means FALSE / size 0 for all of these functions (x64: the caller cleans the stack). */
UINT_PTR ni_fail(void) { SetLastError(ERROR_PROC_NOT_FOUND); return 0; }

#define NI_DECL_PTR(n) __attribute__((used)) void *ni_real_##n = (void *)ni_fail;
NI_EXPORTS(NI_DECL_PTR)

/* Each export is a bare jump to the real function: the signature does not matter and the
 * stack is untouched, so no unwind data is needed. */
#define NI_DEF_STUB(n) \
    __asm__(".text\n.globl ni_proxy_" #n "\nni_proxy_" #n ":\n\tjmp *ni_real_" #n "(%rip)\n");
NI_EXPORTS(NI_DEF_STUB)

static HMODULE g_real;
static int g_resolved;

static void ni_resolve(void)
{
    wchar_t path[MAX_PATH];
    UINT n = GetSystemDirectoryW(path, MAX_PATH);
    if (n == 0 || n > MAX_PATH - 16) return;
    wcscat(path, L"\\version.dll");
    g_real = LoadLibraryW(path);
    if (!g_real) return;
#define NI_RESOLVE(nm) { FARPROC p = GetProcAddress(g_real, #nm); if (p) { ni_real_##nm = (void *)p; g_resolved++; } }
    NI_EXPORTS(NI_RESOLVE)
}

/* ------------------------------------------------------------------ log */

static wchar_t g_home[MAX_PATH];
static HANDLE g_log = INVALID_HANDLE_VALUE;

static void ni_log(const wchar_t *fmt, ...)
{
    if (g_log == INVALID_HANDLE_VALUE) return;
    wchar_t line[1024];
    SYSTEMTIME t;
    GetLocalTime(&t);
    int k = _snwprintf(line, 64, L"%04u-%02u-%02u %02u:%02u:%02u ", t.wYear, t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);
    if (k < 0) k = 0;
    va_list ap;
    va_start(ap, fmt);
    _vsnwprintf(line + k, 1020 - k, fmt, ap);
    va_end(ap);
    line[1020] = 0;
    wcscat(line, L"\r\n");
    char utf8[3200];
    int bytes = WideCharToMultiByte(CP_UTF8, 0, line, -1, utf8, sizeof utf8, NULL, NULL);
    if (bytes > 1) { DWORD w; WriteFile(g_log, utf8, (DWORD)(bytes - 1), &w, NULL); }
}

static int ni_home_dir(void)
{
    DWORD n = GetEnvironmentVariableW(L"NI_ENGINE_HOME", g_home, MAX_PATH);   /* tests only */
    if (n == 0 || n >= MAX_PATH) {
        if (FAILED(SHGetFolderPathW(NULL, CSIDL_PERSONAL, NULL, 0, g_home))) return 0;
        if (wcslen(g_home) > MAX_PATH - 32) return 0;
        wcscat(g_home, L"\\NewIntelligence");
    }
    CreateDirectoryW(g_home, NULL);
    return 1;
}

/* ------------------------------------------------------------------ build check */

static int ni_sha256_file(const wchar_t *path, char out[65])
{
    int ok = 0;
    BCRYPT_ALG_HANDLE alg = NULL;
    BCRYPT_HASH_HANDLE hash = NULL;
    HANDLE f = CreateFileW(path, GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                           NULL, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, NULL);
    if (f == INVALID_HANDLE_VALUE) return 0;
    static unsigned char buf[1 << 20];
    unsigned char digest[32];
    if (BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, NULL, 0) != 0) goto done;
    if (BCryptCreateHash(alg, &hash, NULL, 0, NULL, 0, 0) != 0) goto done;
    for (;;) {
        DWORD got = 0;
        if (!ReadFile(f, buf, sizeof buf, &got, NULL)) goto done;
        if (got == 0) break;
        if (BCryptHashData(hash, buf, got, 0) != 0) goto done;
    }
    if (BCryptFinishHash(hash, digest, sizeof digest, 0) != 0) goto done;
    for (int i = 0; i < 32; i++) sprintf(out + 2 * i, "%02X", digest[i]);
    out[64] = 0;
    ok = 1;
done:
    if (hash) BCryptDestroyHash(hash);
    if (alg) BCryptCloseAlgorithmProvider(alg, 0);
    CloseHandle(f);
    return ok;
}

static DWORD WINAPI ni_worker(LPVOID self)
{
    if (ni_home_dir()) {
        wchar_t p[MAX_PATH + 32];
        _snwprintf(p, MAX_PATH + 31, L"%ls\\engine.log", g_home);
        p[MAX_PATH + 31] = 0;
        g_log = CreateFileW(p, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL, OPEN_ALWAYS,
                            FILE_ATTRIBUTE_NORMAL, NULL);
    }
    wchar_t exe[MAX_PATH];
    GetModuleFileNameW(NULL, exe, MAX_PATH);
    ni_log(L"loader %hs started in %ls (pid %lu)", NI_LOADER_VERSION, exe, GetCurrentProcessId());
    ni_log(L"forwarding: system version.dll %ls, %d of 17 functions", g_real ? L"loaded" : L"NOT loaded", g_resolved);

    wchar_t off[MAX_PATH + 32];
    _snwprintf(off, MAX_PATH + 31, L"%ls\\engine_off", g_home);
    off[MAX_PATH + 31] = 0;
    if (GetFileAttributesW(off) != INVALID_FILE_ATTRIBUTES) {
        ni_log(L"engine_off found: forwarding only, nothing else runs");
    } else {
        char sha[65] = "";
        if (!ni_sha256_file(exe, sha)) {
            ni_log(L"could not hash the host exe: inactive");
        } else if (lstrcmpiA(sha, NI_EXPECTED_SHA256) == 0) {
            ni_log(L"build matches (%hs): active - E1 only writes this log", sha);
        } else {
            ni_log(L"other build (%hs, expected %hs): inactive, forwarding only", sha, NI_EXPECTED_SHA256);
        }
    }
    if (g_log != INVALID_HANDLE_VALUE) { CloseHandle(g_log); g_log = INVALID_HANDLE_VALUE; }
    FreeLibraryAndExitThread((HMODULE)self, 0);
    return 0;
}

/* ------------------------------------------------------------------ entry */

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    if (reason == DLL_PROCESS_ATTACH) {
        DisableThreadLibraryCalls(inst);
        ni_resolve();
        /* the worker holds its own reference to this module, so it can never outlive it */
        HMODULE self = NULL;
        if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS, (LPCWSTR)(void *)ni_worker, &self)) {
            HANDLE t = CreateThread(NULL, 0, ni_worker, self, 0, NULL);
            if (t) CloseHandle(t); else FreeLibrary(self);
        }
    } else if (reason == DLL_PROCESS_DETACH && reserved == NULL && g_real) {
        FreeLibrary(g_real);
    }
    return TRUE;
}
