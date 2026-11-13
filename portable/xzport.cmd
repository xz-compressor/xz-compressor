@echo off
chcp 936 >nul 2>&1
setlocal EnableExtensions EnableDelayedExpansion
title XZ便携压缩工具 早期测试版 0.1
color 0B
rem ============================================================
rem  XZ便携压缩工具 早期测试版 0.1 -- 无环境可运行版 (内嵌 7-Zip)
rem  仅负责压缩: 7z / zip / xz
rem  加密: zip/7z 支持多种形式; xz 加密自动生成加密容器
rem  用法: 双击运行, 或拖文件/文件夹到本程序图标上
rem ============================================================

set "APP=XZ便携压缩工具 早期测试版 0.1"
set "SD=%~dp0"
set "SELF=%~f0"
set "SZIP=%SD%7z.exe"
set "SFXMOD=%SD%7z.sfx"
set "IN="
set "ISDIR=0"
set "MULTI=0"
set "LV=9"
set "OUTTYPE="
set "PASS="
set "PWARG="
set "ENCTYPE="
set "EC=0"

if not exist "%SZIP%" (
  echo  [错误] 未找到内嵌压缩引擎 7z.exe
  echo  [提示] 便携包文件不完整, 请重新获取完整压缩包。
  pause
  exit /b 1
)


rem ============ 拖拽模式 ============
set "ALLARGS=%*"
if not "%~1"=="" (
  set "IN=%~1"
  set "ARGN=0"
  for %%a in (%*) do set /a ARGN+=1
  if !ARGN! gtr 1 set "MULTI=1"
  call :CHECK_INPUT
  if errorlevel 1 pause & exit /b 1
  goto :AFTER_INPUT
)

:MAINMENU
set "MENU="
if defined XZCP_AUTO if defined XZCP_MENU set "MENU=!XZCP_MENU!"
if not defined MENU set /p "MENU=请选择: "
cls
echo.
echo  ============================================================
echo    %APP%
echo    7z / zip / xz 压缩 / 多形式加密 / 无环境运行
echo  ============================================================
echo.
echo    请选择要压缩的对象:
echo      [1] 手动输入路径 （也可直接把文件/文件夹拖进本窗口）
echo      [2] 弹出窗口选择 文件
echo      [3] 弹出窗口选择 文件夹
echo      [Q] 退出
echo.
if /i "!MENU!"=="q" exit /b 0
if "!MENU!"=="1" goto :ASK_INPUT
if "!MENU!"=="2" goto :BROWSE_FILE
if "!MENU!"=="3" goto :BROWSE_DIR
goto :MAINMENU

:ASK_INPUT
echo.
if defined XZCP_AUTO if defined XZCP_IN set "IN=!XZCP_IN!"
if not defined IN (
  echo  [选择] 请在文件资源管理器中选择要压缩的文件 ...
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要压缩的文件'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择文件, 已取消。
    pause
    goto :MAINMENU
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "IN=%%L"
  del "!PICK!" >nul 2>&1
  if not defined IN (
    echo  [提示] 未选择文件, 已取消。
    pause
    goto :MAINMENU
  )
)
call :CHECK_INPUT
if errorlevel 1 goto :MAINMENU
goto :AFTER_INPUT

:BROWSE_FILE
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要压缩的文件'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
if not exist "!PICK!" goto :MAINMENU
for /f "usebackq delims=" %%L in ("!PICK!") do set "IN=%%L"
del "!PICK!" >nul 2>&1
if not defined IN goto :MAINMENU
call :CHECK_INPUT
if errorlevel 1 goto :MAINMENU
goto :AFTER_INPUT

:BROWSE_DIR
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='选择要压缩的文件夹'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.SelectedPath,[Text.Encoding]::Default)}"
if not exist "!PICK!" goto :MAINMENU
for /f "usebackq delims=" %%L in ("!PICK!") do set "IN=%%L"
del "!PICK!" >nul 2>&1
if not defined IN goto :MAINMENU
call :CHECK_INPUT
if errorlevel 1 goto :MAINMENU
goto :AFTER_INPUT

:CHECK_INPUT
if not defined IN (
  echo  [错误] 未输入路径。
  exit /b 1
)
set "IN=!IN:"=!"
:TRIMIN
if not "!IN:~-1!"==" " goto :TRIM_DONE
set "IN=!IN:~0,-1!"
goto :TRIMIN
:TRIM_DONE
if "!IN!"=="" (
  echo  [错误] 路径为空。
  exit /b 1
)
if exist "!IN!\" (
  set "ISDIR=1"
) else if exist "!IN!" (
  set "ISDIR=0"
) else (
  echo  [错误] 找不到路径: !IN!
  exit /b 1
)
for %%F in ("!IN!") do set "OUTDIR=%%~dpF"
set "OUTDIRC=!OUTDIR!"
set "OUTDIRC=!OUTDIRC:\=/!"
if "!OUTDIRC:~-1!"=="/" (
  set "OUTDIRC=!OUTDIRC:~0,-1!"
  if /i "!OUTDIRC!"=="!OUTDIRC:~0,2!" set "OUTDIRC=!OUTDIRC!/"
)
for %%F in ("!IN!") do set "INNAME=%%~nxF"
for %%F in ("!IN!") do set "INBASE=%%~nF"
if "!ISDIR!"=="1" for %%F in ("!IN!") do set "INBASE=%%~nxF"
if "!INBASE!"=="" for %%F in ("!IN!") do set "INBASE=%%~nxF"
exit /b 0

:AFTER_INPUT
if "!ISDIR!"=="1" echo  [信息] 输入为文件夹, 输出将为 tar.xz 压缩包。
if "!MULTI!"=="1" echo  [信息] 输入了多个文件, 输出将为 tar.xz 压缩包。
echo.

:GETTYPE
set "OUTTYPE="
echo.
echo  ============================================================
echo    输出格式 （选一项）
echo  ============================================================
echo      [1] .xz  极致压缩, 7-Zip/WinRAR 可解
echo      [2] .zip 通用格式, 兼容性最好
echo      [3] .7z  高压缩率, 7-Zip 原生格式
echo     压缩等级: 固定极限 9（压缩到最小, 速度最慢）
echo     加密: zip/7z 支持 传统/AES-256/头部加密; xz 加密自动生成加密容器
echo.
if defined XZCP_AUTO if defined XZCP_OUTTYPE set "OUTTYPE=!XZCP_OUTTYPE!"
if not defined OUTTYPE set /p "OUTTYPE=请选择 1 / 2 / 3 (直接回车=1): "
if "!OUTTYPE!"=="" set "OUTTYPE=1"
if "!OUTTYPE!"=="1" goto :OUTTYPE_OK
if "!OUTTYPE!"=="2" goto :OUTTYPE_OK
if "!OUTTYPE!"=="3" goto :OUTTYPE_OK
echo  [错误] 只能输入 1、2 或 3。
goto :GETTYPE

:OUTTYPE_OK
set "LV=9"
rem ---- 压缩等级固定极限 9 ----

rem ============ 加密询问 (xz 加密将生成加密容器) ============
set "PASS="
set "PWARG="
set "ENCTYPE="
call :ASK_PASS
goto :BUILD_OUT
:ASK_PASS
echo.
echo  ============================================================
echo    压缩加密
echo  ============================================================
echo      [0] 不加密 (默认)
echo      [1] 设置密码
echo.
if defined XZCP_AUTO if defined XZCP_PASSOPT set "PASSOPT=!XZCP_PASSOPT!"
if not defined PASSOPT set /p "PASSOPT=请选择 0 / 1 (直接回车=0): "
if "!PASSOPT!"=="" set "PASSOPT=0"
if "!PASSOPT!"=="0" goto :BUILD_OUT
if not "!PASSOPT!"=="1" goto :ASK_PASS
echo.
if defined XZCP_AUTO if defined XZCP_PASS set "PASS=!XZCP_PASS!"
if not defined PASS set /p "PASS=请输入压缩密码: "
if not defined PASS (
  echo  [提示] 未输入密码, 本次不加密。
  goto :BUILD_OUT
)
set "PWARG=-p!PASS!"
echo  [信息] 已启用加密。
echo.
echo  ============================================================
echo    加密方式
echo  ============================================================
echo      [1] 传统密码       ZIP 标准加密（兼容性最好）
echo      [2] AES-256        高强度加密（zip/7z 推荐）
echo      [3] AES-256+头部加密  7z 专用（文件名也加密）
echo.
if defined XZCP_AUTO if defined XZCP_ENCTYPE set "ENCTYPE=!XZCP_ENCTYPE!"
if not defined ENCTYPE set /p "ENCTYPE=请选择 1 / 2 / 3 (直接回车=2): "
if "!ENCTYPE!"=="" set "ENCTYPE=2"
exit /b 0

rem ============ 构建输出文件名 ============
:BUILD_OUT
set "EXT="
if "!OUTTYPE!"=="1" (
  if "!ISDIR!"=="1" set "EXT=.tar.xz"
  if "!MULTI!"=="1" set "EXT=.tar.xz"
  if not defined EXT set "EXT=.xz"
)
if "!OUTTYPE!"=="2" set "EXT=.zip"
if "!OUTTYPE!"=="3" set "EXT=.7z"
set "OUT=!OUTDIR!!INBASE!_L!LV!!EXT!"
if exist "!OUT!" (
  echo.
  echo  [提示] 输出文件已存在: !OUT!
  set "OW="
  if defined XZCP_AUTO if defined XZCP_OW set "OW=!XZCP_OW!"
  if not defined OW set /p "OW=[Y]覆盖  [N]改名另存  [C]取消: "
  if /i "!OW!"=="n" set "OUT=!OUTDIR!!INBASE!_L!LV!_!RANDOM!!EXT!"
  if /i "!OW!"=="c" goto :MAINMENU
  if /i "!OW!"=="y" del /f /q "!OUT!" >nul 2>&1
  if "!OW!"=="" del /f /q "!OUT!" >nul 2>&1
)

rem ============ 开始压缩 ============
echo.
echo  ============================================================
echo    开始压缩 （极限等级 9）
echo  ============================================================
set "T0=%time%"
if "!OUTTYPE!"=="1" goto :RUN_XZ
if "!OUTTYPE!"=="2" goto :RUN_ZIP
if "!OUTTYPE!"=="3" goto :RUN_7Z
goto :FAIL

:RUN_XZ
set "XZC_ENC="
if defined PASS (
  echo  [提示] .xz 格式本身不支持加密。
  echo         压缩后将额外生成 AES-256 加密容器（.enc.zip, 内含 .xz 文件）。
  set "XZC_ENC=1"
)
if "!ISDIR!"=="1" goto :XZ_TAR
if "!MULTI!"=="1" goto :XZ_TAR
echo  [7-Zip] 正在压缩为 .xz ...
"!SZIP!" a -txz -mx=!LV! -mmt=on "!OUT!" "!IN!" >nul
set "EC=!errorlevel!"
if not "!EC!"=="0" goto :FAIL
call :XZ_FINISH
goto :VERIFY

:XZ_TAR
echo  [7-Zip] 正在打包为 tar.xz （文件夹/多文件）...
set "TMPTAR=%TEMP%\xz_tmp_!RANDOM!.tar"
if "!MULTI!"=="1" (
  "!SZIP!" a -ttar "!TMPTAR!" !ALLARGS! >nul
) else (
  "!SZIP!" a -ttar "!TMPTAR!" -C "!OUTDIRC!" "!INNAME!" >nul
)
set "EC=!errorlevel!"
if not "!EC!"=="0" goto :FAIL
"!SZIP!" a -txz -mx=!LV! "!OUT!" "!TMPTAR!" >nul
set "EC=!errorlevel!"
del "!TMPTAR!" >nul 2>&1
if not "!EC!"=="0" goto :FAIL
call :XZ_FINISH
goto :VERIFY

:RUN_ZIP
set "ZARG="
if defined PASS (
  set "ZARG=!PWARG!"
  if not "!ENCTYPE!"=="1" set "ZARG=!PWARG! -mem=AES256"
)
echo  [7-Zip] 正在压缩为 .zip ...
if "!ISDIR!"=="1" (
  "!SZIP!" a -tzip -mx=!LV! -mmt=on !ZARG! "!OUT!" "!IN!\" >nul
) else if "!MULTI!"=="1" (
  "!SZIP!" a -tzip -mx=!LV! -mmt=on !ZARG! "!OUT!" !ALLARGS! >nul
) else (
  "!SZIP!" a -tzip -mx=!LV! -mmt=on !ZARG! "!OUT!" "!IN!" >nul
)
set "EC=!errorlevel!"
if not "!EC!"=="0" goto :FAIL
goto :VERIFY

:RUN_7Z
set "S7ARGS="
if defined PASS (
  set "S7ARGS=!PWARG!"
  if "!ENCTYPE!"=="3" set "S7ARGS=!PWARG! -mhe=on"
)
echo  [7-Zip] 正在压缩为 .7z ...
if "!ISDIR!"=="1" (
  "!SZIP!" a -t7z -mx=!LV! -mmt=on !S7ARGS! "!OUT!" "!IN!\" >nul
) else if "!MULTI!"=="1" (
  "!SZIP!" a -t7z -mx=!LV! -mmt=on !S7ARGS! "!OUT!" !ALLARGS! >nul
) else (
  "!SZIP!" a -t7z -mx=!LV! -mmt=on !S7ARGS! "!OUT!" "!IN!" >nul
)
set "EC=!errorlevel!"
if not "!EC!"=="0" goto :FAIL
goto :VERIFY

:XZ_FINISH
if defined XZC_ENC (
  echo  [容器] 正在生成 AES-256 加密容器 ...
  "!SZIP!" a -tzip -mem=AES256 !PWARG! "!OUT!.enc.zip" "!OUT!" >nul
  set "ECE=!errorlevel!"
  if "!ECE!"=="0" (
    echo  [完成] 加密容器: !OUT!.enc.zip （AES-256, 内含 .xz）
  ) else (
    echo  [警告] 加密容器生成失败, 退出码 !ECE!, 请检查 7-Zip。
  )
)
exit /b 0

:VERIFY
echo.
echo  [校验] 正在测试压缩包完整性 ...
"!SZIP!" t "!OUT!" >nul
set "EC=!errorlevel!"
if not "!EC!"=="0" (
  echo  [失败] 完整性校验未通过, 退出码 !EC!。
) else (
  echo  [通过] 完整性校验成功。
)

rem ============ 结果统计 ============
set "CALC_SRC=!IN!"
set "CALC_OUT=!OUT!"
set "CALC_T0=!T0!"
set "CALC_SUMFILE=%TEMP%\xz_sum_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=$env:CALC_SRC;$oF=Get-Item -LiteralPath $s -ErrorAction Stop;$o=if($oF.PSIsContainer){(Get-ChildItem -LiteralPath $s -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum}else{$oF.Length};$n=(Get-Item -LiteralPath $env:CALC_OUT -ErrorAction Stop).Length;$r=if($o -gt 0){[math]::Round((1-$n/[double]$o)*100,2)}else{0};$d=[DateTime]::Now-[DateTime]::Parse($env:CALC_T0);[IO.File]::WriteAllText($env:CALC_SUMFILE,('{0}|{1}|{2}|{3}|{4}' -f $o,$n,$r,[math]::Round($d.TotalSeconds,1),[math]::Round($n/1MB,2)))"
set "SUM="
for /f "usebackq delims=" %%L in ("!CALC_SUMFILE!") do set "SUM=%%L"
del "!CALC_SUMFILE!" >nul 2>&1
set "SO="
set "SN="
set "SR="
set "ST="
for /f "tokens=1-5 delims=|" %%a in ("!SUM!") do set "SO=%%a" & set "SN=%%b" & set "SR=%%c" & set "ST=%%d"
echo.
echo  ============================================================
echo    压缩完成!
if defined SO echo    原始大小:  !SO! 字节
if defined SN echo    压缩后:    !SN! 字节
if defined SR echo    压缩率:    !SR!%%  （越小越好）
if defined ST echo    耗时:      !ST! 秒
echo    输出文件:  !OUT!
echo  ============================================================
echo.
set "AGAIN="
if defined XZCP_AUTO if defined XZCP_AGAIN set "AGAIN=!XZCP_AGAIN!"
if not defined AGAIN set /p "AGAIN=按 R 再压缩一个, 直接回车退出: "
if /i "!AGAIN!"=="r" (
  set "IN="
  set "ISDIR=0"
  set "MULTI=0"
  set "OUTTYPE="
  set "LV=9"
  set "PASS="
  set "PWARG="
  set "PASSOPT="
)
if /i "!AGAIN!"=="r" goto :MAINMENU
exit /b 0

:FAIL
echo.
echo  [错误] 压缩失败, 引擎退出码 !EC!
echo  [提示] 请检查磁盘空间 / 文件占用 / 权限。
echo  [日志] 上面显示的完整命令行即为实际执行命令。
pause
exit /b 1
