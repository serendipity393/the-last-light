#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <windows.h>
#include <wchar.h>
#include <stdio.h>

/* Native portable launcher: no Python, .NET, Godot install or shell required. */
int WINAPI wWinMain(HINSTANCE inst, HINSTANCE previous, LPWSTR args, int show) {
    wchar_t base[32768], runtime[32768], cache[32768], exe[32768], command[32768];
    if (!GetModuleFileNameW(NULL, base, 32768)) return 1;
    wchar_t *slash = wcsrchr(base, L'\\');
    if (!slash) return 2;
    *slash = 0;
    _snwprintf(runtime,32768,L"%ls\\运行数据",base);
    _snwprintf(cache,32768,L"%ls\\缓存",runtime);
    CreateDirectoryW(runtime,NULL);
    CreateDirectoryW(cache,NULL);
    SetEnvironmentVariableW(L"APPDATA",runtime);
    SetEnvironmentVariableW(L"LOCALAPPDATA",runtime);
    SetEnvironmentVariableW(L"TEMP",cache);
    SetEnvironmentVariableW(L"TMP",cache);
    SetEnvironmentVariableW(L"__GL_SHADER_DISK_CACHE_PATH",cache);
    SetEnvironmentVariableW(L"LAST_LIGHT_ROOT",base);
    _snwprintf(exe,32768,L"%ls\\data\\LastLight.exe",base);
    _snwprintf(command,32768,L"\"%ls\" %ls",exe,args);
    STARTUPINFOW si = {0};
    PROCESS_INFORMATION pi = {0};
    si.cb = sizeof(si);
    if (!CreateProcessW(exe,command,NULL,NULL,FALSE,CREATE_UNICODE_ENVIRONMENT,NULL,base,&si,&pi)) {
        MessageBoxW(NULL,L"无法启动游戏。请先完整解压压缩包，并保留 data 文件夹。",L"最后一盏灯",MB_OK|MB_ICONERROR);
        return 3;
    }
    WaitForSingleObject(pi.hProcess,INFINITE);
    DWORD result=0;
    GetExitCodeProcess(pi.hProcess,&result);
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return (int)result;
}
