rem ============================================================
rem  build_full_apk.cmd -- 安卓完整版压缩程序构建器 (早期测试版 0.1)
rem  用法: build_full_apk.cmd [/icon:图片或ico] [/pkg:包名] [/alias:别名]
rem          [/storepass:密码] [/keypass:密码] [/cn:CN=...] [/api:目标SDK]
rem  功能: 安卓完整版 (xz 压缩/解压 + zip 加密 + 7z/rar 解压 + 内置工具解出)
rem  输出: %SD%XZ完整压缩.apk
rem  依赖: Android SDK(build-tools + platform) + JDK
rem ============================================================
rem ============================================================
@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion

set "SD=%~dp0"
set "TPL=%SD%android_full"
set "OUTAPK=%SD%XZ完整压缩.apk"
set "PKG=com.xzfull"
set "ALIAS=xzfull"
set "SPASS=changeit"
set "KPASS=changeit"
set "DNAME=CN=XZFull,OU=XZ,O=XZ,L=CN,ST=CN,C=CN"
set "ICON=%SD%tools\xz.ico"
set "TAPI=36"
set "NAME="
set "VER=1.0"

rem ---- 解析可选参数 ----
:PARSE
if "%~1"=="" goto :PARSE_END
set "A=%~1"
if /i "%A:~0,6%"=="/icon:" if not "%A:~6%"=="" set "ICON=%A:~6%"
if /i "%A:~0,5%"=="/pkg:" if not "%A:~5%"=="" set "PKG=%A:~5%"
if /i "%A:~0,7%"=="/alias:" if not "%A:~7%"=="" set "ALIAS=%A:~7%"
if /i "%A:~0,11%"=="/storepass:" if not "%A:~11%"=="" set "SPASS=%A:~11%"
if /i "%A:~0,9%"=="/keypass:" if not "%A:~9%"=="" set "KPASS=%A:~9%"
if /i "%A:~0,4%"=="/cn:" if not "%A:~4%"=="" set "DNAME=%A:~4%"
if /i "%A:~0,5%"=="/api:" if not "%A:~5%"=="" set "TAPI=%A:~5%"
if /i "%A:~0,6%"=="/name:" if not "%A:~6%"=="" set "NAME=%A:~6%"
if /i "%A:~0,5%"=="/ver:" if not "%A:~5%"=="" set "VER=%A:~5%"
if /i "%A:~0,5%"=="/out:" if not "%A:~5%"=="" set "OUTAPK=%A:~5%"
shift
goto :PARSE
:PARSE_END
if defined XZ_DNAME set "DNAME=%XZ_DNAME%"
if defined XZ_ICON set "ICON=%XZ_ICON%"
if defined XZ_PKG set "PKG=%XZ_PKG%"
if defined XZ_ALIAS set "ALIAS=%XZ_ALIAS%"
if defined XZ_SPASS set "SPASS=%XZ_SPASS%"
if defined XZ_KPASS set "KPASS=%XZ_KPASS%"
if defined XZ_API set "TAPI=%XZ_API%"
if defined XZ_NAME set "NAME=%XZ_NAME%"
if defined XZ_VER set "VER=%XZ_VER%"

rem ---- 定位 Android SDK ----
set "SDKROOT="
for %%R in ("%ANDROID_HOME%" "%ANDROID_SDK_ROOT%" "D:\Android\Sdk" "%LOCALAPPDATA%\Android\Sdk") do (
  if not defined SDKROOT if exist "%%~R\platforms" set "SDKROOT=%%~R"
)
if not defined SDKROOT (
  echo  [错误] 未找??Android SDK, 请安??Android SDK 并设??ANDROID_HOME 环境变量??  exit /b 1
)
echo  [SDK]   %SDKROOT%

rem ---- 定位 platform android.jar（优??android-36??---
set "PLAT="
if exist "%SDKROOT%\platforms\android-36\android.jar" set "PLAT=%SDKROOT%\platforms\android-36\android.jar"
if not defined PLAT for /f "delims=" %%D in ('dir /b /ad "%SDKROOT%\platforms" 2^>nul') do (
  if not defined PLAT if exist "%SDKROOT%\platforms\%%D\android.jar" set "PLAT=%SDKROOT%\platforms\%%D\android.jar"
)
if not defined PLAT (
  echo  [错误] 未找??android.jar, 请用 sdkmanager 安装 SDK Platform??  exit /b 1
)
echo  [平台]  %PLAT%

rem ---- 定位 build-tools ----
set "BT="
for /f "delims=" %%D in ('dir /b /ad "%SDKROOT%\build-tools" 2^>nul') do (
  if not defined BT if exist "%SDKROOT%\build-tools\%%D\aapt2.exe" set "BT=%SDKROOT%\build-tools\%%D"
)
if not defined BT (
  echo  [错误] 未找??build-tools, 请用 sdkmanager 安装 build-tools??  exit /b 1
)
echo  [工具]  %BT%

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
  echo  [错误] 未找??JDK jar.exe, 请安??JDK 并设??JAVA_HOME??  exit /b 1
)
echo  [JDK]   %JAVADIR%

rem ---- 检查模??----
if not exist "%TPL%\AndroidManifest.xml" (
  echo  [错误] 缺少安卓模板: %TPL%\AndroidManifest.xml
  exit /b 1
)
if not exist "%TPL%\src\com\xzfull\MainActivity.java" (
  echo  [错误] 缺少安卓源码: %TPL%\src\com\xzfull\MainActivity.java
  exit /b 1
)
if not exist "%TPL%\src\org\tukaani\xz\XZOutputStream.java" (
  echo  [错误] 缺少 xz 压缩库源?? 请恢??android_full\src\org\tukaani\xz\
  exit /b 1
)

rem ---- 准备构建目录 ----
set "W=%TEMP%\apkfull_%RANDOM%"
mkdir "%W%\classes" >nul 2>&1
mkdir "%W%\dex" >nul 2>&1
mkdir "%W%\gen" >nul 2>&1
mkdir "%W%\res" >nul 2>&1
mkdir "%W%\res\mipmap-xxxhdpi" >nul 2>&1
mkdir "%W%\assets" >nul 2>&1
copy /y "%TPL%\lib\commons-compress.jar" "%W%\assets\" >nul 2>&1
copy /y "%TPL%\lib\junrar.jar" "%W%\assets\" >nul 2>&1
copy /y "%TPL%\lib\zip4j.jar" "%W%\assets\" >nul 2>&1
echo  [工具]  内置工具库已打包进 assets (3 个 jar)
copy /y "%TPL%\lib\commons-io.jar" "%W%\assets\" >nul 2>&1
copy /y "%TPL%\lib\commons-io.jar" "%W%\assets\" >nul 2>&1
rem ---- 第三方许可证文本随 APK 分发 (Apache / Zip4j / junrar) ----
if exist "%TPL%\lib\licenses" (
  mkdir "%W%\assets\licenses" >nul 2>&1
  copy /y "%TPL%\lib\licenses\*.txt" "%W%\assets\licenses\" >nul 2>&1
  echo  [工具]  第三方许可证文本已打包进 assets/licenses
)

rem ---- 图标处理 (图片/ico -> mipmap png) ----
if defined ICON (
  if not exist "%ICON%" (
    echo  [错误] 图标文件不存在: %ICON%
    rmdir /s /q "%W%" >nul 2>&1
    exit /b 1
  )
  echo  [图标]  转换图标: %ICON%
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\imgtool.ps1" "%ICON%" "%W%\res\mipmap-xxxhdpi\icon.png" png
  if errorlevel 1 (
    echo  [错误] 图标转换失败, 请提供 png/jpg/bmp/ico 图片.
    rmdir /s /q "%W%" >nul 2>&1
    exit /b 1
  )
)

echo  [包名]  %PKG%
echo  [API]   目标 SDK %TAPI%

rem ---- 工作副本: 复制源码树, 替换 MainActivity 包名声明 ----
xcopy /e /i /y "%TPL%\src\*" "%W%\src\" >nul 2>&1
if not "%PKG%"=="com.xzfull" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\pkg_patch.ps1" "%W%\src\com\xzfull\MainActivity.java" "%PKG%"
  if errorlevel 1 goto :FAIL
)

rem ---- 工作副本: Manifest (替换包名/图标) ----
copy /y "%TPL%\AndroidManifest.xml" "%W%\AndroidManifest.xml" >nul
powershell -NoProfile -ExecutionPolicy Bypass -File "%SD%tools\manifest_patch.ps1" "%W%\AndroidManifest.xml" "%PKG%" "%ICON%" "%NAME%"
if errorlevel 1 goto :FAIL
rem ---- 1) 编译资源 (有图标时) ----
if defined ICON (
  echo  [构建] 编译资源 ...
  "%BT%\aapt2.exe" compile --dir "%W%\res" -o "%W%\res.zip"
  if errorlevel 1 goto :FAIL
)

rem ---- 2) 链接清单 ----
echo  [构建] 链接清单 ...
if defined ICON (
  "%BT%\aapt2.exe" link -o "%W%\base.apk" -I "%PLAT%" --manifest "%W%\AndroidManifest.xml" -R "%W%\res.zip" --java "%W%\gen" -A "%W%\assets" -0 jar --min-sdk-version 29 --target-sdk-version %TAPI% --version-code 1 --version-name %VER%
) else (
  "%BT%\aapt2.exe" link -o "%W%\base.apk" -I "%PLAT%" --manifest "%W%\AndroidManifest.xml" -A "%W%\assets" -0 jar --min-sdk-version 29 --target-sdk-version %TAPI% --version-code 1 --version-name %VER%
)
if errorlevel 1 goto :FAIL

rem ---- 3) 生成源码文件列表 (javac argfile) ----
echo  [构建] 收集源码 ...
dir /b /s "%W%\src\*.java" > "%W%\srcfiles.txt"
if defined ICON dir /b /s "%W%\gen\*.java" >> "%W%\srcfiles.txt"
set "SRCNUM=0"
for /f %%N in ('type "%W%\srcfiles.txt"') do set /a SRCNUM+=1
echo         Java 源文件数: %SRCNUM%

rem ---- 4) 编译 Java ----
echo  [构建] 编译 Java ...
"%JAVADIR%\javac.exe" -encoding UTF-8 -source 8 -target 8 -classpath "%PLAT%;%TPL%\lib\commons-compress.jar;%TPL%\lib\junrar.jar;%TPL%\lib\zip4j.jar;%TPL%\lib\commons-io.jar" -d "%W%\classes" @"%W%\srcfiles.txt"
if errorlevel 1 goto :FAIL
rem ---- 4) 生成 classes.dex ----
echo  [构建] 生成 dex ...
set "DFILES="
for /f "delims=" %%C in ('dir /b /s "%W%\classes\*.class" 2^>nul') do (
  set "REL=%%C"
  set "REL=!REL:%W%\classes\=!"
  set "DFILES=!DFILES! !REL!"
)
pushd "%W%\classes"
"%JAVADIR%\java.exe" -Xmx1024M -cp "%BT%\lib\d8.jar" com.android.tools.r8.D8 --release --lib "%PLAT%" --min-api 29 --output "%W%\dex" !DFILES! "%TPL%\lib\commons-compress.jar" "%TPL%\lib\junrar.jar" "%TPL%\lib\zip4j.jar" "%TPL%\lib\commons-io.jar"
set "EC=!errorlevel!"
popd
if not "!EC!"=="0" goto :FAIL

rem ---- 5) ??dex ??apk ----
"%JAVADIR%\jar.exe" -uf "%W%\base.apk" -C "%W%\dex" classes.dex
if errorlevel 1 goto :FAIL

rem ---- 6) zipalign ----
echo  [构建] 对齐优化 ...
"%BT%\zipalign.exe" -f 4 "%W%\base.apk" "%W%\aligned.apk"
if errorlevel 1 goto :FAIL

rem ---- 7) 签名 (keystore 按包名命名, 自定义 alias) ----
set "KS=%TPL%\%PKG:.=_%.keystore"
if exist "%KS%" goto :SIGN_READY
echo  [签名] 首次构建, 自动生成签名密钥, alias=%ALIAS% ...
"%JAVADIR%\keytool.exe" -genkeypair -keystore "%KS%" -alias "%ALIAS%" -keyalg RSA -keysize 2048 -validity 10000 -storepass "%SPASS%" -keypass "%KPASS%" -dname "%DNAME%" >nul 2>&1
if errorlevel 1 goto :FAIL
:SIGN_READY
echo  [签名] apksigner 签名, alias=%ALIAS% ...
echo  [调试] KS=%KS% OUT=%OUTAPK% IN=%W%\aligned.apk
"%JAVADIR%\java.exe" -Xmx1024M -jar "%BT%\lib\apksigner.jar" sign --v4-signing-enabled false --ks "%KS%" --ks-pass pass:%SPASS% --key-pass pass:%KPASS% --out "%W%\signed.apk" "%W%\aligned.apk"
if errorlevel 1 goto :FAIL
for %%F in ("%OUTAPK%") do if not exist "%%~dpF" mkdir "%%~dpF" 2>nul
copy /y "%W%\signed.apk" "%OUTAPK%" >nul
if errorlevel 1 goto :FAIL
rem ---- 8) 验证 ----
"%JAVADIR%\java.exe" -Xmx1024M -jar "%BT%\lib\apksigner.jar" verify "%OUTAPK%" >nul 2>&1
if errorlevel 1 goto :FAIL

for %%F in ("%OUTAPK%") do set "APSIZE=%%~zF"
echo  [通过] 安卓完整版压缩程序构建成功
echo  [包名]  %PKG%
echo  [大小] %APSIZE% 字节
rmdir /s /q "%W%" >nul 2>&1
exit /b 0

:FAIL
echo  [错误] 安卓完整版构建失?? 构建目录: %W%
echo  [提示] 请检??JDK ??Android SDK; 可查看上方错误信息??exit /b 1
