@echo off
chcp 936 >nul
rem ============================================================
rem  启动 android16 模拟器（C 盘版，修复开机黑屏）
rem  黑屏根因：无窗口/远程环境下硬件 GPU 加速失败
rem  解法：-gpu swiftshader_indirect 软件渲染 + 跳过损坏快照
rem  SDK 位置: C:\Android\Sdk（D 盘空间不足时装 C 盘）
rem ============================================================
setlocal
set "SDK=C:\Android\Sdk"
set "EMU=%SDK%\emulator\emulator.exe"
set "ADB=%SDK%\platform-tools\adb.exe"
if not exist "%EMU%" (
  echo [错误] 未找到 %EMU%
  pause
  exit /b 1
)
echo 启动 android16（软件渲染，避免黑屏）...
start "" "%EMU%" -avd android16 -no-window -no-audio -no-boot-anim -no-snapshot-load -gpu swiftshader_indirect -netfast
echo 已后台启动。
echo 等待开机完成（约 25-60 秒）...
"%ADB%" wait-for-device
:waitloop
for /f "delims=" %%a in ('""%ADB%" shell getprop sys.boot_completed 2^>nul"') do set "BC=%%a"
if not "%BC%"=="1" (
  ping -n 6 127.0.0.1 >nul
  goto waitloop
)
echo 开机完成！Android 版本:
"%ADB%" shell getprop ro.build.version.release
