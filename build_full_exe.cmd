@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
rem ============================================================
rem  build_full_exe.cmd -- 构建 Windows 完整版压缩程序
rem  输出: %SD%XZ完整版.exe (免安装 7-Zip, 含全部功能)
rem ============================================================

set "SD=%~dp0"
set "SELF=%~f0"
set "BRAND=XZ完整版压缩工具"
set "BVER=正式版 1.0"
set "BICON=%SD%tools\xz.ico"
set "OUTEXE="
rem 兼容旧位置参数 %1=图标（不以 / 开头则视为图标路径）
if not "%~1"=="" (
  set "FIRSTARG=%~1"
  if not "!FIRSTARG:~0,1!"=="/" set "BICON=%~1"
)
:PARSE_EXE
if "%~1"=="" goto :PARSE_EXE_END
set "A=%~1"
if /i "%A:~0,6%"=="/name:" set "BRAND=%A:~6%"
if /i "%A:~0,9%"=="/version:" set "BVER=%A:~9%"
if /i "%A:~0,6%"=="/icon:" set "BICON=%A:~6%"
if /i "%A:~0,5%"=="/out:" set "OUTEXE=%A:~5%"
shift
goto :PARSE_EXE
:PARSE_EXE_END
if not defined OUTEXE set "OUTEXE=%SD%!BRAND!.exe"

rem ---- 定位 7-Zip ----
set "SZDIR="
for /f "tokens=2,* delims= " %%a in ('reg query "HKLM\SOFTWARE\7-Zip" /v Path 2^>nul') do if exist "%%b7z.exe" set "SZDIR=%%b"
if not defined SZDIR if exist "%ProgramFiles%\7-Zip\7z.exe" set "SZDIR=%ProgramFiles%\7-Zip\"
if not defined SZDIR if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" set "SZDIR=%ProgramFiles(x86)%\7-Zip\"
if not defined SZDIR (
  echo  [错误] 未找到 7-Zip, 完整版需要 7z.exe/7z.dll/7z.sfx。
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

rem ---- 定位 csc ----
set "CSC="
if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC (
  echo  [错误] 未找到 .NET Framework 编译器 csc.exe
  pause
  exit /b 1
)

rem ---- 检查必需文件 ----
for %%F in ("%SD%xz-compressor.cmd" "%SD%build_apk.cmd" "%SD%build_full_apk.cmd" "%SD%build_portable_exe.cmd" "%SD%portable\xzport.cmd" "%SD%android\AndroidManifest.xml" "%SD%android_full\AndroidManifest.xml" "%SD%tools\XZGui.exe") do (
  if not exist "%%~F" (
    echo  [错误] 缺少必需文件: %%~F
    pause
    exit /b 1
  )
)

rem ---- 打包 android 模板目录为 zip ----
set "AZIP=%TEMP%\xz_full_android_!RANDOM!.zip"
set "FZIP=%TEMP%\xz_full_androidfull_!RANDOM!.zip"
echo  [构建] 打包安卓模板 ...
"%SZDIR%7z.exe" a -tzip -y "%AZIP%" "%SD%android\*" >nul 2>&1
if errorlevel 1 goto :FAIL
"%SZDIR%7z.exe" a -tzip -y "%FZIP%" "%SD%android_full\*" >nul 2>&1
if errorlevel 1 goto :FAIL

rem ---- 提取内嵌 C# 启动器源码 ----
set "B64=%TEMP%\xz_fe_!RANDOM!.b64"
set "CSSRC=%TEMP%\xz_felauncher_!RANDOM!.cs"
for /f "tokens=1,* delims=:" %%a in ('findstr /b "CSCB64:" "!SELF!"') do >>"!B64!" echo %%b
certutil -decode "!B64!" "!CSSRC!" >nul 2>&1
if not exist "!CSSRC!" (
  echo  [错误] 启动器源码解码失败。
  pause
  exit /b 1
)
rem 品牌标题替换
powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\brand_title.ps1" "!CSSRC!" "!BRAND!" "!BVER!"
rem 图标处理（图片转 ico）
set "WINICON="
if defined BICON (
  if not exist "!BICON!" (
    echo  [错误] 图标文件不存在: !BICON!
    set "BICON="
  ) else (
    if /i not "!BICON:~-4!"==".ico" (
      echo  [图标] 正在把图片转换为 .ico ...
      set "BICONICO=%TEMP%\xzfe_!RANDOM!.ico"
      powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\imgtool.ps1" "!BICON!" "!BICONICO!" ico
      if exist "!BICONICO!" (set "BICON=!BICONICO!") else (set "BICON=")
    )
    if defined BICON set "WINICON=/win32icon:"!BICON!""
  )
)

echo  [构建] 编译完整版 exe (含引擎与模板)...
"!CSC!" /nologo /optimize+ /codepage:65001 /target:exe !WINICON! "/out:!OUTEXE!" "/resource:%SD%xz-compressor.cmd,xz-compressor.cmd" "/resource:!SZDIR!7z.exe,7z.exe" "/resource:!SZDIR!7z.dll,7z.dll" "/resource:!SZDIR!7z.sfx,7z.sfx" "/resource:%SD%build_apk.cmd,build_apk.cmd" "/resource:%SD%build_full_apk.cmd,build_full_apk.cmd" "/resource:%SD%build_portable_exe.cmd,build_portable_exe.cmd" "/resource:%SD%build_full_exe.cmd,build_full_exe.cmd" "/resource:%SD%portable\xzport.cmd,xzport.cmd" "/resource:!AZIP!,android.zip" "/resource:!FZIP!,android_full.zip" "/resource:%SD%tools\XZGui.exe,XZGui.exe" /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll "!CSSRC!"
set "EC=!errorlevel!"
del "!B64!" >nul 2>&1
del "!CSSRC!" >nul 2>&1
del "!AZIP!" >nul 2>&1
del "!FZIP!" >nul 2>&1
if not "!EC!"=="0" (
  echo  [错误] 编译失败, csc 退出码 !EC!。
  pause
  exit /b 1
)
for %%F in ("!OUTEXE!") do echo  [通过] 完整版生成成功: !OUTEXE!  （%%~zF 字节）
pause
exit /b 0

:FAIL
echo  [错误] 打包失败, 请检查目录完整。
pause
exit /b 1

rem ============================================================
rem  内嵌 C# 启动器源码 (base64), 构建时 certutil 解码
rem ============================================================
CSCB64:dXNpbmcgU3lzdGVtOwoKdXNpbmcgU3lzdGVtLkRpYWdub3N0aWNzOwoKdXNpbmcgU3lzdGVtLklP
CSCB64:OwoKdXNpbmcgU3lzdGVtLklPLkNvbXByZXNzaW9uOwoKdXNpbmcgU3lzdGVtLlJlZmxlY3Rpb247
CSCB64:CgoKCmNsYXNzIEZ1bGxMYXVuY2hlcgoKewoKICAgIHN0YXRpYyB2b2lkIE1haW4oc3RyaW5nW10g
CSCB64:YXJncykKCiAgICB7CgogICAgICAgIHRyeSB7IENvbnNvbGUuT3V0cHV0RW5jb2RpbmcgPSBTeXN0
CSCB64:ZW0uVGV4dC5FbmNvZGluZy5VVEY4OyB9IGNhdGNoIHsgfQoKICAgICAgICBzdHJpbmcgZGlyID0g
CSCB64:UGF0aC5Db21iaW5lKFBhdGguR2V0VGVtcFBhdGgoKSwgInh6ZnVsbF8iICsgR3VpZC5OZXdHdWlk
CSCB64:KCkuVG9TdHJpbmcoIk4iKSk7CgogICAgICAgIERpcmVjdG9yeS5DcmVhdGVEaXJlY3RvcnkoZGly
CSCB64:KTsKCiAgICAgICAgdHJ5CgogICAgICAgIHsKCiAgICAgICAgICAgIEFzc2VtYmx5IGFzbSA9IEFz
CSCB64:c2VtYmx5LkdldEV4ZWN1dGluZ0Fzc2VtYmx5KCk7CgogICAgICAgICAgICBzdHJpbmdbXSBuYW1l
CSCB64:cyA9IGFzbS5HZXRNYW5pZmVzdFJlc291cmNlTmFtZXMoKTsKCiAgICAgICAgICAgIGlmIChuYW1l
CSCB64:cy5MZW5ndGggPT0gMCkKCiAgICAgICAgICAgIHsKCiAgICAgICAgICAgICAgICBDb25zb2xlLldy
CSCB64:aXRlTGluZSgiW+mUmeivr10g5YaF572u6LWE5rqQ57y65aSxLCDor7fph43mlrDnlJ/miJDjgIIi
CSCB64:KTsKCiAgICAgICAgICAgICAgICBDb25zb2xlLlJlYWRLZXkoKTsKCiAgICAgICAgICAgICAgICBy
CSCB64:ZXR1cm47CgogICAgICAgICAgICB9CgogICAgICAgICAgICBmb3JlYWNoIChzdHJpbmcgbiBpbiBu
CSCB64:YW1lcykKCiAgICAgICAgICAgIHsKCiAgICAgICAgICAgICAgICBzdHJpbmcgZm5hbWUgPSBQYXRo
CSCB64:LkdldEZpbGVOYW1lKG4pOwoKICAgICAgICAgICAgICAgIHN0cmluZyB0YXJnZXQgPSBQYXRoLkNv
CSCB64:bWJpbmUoZGlyLCBmbmFtZSk7CgogICAgICAgICAgICAgICAgdXNpbmcgKFN0cmVhbSBycyA9IGFz
CSCB64:bS5HZXRNYW5pZmVzdFJlc291cmNlU3RyZWFtKG4pKQoKICAgICAgICAgICAgICAgIHVzaW5nIChG
CSCB64:aWxlU3RyZWFtIGZzID0gRmlsZS5DcmVhdGUodGFyZ2V0KSkKCiAgICAgICAgICAgICAgICAgICAg
CSCB64:cnMuQ29weVRvKGZzKTsKCiAgICAgICAgICAgICAgICBpZiAoZm5hbWUuRW5kc1dpdGgoIi56aXAi
CSCB64:KSkKCiAgICAgICAgICAgICAgICB7CgogICAgICAgICAgICAgICAgICAgIHN0cmluZyB6ZGVzdCA9
CSCB64:IFBhdGguQ29tYmluZShkaXIsIGZuYW1lLlN1YnN0cmluZygwLCBmbmFtZS5MZW5ndGggLSA0KSk7
CSCB64:CgogICAgICAgICAgICAgICAgICAgIFppcEZpbGUuRXh0cmFjdFRvRGlyZWN0b3J5KHRhcmdldCwg
CSCB64:emRlc3QpOwoKICAgICAgICAgICAgICAgICAgICBGaWxlLkRlbGV0ZSh0YXJnZXQpOwoKICAgICAg
CSCB64:ICAgICAgICAgIH0KCiAgICAgICAgICAgIH0KCiAgICAgICAgICAgIC8vIOW8gOa6kOiuuOWPr+e9
CSCB64:suWQje+8iOmaj+W8leaTjumHiuaUvuWIsOS4tOaXtuebruW9le+8jOS+v+S6jiBMR1BMLzBCU0Qg
CSCB64:5ZCI6KeE77yJCiAgICAgICAgICAgIHRyeSB7CiAgICAgICAgICAgICAgICBzdHJpbmcgbGljID0K
CSCB64:ICAgICAgICAgICAgICAgICAgICAiWFogQ29tcHJlc3NvciAtIFRoaXJkLVBhcnR5IE9wZW4gU291
CSCB64:cmNlIE5vdGljZXNcclxuIiArCiAgICAgICAgICAgICAgICAgICAgIj09PT09PT09PT09PT09PT09
CSCB64:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT1cclxuIiArCiAgICAgICAgICAgICAgICAgICAg
CSCB64:IlRoaXMgZnVsbCBidWlsZCBleHRyYWN0cyB0aGUgZm9sbG93aW5nIG9wZW4tc291cmNlIGVuZ2lu
CSCB64:ZXMgdG8gYSB0ZW1wIGRpcjpcclxuXHJcbiIgKwogICAgICAgICAgICAgICAgICAgICIxLiA3LVpp
CSCB64:cCAyNC4wOSAoN3ouZXhlLzd6LmRsbC83ei5zZngpIC0gR05VIExHUEwgdjIuMSBvciBsYXRlciAo
CSCB64:c29tZSBCU0QtMy1DbGF1c2UpLlxyXG4iICsKICAgICAgICAgICAgICAgICAgICAiICAgQ29weXJp
CSCB64:Z2h0IChDKSBJZ29yIFBhdmxvdi4gRnJlZSBmb3IgY29tbWVyY2lhbCB1c2UuIFNvdXJjZS9saWNl
CSCB64:bnNlOiBodHRwczovL3d3dy43LXppcC5vcmcvXHJcblxyXG4iICsKICAgICAgICAgICAgICAgICAg
CSCB64:ICAiMi4gWFogVXRpbHMgNS44LjQgKHh6LmV4ZS94emRlYy5leGUvbGlibHptYS5kbGwpIC0gMEJT
CSCB64:RCAoTWluR1ctdzY0IHJ1bnRpbWUpLlxyXG4iICsKICAgICAgICAgICAgICAgICAgICAiICAgaHR0
CSCB64:cHM6Ly90dWthYW5pLm9yZy94ei9cclxuXHJcbiIgKwogICAgICAgICAgICAgICAgICAgICIzLiBB
CSCB64:bmRyb2lkIHRlbXBsYXRlcyBidW5kbGU6IEFwYWNoZSBDb21tb25zIENvbXByZXNzIC8gQ29tbW9u
CSCB64:cyBJTyAvIFppcDRqIChBcGFjaGUgMi4wKSxcclxuIiArCiAgICAgICAgICAgICAgICAgICAgIiAg
CSCB64:IGFuZCBqdW5yYXIgKFVuUkFSIExpY2Vuc2U7IFJBUiBleHRyYWN0aW9uIG9ubHksIG5vIFJBUiBj
CSCB64:cmVhdGlvbikuXHJcblxyXG4iICsKICAgICAgICAgICAgICAgICAgICAiRnVsbCBsaWNlbnNlIHRl
CSCB64:eHRzIHNoaXAgd2l0aCB0aGUgZGlzdHJpYnV0aW9uIGluIFRISVJELVBBUlRZLUxJQ0VOU0VTLm1k
CSCB64:IGFuZCB0aGUgdG9vbHMgZm9sZGVyLlxyXG4iICsKICAgICAgICAgICAgICAgICAgICAiUkFSIGlz
CSCB64:IHN1cHBvcnRlZCBmb3IgZXh0cmFjdGlvbiBvbmx5OyB0aGUgdW5SQVIgbGljZW5zZSBmb3JiaWRz
CSCB64:IHJlYnVpbGRpbmcgdGhlIFJBUiBhbGdvcml0aG0uXHJcbiI7CiAgICAgICAgICAgICAgICBGaWxl
CSCB64:LldyaXRlQWxsVGV4dChQYXRoLkNvbWJpbmUoZGlyLCAiTElDRU5TRVMudHh0IiksIGxpYywgbmV3
CSCB64:IFN5c3RlbS5UZXh0LlVURjhFbmNvZGluZyhmYWxzZSkpOwogICAgICAgICAgICB9IGNhdGNoIHsg
CSCB64:fQogICAgICAgICAgICBQcm9jZXNzU3RhcnRJbmZvIHBzaSA9IG5ldyBQcm9jZXNzU3RhcnRJbmZv
CSCB64:KCJjbWQiLAoKICAgICAgICAgICAgICAgICIvayB0aXRsZSBYWuWujOaVtOeJiOWOi+e8qeW3peWF
CSCB64:tyDml6nmnJ/mtYvor5XniYggMC4xIC0g5Li05pe255uu5b2VOiIgKyBkaXIgKwoKICAgICAgICAg
CSCB64:ICAgICAgICIgJiBjZCAvZCBcIiIgKyBkaXIgKyAiXCIgJiB4ei1jb21wcmVzc29yLmNtZCIpOwoK
CSCB64:ICAgICAgICAgICAgcHNpLlVzZVNoZWxsRXhlY3V0ZSA9IGZhbHNlOwoKICAgICAgICAgICAgUHJv
CSCB64:Y2VzcyBwID0gUHJvY2Vzcy5TdGFydChwc2kpOwoKICAgICAgICAgICAgcC5XYWl0Rm9yRXhpdCgp
CSCB64:OwoKICAgICAgICB9CgogICAgICAgIGNhdGNoIChFeGNlcHRpb24gZXgpCgogICAgICAgIHsKCiAg
CSCB64:ICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCJb6ZSZ6K+vXSAiICsgZXguTWVzc2FnZSk7Cgog
CSCB64:ICAgICAgICAgICBDb25zb2xlLldyaXRlTGluZSgi5oyJ5Lu75oSP6ZSu6YCA5Ye6Li4uIik7Cgog
CSCB64:ICAgICAgICAgICBDb25zb2xlLlJlYWRLZXkoKTsKCiAgICAgICAgfQoKICAgICAgICBmaW5hbGx5
CSCB64:CgogICAgICAgIHsKCiAgICAgICAgICAgIHRyeSB7IERpcmVjdG9yeS5EZWxldGUoZGlyLCB0cnVl
CSCB64:KTsgfSBjYXRjaCB7IH0KCiAgICAgICAgfQoKICAgIH0KCn0KCg==
