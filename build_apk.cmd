@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
rem ============================================================
rem  build_apk.cmd  -- 安卓自解压 APK 构建器 (早期测试版 0.1)
rem  用法: build_apk.cmd <payload.zip> <输出.apk> [应用名]
rem          [/icon:图片或ico] [/pkg:包名] [/alias:别名]
rem          [/storepass:密码] [/keypass:密码] [/cn:CN=...] [/api:目标SDK]
rem  依赖: Android SDK(build-tools + platform) + JDK
rem ============================================================

set "SD=%~dp0"
set "TPL=%SD%android"
set "PAY=%~1"
set "OUTAPK=%~2"
set "APPNM=%~3"
if not defined APPNM set "APPNM=XZ便携压缩"
set "PKG=com.xzport"
set "ALIAS=xzport"
set "SPASS=changeit"
set "KPASS=changeit"
set "DNAME=CN=XZPort,OU=XZ,O=XZ,L=CN,ST=CN,C=CN"
set "ICON="
set "TAPI=36"

rem ---- 解析可选参数 ----
:PARSE
if "%~1"=="" goto :PARSE_END
set "A=%~1"
if /i "%A:~0,6%"=="/icon:" set "ICON=%A:~6%"
if /i "%A:~0,5%"=="/pkg:" set "PKG=%A:~5%"
if /i "%A:~0,7%"=="/alias:" set "ALIAS=%A:~7%"
if /i "%A:~0,11%"=="/storepass:" set "SPASS=%A:~11%"
if /i "%A:~0,9%"=="/keypass:" set "KPASS=%A:~9%"
if /i "%A:~0,4%"=="/cn:" set "DNAME=%A:~4%"
if /i "%A:~0,5%"=="/api:" if not "%A:~5%"=="" set "TAPI=%A:~5%"
shift
goto :PARSE
:PARSE_END
if defined XZ_DNAME set "DNAME=%XZ_DNAME%"
if defined XZ_ICON set "ICON=%XZ_ICON%"
if defined XZ_API set "TAPI=%XZ_API%"

if not exist "%PAY%" (
  echo  [错误] 未找到 payload 压缩包: %PAY%
  exit /b 1
)

rem ---- 定位 Android SDK ----
set "SDKROOT="
for %%R in ("%ANDROID_HOME%" "%ANDROID_SDK_ROOT%" "D:\Android\Sdk" "%LOCALAPPDATA%\Android\Sdk") do (
  if not defined SDKROOT if exist "%%~R\platforms" set "SDKROOT=%%~R"
)
if not defined SDKROOT (
  echo  [错误] 未找到 Android SDK, 请安装 Android SDK 并设置 ANDROID_HOME 环境变量.
  exit /b 1
)
echo  [SDK]   %SDKROOT%

rem ---- 定位 platform android.jar (优先 android-36) ----
set "PLAT="
if exist "%SDKROOT%\platforms\android-36\android.jar" set "PLAT=%SDKROOT%\platforms\android-36\android.jar"
if not defined PLAT for /f "delims=" %%D in ('dir /b /ad "%SDKROOT%\platforms" 2^>nul') do (
  if not defined PLAT if exist "%SDKROOT%\platforms\%%D\android.jar" set "PLAT=%SDKROOT%\platforms\%%D\android.jar"
)
if not defined PLAT (
  echo  [错误] 未找到 android.jar, 请用 sdkmanager 安装 SDK Platform.
  exit /b 1
)
echo  [平台]  %PLAT%

rem ---- 定位 build-tools ----
set "BT="
for /f "delims=" %%D in ('dir /b /ad "%SDKROOT%\build-tools" 2^>nul') do (
  if not defined BT if exist "%SDKROOT%\build-tools\%%D\aapt2.exe" set "BT=%SDKROOT%\build-tools\%%D"
)
if not defined BT (
  echo  [错误] 未找到 build-tools, 请用 sdkmanager 安装 build-tools.
  exit /b 1
)
echo  [构建]  %BT%

rem ---- 定位 JDK (javac/jar/keytool, 要求 jar.exe) ----
set "JAVADIR="
if defined JAVA_HOME if exist "%JAVA_HOME%\bin\javac.exe" set "JAVADIR=%JAVA_HOME%\bin"
if defined JAVADIR if not exist "%JAVADIR%jar.exe" set "JAVADIR="
if not defined JAVADIR for /f "delims=" %%J in ('where javac 2^>nul') do (
  if not defined JAVADIR set "JAVADIR=%%~dpJ"
)
if defined JAVADIR if not exist "%JAVADIR%jar.exe" set "JAVADIR="
if not defined JAVADIR if exist "%ProgramFiles%\Java" for /f "delims=" %%J in ('dir /b /ad "%ProgramFiles%\Java" 2^>nul') do (
  if not defined JAVADIR if exist "%ProgramFiles%\Java\%%J\bin\jar.exe" set "JAVADIR=%ProgramFiles%\Java\%%J\bin"
)
if not defined JAVADIR if defined LOCALAPPDATA if exist "%LOCALAPPDATA%\Programs\Java" for /f "delims=" %%J in ('dir /b /ad "%LOCALAPPDATA%\Programs\Java" 2^>nul') do (
  if not defined JAVADIR if exist "%LOCALAPPDATA%\Programs\Java\%%J\bin\jar.exe" set "JAVADIR=%LOCALAPPDATA%\Programs\Java\%%J\bin"
)
if not defined JAVADIR (
  echo  [错误] 未找到 JDK jar.exe, 请安装 JDK 并设置 JAVA_HOME.
  exit /b 1
)
echo  [JDK]   %JAVADIR%

rem ---- 检查模板 ----
if not exist "%TPL%\AndroidManifest.xml" (
  echo  [错误] 缺少安卓模板: %TPL%\AndroidManifest.xml
  exit /b 1
)
if not exist "%TPL%\src\com\xzport\MainActivity.java" (
  echo  [错误] 缺少安卓模板源码: %TPL%\src\com\xzport\MainActivity.java
  exit /b 1
)

rem ---- 包名 -> 目录路径 (com.abc -> com\abc) ----
set "PKGPATH=%PKG:.=\%"
echo  [包名]  %PKG%

rem ---- 准备构建目录 ----
set "W=%TEMP%\apkbuild_!RANDOM!"
mkdir "%W%\res" >nul 2>&1
mkdir "%W%\res\raw" >nul 2>&1
mkdir "%W%\gen" >nul 2>&1
mkdir "%W%\classes" >nul 2>&1
mkdir "%W%\dex" >nul 2>&1
xcopy /e /i /y "%TPL%\res\*" "%W%\res\" >nul 2>&1
copy /y "%PAY%" "%W%\res\raw\payload" >nul

rem ---- 图标处理 (图片/ico -> mipmap png) ----
if defined ICON (
  if not exist "%ICON%" (
    echo  [错误] 图标文件不存在: %ICON%
    rmdir /s /q "%W%" >nul 2>&1
    exit /b 1
  )
  mkdir "%W%\res\mipmap-xxxhdpi" >nul 2>&1
  echo  [图标]  转换图标: %ICON%
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\imgtool.ps1" "%ICON%" "%W%\res\mipmap-xxxhdpi\icon.png" png
  if errorlevel 1 (
    echo  [错误] 图标转换失败, 请提供 png/jpg/bmp/ico 图片.
    rmdir /s /q "%W%" >nul 2>&1
    exit /b 1
  )
)

rem ---- 生成工作副本: manifest (替换包名/应用名/图标) ----
copy /y "%TPL%\AndroidManifest.xml" "%W%\AndroidManifest.xml" >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\manifest_patch.ps1" "%W%\AndroidManifest.xml" "%PKG%" "%ICON%" "%APPNM%"
if errorlevel 1 goto :APK_FAIL

rem ---- 生成工作副本: MainActivity (替换包名) ----
xcopy /e /i /y "%TPL%\src\*" "%W%\src\" >nul 2>&1
if not "%PKG%"=="com.xzport" powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\pkg_patch.ps1" "%W%\src\com\xzport\MainActivity.java" "%PKG%"
if errorlevel 1 goto :APK_FAIL

rem ---- 1) 编译资源 ----
echo  [构建] 编译资源 ...
"%BT%\aapt2.exe" compile --dir "%W%\res" -o "%W%\res.zip"
if errorlevel 1 goto :APK_FAIL

rem ---- 2) 链接资源与清单 ----
echo  [构建] 链接清单与资源 ...
"%BT%\aapt2.exe" link -o "%W%\base.apk" -I "%PLAT%" --manifest "%W%\AndroidManifest.xml" -R "%W%\res.zip" --java "%W%\gen" --min-sdk-version 24 --target-sdk-version %TAPI% --version-code 1 --version-name 1.0
if errorlevel 1 goto :APK_FAIL

rem ---- 3) 编译 Java ----
echo  [构建] 编译 Java ...
dir /b /s "%W%\src\*.java" > "%W%\srcfiles.txt"
dir /b /s "%W%\gen\*.java" >> "%W%\srcfiles.txt"
"%JAVADIR%\javac.exe" -encoding UTF-8 -source 8 -target 8 -classpath "%PLAT%;%TPL%\lib\commons-compress.jar;%TPL%\lib\zip4j.jar;%TPL%\lib\commons-io.jar" -d "%W%\classes" @"%W%\srcfiles.txt"
if errorlevel 1 goto :APK_FAIL

rem ---- 4) 生成 classes.dex ----
echo  [构建] 生成 dex ...
set "DFILES="
for /f "delims=" %%C in ('dir /b /s "%W%\classes\*.class" 2^>nul') do (
  set "REL=%%C"
  set "REL=!REL:%W%\classes\=!"
  set "DFILES=!DFILES! !REL!"
)
pushd "%W%\classes"
"%JAVADIR%\java.exe" -Xmx1024M -cp "%BT%\lib\d8.jar" com.android.tools.r8.D8 --release --lib "%PLAT%" --min-api 24 --output "%W%\dex" !DFILES! "%TPL%\lib\commons-compress.jar" "%TPL%\lib\zip4j.jar" "%TPL%\lib\commons-io.jar"
set "EC=!errorlevel!"
popd
if not "!EC!"=="0" goto :APK_FAIL

rem ---- 5) 打包 dex 进 apk ----
"%JAVADIR%\jar.exe" -uf "%W%\base.apk" -C "%W%\dex" classes.dex
if errorlevel 1 goto :APK_FAIL

rem ---- 6) zipalign ----
echo  [构建] 对齐优化 ...
"%BT%\zipalign.exe" -f 4 "%W%\base.apk" "%W%\aligned.apk"
if errorlevel 1 goto :APK_FAIL

rem ---- 7) 签名 ----
set "KS=%TPL%\%PKG:.=_%.keystore"
if exist "%KS%" goto :SIGN_READY
echo  [签名] 首次构建, 自动生成签名密钥, alias=%ALIAS% ...
"%JAVADIR%\keytool.exe" -genkeypair -keystore "%KS%" -alias "%ALIAS%" -keyalg RSA -keysize 2048 -validity 10000 -storepass "%SPASS%" -keypass "%KPASS%" -dname "%DNAME%" 2>&1
if errorlevel 1 goto :KS_FAIL
:SIGN_READY
echo  [签名] apksigner 签名, alias=%ALIAS% ...
"%JAVADIR%\java.exe" -Xmx1024M -jar "%BT%\lib\apksigner.jar" sign --v4-signing-enabled false --ks "%KS%" --ks-pass pass:%SPASS% --key-pass pass:%KPASS% --out "%W%\signed.apk" "%W%\aligned.apk"
if errorlevel 1 goto :FAIL
copy /y "%W%\signed.apk" "%OUTAPK%" >nul
if errorlevel 1 goto :FAIL
if errorlevel 1 goto :APK_FAIL

rem ---- 8) 校验签名 ----
"%JAVADIR%\java.exe" -Xmx1024M -jar "%BT%\lib\apksigner.jar" verify "%OUTAPK%" >nul 2>&1
if errorlevel 1 goto :APK_FAIL

for %%F in ("%OUTAPK%") do set "APSIZE=%%~zF"
echo  [通过] APK 构建并签名成功
echo  [输出] %OUTAPK%
echo  [大小] %APSIZE% 字节
rmdir /s /q "%W%" >nul 2>&1
exit /b 0

:KS_FAIL
echo  [错误] 密钥生成失败, 请检查 alias/密码格式.
rmdir /s /q "%W%" >nul 2>&1
exit /b 1

:APK_FAIL
echo  [错误] APK 构建失败, 构建目录: %W%
echo  [提示] 请安装 JDK 与 Android SDK build-tools; 可查看上方错误信息.
exit /b 1
