@echo off
rem Builds FreeTrackClient64.dll and hhl_x64.dll into the repo root (the mod root) with the
rem MSVC toolset only. No Windows SDK is needed: the sources include no headers and link no
rem C runtime; the kernel32 and advapi32 imports come from import libraries that lib.exe
rem generates from the .def files here.
setlocal
set "VCDIR=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133"
set "PATH=%VCDIR%\bin\Hostx64\x64;%PATH%"
cd /d "%~dp0"
if not exist out mkdir out
lib /nologo /def:kernel32.def /machine:x64 /out:out\kernel32.lib || exit /b 1
lib /nologo /def:advapi32.def /machine:x64 /out:out\advapi32.lib || exit /b 1
cl /nologo /c /O1 /GS- /W4 /Fo:out\freetrackclient.obj freetrackclient.c || exit /b 1
link /nologo /DLL /NODEFAULTLIB /ENTRY:DllMain /SUBSYSTEM:WINDOWS /MACHINE:X64 /IMPLIB:out\FreeTrackClient64.lib /OUT:..\FreeTrackClient64.dll out\freetrackclient.obj || exit /b 1
cl /nologo /c /O1 /GS- /W4 /Fo:out\hhl.obj hhl.c || exit /b 1
link /nologo /DLL /NODEFAULTLIB /ENTRY:DllMain /SUBSYSTEM:WINDOWS /MACHINE:X64 /IMPLIB:out\hhl_x64.lib /OUT:..\hhl_x64.dll out\hhl.obj out\kernel32.lib out\advapi32.lib || exit /b 1
dumpbin /nologo /exports ..\FreeTrackClient64.dll
dumpbin /nologo /exports ..\hhl_x64.dll
dumpbin /nologo /imports ..\hhl_x64.dll
echo BUILD_OK
