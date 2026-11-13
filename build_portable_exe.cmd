@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
rem ============================================================
rem  build_portable_exe.cmd -- 构建 XZ 便携版.exe
rem  把精简工具(xzport.cmd)+内嵌7z(7z.exe/7z.dll/7z.sfx)打包进
rem  单个自解压 exe, 任意电脑双击即用, 无需安装任何软件
rem ============================================================

set "SD=%~dp0"
set "PORTDIR=%SD%portable"
set "OUTEXE=%SD%XZ便携版.exe"

rem ---- 可选图标 (%1 或环境变量 XZ_ICON; 0/空=无图标) ----
set "ICON=%~1"
if not defined ICON if defined XZ_ICON set "ICON=%XZ_ICON%"
set "WINICO="
if defined ICON (
  if not exist "%ICON%" (
    echo  [错误] 图标文件不存在: %ICON%
    pause
    exit /b 1
  )
  set "ICEXT=!ICON:~-4!"
  if /i "!ICEXT!"==".ico" (
    set "WINICO=/win32icon:%ICON%"
  ) else (
    set "ICOTMP=%TEMP%\xz_ico_!RANDOM!.ico"
    powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\imgtool.ps1" "%ICON%" "%ICOTMP%" ico >nul 2>&1
    if exist "%ICOTMP%" set "WINICO=/win32icon:%ICOTMP%"
    if not defined WINICO echo  [提示] 图标转换失败, 使用无图标版本。
  )
)

rem ---- 检测 7-Zip ----
set "SZDIR="
for /f "tokens=2,* delims= " %%a in ('reg query "HKLM\SOFTWARE\7-Zip" /v Path 2^>nul') do if exist "%%b7z.exe" set "SZDIR=%%b"
if not defined SZDIR if exist "%ProgramFiles%\7-Zip\7z.exe" set "SZDIR=%ProgramFiles%\7-Zip\"
if not defined SZDIR if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" set "SZDIR=%ProgramFiles(x86)%\7-Zip\"
if not defined SZDIR (
  echo  [错误] 未找到 7-Zip, 便携版需要 7z.exe/7z.dll/7z.sfx。
  echo  [提示] 请先安装 7-Zip, 或把 7z.exe 等文件放到便携目录。
  pause
  exit /b 1
)
if not exist "%SZDIR%7z.dll" (
  echo  [错误] 未找到 %SZDIR%7z.dll
  pause
  exit /b 1
)
if not exist "%SZDIR%7z.sfx" (
  echo  [错误] 未找到 %SZDIR%7z.sfx
  pause
  exit /b 1
)

rem ---- 检测 csc ----
set "CSC="
if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC (
  echo  [错误] 未找到 .NET Framework 编译器 csc.exe
  pause
  exit /b 1
)

if not exist "%PORTDIR%\xzport.cmd" (
  echo  [错误] 缺少精简工具: %PORTDIR%\xzport.cmd
  pause
  exit /b 1
)

rem ---- 提取内嵌 C# 启动器源码 ----
set "B64=%TEMP%\xz_pe_!RANDOM!.b64"
set "CSSRC=%TEMP%\xz_launcher_!RANDOM!.cs"
for /f "tokens=1,* delims=:" %%a in ('findstr /b "CSCB64:" "%~f0"') do >>"!B64!" echo %%b
certutil -decode "!B64!" "!CSSRC!" >nul 2>&1
if not exist "!CSSRC!" (
  echo  [错误] 启动器源码解码失败。
  pause
  exit /b 1
)

echo  [构建] 正在编译便携版 exe ...
"!CSC!" /nologo /optimize+ /codepage:65001 /target:exe "/out:!OUTEXE!" !WINICO! "/resource:!PORTDIR!\xzport.cmd,xzport.cmd" "/resource:!SZDIR!7z.exe,7z.exe" "/resource:!SZDIR!7z.dll,7z.dll" "/resource:!SZDIR!7z.sfx,7z.sfx" "!CSSRC!"
set "EC=!errorlevel!"
del "!B64!" >nul 2>&1
del "!CSSRC!" >nul 2>&1
if not "!EC!"=="0" (
  echo  [错误] 编译失败, csc 退出码 !EC!。
  pause
  exit /b 1
)
for %%F in ("!OUTEXE!") do echo  [通过] 便携版生成成功: !OUTEXE!  （%%~zF 字节）
pause
exit /b 0

rem ============================================================
rem  内嵌 C# 启动器源码 (base64), 运行时 certutil 解码
rem ============================================================
CSCB64:dXNpbmcgU3lzdGVtOwp1c2luZyBTeXN0ZW0uRGlhZ25vc3RpY3M7CnVzaW5nIFN5c3RlbS5JTzsK
CSCB64:dXNpbmcgU3lzdGVtLlJlZmxlY3Rpb247CgpjbGFzcyBQb3J0YWJsZUxhdW5jaGVyCnsKICAgIHN0
CSCB64:YXRpYyB2b2lkIE1haW4oc3RyaW5nW10gYXJncykKICAgIHsKICAgICAgICB0cnkgeyBDb25zb2xl
CSCB64:Lk91dHB1dEVuY29kaW5nID0gU3lzdGVtLlRleHQuRW5jb2RpbmcuVVRGODsgfSBjYXRjaCB7IH0K
CSCB64:ICAgICAgICBzdHJpbmcgZGlyID0gUGF0aC5Db21iaW5lKFBhdGguR2V0VGVtcFBhdGgoKSwgInh6
CSCB64:cG9ydF8iICsgR3VpZC5OZXdHdWlkKCkuVG9TdHJpbmcoIk4iKSk7CiAgICAgICAgRGlyZWN0b3J5
CSCB64:LkNyZWF0ZURpcmVjdG9yeShkaXIpOwogICAgICAgIHRyeQogICAgICAgIHsKICAgICAgICAgICAg
CSCB64:QXNzZW1ibHkgYXNtID0gQXNzZW1ibHkuR2V0RXhlY3V0aW5nQXNzZW1ibHkoKTsKICAgICAgICAg
CSCB64:ICAgc3RyaW5nW10gbmFtZXMgPSBhc20uR2V0TWFuaWZlc3RSZXNvdXJjZU5hbWVzKCk7CiAgICAg
CSCB64:ICAgICAgIGlmIChuYW1lcy5MZW5ndGggPT0gMCkKICAgICAgICAgICAgewogICAgICAgICAgICAg
CSCB64:ICAgQ29uc29sZS5Xcml0ZUxpbmUoIlvplJnor69dIOS+v+aQuuWMheWGheacquaJvuWIsOS7u+S9
CSCB64:leaWh+S7tiwg6K+36YeN5paw55Sf5oiQ44CCIik7CiAgICAgICAgICAgICAgICBDb25zb2xlLlJl
CSCB64:YWRLZXkoKTsKICAgICAgICAgICAgICAgIHJldHVybjsKICAgICAgICAgICAgfQogICAgICAgICAg
CSCB64:ICBmb3JlYWNoIChzdHJpbmcgbiBpbiBuYW1lcykKICAgICAgICAgICAgewogICAgICAgICAgICAg
CSCB64:ICAgc3RyaW5nIGZuYW1lID0gUGF0aC5HZXRGaWxlTmFtZShuKTsKICAgICAgICAgICAgICAgIHVz
CSCB64:aW5nIChTdHJlYW0gcnMgPSBhc20uR2V0TWFuaWZlc3RSZXNvdXJjZVN0cmVhbShuKSkKICAgICAg
CSCB64:ICAgICAgICAgIHVzaW5nIChGaWxlU3RyZWFtIGZzID0gRmlsZS5DcmVhdGUoUGF0aC5Db21iaW5l
CSCB64:KGRpciwgZm5hbWUpKSkKICAgICAgICAgICAgICAgICAgICBycy5Db3B5VG8oZnMpOwogICAgICAg
CSCB64:ICAgICB9CiAgICAgICAgICAgIFByb2Nlc3NTdGFydEluZm8gcHNpID0gbmV3IFByb2Nlc3NTdGFy
CSCB64:dEluZm8oImNtZCIsICIvayB0aXRsZSBYWuS+v+aQuuWOi+e8qeW3peWFtyAmIGNkIC9kIFwiIiAr
CSCB64:IGRpciArICJcIiAmIHh6cG9ydC5jbWQiKTsKICAgICAgICAgICAgcHNpLlVzZVNoZWxsRXhlY3V0
CSCB64:ZSA9IGZhbHNlOwogICAgICAgICAgICBQcm9jZXNzIHAgPSBQcm9jZXNzLlN0YXJ0KHBzaSk7CiAg
CSCB64:ICAgICAgICAgIHAuV2FpdEZvckV4aXQoKTsKICAgICAgICB9CiAgICAgICAgY2F0Y2ggKEV4Y2Vw
CSCB64:dGlvbiBleCkKICAgICAgICB7CiAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCJb6ZSZ6K+v
CSCB64:XSAiICsgZXguTWVzc2FnZSk7CiAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCLmjInku7vm
CSCB64:hI/plK7pgIDlh7ouLi4iKTsKICAgICAgICAgICAgQ29uc29sZS5SZWFkS2V5KCk7CiAgICAgICAg
CSCB64:fQogICAgICAgIGZpbmFsbHkKICAgICAgICB7CiAgICAgICAgICAgIHRyeSB7IERpcmVjdG9yeS5E
CSCB64:ZWxldGUoZGlyLCB0cnVlKTsgfSBjYXRjaCB7IH0KICAgICAgICB9CiAgICB9Cn0K
