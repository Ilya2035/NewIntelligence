/* Test host for the version.dll proxy: imports VERSION.dll like eu5.exe does, so when it sits
 * next to our version.dll Windows loads ours. It asks for the version of kernel32.dll twice -
 * through the import (our proxy) and straight from the system version.dll - and compares.
 * (Unmanifested programs get a "version lie" from Windows, 6.2 instead of 10.0, so the only
 * fair reference is the system DLL called from this same process.) Exit 0 = forwarding works. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

typedef DWORD (WINAPI *size_fn)(LPCWSTR, LPDWORD);
typedef BOOL (WINAPI *info_fn)(LPCWSTR, DWORD, DWORD, LPVOID);
typedef BOOL (WINAPI *query_fn)(LPCVOID, LPCWSTR, LPVOID *, PUINT);

extern void *__imp_GetFileVersionInfoSizeW;   /* the import slot: points into whichever DLL was loaded */

static int version_of(const wchar_t *file, size_fn sz, info_fn info, query_fn query, char out[64])
{
    DWORD handle = 0, size = sz(file, &handle);
    if (!size) return 0;
    void *buf = malloc(size);
    VS_FIXEDFILEINFO *fi = NULL;
    UINT len = 0;
    int ok = info(file, 0, size, buf) && query(buf, L"\\", (void **)&fi, &len) && fi;
    if (ok)
        snprintf(out, 64, "%u.%u.%u.%u", HIWORD(fi->dwFileVersionMS), LOWORD(fi->dwFileVersionMS),
                 HIWORD(fi->dwFileVersionLS), LOWORD(fi->dwFileVersionLS));
    free(buf);
    return ok;
}

int main(void)
{
    const wchar_t *file = L"C:\\Windows\\System32\\kernel32.dll";
    char viaImport[64] = "", viaSystem[64] = "";

    if (!version_of(file, GetFileVersionInfoSizeW, GetFileVersionInfoW, VerQueryValueW, viaImport)) {
        printf("FAIL through the import (error %lu)\n", GetLastError());
        return 1;
    }
    wchar_t sysPath[MAX_PATH];
    GetSystemDirectoryW(sysPath, MAX_PATH);
    wcscat(sysPath, L"\\version.dll");
    HMODULE sys = LoadLibraryW(sysPath);
    if (!sys || !version_of(file, (size_fn)(void *)GetProcAddress(sys, "GetFileVersionInfoSizeW"),
                            (info_fn)(void *)GetProcAddress(sys, "GetFileVersionInfoW"),
                            (query_fn)(void *)GetProcAddress(sys, "VerQueryValueW"), viaSystem)) {
        printf("FAIL through the system version.dll\n");
        return 1;
    }
    printf("kernel32 through the import: %s; through the system DLL: %s; %s\n", viaImport, viaSystem,
           strcmp(viaImport, viaSystem) == 0 ? "versions match" : "VERSIONS DIFFER");

    HMODULE m = NULL;
    wchar_t path[MAX_PATH] = L"?";
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCWSTR)__imp_GetFileVersionInfoSizeW, &m))
        GetModuleFileNameW(m, path, MAX_PATH);
    printf("GetFileVersionInfoSizeW served by %ls\n", path);
    Sleep(3000);   /* let the loader's worker thread finish hashing and logging */
    return strcmp(viaImport, viaSystem) == 0 ? 0 : 1;
}
