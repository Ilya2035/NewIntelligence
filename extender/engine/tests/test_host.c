/* Test host for the version.dll proxy: imports VERSION.dll like eu5.exe does, so when it sits
 * next to our version.dll Windows loads ours. Checks that forwarding gives the same answer as
 * the system DLL and reports which file was loaded. Exit code 0 = forwarding works. */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(void)
{
    const wchar_t *file = L"C:\\Windows\\System32\\kernel32.dll";
    DWORD handle = 0, size = GetFileVersionInfoSizeW(file, &handle);
    if (!size) { printf("FAIL GetFileVersionInfoSizeW %lu\n", GetLastError()); return 1; }
    void *buf = malloc(size);
    if (!GetFileVersionInfoW(file, 0, size, buf)) { printf("FAIL GetFileVersionInfoW %lu\n", GetLastError()); return 1; }
    VS_FIXEDFILEINFO *fi = NULL;
    UINT len = 0;
    if (!VerQueryValueW(buf, L"\\", (void **)&fi, &len) || !fi) { printf("FAIL VerQueryValueW\n"); return 1; }
    printf("kernel32 %u.%u.%u.%u\n", HIWORD(fi->dwFileVersionMS), LOWORD(fi->dwFileVersionMS),
           HIWORD(fi->dwFileVersionLS), LOWORD(fi->dwFileVersionLS));

    HMODULE m = NULL;
    wchar_t path[MAX_PATH] = L"?";
    if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                           (LPCWSTR)(void *)GetFileVersionInfoSizeW, &m))
        GetModuleFileNameW(m, path, MAX_PATH);
    printf("GetFileVersionInfoSizeW served by %ls\n", path);
    Sleep(3000);   /* let the loader's worker thread finish hashing and logging */
    free(buf);
    return 0;
}
