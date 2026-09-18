@echo off
rem Builds bin\FreeTrackClient64.dll and bin\hhl_x64.dll with the MSVC toolset only.
rem No Windows SDK is needed: the sources include no headers and link no C runtime;
rem the two kernel32 imports come from an import library generated from kernel32.def.
setlocal
set "VCDIR=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Tools\MSVC\14.29.30133"
set "PATH=%VCDIR%\bin\Hostx64\x64;%PATH%"
cd /d "%~dp0"
if not exist out mkdir out
if not exist ..\bin mkdir ..\bin
lib /nologo /def:kernel32.def /machine:x64 /out:out\kernel32.lib || exit /b 1
cl /nologo /c /O1 /GS- /W4 /Fo:out\freetrackclient.obj freetrackclient.c || exit /b 1
link /nologo /DLL /NODEFAULTLIB /ENTRY:DllMain /SUBSYSTEM:WINDOWS /MACHINE:X64 /OUT:..\bin\FreeTrackClient64.dll out\freetrackclient.obj || exit /b 1
cl /nologo /c /O1 /GS- /W4 /Fo:out\hhl.obj hhl.c || exit /b 1
link /nologo /DLL /NODEFAULTLIB /ENTRY:DllMain /SUBSYSTEM:WINDOWS /MACHINE:X64 /OUT:..\bin\hhl_x64.dll out\hhl.obj out\kernel32.lib || exit /b 1
dumpbin /nologo /exports ..\bin\FreeTrackClient64.dll
dumpbin /nologo /exports ..\bin\hhl_x64.dll
dumpbin /nologo /imports ..\bin\hhl_x64.dll
echo BUILD_OK
