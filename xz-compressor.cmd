@echo off
chcp 936 >nul 2>&1 <nul
setlocal EnableExtensions EnableDelayedExpansion
title XZ极速压缩工具 正式版 1.0
color 0B

rem ============================================================
rem  XZ极速压缩工具 正式版 1.0
rem  功能: xz 极致压缩 / 自解压 exe+apk / zip+7z / 多形式加密 / 解压 / 工具下载
rem  引擎: 自动检测 7-Zip / xz.exe / 系统 tar (Windows 10+)
rem        便携版: EXE 单文件工具 / APK 安卓自解压安装包
rem ============================================================

set "APP=XZ极速压缩工具"
set "VER=正式版 1.0"
set "SD=%~dp0"
set "SELF=%~f0"
set "LOG=%SD%xz-compressor.log"
rem 日志写不进脚本目录时退回临时目录
echo. >>"%LOG%" 2>nul
if errorlevel 1 set "LOG=%TEMP%\xz-compressor.log"

set "TAREXE=%WINDIR%\System32\tar.exe"
set "PSH=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSH%" set "PSH=powershell"
set "SZIP="
set "SZDIR="
set "SFXMOD="
set "XZEXE="
set "CSC="
set "RAREXE="
set "IN="
set "ISDIR=0"
set "MULTI=0"
set "DRAGMODE=0"
set "LV=9"
set "OUTTYPE="
set "EC=0"
set "EXEBACKEND="
rem ---- v11 新增选项变量 ----
set "VOL="
set "SOLID="
set "DICT="
set "MTN="
set "RR="
set "ZOPTS="
set "DOBEEP="
set "DOSHA="
set "PRESET="
set "GUILIB="
set "CLIPOS="

if /i "%~1"=="/h" goto :HELP_SHOW
if /i "%~1"=="/?" goto :HELP_SHOW
if /i "%~1"=="--help" goto :HELP_SHOW
if /i "%~1"=="-help" goto :HELP_SHOW
goto :CLI_GATE

:EASTEREGG
cls
set /a GAMENUM=%RANDOM% %% 100 + 1
set /a GAMETRIES=7
echo ============================================
echo.   NUMBER GUESSING GAME  -  1 to 100
echo.   You have 7 tries. Good luck!
echo ============================================
echo.
:GAME_LOOP
set /a GAMETRIES-=1
set "GUESSED="
set /p GUESSED=Your guess (q=quit): 
if /i "%GUESSED%"=="q" goto :GAME_END
if not defined GUESSED goto :GAME_LOOP
if %GUESSED% LSS %GAMENUM% echo   Too low! Tries left: %GAMETRIES%
if %GUESSED% GTR %GAMENUM% echo   Too high! Tries left: %GAMETRIES%
if %GUESSED%==%GAMENUM% goto :GAME_WIN
if %GAMETRIES% GTR 0 goto :GAME_LOOP
echo.
echo   Game over! The number was %GAMENUM%.
echo.
pause >nul
goto :GAME_END
:GAME_WIN
echo.
echo   Congrats! You got it. Tries left: %GAMETRIES%
echo   This is the XZ compressor easter egg. ^_^
echo.
pause >nul
:GAME_END
set "GAMENUM=" & set "GAMETRIES=" & set "GUESSED="
goto :MAINMENU

:HELP
:CLI_GATE
set "ALLARGS=%*"
call :LOG "命令行参数: %*"
goto :PARSE_CLI
:PARSE_CLI_RET
goto :STARTUP

:HELP_SHOW
chcp 936 >nul 2>&1 <nul
echo.
echo  ============================================================
echo    %APP% %VER%  命令行用法
echo  ============================================================
echo.
echo  交互模式: 直接双击或运行 xz-compressor.cmd
echo  拖拽模式: 把文件/文件夹拖到脚本上
echo  命令行:
echo    xz-compressor.cmd ^<文件/文件夹^> [选项]
echo.
echo  选项:
echo    --format xz^|zip^|7z^|gz^|bz2^|tgz   压缩格式(默认 xz)
echo    --level 0..9                        压缩等级(默认 9)
echo    --out ^<输出文件^>                     指定输出路径
echo    --sfx exe^|apk                       生成自解压 EXE/APK
echo    --pass ^<密码^>                        加密(zip/7z/加密容器)
echo    --solid                             7z 固实压缩
echo    --volume ^<大小^>                      分卷
echo    --sha256                            生成 SHA256 校验
echo    --yes                               全部确认, 不询问
echo    /h /? --help                        显示本帮助
echo.
echo  示例:
echo    xz-compressor.cmd data.txt --format xz --level 9 --yes
echo    xz-compressor.cmd folder --format 7z --pass 123456 --solid --yes
echo.
goto :QUIT

call :LOG "================================================"
call :LOG "%APP% %VER% 启动"

:STARTUP
rem ============ 引擎检测 ============
call :DETECT
call :LOG "引擎: 7z=!SZIP!  sfx=!SFXMOD!  tar=!TAREXE!  csc=!CSC!  xz=!XZEXE!"

cls
echo.
echo  ============================================================
echo    %APP% %VER%   --  xz 极致压缩 / 自解压 exe+apk / 多形式加密 / 工具下载
echo  ============================================================
echo    [引擎检测]  7-Zip: !SZIP!
if defined SFXMOD echo                自解压模块: !SFXMOD!
echo                系统 tar: !TAREXE!
echo                .NET 编译器: !CSC!
if defined XZEXE echo                xz.exe: !XZEXE!
echo  ============================================================
echo.

rem ============ 拖入模式: 直接把文件/文件夹拖到脚本上 ============
if not "%~1"=="" (
  set "DRAGMODE=1"
  set "IN=%~1"
)
if "!DRAGMODE!"=="1" (
  set "ARGN=0"
  for %%a in (%*) do set /a ARGN+=1
  if !ARGN! gtr 1 set "MULTI=1"
)
if "!DRAGMODE!"=="1" call :LOG "拖入模式: !IN! (参数数=!ARGN!)"
if "!DRAGMODE!"=="1" call :CHECK_INPUT
if "!DRAGMODE!"=="1" if errorlevel 1 goto :END
if "!DRAGMODE!"=="1" goto :AFTER_INPUT

:MAINMENU
set "MENU="
cls
echo.
echo  ============================================================
echo    %APP% %VER%
echo    xz 极致压缩 / exe+apk 自解压 / zip+7z / 多形式加密 / 解压 / 修复 / 工具下载
echo  ============================================================
echo.
echo    请选择功能:
echo      [0] 打开压缩文件  (列表/搜索/预览/添加/解压/移除/注释/加解密)
echo      [1] 压缩文件 （文件 / 文件夹 / 批量添加 · xz/zip/7z/gz/bz2）
echo      [2] 工具集  (批量加密 / 压缩率对比 / 校验值 / 定时备份 / 右键菜单 /
echo                    图形界面 / 历史记录 / 预设 / 自检)
echo      [3] 创建便携程序/安装器（HTML版 · 安卓完整版 · Windows完整版 · 安装器 · 鸿蒙）
echo      [4] 所需工具下载（缺少引擎时打开官网 / 一键安装）
echo      [5] 修复损坏文件（zip/7z/xz/exe/apk/rar）
echo      [6] 网络功能  (公告 / 投票 / 我要反馈)
echo      [Q] 退出
echo.
if defined XZCP_AUTO if defined XZCP_MENU set "MENU=!XZCP_MENU!"
if not defined MENU (
  choice /c 0123456QE /n /m "请选择: "
  set "EL=!ERRORLEVEL!"
  if !EL! EQU 1 set "MENU=0"
  if !EL! EQU 2 set "MENU=1"
  if !EL! EQU 3 set "MENU=2"
  if !EL! EQU 4 set "MENU=3"
  if !EL! EQU 5 set "MENU=4"
  if !EL! EQU 6 set "MENU=5"
  if !EL! EQU 7 set "MENU=6"
  if !EL! EQU 8 set "MENU=q"
  if !EL! EQU 9 set "MENU=egg"
)
if defined XZCP_AUTO if not defined MENU goto :QUIT
if /i "!MENU!"=="q" goto :QUIT
if /i "!MENU!"=="彩蛋" goto :EASTEREGG
if /i "!MENU!"=="easter" goto :EASTEREGG
if /i "!MENU!"=="egg" goto :EASTEREGG
if /i "!MENU!"=="secret" goto :EASTEREGG
if /i "!MENU!"=="666" goto :EASTEREGG
if "!MENU!"=="0" goto :OPENARC
if "!MENU!"=="1" goto :COMPRESS_MENU
if "!MENU!"=="2" goto :TOOLSET
if "!MENU!"=="3" goto :PORTABLE
if "!MENU!"=="4" goto :TOOLDOWN
if "!MENU!"=="5" goto :REPAIR
if "!MENU!"=="6" goto :NETMENU
goto :MAINMENU

:NETMENU
set "NM="
set "SERVER=http://127.0.0.1:14923"
cls
echo.
echo  ============================================================
echo    网络功能
echo  ============================================================
echo.
echo      [1] 查看最新公告
echo      [2] 查看当前投票
echo      [3] 我要反馈
echo      [Q] 返回主菜单
echo.
if not defined NM (
  choice /c 123Q /n /m "请选择: "
  set "EL=!ERRORLEVEL!"
  if !EL! EQU 1 set "NM=1"
  if !EL! EQU 2 set "NM=2"
  if !EL! EQU 3 set "NM=3"
  if !EL! EQU 4 set "NM=q"
)
if /i "!NM!"=="q" goto :MAINMENU
if "!NM!"=="1" goto :NET_ANNOUNCE
if "!NM!"=="2" goto :NET_POLL
if "!NM!"=="3" goto :NET_FEEDBACK
goto :NETMENU

:NET_ANNOUNCE
cls
echo  ---- 最新公告 ----
curl -s -m 15 "!SERVER!/xz/announce"
echo.
pause
goto :NETMENU

:NET_POLL
cls
echo  ---- 当前投票 ----
curl -s -m 15 "!SERVER!/xz/polls"
echo.
echo  (投票请用浏览器打开后台)
pause
goto :NETMENU

:NET_FEEDBACK
cls
echo  ---- 我要反馈 ----
set "FB_TITLE="
set "FB_CONTENT="
set /p "FB_TITLE=标题: "
set /p "FB_CONTENT=内容: "
if not defined FB_CONTENT goto :NETMENU
curl -s -m 15 -X POST --data-urlencode "type=建议" --data-urlencode "title=!FB_TITLE!" --data-urlencode "content=!FB_CONTENT!" "!SERVER!/xz/feedback"
echo.
echo  反馈已发送，感谢！
pause
set "FB_TITLE=" & set "FB_CONTENT="
goto :NETMENU

:COMPRESS_MENU
set "CMENU="
cls
echo.
echo  ============================================================
echo    压缩文件 （选择压缩对象类型）
echo  ============================================================
echo      [1] 压缩文件    弹出窗口选择文件
echo      [2] 压缩文件夹  弹出窗口选择文件夹
echo      [3] 添加压缩文件  批量压缩（列表管理）
echo      [Q] 返回主菜单
echo.
if defined XZCP_AUTO if defined XZCP_CMENU set "CMENU=!XZCP_CMENU!"
if not defined CMENU set /p "CMENU=请选择: "
if defined XZCP_AUTO if not defined CMENU goto :QUIT
if /i "!CMENU!"=="q" (if defined XZCP_AUTO (goto :QUIT) else (goto :MAINMENU))
if "!CMENU!"=="1" goto :ASK_INPUT
if "!CMENU!"=="2" goto :BROWSE_DIR
if "!CMENU!"=="3" goto :LIST_MENU
goto :COMPRESS_MENU

rem ============ 批量压缩列表管理 ============
:LIST_MENU
if not defined XZCOUNT set "XZCOUNT=0"
:LIST_LOOP
set "LISTIN="
cls
echo.
echo  ============================================================
echo    添加压缩文件 （批量压缩列表）
echo  ============================================================
echo    当前列表（共 !XZCOUNT! 项）:
if "!XZCOUNT!"=="0" echo     （列表为空, 请先添加）
set /a XZ_I=1
:LIST_SHOW
if !XZ_I! gtr !XZCOUNT! goto :LIST_SHOW_END
call set "LI=%%XZL_!XZ_I!%%"
if defined LI echo     !XZ_I!. !LI!
set /a XZ_I+=1
goto :LIST_SHOW
:LIST_SHOW_END
echo.
echo      [Q] 退出（返回）
echo      [2] 添加压缩文件
echo      [3] 移除列表中的文件（输入序号）
echo      [4] 确定, 开始压缩
echo.
if defined XZCP_AUTO if defined XZCP_LDONE goto :LIST_DONE
if defined XZCP_AUTO if defined XZCP_LACT set "LISTIN=!XZCP_LACT!"
if not defined LISTIN set /p "LISTIN=请选择: "
if /i "!LISTIN!"=="q" goto :LIST_QUIT
if "!LISTIN!"=="2" goto :LIST_ADD
if "!LISTIN!"=="3" goto :LIST_DEL
if "!LISTIN!"=="4" goto :LIST_DONE
goto :LIST_LOOP

:LIST_ADD
set "XZNEW="
if defined XZCP_AUTO if defined XZCP_LADD (
  for %%P in (!XZCP_LADD!) do (
    set "XZNEW=%%P"
    call :LIST_ADD_ONE
  )
  goto :LIST_DONE
)
echo  [选择] 请在文件资源管理器中选择要添加的文件 (可多选) ...
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='添加压缩文件(可多选)'; $f.Multiselect=$true; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllLines('!PICK!',$f.FileNames,[Text.Encoding]::Default)}"
if not exist "!PICK!" (
  echo  [提示] 未选择文件, 已取消。
  if not defined XZCP_AUTO pause
  goto :LIST_LOOP
)
for /f "usebackq delims=" %%L in ("!PICK!") do (
  set "XZNEW=%%L"
  call :LIST_ADD_ONE
)
del "!PICK!" >nul 2>&1
goto :LIST_LOOP

:LIST_ADD_ONE
if not defined XZNEW exit /b 0
set "XZNEW=!XZNEW:"=!"
if not exist "!XZNEW!" (
  echo  [错误] 找不到该路径: !XZNEW!
  if not defined XZCP_AUTO pause
  exit /b 0
)
set /a XZCOUNT+=1
call set "XZL_!XZCOUNT!=%%XZNEW%%"
echo  [已添加] !XZCOUNT!. !XZNEW!
if not defined XZCP_AUTO pause
exit /b 0

:LIST_DEL
set "XZDEL="
set /p "XZDEL=请输入要移除的序号 (直接回车=取消): "
if "!XZDEL!"=="" goto :LIST_LOOP
set "XZ_FOUND=0"
set /a XZ_N2=1
:LIST_DEL_LOOP
if !XZ_N2! gtr !XZCOUNT! goto :LIST_DEL_END
if "!XZ_N2!"=="!XZDEL!" (
  set "XZ_FOUND=1"
  call set "XZ_TMP=%%XZL_!XZ_N2!%%"
  echo  [已移除] !XZ_N2!. !XZ_TMP!
  set /a XZ_N3=!XZ_N2!
  :LIST_SHIFT
  set /a XZ_N4=!XZ_N3!+1
  if !XZ_N4! gtr !XZCOUNT! goto :LIST_SHIFT_END
  call set "XZL_!XZ_N3!=%%XZL_!XZ_N4!%%"
  set /a XZ_N3+=1
  goto :LIST_SHIFT
  :LIST_SHIFT_END
  call set "XZL_!XZCOUNT!="
  set /a XZCOUNT-=1
)
set /a XZ_N2+=1
goto :LIST_DEL_LOOP
:LIST_DEL_END
if "!XZ_FOUND!"=="0" echo  [错误] 序号 !XZDEL! 不在列表中。
if not defined XZCP_AUTO pause
goto :LIST_LOOP

:LIST_DONE
if "!XZCOUNT!"=="0" (
  echo  [错误] 列表为空, 请先添加文件。
  if not defined XZCP_AUTO pause
  goto :LIST_LOOP
)
set "MULTI=1"
set "ALLARGS="
set /a XZ_J=1
:LIST_ARG
if !XZ_J! gtr !XZCOUNT! goto :LIST_ARG_END
call set "XZITEM=%%XZL_!XZ_J!%%"
set "ALLARGS=!ALLARGS! "!XZITEM!""
set /a XZ_J+=1
goto :LIST_ARG
:LIST_ARG_END
call set "IN=%%XZL_1%%"
call :CHECK_INPUT
if errorlevel 1 goto :LIST_QUIT
echo  [信息] 批量压缩 !XZCOUNT! 个文件/文件夹。
goto :GETTYPE

:LIST_QUIT
set "XZCOUNT="
set /a XZ_K=1
:LIST_CLR
if !XZ_K! gtr 40 goto :LIST_CLR_END
call set "XZL_!XZ_K!="
set /a XZ_K+=1
goto :LIST_CLR
:LIST_CLR_END
if defined XZCP_AUTO goto :QUIT
goto :COMPRESS_MENU

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
if errorlevel 1 (
  if defined XZCP_AUTO goto :QUIT
  goto :MAINMENU
)
goto :AFTER_INPUT

:BROWSE_FILE
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要压缩的文件'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
if not exist "!PICK!" (
  echo  [提示] 未选择文件, 已取消。
  pause
)
if not exist "!PICK!" goto :MAINMENU
for /f "usebackq delims=" %%L in ("!PICK!") do set "IN=%%L"
del "!PICK!" >nul 2>&1
if not defined IN (
  echo  [提示] 未选择文件, 已取消。
  pause
)
if not defined IN goto :MAINMENU
call :CHECK_INPUT
if errorlevel 1 (
  if defined XZCP_AUTO goto :QUIT
  goto :MAINMENU
)
goto :AFTER_INPUT

:BROWSE_DIR
if defined XZCP_AUTO if defined XZCP_IN (
  set "IN=!XZCP_IN!"
  call :CHECK_INPUT
  if errorlevel 1 (goto :QUIT) else (goto :AFTER_INPUT)
)
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='选择要压缩的文件夹'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.SelectedPath,[Text.Encoding]::Default)}"
if not exist "!PICK!" (
  echo  [提示] 未选择文件夹, 已取消。
  pause
)
if not exist "!PICK!" goto :MAINMENU
for /f "usebackq delims=" %%L in ("!PICK!") do set "IN=%%L"
del "!PICK!" >nul 2>&1
if not defined IN (
  echo  [提示] 未选择文件夹, 已取消。
  pause
)
if not defined IN goto :MAINMENU
call :CHECK_INPUT
if errorlevel 1 (
  if defined XZCP_AUTO goto :QUIT
  goto :MAINMENU
)
goto :AFTER_INPUT

rem ============ 输入校验 ============
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
  echo  [错误] 输入为空。
  exit /b 1
)
if exist "!IN!\" (
  set "ISDIR=1"
) else if exist "!IN!" (
  set "ISDIR=0"
) else (
  echo  [错误] 找不到该路径: !IN!
  echo         请检查: 路径是否正确 / 盘符是否存在 / 是否有访问权限。
  call :LOG "输入路径不存在: !IN!"
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
call :LOG "输入: !IN!  (文件夹=!ISDIR!  多文件=!MULTI!)"
exit /b 0

rem ============ 输入完成 ============
:AFTER_INPUT
if "!ISDIR!"=="1" echo  [信息] 输入为文件夹, 将打包为 tar.xz 容器。
if "!MULTI!"=="1" echo  [信息] 多个独立文件, 将打包为 tar.xz 容器。

rem ============ 第一步：压缩格式 ============
:GETTYPE
set "FMAT="
set "PACK="
echo.
echo  ============================================================
echo    第一步：选择压缩格式
echo  ============================================================
echo      [1] xz   极限压缩, 体积最小 (文件夹/多文件用 tar.xz)
echo      [2] zip  通用格式, 兼容性最好
echo      [3] 7z   高压缩率, 支持固实/分卷/恢复记录
echo      [4] gzip  (.gz)   单文件快速压缩, 通用
echo      [5] bzip2 (.bz2)  单文件高压缩
echo      [6] tgz   (tar.gz) 文件夹/多文件 gzip 压缩包
echo.
if defined XZCP_AUTO if defined XZCP_FMAT set "FMAT=!XZCP_FMAT!"
if not defined FMAT (
  if defined XZCP_AUTO if defined XZCP_OUTTYPE (
    if "!XZCP_OUTTYPE!"=="1" set "FMAT=xz"
    if "!XZCP_OUTTYPE!"=="2" set "FMAT=7z"
    if "!XZCP_OUTTYPE!"=="3" set "FMAT=zip"
    if "!XZCP_OUTTYPE!"=="4" set "FMAT=zip"
    if "!XZCP_OUTTYPE!"=="5" set "FMAT=7z"
  )
)
if not defined FMAT set /p "FMAT=请选择压缩格式 1-6 (直接回车=1): "
if "!FMAT!"=="" set "FMAT=1"
if "!FMAT!"=="1" set "FMAT=xz"
if "!FMAT!"=="2" set "FMAT=zip"
if "!FMAT!"=="3" set "FMAT=7z"
if "!FMAT!"=="4" set "FMAT=gz"
if "!FMAT!"=="5" set "FMAT=bz2"
if "!FMAT!"=="6" set "FMAT=tgz"
if not "!FMAT!"=="xz" if not "!FMAT!"=="zip" if not "!FMAT!"=="7z" if not "!FMAT!"=="gz" if not "!FMAT!"=="bz2" if not "!FMAT!"=="tgz" (
  echo  [错误] 只能输入 1 到 6
  goto :GETTYPE
)
if "!FMAT!"=="gz" goto :PACK_FORCE0
if "!FMAT!"=="bz2" goto :PACK_FORCE0
if "!FMAT!"=="tgz" goto :PACK_FORCE0
echo.
echo  ============================================================
echo    第二步：选择输出形式 (便携性)
echo  ============================================================
echo      [0] 普通压缩包 (.xz/.zip/.7z)
echo      [1] EXE 自解压  (Windows 双击即解压, 无需安装软件)
echo      [2] APK 自解压  (安卓安装后一键解压)
echo.
if defined XZCP_AUTO if defined XZCP_PACK set "PACK=!XZCP_PACK!"
if not defined PACK (
  if defined XZCP_AUTO if defined XZCP_OUTTYPE (
    if "!XZCP_OUTTYPE!"=="2" set "PACK=1"
    if "!XZCP_OUTTYPE!"=="3" set "PACK=2"
  )
)
if not defined PACK set /p "PACK=请选择输出形式 0/1/2 (直接回车=0): "
if "!PACK!"=="" set "PACK=0"
if not "!PACK!"=="0" if not "!PACK!"=="1" if not "!PACK!"=="2" (
  echo  [错误] 只能输入 0、1 或 2
  goto :GETTYPE
)
:PACK_FORCE0
if "!FMAT!"=="gz" set "PACK=0"
if "!FMAT!"=="bz2" set "PACK=0"
if "!FMAT!"=="tgz" set "PACK=0"
rem ---- 映射内部 OUTTYPE: 1=xz 2=exe 3=apk 4=zip 5=7z 6=gz 7=bz2 8=tgz ----
if "!PACK!"=="1" set "OUTTYPE=2"
if "!PACK!"=="2" set "OUTTYPE=3"
if "!PACK!"=="0" (
  if "!FMAT!"=="xz" set "OUTTYPE=1"
  if "!FMAT!"=="zip" set "OUTTYPE=4"
  if "!FMAT!"=="7z" set "OUTTYPE=5"
  if "!FMAT!"=="gz" set "OUTTYPE=6"
  if "!FMAT!"=="bz2" set "OUTTYPE=7"
  if "!FMAT!"=="tgz" set "OUTTYPE=8"
)
if "!PACK!"=="1" echo  [信息] 输出格式: .exe 自解压, 内置 !FMAT! 压缩数据
if "!PACK!"=="2" echo  [信息] 输出格式: .apk 自解压, 内置 !FMAT! 压缩数据
if "!PACK!"=="0" echo  [信息] 输出格式: !FMAT!
call :LOG "压缩格式: !FMAT!  封装: !PACK!  (OUTTYPE=!OUTTYPE!)"

rem ============ 图标 / 签名 / 加密询问 ============
:OUTTYPE_ASK
if "!PACK!"=="1" call :ASK_ICON
if "!PACK!"=="2" call :ASK_ICON
if "!PACK!"=="2" call :ASK_APKSIGN
if "!PACK!"=="2" call :ASK_API
call :ASK_PASS
if "!PACK!"=="1" if "!FMAT!"=="xz" if defined PASS (
  echo  [提示] xz 自解压 EXE 不支持加密, 已忽略密码（普通 xz 包会生成 .enc.zip）
  set "PASS="
  set "PWARG="
)
if "!PACK!"=="2" if "!FMAT!"=="xz" if defined PASS (
  echo  [提示] xz 自解压 APK 不支持加密, 已忽略密码
  set "PASS="
  set "PWARG="
)
rem ---- v11 压缩档位与高级参数 ----
call :ASK_LEVEL
call :ASK_ADVOPTS

rem ============ 引擎检测（不满足则停止） ============
call :CHECK_ENGINE
if errorlevel 1 goto :END

rem ============ 生成输出文件名并检查 ============
call :BUILD_OUT
if errorlevel 1 goto :END

rem ============ 开始压缩 ============
call :DO_COMPRESS
if errorlevel 1 goto :END_ERR

rem ============ 校验 ============
call :VERIFY

rem ============ 结果汇总 ============
call :SUMMARY

:AFTER_DONE
set "AGAIN="
echo.
if defined XZCP_AUTO if defined XZCP_AGAIN set "AGAIN=!XZCP_AGAIN!"
if not defined AGAIN set /p "AGAIN=按 R 再压缩一个, 直接回车退出: "
if /i "!AGAIN!"=="r" (
  set "IN="
  set "ISDIR=0"
  set "MULTI=0"
  set "OUTTYPE="
  set "FMAT="
  set "PACK="
  set "LV=9"
  set "EC=0"
  set "EXEBACKEND="
  set "VOL="
  set "SOLID="
  set "DICT="
  set "MTN="
  set "RR="
  set "ZOPTS="
  set "ZOPTSS="
  set "DOBEEP="
  set "DOSHA="
  set "PASS="
  set "PWARG="
  set "PASSOPT="
  set "ENCTYPE="
)
if /i "!AGAIN!"=="r" goto :MAINMENU
goto :QUIT

rem ============ 引擎检测 ============
:DETECT
rem ---- 优先检测脚本/便携自带 7-Zip（无环境运行） ----
if exist "%SD%7z.exe" set "SZIP=%SD%7z.exe"
if not defined SZIP if exist "%SD%portable\7z.exe" set "SZIP=%SD%portable\7z.exe"
if defined SZIP (
  for %%D in ("!SZIP!") do set "SZDIR=%%~dpD"
  if exist "!SZDIR!7z.sfx" set "SFXMOD=!SZDIR!7z.sfx"
  if not defined SFXMOD if exist "!SZDIR!7zS.sfx" set "SFXMOD=!SZDIR!7zS.sfx"
  if not defined SFXMOD if exist "!SZDIR!7zCon.sfx" set "SFXMOD=!SZDIR!7zCon.sfx"
)
rem ---- 7-Zip (注册表优先) ----
for /f "tokens=2,* delims= " %%a in ('reg query "HKLM\SOFTWARE\7-Zip" /v Path 2^>nul') do if not defined SZIP if exist "%%b7z.exe" set "SZIP=%%b7z.exe"
if not defined SZIP if exist "%ProgramFiles%\7-Zip\7z.exe" set "SZIP=%ProgramFiles%\7-Zip\7z.exe"
if not defined SZIP if exist "%ProgramFiles(x86)%\7-Zip\7z.exe" set "SZIP=%ProgramFiles(x86)%\7-Zip\7z.exe"
if not defined SZIP if exist "%ProgramW6432%\7-Zip\7z.exe" set "SZIP=%ProgramW6432%\7-Zip\7z.exe"
if not defined SZIP (
  where 7z >nul 2>&1 && set "SZIP=7z"
)
if defined SZIP (
  for %%D in ("!SZIP!") do set "SZDIR=%%~dpD"
  if exist "!SZDIR!7z.sfx" set "SFXMOD=!SZDIR!7z.sfx"
  if not defined SFXMOD if exist "!SZDIR!7zS.sfx" set "SFXMOD=!SZDIR!7zS.sfx"
  if not defined SFXMOD if exist "!SZDIR!7zCon.sfx" set "SFXMOD=!SZDIR!7zCon.sfx"
)
rem ---- 测试开关: 设环境变量 XZCP_NO7Z=1 可强制跳过 7-Zip ----
if /i "%XZCP_NO7Z%"=="1" (
  set "SZIP="
  set "SFXMOD="
)
rem ---- xz.exe (XZ Utils 原生) ----
if exist "%SD%tools\xz\xz.exe" set "XZEXE=%SD%tools\xz\xz.exe"
if not defined XZEXE if exist "%ProgramFiles%\xz\bin\xz.exe" set "XZEXE=%ProgramFiles%\xz\bin\xz.exe"
if not defined XZEXE if exist "%ProgramFiles(x86)%\xz\bin\xz.exe" set "XZEXE=%ProgramFiles(x86)%\xz\bin\xz.exe"
if not defined XZEXE where xz >nul 2>&1 && set "XZEXE=xz"
rem ---- tar.exe ----
if not exist "%TAREXE%" (
  where tar >nul 2>&1
  if not errorlevel 1 set "TAREXE=tar"
)
if not exist "%TAREXE%" set "TAREXE="
rem ---- csc.exe (.NET Framework 编译器) ----
if exist "%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not defined CSC if exist "%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe" set "CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not defined CSC where csc >nul 2>&1 && set "CSC=csc"
exit /b 0

rem ============ 引擎检查（按输出类型） ============
:CHECK_ENGINE
if "!OUTTYPE!"=="1" call :CK_XZ
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="2" call :CK_EXE
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="3" call :CK_APK
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="4" call :CK_ZIP
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="5" call :CK_7Z
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="6" call :CK_GZ
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="7" call :CK_GZ
if errorlevel 1 exit /b 1
if "!OUTTYPE!"=="8" call :CK_GZ
if errorlevel 1 exit /b 1
exit /b 0

:CK_XZ
if not "!ISDIR!"=="1" if not "!MULTI!"=="1" (
  if defined SZIP exit /b 0
  if defined XZEXE exit /b 0
  if defined TAREXE exit /b 0
  echo  [错误] 缺少 xz 压缩引擎。
  echo         请安装 7-Zip （https://www.7-zip.org） 后重试,
  echo         或确认系统为 Windows 10 及以上 （自带 tar.exe 可压 xz）。
  echo         也可在主菜单 [5] 所需工具下载 打开官网或一键安装。
  call :LOG "缺少 xz 引擎"
  pause
  exit /b 1
)
if defined TAREXE exit /b 0
echo  [错误] 文件夹/多文件压成 xz 需要系统自带 tar.exe （Windows 10+）。
echo         当前系统未找到 tar.exe。可改压单个文件, 或安装 7-Zip 后选 .exe 输出。
call :LOG "缺少 tar.exe"
pause
exit /b 1

:CK_EXE
if defined CSC (
  if "!FMAT!"=="xz" (
    if defined TAREXE exit /b 0
    if defined SZIP exit /b 0
  ) else (
    if defined SZIP exit /b 0
  )
)
if "!FMAT!"=="7z" if not defined XZ_ICON if defined SZIP if defined SFXMOD exit /b 0
echo  [错误] 生成自解压 exe 需要:
if "!FMAT!"=="xz" (
  echo         Windows 10+ 自带的 tar.exe 或 7-Zip, 以及 .NET Framework 编译器 csc.exe
) else (
  echo         7-Zip（作为内置解压引擎）及 .NET Framework 编译器 csc.exe
)
echo         也可以按菜单 [5] 所需工具下载 打开官网一键安装。
call :LOG "缺少 exe 生成条件 (FMAT=!FMAT!)"
pause
exit /b 1

:CK_APK
if not exist "!SD!build_apk.cmd" (
  echo  [错误] 缺少构建脚本 build_apk.cmd, 请确认脚本在同一目录。
  pause
  exit /b 1
)
if not exist "!SD!android\AndroidManifest.xml" (
  echo  [错误] 缺少安卓模板目录 android\, 请确认脚本在同一目录。
  pause
  exit /b 1
)
if "!FMAT!"=="xz" (
  if defined TAREXE exit /b 0
  if defined SZIP exit /b 0
) else (
  if defined SZIP exit /b 0
)
echo  [错误] 生成 APK 自解压需要 7-Zip 或系统 tar 来生成压缩数据。
echo         请先安装 7-Zip，或按菜单 [5] 一键安装。
call :LOG "缺少 APK 生成条件 (FMAT=!FMAT!)"
pause
exit /b 1

:BUILD_OUT
set "EXT="
if "!PACK!"=="1" (
  set "EXT=.exe"
) else if "!PACK!"=="2" (
  set "EXT=.apk"
) else (
  if "!FMAT!"=="xz" (
    if "!ISDIR!"=="1" set "EXT=.tar.xz"
    if "!MULTI!"=="1" set "EXT=.tar.xz"
    if not defined EXT set "EXT=.xz"
  )
  if "!FMAT!"=="zip" set "EXT=.zip"
  if "!FMAT!"=="7z" set "EXT=.7z"
  if "!FMAT!"=="gz" (
    if "!ISDIR!"=="1" set "EXT=.tar.gz"
    if "!MULTI!"=="1" set "EXT=.tar.gz"
    if not defined EXT set "EXT=.gz"
  )
  if "!FMAT!"=="bz2" (
    if "!ISDIR!"=="1" set "EXT=.tar.bz2"
    if "!MULTI!"=="1" set "EXT=.tar.bz2"
    if not defined EXT set "EXT=.bz2"
  )
  if "!FMAT!"=="tgz" set "EXT=.tar.gz"
)
set "OUT=!OUTDIR!!INBASE!_L!LV!!EXT!"
call :LOG "输出文件: !OUT!"
if exist "!OUT!" (
  echo.
  echo  [提示] 输出文件已存在: !OUT!
  set "OW="
  if defined XZCP_AUTO if defined XZCP_OW set "OW=!XZCP_OW!"
  if not defined OW set /p "OW=[Y]覆盖  [N]另存新文件  [C]取消: "
  if /i "!OW!"=="n" set "OUT=!OUTDIR!!INBASE!_L!LV!_!RANDOM!!EXT!"
  if /i "!OW!"=="c" (
    echo  取消压缩
    exit /b 1
  )
  if /i "!OW!"=="y" del /f /q "!OUT!" >nul 2>&1
  if "!OW!"=="" del /f /q "!OUT!" >nul 2>&1
)
exit /b 0

:RUN_PROG
rem 输入: PMODE=add|extract, PROGCMD=参数行, SZIP=引擎路径
if not defined PROGEXE set "PROGEXE=!SZIP!"
set "XZ_CMDLINE=!PROGCMD!"
call :LOG "进度条执行: !PROGEXE! !PROGCMD!"
"!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\runprog.ps1" -Exe "!PROGEXE!" -Mode !PMODE!
set "EC=!errorlevel!"
set "XZ_CMDLINE="
set "PROGEXE="
exit /b !EC!

:DO_COMPRESS
if defined CLIOUT for %%F in ("!CLIOUT!") do set "OUT=%%~fF"
call :LOG "开始压缩 (格式 !FMAT! 封装 !PACK! 等级 !LV!)"
set "T0=%time%"
if "!PACK!"=="1" call :RUN_EXE
if errorlevel 1 exit /b 1
if "!PACK!"=="2" call :RUN_APK
if errorlevel 1 exit /b 1
if "!PACK!"=="0" (
  if "!FMAT!"=="xz" call :RUN_XZ
  if "!FMAT!"=="zip" call :RUN_ZIP
  if "!FMAT!"=="7z" call :RUN_7Z
  if "!FMAT!"=="gz" call :RUN_GZ
  if "!FMAT!"=="bz2" call :RUN_BZ2
  if "!FMAT!"=="tgz" call :RUN_TGZ
)
if errorlevel 1 exit /b 1
exit /b 0

:RUN_XZ
set "XZC_ENC="
if defined PASS (
  echo  [提示] .xz 格式本身不支持加密。
  echo         压缩后将额外生成 AES-256 加密容器（.enc.zip, 内含 .xz 文件）。
  set "XZC_ENC=1"
)
if "!ISDIR!"=="1" goto :XZ_TAR
if "!MULTI!"=="1" goto :XZ_TAR
if defined XZEXE goto :XZ_XZEXE
if defined SZIP goto :XZ_7Z
goto :XZ_TAR

:XZ_7Z
set "PROGCMD=a -txz -mx=!LV! -mmt=on -bsp1 "!OUT!" "!IN!""
echo.
echo  [7-Zip] 正在压缩为 .xz ...
set "PMODE=add"
call :RUN_PROG
call :LOG "7-Zip 退出码: !EC!"
if "!EC!"=="0" (call :XZ_FINISH & exit /b 0)
if "!EC!"=="1" (
  echo  [警告] 7-Zip 报告了警告, 已继续。
  call :LOG "警告: 7-Zip 退出码 1"
  call :XZ_FINISH & exit /b 0
)
goto :FAIL_7Z

:XZ_XZEXE
echo.
echo  [xz.exe] 正在压缩为 .xz ...
set "PROGEXE=!XZEXE!"
set "PROGCMD=-!LV! -k -f -v "!IN!""
set "PMODE=add"
call :RUN_PROG
set "EC=!errorlevel!"
call :LOG "xz 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_XZ
if exist "!IN!.xz" move /y "!IN!.xz" "!OUT!" >nul 2>&1
if not exist "!OUT!" (
  echo  [错误] xz 输出文件未生成, 请检查日志。
  goto :FAIL_XZ
)
call :XZ_FINISH & exit /b 0

:XZ_TAR
echo.
echo  [tar] 正在压缩为 tar.xz （文件夹/多文件） ...
if "!MULTI!"=="1" goto :XZ_TAR_MULTI
set "CMD="!TAREXE!" -a -c -J --options compression-level=!LV! -f "!OUT!" -C "!OUTDIRC!" "!INNAME!""
call :LOG "命令: !CMD!"
!CMD!
set "EC=!errorlevel!"
call :LOG "tar 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_TAR
call :XZ_FINISH & exit /b 0

:XZ_TAR_MULTI
set "TARARGS="
for %%F in (!ALLARGS!) do (
  for %%G in ("%%~fF") do set "TD=%%~dpG"
  for %%G in ("%%~fF") do set "TN=%%~nxG"
  set "TDT=!TD!"
  set "TDT=!TDT:\=/!"
  if "!TDT:~-1!"=="/" (
    set "TDT=!TDT:~0,-1!"
    if /i "!TDT!"=="!TDT:~0,2!" set "TDT=!TDT!/"
  )
  set "TARARGS=!TARARGS! -C "!TDT!" "!TN!""
)
set "CMD="!TAREXE!" -a -c -J --options compression-level=!LV! -f "!OUT!"!TARARGS!"
call :LOG "命令: !CMD!"
!CMD!
set "EC=!errorlevel!"
call :LOG "tar 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_TAR
call :XZ_FINISH & exit /b 0

rem ============ xz 加密容器 ============
:XZ_FINISH
if defined XZC_ENC if defined SZIP (
  echo  [容器] 正在生成 AES-256 加密容器 ...
  set "PROGCMD=a -tzip -mem=AES256 -bsp1 !PWARG! "!OUT!.enc.zip" "!OUT!""
  set "PMODE=add"
  call :RUN_PROG
  set "ECE=!EC!"
  if "!ECE!"=="0" (
    echo  [完成] 加密容器: !OUT!.enc.zip （AES-256, 内含 .xz）
    call :LOG "加密容器: !OUT!.enc.zip"
  ) else (
    echo  [警告] 加密容器生成失败, 退出码 !ECE!, 请检查 7-Zip。
    call :LOG "加密容器失败: !ECE!"
  )
)
exit /b 0

:RUN_EXE
rem 7z 格式且无图标: 优先 7z.sfx 原生自解压 (体积最小)
if "!FMAT!"=="7z" if not defined XZ_ICON if not defined PWARG if defined SZIP if defined SFXMOD goto :EXE_7Z
goto :EXE_CSC

:EXE_7Z
set "EXEARGS="
if defined PWARG set "EXEARGS=!PWARG! -mhe=on"
if "!MULTI!"=="1" (
  set "PROGCMD=a -sfx"!SFXMOD!" -bsp1 !ZOPTSS! !EXEARGS! "!OUT!" !ALLARGS!"
) else (
  set "PROGCMD=a -sfx"!SFXMOD!" -bsp1 !ZOPTSS! !EXEARGS! "!OUT!" "!IN!""
)
echo.
echo.
echo  [7-Zip] 正在生成自解压 exe ...
echo.
echo  [7-Zip] 正在生成自解压 exe ...
set "PMODE=add"
call :RUN_PROG
call :LOG "7-Zip 退出码: !EC!"
if "!EC!"=="0" (
  set "EXEBACKEND=7z"
  exit /b 0
)
if "!EC!"=="1" (
  echo  [警告] 7-Zip 报告了警告, 已继续。
  set "EXEBACKEND=7z"
  call :LOG "警告: 7-Zip 退出码 1"
  exit /b 0
)
goto :FAIL_7Z

rem ============ 通用 C# 自解压壳 (zip/7z/xz 三格式, 内置引擎) ============
:EXE_CSC
echo.
echo  [通用自解压] 使用 .NET 编译器生成自解压 exe ...
set "PAYBASE=%TEMP%\xz_payload_!RANDOM!"
set "PAYLOAD="
if "!FMAT!"=="xz" (
  set "PAYLOAD=!PAYBASE!.tar.xz"
  call :MAKE_PAYLOAD_TAR
  if errorlevel 1 goto :FAIL_TAR
) else (
  set "PAYLOAD=!PAYBASE!.!FMAT!"
  set "ENCARG="
  if defined PWARG (
    if "!FMAT!"=="zip" if "!ENCTYPE!"=="1" set "ENCARG=!PWARG!"
    if "!FMAT!"=="zip" if not "!ENCTYPE!"=="1" set "ENCARG=!PWARG! -mem=AES256"
    if "!FMAT!"=="7z" set "ENCARG=!PWARG!"
    if "!FMAT!"=="7z" if "!ENCTYPE!"=="3" set "ENCARG=!PWARG! -mhe=on"
  )
  if "!MULTI!"=="1" (
    set "CMD="!SZIP!" a -t!FMAT! !ZOPTSS! !ENCARG! "!PAYLOAD!" !ALLARGS!"
  ) else (
    set "CMD="!SZIP!" a -t!FMAT! !ZOPTSS! !ENCARG! "!PAYLOAD!" "!IN!""
  )
  call :LOG "命令: !CMD!"
  echo  [!FMAT!] 正在生成压缩数据 ...
  !CMD!
  set "EC=!errorlevel!"
  call :LOG "payload 压缩退出码: !EC!"
  if not "!EC!"=="0" goto :FAIL_7Z
)
if not exist "!PAYLOAD!" (
  call :FAIL "压缩数据未生成"
  exit /b 1
)
set "PAYEXT=!PAYLOAD:~-7!"
if /i "!PAYEXT!"==".tar.xz" (
  set "PAYEXT=tar.xz"
) else (
  for %%F in ("!PAYLOAD!") do set "PAYEXT=%%~xF"
  set "PAYEXT=!PAYEXT:~1!"
)

rem ---- 定位内置 7z 引擎 (zip/7z 必需; tar.xz 作为回退) ----
set "ENG7Z="
set "ENGDLL="
if defined SZIP for %%D in ("!SZIP!") do set "ENG7Z=%%~fD"
if not defined ENG7Z if exist "!SD!7z.exe" set "ENG7Z=!SD!7z.exe"
if not defined ENG7Z if exist "!SD!portable\7z.exe" set "ENG7Z=!SD!portable\7z.exe"
if exist "!ENG7Z!" for %%D in ("!ENG7Z!") do set "ENGDLL=%%~dpD7z.dll"
if not "!FMAT!"=="xz" if not exist "!ENG7Z!" (
  call :FAIL "未找到 7z.exe, 无法构建 !FMAT! 自解压 exe (可按菜单 [5] 安装)"
  exit /b 1
)

rem ---- 将引擎复制到临时目录(避免 csc 资源路径含空格被拆断) ----
set "E7Z="
set "E7D="
if exist "!ENG7Z!" (
  set "E7Z=%TEMP%\xz_e7z_!RANDOM!.exe"
  copy /y "!ENG7Z!" "!E7Z!" >nul 2>&1
  if exist "!ENGDLL!" (
    set "E7D=%TEMP%\xz_e7d_!RANDOM!.dll"
    copy /y "!ENGDLL!" "!E7D!" >nul 2>&1
  )
)

rem ---- 解码 C# 壳 ----
set "B64=%TEMP%\xz_cs_!RANDOM!.b64"
set "CSSRC=%TEMP%\xz_extractor_!RANDOM!.cs"
for /f "tokens=1,* delims=:" %%a in ('findstr /b "CSCB64:" "!SELF!"') do >>"!B64!" echo %%b
certutil -decode "!B64!" "!CSSRC!" >nul 2>&1
if not exist "!CSSRC!" (
  call :FAIL "C# 源码解码失败, 请检查临时目录权限"
  exit /b 1
)

echo  [编译] 正在编译自解压程序 (约几秒) ...
set "WINICON="
if defined XZ_ICON (
  set "ICEXT=!XZ_ICON:~-4!"
  if /i "!ICEXT!"==".ico" (
    set "WINICON=/win32icon:"!XZ_ICON!""
  ) else (
    set "ICOFILE=%TEMP%\xz_icon_!RANDOM!.ico"
    powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\imgtool.ps1" "!XZ_ICON!" "!ICOFILE!" ico >nul 2>&1
    if exist "!ICOFILE!" set "WINICON=/win32icon:"!ICOFILE!""
    if not defined WINICON echo  [提示] 图标转换失败, 使用无图标版本。
  )
)

set "SFXCFG="
if not defined XZCP_AUTO call :SFX_ADV
set "RESARGS=/resource:"!PAYLOAD!",arc.!PAYEXT!"
if exist "!E7Z!" set "RESARGS=!RESARGS! /resource:"!E7Z!",eng7z.exe"
if exist "!E7D!" set "RESARGS=!RESARGS! /resource:"!E7D!",eng7z.dll"
if defined SFXCFG if exist "!SFXCFG!" set "RESARGS=!RESARGS! /resource:"!SFXCFG!",sfx.cfg"
call :LOG "csc 资源: !RESARGS!"
"!CSC!" /nologo /optimize+ /codepage:65001 /target:exe !WINICON! "/out:!OUT!" !RESARGS! "!CSSRC!"
set "EC=!errorlevel!"
call :LOG "csc 退出码: !EC!"
del "!B64!" >nul 2>&1
del "!CSSRC!" >nul 2>&1
del "!SFXCFG!" >nul 2>&1
del "!PAYLOAD!" >nul 2>&1
del "!E7Z!" >nul 2>&1
del "!E7D!" >nul 2>&1
if not "!EC!"=="0" goto :FAIL_CSC
if not exist "!OUT!" (
  call :FAIL "exe 未生成, 请查看上方编译错误"
  exit /b 1
)
set "EXEBACKEND=csc"
exit /b 0

rem ============ 自解压高级选项 (标题/欢迎语/EULA/默认目录/解压后运行) ============
:SFX_ADV
echo.
echo   ---- 自解压高级选项（可选, 全部直接回车则使用默认）----
set "ADVASK="
set /p "ADVASK=是否自定义标题/欢迎语/许可协议/默认目录/解压后运行 (Y/N, 默认N): "
if /i not "!ADVASK!"=="Y" exit /b 0
set "SFXT="
set /p "SFXT=窗口标题(回车=默认): "
set "SFXW="
set /p "SFXW=欢迎语(回车=跳过): "
set "SFXEF="
set "EULAASK="
set /p "EULAASK=加入许可协议(解压前需同意) (Y/N, 默认N): "
if /i "!EULAASK!"=="Y" (
  set "EFPICK=%TEMP%\xz_eula_!RANDOM!.txt"
  echo   [选择] 请选择许可协议文本文件 .txt ...
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择许可协议文本'; $f.Filter='文本文件|*.txt|所有文件|*.*'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!EFPICK!',$f.FileName,[Text.Encoding]::Default)}"
  if exist "!EFPICK!" (
    for /f "usebackq delims=" %%L in ("!EFPICK!") do set "SFXEF=%%L"
    del "!EFPICK!"
  )
)
set "SFXD=CURRENT"
echo   默认解压目录:  [1] 当前目录(默认)  [2] EXE所在目录  [3] 自定义文件夹
set "DM="
set /p "DM=选择 [1/2/3]: "
if "!DM!"=="2" set "SFXD=EXE"
if "!DM!"=="3" (
  set "DMPICK=%TEMP%\xz_defdir_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='选择默认解压目录'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!DMPICK!',$f.SelectedPath,[Text.Encoding]::Default)}"
  if exist "!DMPICK!" (
    for /f "usebackq delims=" %%L in ("!DMPICK!") do set "SFXD=%%L"
    del "!DMPICK!"
  )
)
set "SFXR="
set /p "SFXR=解压后自动运行的【包内文件】(如 start.bat, 回车=不运行): "
if defined SFXR echo   [安全提示] 对方运行时会被明确询问是否运行该程序, 不会静默执行。
set "SFXCFG=%TEMP%\xz_sfxcfg_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\makesfxcfg.ps1" -out "!SFXCFG!" -title "!SFXT!" -welcome "!SFXW!" -eulaFile "!SFXEF!" -defdir "!SFXD!" -run "!SFXR!"
if not exist "!SFXCFG!" set "SFXCFG="
exit /b 0

rem ============ 生成 tar.xz payload (EXE/APK 共用) ============
:MAKE_PAYLOAD_TAR
echo  [tar] 正在生成 tar.xz 压缩数据 ...
if "!MULTI!"=="1" (
  set "TARARGS="
  for %%F in (!ALLARGS!) do (
    for %%G in ("%%~fF") do set "TD=%%~dpG"
    for %%G in ("%%~fF") do set "TN=%%~nxG"
    set "TDT=!TD!"
    set "TDT=!TDT:\=\/!"
    if "!TDT:~-1!"=="/" (
      set "TDT=!TDT:~0,-1!"
      if /i "!TDT!"=="!TDT:~0,2!" set "TDT=!TDT!/"
    )
    set "TARARGS=!TARARGS! -C "!TDT!" "!TN!""
  )
  set "CMD="!TAREXE!" -a -c -J --options compression-level=!LV! -f "!PAYLOAD!"!TARARGS!"
  call :LOG "命令: !CMD!"
  !CMD!
) else (
  set "CMD="!TAREXE!" -a -c -J --options compression-level=!LV! -f "!PAYLOAD!" -C "!OUTDIRC!" "!INNAME!""
  call :LOG "命令: !CMD!"
  !CMD!
)
set "EC=!errorlevel!"
call :LOG "tar payload 退出码: !EC!"
exit /b !EC!

:RUN_APK
echo.
echo  [APK] 正在生成安卓自解压安装包 (!FMAT!) ...
set "PAYBASE=%TEMP%\xz_apk_payload_!RANDOM!"
if "!FMAT!"=="xz" (
  set "PAYLOAD=!PAYBASE!.tar.xz"
  call :MAKE_PAYLOAD_TAR
  if errorlevel 1 goto :FAIL_APK
) else (
  set "PAYLOAD=!PAYBASE!.!FMAT!"
  set "ENCARG="
  if defined PWARG (
    if "!FMAT!"=="zip" if "!ENCTYPE!"=="1" set "ENCARG=!PWARG!"
    if "!FMAT!"=="zip" if not "!ENCTYPE!"=="1" set "ENCARG=!PWARG! -mem=AES256"
    if "!FMAT!"=="7z" set "ENCARG=!PWARG!"
    if "!FMAT!"=="7z" if "!ENCTYPE!"=="3" set "ENCARG=!PWARG! -mhe=on"
  )
  if "!MULTI!"=="1" (
    set "CMD="!SZIP!" a -t!FMAT! !ZOPTSS! !ENCARG! "!PAYLOAD!" !ALLARGS!"
  ) else (
    set "CMD="!SZIP!" a -t!FMAT! !ZOPTSS! !ENCARG! "!PAYLOAD!" "!IN!""
  )
  call :LOG "命令: !CMD!"
  !CMD!
  set "EC=!errorlevel!"
  call :LOG "payload 压缩退出码: !EC!"
  if not "!EC!"=="0" goto :FAIL_APK
)
if not exist "!PAYLOAD!" goto :FAIL_APK
set "APKARGS="
if defined XZ_PKG set "APKARGS=!APKARGS! /pkg:!XZ_PKG!"
if defined XZ_ALIAS set "APKARGS=!APKARGS! /alias:!XZ_ALIAS!"
if defined XZ_API set "APKARGS=!APKARGS! /api:!XZ_API!"
if defined XZ_SPASS set "APKARGS=!APKARGS! /storepass:!XZ_SPASS!"
if defined XZ_KPASS set "APKARGS=!APKARGS! /keypass:!XZ_KPASS!"
if defined XZ_ICON set "APKARGS=!APKARGS! /icon:!XZ_ICON!"
call "!SD!build_apk.cmd" "!PAYLOAD!" "!OUT!"!APKARGS!
set "EC=!errorlevel!"
del "!PAYLOAD!" >nul 2>&1
if not "!EC!"=="0" goto :FAIL_APK
if not exist "!OUT!" goto :FAIL_APK
exit /b 0

:FAIL_APK
echo.
echo  [错误] APK 生成失败, 退出码 !EC!
call :LOG "APK 失败, 退出码 !EC!"
echo  [提示] 请确认已安装 JDK 和 Android SDK build-tools。
echo  [日志] !LOG!
pause
exit /b 1

:VERIFY
set "VF="
if defined XZCP_AUTO if defined XZCP_VF set "VF=!XZCP_VF!"
if not defined VF set /p "VF=压缩完成, 是否自动校验压缩包? (Y/n): "
if /i "!VF!"=="n" exit /b 0
set "EC=0"
if defined VOL if "!PACK!"=="0" (
  if exist "!OUT!.001" (
    echo  [校验] 7-Zip 检查分卷压缩包第一卷 ...
    "!SZIP!" t "!OUT!.001"
    set "EC=!errorlevel!"
  ) else (
    echo  [错误] 未找到分卷第一卷: !OUT!.001
    set "EC=2"
  )
  if not "!EC!"=="0" (echo  [错误] 分卷校验未通过, 退出码 !EC!) else (echo  [通过] 分卷压缩包校验成功)
  pause
  exit /b 0
)
if "!PACK!"=="1" (
  if "!EXEBACKEND!"=="7z" (
    echo  [校验] 7-Zip 检查内部自解压包 ...
    "!SZIP!" t "!OUT!"
    set "EC=!errorlevel!"
  ) else (
    echo  [提示] 通用自解压 exe 已内置完整引擎, 双击运行即可解压（此处跳过自动校验）
    set "EC=0"
  )
) else if "!PACK!"=="2" (
  if defined SZIP (
    echo  [校验] 7-Zip 检查 APK 内部 ...
    "!SZIP!" t "!OUT!"
    set "EC=!errorlevel!"
  ) else (
    echo  [提示] 无 7-Zip, 跳过 APK 校验
    set "EC=0"
  )
) else (
  if "!FMAT!"=="xz" (
    if defined SZIP (
      echo  [校验] 7-Zip 检查内部压缩包 ...
      "!SZIP!" t "!OUT!"
      set "EC=!errorlevel!"
    ) else (
      echo  [校验] tar 检查内部压缩包 ...
      "!TAREXE!" -tf "!OUT!" >nul 2>&1
      set "EC=!errorlevel!"
    )
  ) else (
    echo  [校验] 7-Zip 检查 !FMAT! 包 ...
    "!SZIP!" t "!OUT!"
    set "EC=!errorlevel!"
  )
)
if not "!EC!"=="0" (
  echo  [错误] 校验未通过, 退出码 !EC!, 压缩文件可能损坏。
  call :LOG "校验失败, 退出码 !EC!"
) else (
  echo  [通过] 压缩包校验成功
  call :LOG "校验通过"
)
pause
exit /b 0

:SUMMARY
if not exist "!OUT!" if not defined VOL exit /b 0
if defined VOL if not exist "!OUT!.001" exit /b 0
set "CALC_VOL=0"
if defined VOL set "CALC_VOL=1"
set "CALC_SRC=!IN!"
set "CALC_OUT=!OUT!"
set "CALC_T0=!T0!"
set "CALC_SUMFILE=%TEMP%\xz_sum_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s=$env:CALC_SRC;$oF=Get-Item -LiteralPath $s -ErrorAction Stop;$o=if($oF.PSIsContainer){(Get-ChildItem -LiteralPath $s -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum}else{$oF.Length};if($env:CALC_VOL -eq '1'){$n=(Get-ChildItem -LiteralPath ($env:CALC_OUT+'.*') -File|Measure-Object Length -Sum).Sum}else{$n=(Get-Item -LiteralPath $env:CALC_OUT -ErrorAction Stop).Length};$r=if($o -gt 0){[math]::Round((1-$n/[double]$o)*100,2)}else{0};$d=[DateTime]::Now-[DateTime]::Parse($env:CALC_T0);[IO.File]::WriteAllText($env:CALC_SUMFILE,('{0}|{1}|{2}|{3}|{4}' -f $o,$n,$r,[math]::Round($d.TotalSeconds,1),[math]::Round($n/1MB,2)))"
set "SUM="
for /f "usebackq delims=" %%L in ("!CALC_SUMFILE!") do set "SUM=%%L"
del "!CALC_SUMFILE!" >nul 2>&1
set "SO="
set "SN="
set "SR="
set "ST="
set "SMB="
for /f "tokens=1-5 delims=|" %%a in ("!SUM!") do set "SO=%%a" & set "SN=%%b" & set "SR=%%c" & set "ST=%%d" & set "SMB=%%e"
echo.
echo  ============================================================
echo    压缩完成!
if defined SO echo    原始大小:  !SO! 字节
if defined SN echo    压缩后:    !SN! 字节
if defined SMB echo              约 !SMB! MB
if defined SR echo    压缩率:    !SR!%%  (数字越大压缩效果越好)
if defined ST echo    用时:      !ST! 秒
echo    输出文件:  !OUT!
echo  ============================================================
if defined VOL echo    分卷文件:  !OUT!.001 !OUT!.002 ...
call :LOG "完成: !OUT! (原=!SO! 压缩后=!SN! 压缩率=!SR!% 用时=!ST!秒)"
if defined DOSHA call :MAKE_SHA
if defined DOBEEP call :DO_BEEP
call :ADD_HISTORY
rem ---- 生成后自动在资源管理器中定位输出文件 ----
if exist "!OUT!" start "" explorer /select,"!OUT!"
rem ---- 清理本次任务的临时中间文件（不删用户产物） ----
del /q "%TEMP%\xz_tmp_*" >nul 2>&1
for /d %%D in ("%TEMP%\xz_build_*") do rmdir /s /q "%%D" >nul 2>&1
exit /b 0

rem ============ 生成 SHA256 校验文件 ============
:MAKE_SHA
set "XZ_OUT=!OUT!"
if defined VOL (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$o=$env:XZ_OUT; if(Test-Path ($o+'.sha256')){Remove-Item ($o+'.sha256') -Force}; Get-ChildItem -LiteralPath ($o+'.*') -File | Sort-Object Name | ForEach-Object { $h=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash; Add-Content -Path ($o+'.sha256') -Value ($h+'  '+$_.Name) }"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "$o=$env:XZ_OUT; $h=(Get-FileHash -LiteralPath $o -Algorithm SHA256).Hash; [IO.File]::WriteAllText($o+'.sha256', ($h+'  '+[IO.Path]::GetFileName($o)))"
)
if exist "!OUT!.sha256" (
  echo  [校验] 已生成 SHA256 校验文件: !OUT!.sha256
  call :LOG "SHA256 清单: !OUT!.sha256"
)
exit /b 0

rem ============ 完成提示音 ============
:DO_BEEP
powershell -NoProfile -Command "try{[System.Media.SystemSounds]::Asterisk.Play();Start-Sleep -Milliseconds 600}catch{}" >nul 2>&1
exit /b 0

rem ============ 压缩为 gzip ============
:RUN_GZ
echo.
echo  [gzip] 正在压缩为 .gz ...
if "!ISDIR!"=="1" goto :RUN_TARGZ
if "!MULTI!"=="1" goto :RUN_TARGZ
set "PROGCMD=a -tgzip -mx=!LV! -bsp1 "!OUT!" "!IN!""
set "PMODE=add"
call :RUN_PROG
call :LOG "gzip 退出码: !EC!"
if "!EC!"=="0" exit /b 0
if "!EC!"=="1" (echo  [警告] 7-Zip 警告, 已忽略。 & exit /b 0)
goto :FAIL_7Z

rem ============ 压缩为 bzip2 ============
:RUN_BZ2
echo.
echo  [bzip2] 正在压缩为 .bz2 ...
if "!ISDIR!"=="1" goto :RUN_TARBZ2
if "!MULTI!"=="1" goto :RUN_TARBZ2
set "PROGCMD=a -tbzip2 -mx=!LV! -bsp1 "!OUT!" "!IN!""
set "PMODE=add"
call :RUN_PROG
call :LOG "bzip2 退出码: !EC!"
if "!EC!"=="0" exit /b 0
if "!EC!"=="1" (echo  [警告] 7-Zip 警告, 已忽略。 & exit /b 0)
goto :FAIL_7Z

rem ============ 压缩为 tar.gz ============
:RUN_TGZ
goto :RUN_TARGZ

:RUN_TARGZ
echo.
echo  [tar] 正在压缩为 tar.gz ...
if "!MULTI!"=="1" goto :TARGZ_MULTI
set "CMD="!TAREXE!" -czf "!OUT!" -C "!OUTDIRC!" "!INNAME!""
call :LOG "命令: !CMD!"
!CMD!
set "EC=!errorlevel!"
call :LOG "tar.gz 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_TAR
exit /b 0
:TARGZ_MULTI
set "TARARGS="
for %%F in (!ALLARGS!) do (
  for %%G in ("%%~fF") do set "TD=%%~dpG"
  for %%G in ("%%~fF") do set "TN=%%~nxG"
  set "TDT=!TD!"
  set "TDT=!TDT:\=/!"
  if "!TDT:~-1!"=="/" (
    set "TDT=!TDT:~0,-1!"
    if /i "!TDT!"=="!TDT:~0,2!" set "TDT=!TDT!/"
  )
  set "TARARGS=!TARARGS! -C "!TDT!" "!TN!""
)
set "CMD="!TAREXE!" -czf "!OUT!"!TARARGS!"
call :LOG "命令: !CMD!"
!CMD!
set "EC=!errorlevel!"
call :LOG "tar.gz 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_TAR
exit /b 0

rem ============ 压缩为 tar.bz2 ============
:RUN_TARBZ2
echo.
echo  [tar] 正在压缩为 tar.bz2 ...
if "!MULTI!"=="1" goto :TARBZ2_MULTI
set "CMD="!TAREXE!" -cjf "!OUT!" -C "!OUTDIRC!" "!INNAME!""
call :LOG "命令: !CMD!"
!CMD!
set "EC=!errorlevel!"
call :LOG "tar.bz2 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_TAR
exit /b 0
:TARBZ2_MULTI
set "TARARGS="
for %%F in (!ALLARGS!) do (
  for %%G in ("%%~fF") do set "TD=%%~dpG"
  for %%G in ("%%~fF") do set "TN=%%~nxG"
  set "TDT=!TD!"
  set "TDT=!TDT:\=/!"
  if "!TDT:~-1!"=="/" (
    set "TDT=!TDT:~0,-1!"
    if /i "!TDT!"=="!TDT:~0,2!" set "TDT=!TDT!/"
  )
  set "TARARGS=!TARARGS! -C "!TDT!" "!TN!""
)
set "CMD="!TAREXE!" -cjf "!OUT!"!TARARGS!"
call :LOG "命令: !CMD!"
!CMD!
set "EC=!errorlevel!"
call :LOG "tar.bz2 退出码: !EC!"
if not "!EC!"=="0" goto :FAIL_TAR
exit /b 0

rem ============ 错误处理 ============
:FAIL_7Z
echo.
echo  [错误] 7-Zip 压缩失败, 退出码 !EC!
echo  ------------------------------------------
echo   退出码含义:  0=成功  1=警告  2=致命错误
echo                7=命令行错误  8=内存不足  255=用户中止
echo  ------------------------------------------
if "!EC!"=="2" (
  echo   常见原因: 磁盘空间不足 / 无写入权限 / 源文件被占用 / 路径过长
)
call :LOG "7-Zip 失败, 退出码 !EC!"
echo  完整日志: !LOG!
echo  可将日志中的命令复制到命令行手动复现, 以便进一步排查。
pause
exit /b 1

:FAIL_TAR
echo.
echo  [错误] tar 压缩失败, 退出码 !EC!
call :LOG "tar 失败, 退出码 !EC!"
echo  常见原因: 磁盘空间不足 / 无写入权限 / 源文件被占用 / 路径过长
echo  完整日志: !LOG!
pause
exit /b 1

:FAIL_XZ
echo.
echo  [错误] xz.exe 压缩失败, 退出码 !EC!
call :LOG "xz 失败, 退出码 !EC!"
echo  完整日志: !LOG!
pause
exit /b 1

:FAIL_CSC
echo.
echo  [错误] exe 编译失败, 退出码 !EC!
call :LOG "csc 失败, 退出码 !EC!"
echo  请检查系统 .NET Framework 是否完整, 或安装 7-Zip 后重试。
echo  完整日志: !LOG!
pause
exit /b 1

:FAIL
echo.
echo  [错误] %~1
call :LOG "失败: %~1"
echo  完整日志: !LOG!
pause
exit /b 1

:END_ERR
echo.
echo  ============================================================
echo    压缩失败, 请根据上方错误提示排查。
echo    详细日志: !LOG!
echo  ============================================================
pause
goto :END

rem ============ 修复损坏的压缩文件 ============
:REPAIR
set "REPIN="
set "RPFMT="
set "RPAPK="
set "RPRAR="
set "RPSFX="
set "RPE="
cls
echo.
echo  ============================================================
echo    修复损坏的压缩文件
echo  ============================================================
echo.
echo    支持格式: zip / 7z / xz / exe自解压 / apk / rar
echo    流程: 测试完整性 - 尽力提取可读内容 - 重新打包 - 再次校验
echo          修复产物未通过完整性校验时, 判定为修复失败。
echo.
if defined XZCP_AUTO if defined XZCP_REPIN set "REPIN=!XZCP_REPIN!"
if not defined REPIN (
  echo  [选择] 请在文件资源管理器中选择要修复的文件 ...
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要修复的文件'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择文件, 已取消。
    if defined XZCP_AUTO goto :QUIT
    goto :MAINMENU
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "REPIN=%%L"
  del "!PICK!" >nul 2>&1
  if not defined REPIN goto :MAINMENU
)
if not exist "!REPIN!" (
  echo  [错误] 输入路径不存在: !REPIN!
  call :LOG "修复: 路径不存在 !REPIN!"
  if defined XZCP_AUTO goto :QUIT
  pause
  goto :REPAIR
)
call :LOG "修复开始: !REPIN!"
for %%F in ("!REPIN!") do (
  set "RPDIR=%%~dpF"
  set "RPNAME=%%~nxF"
  set "RPBASE=%%~nF"
  set "RPE=%%~xF"
)
set "RPL=!REPIN!"

rem ---- 1) 测试完整性 ----
echo  [测试] 正在检测归档完整性 ...
"!SZIP!" t "!REPIN!" >nul 2>&1
if not errorlevel 1 (
  echo  [完成] 文件完好, 无需修复: !RPNAME!
  call :LOG "修复: 文件完好无需修复 !RPNAME!"
  if defined XZCP_AUTO goto :QUIT
  pause
  goto :REPAIR
)
echo  [检测] 文件已损坏, 尝试提取可读内容 ...

rem ---- 2) 尽力提取 ----
set "RPTMP=%TEMP%\xzrepair_!RANDOM!"
mkdir "!RPTMP!" >nul 2>&1
"!SZIP!" x -y "-o!RPTMP!" "!REPIN!" >nul 2>&1
set "RPCNT=0"
for /f "delims=" %%F in ('dir /b "!RPTMP!" 2^>nul') do set /a RPCNT+=1
if "!RPCNT!"=="0" (
  echo  [失败] 无法提取任何可读内容, 该文件无法修复。
  call :LOG "修复失败: 无可读内容 !RPNAME!"
  rmdir /s /q "!RPTMP!" >nul 2>&1
  if defined XZCP_AUTO goto :QUIT
  pause
  goto :REPAIR
)
echo  [提取] 已恢复 !RPCNT! 个条目, 正在重新打包 ...

rem ---- 3) 按类型重新打包 ----
if /i "!RPE!"==".zip" set "RPFMT=-tzip" & set "RPOUTEXT=.zip"
if /i "!RPE!"==".apk" set "RPFMT=-tzip" & set "RPOUTEXT=.zip" & set "RPAPK=1"
if /i "!RPE!"==".7z"  set "RPFMT=-t7z"  & set "RPOUTEXT=.7z"
if /i "!RPE!"==".rar" set "RPFMT=-tzip" & set "RPOUTEXT=.zip" & set "RPRAR=1"
if /i "!RPE!"==".xz"  set "RPFMT=-txz"  & set "RPOUTEXT=.xz"
if /i "!RPE!"==".exe" set "RPFMT=-sfx"  & set "RPOUTEXT=.exe" & set "RPSFX=1"
if /i "!RPE!"==".xz" if not "!RPCNT!"=="1" (
  set "RPFMT=-tzip"
  set "RPOUTEXT=.zip"
  echo  [提示] xz 只能打包单文件, 已改用 zip 输出。
)
if not defined RPFMT (
  echo  [失败] 不支持的扩展名, 无法修复: !RPNAME!
  call :LOG "修复失败: 不支持的类型 !RPNAME!"
  rmdir /s /q "!RPTMP!" >nul 2>&1
  if defined XZCP_AUTO goto :QUIT
  pause
  goto :REPAIR
)
set "RPOUT=!RPDIR!!RPBASE!_fixed!RPOUTEXT!"
if "!RPFMT!"=="-sfx" (
  "!SZIP!" a -y -mx=9 -sfx"!SZDIR!7z.sfx" "!RPOUT!" "!RPTMP!\*" >nul 2>&1
) else (
  "!SZIP!" a -y -mx=9 !RPFMT! "!RPOUT!" "!RPTMP!\*" >nul 2>&1
)
if errorlevel 1 (
  echo  [失败] 重新打包失败, 无法修复: !RPNAME!
  call :LOG "修复失败: 重打包失败 !RPNAME!"
  del "!RPOUT!" >nul 2>&1
  rmdir /s /q "!RPTMP!" >nul 2>&1
  if defined XZCP_AUTO goto :QUIT
  pause
  goto :REPAIR
)

rem ---- 4) 合法性校验 ----
"!SZIP!" t "!RPOUT!" >nul 2>&1
if errorlevel 1 (
  echo  [失败] 修复产物未通过完整性校验, 判定修复失败。
  call :LOG "修复失败: 产物校验不通过 !RPNAME!"
  del "!RPOUT!" >nul 2>&1
  rmdir /s /q "!RPTMP!" >nul 2>&1
  if defined XZCP_AUTO goto :QUIT
  pause
  goto :REPAIR
)
rmdir /s /q "!RPTMP!" >nul 2>&1
echo  [成功] 修复完成: !RPOUT!
if defined RPAPK echo  [提示] APK 修复后需重新签名才能安装, 可用 [4] 创建完整版或 apksigner 重新签名。
if defined RPRAR echo  [提示] RAR 压缩已移除, 修复输出为 zip 格式。
call :LOG "修复成功: !RPOUT!"
if defined XZCP_AUTO goto :QUIT
pause
goto :REPAIR


rem ============ 所需工具下载 ============
:TOOLDOWN

set "TDMENU="
cls
echo.
echo  ============================================================
echo    所需工具下载
echo  ============================================================
echo.
echo    当前工具状态:
if defined SZIP (echo       7-Zip     已安装   !SZIP!) else (echo       7-Zip     未安装   （xz/7z/zip 压缩必需）)
if defined XZEXE (echo       xz.exe    已安装   !XZEXE!) else (echo       xz.exe    未安装   （可选, 7-Zip 可替代）)
if defined TAREXE (echo      tar.exe   已安装   [系统自带]) else (echo      tar.exe   未安装   （文件夹压 xz 需要 Windows 10+）)
if defined CSC (echo        csc.exe   已安装   [.NET 编译器]) else (echo       csc.exe   未安装   （exe 自解压带图标需要）)
echo.
echo      [1] 打开 7-Zip 官网下载 （推荐: 安装后支持 xz/7z/zip/exe/apk）
echo      [2] 一键下载并安装 7-Zip
echo      [3] 鸿蒙 DevEco Studio 官方下载（HarmonyOS NEXT 开发）
echo      [4] 华为开发者联盟（HarmonyOS SDK / 文档）
echo      [Q] 返回主菜单
echo.
if defined XZCP_AUTO if defined XZCP_TDMENU set "TDMENU=!XZCP_TDMENU!"
if not defined TDMENU set /p "TDMENU=请选择: "
if /i "!TDMENU!"=="q" (if defined XZCP_AUTO (goto :QUIT) else (goto :MAINMENU))
if "!TDMENU!"=="1" (
  echo  [打开] 正在打开 7-Zip 官网下载页...
  start "" "https://www.7-zip.org/download.html"
  pause
  goto :TOOLDOWN
)
if "!TDMENU!"=="2" (
  call :DL_7Z
  pause
  goto :TOOLDOWN
)
if "!TDMENU!"=="3" (
  echo  [打开] 正在打开 DevEco Studio 官方下载页...
  start "" "https://developer.huawei.com/consumer/cn/deveco-studio/"
  pause
  goto :TOOLDOWN
)
if "!TDMENU!"=="4" (
  echo  [打开] 正在打开华为开发者联盟...
  start "" "https://developer.huawei.com/consumer/cn/doc/"
  pause
  goto :TOOLDOWN
)
goto :TOOLDOWN

rem ============ 创建便携式压缩程序 ============
:PORTABLE
set "PMENU="
cls
echo.
echo  ============================================================
echo    创建便携式压缩程序
echo  ============================================================
echo.
echo      [1] HTML 完整版     浏览器端完整功能（压缩/解压/加密，单文件）
echo      [2] HTML 便携自解压 压缩包嵌入单文件HTML，双击即解压
echo      [3] 安卓完整版     安卓端完整压缩程序（xz 压缩/解压）
echo      [4] Windows 完整版 完整功能压缩程序 exe（免安装 7-Zip）
echo      [5] 创建安装程序    安装向导（自定义名称/版本/协议/图标）
echo      [6] 鸿蒙 HarmonyOS 鸿蒙版（兼容APK / 纯血NEXT工程）
echo      [Q] 返回主菜单
echo.
if defined XZCP_AUTO if defined XZCP_PMENU set "PMENU=!XZCP_PMENU!"
if not defined PMENU set /p "PMENU=请选择: "
if /i "!PMENU!"=="q" (if defined XZCP_AUTO (goto :QUIT) else (goto :MAINMENU))
if "!PMENU!"=="1" goto :PORTABLE_HTML
if "!PMENU!"=="2" goto :PORTABLE_HTMLSFX
if "!PMENU!"=="3" goto :PORTABLE_FULLAPK
if "!PMENU!"=="4" goto :PORTABLE_FULLEXE
if "!PMENU!"=="5" goto :MAKE_INSTALLER
if "!PMENU!"=="6" goto :HARMONY
goto :PORTABLE

:PORTABLE_HTML
if not exist "!SD!tools\html\build_html.ps1" (
  echo  [错误] 缺少构建脚本 tools\html\build_html.ps1!
  pause
  goto :PORTABLE
)
set "HTMLOUT="
set "HNAME=XZ压缩工具"
set "HVER=正式版 1.0"
if defined XZCP_AUTO (
  if defined XZCP_HTMLOUT set "HTMLOUT=!XZCP_HTMLOUT!"
  if defined XZCP_HNAME set "HNAME=!XZCP_HNAME!"
  if defined XZCP_HVER set "HVER=!XZCP_HVER!"
)
if not defined HTMLOUT (
  echo.
  echo  [HTML完整版] 请在“另存为”窗口选择保存位置 ...
  set "PICK=%TEMP%\xz_save_!RANDOM!.txt"
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $s=New-Object System.Windows.Forms.SaveFileDialog; $s.Title='保存HTML完整版'; $s.Filter='HTML文件|*.html'; $s.FileName='XZ压缩工具_HTML版.html'; if($s.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$s.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择保存位置, 已取消。
    if defined XZCP_AUTO goto :QUIT
    goto :PORTABLE
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "HTMLOUT=%%L"
  del "!PICK!" >nul 2>&1
)
echo.
echo  [HTML完整版] 正在生成单文件 HTML 压缩工具 ...
"!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\html\build_html.ps1" -AppName "!HNAME!" -AppVersion "!HVER!" -OutFile "!HTMLOUT!"
set "HEC=!ERRORLEVEL!"
if not "!HEC!"=="0" (
  echo  [错误] HTML 生成失败（退出码 !HEC!）。
  call :LOG "HTML完整版生成失败 ec=!HEC!"
  pause
  goto :PORTABLE
)
if exist "!HTMLOUT!" (
  echo.
  echo  [完成] HTML 完整版已生成: !HTMLOUT!
  echo         双击即可在任意现代浏览器打开使用，无需安装。
  call :LOG "HTML完整版已生成: !HTMLOUT!"
  if exist "!HTMLOUT!" start "" explorer /select,"!HTMLOUT!"
)
set "HTMLOUT=" & set "HEC=" & set "HNAME=" & set "HVER="
pause
if defined XZCP_AUTO goto :QUIT
goto :MAINMENU

:PORTABLE_HTMLSFX
if not exist "!SD!tools\html\build_html_sfx.ps1" (
  echo  [错误] 缺少构建脚本 tools\html\build_html_sfx.ps1!
  pause
  goto :PORTABLE
)
set "SFXARC="
set "SFXOUT="
set "SFXT="
if defined XZCP_AUTO (
  if defined XZCP_SFXARC set "SFXARC=!XZCP_SFXARC!"
  if defined XZCP_SFXOUT set "SFXOUT=!XZCP_SFXOUT!"
  if defined XZCP_SFXT set "SFXT=!XZCP_SFXT!"
)
if not defined SFXARC (
  echo.
  echo  [HTML自解压] 请选择要嵌入的压缩包（xz/zip/7z/gz等）...
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要嵌入的压缩包'; $f.Filter='压缩文件|*.xz;*.zip;*.7z;*.gz;*.bz2;*.tgz;*.tar;*.txz|所有文件|*.*'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择压缩包, 已取消。
    if defined XZCP_AUTO goto :QUIT
    goto :PORTABLE
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "SFXARC=%%L"
  del "!PICK!" >nul 2>&1
)
if not exist "!SFXARC!" (
  echo  [错误] 压缩包不存在。
  pause
  goto :PORTABLE
)
if not defined SFXOUT (
  echo.
  echo  [HTML自解压] 请在“另存为”窗口选择保存位置 ...
  set "PICK=%TEMP%\xz_save_!RANDOM!.txt"
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $s=New-Object System.Windows.Forms.SaveFileDialog; $s.Title='保存HTML自解压'; $s.Filter='HTML文件|*.html'; $s.FileName='!SFXARC!_自解压.html'; if($s.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$s.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择保存位置, 已取消。
    if defined XZCP_AUTO goto :QUIT
    goto :PORTABLE
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "SFXOUT=%%L"
  del "!PICK!" >nul 2>&1
)
echo.
echo  [HTML自解压] 正在生成 ...
if defined SFXT (
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\html\build_html_sfx.ps1" -ArcFile "!SFXARC!" -Title "!SFXT!" -OutFile "!SFXOUT!"
) else (
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\html\build_html_sfx.ps1" -ArcFile "!SFXARC!" -OutFile "!SFXOUT!"
)
set "SEC=!ERRORLEVEL!"
if not "!SEC!"=="0" (
  echo  [错误] 自解压生成失败（退出码 !SEC!）。
  call :LOG "HTML自解压生成失败 ec=!SEC!"
  pause
  goto :PORTABLE
)
if exist "!SFXOUT!" (
  echo.
  echo  [完成] HTML 自解压已生成: !SFXOUT!
  echo         双击打开后点击按钮即可解压，无需安装任何软件。
  call :LOG "HTML自解压已生成: !SFXOUT!"
  if exist "!SFXOUT!" start "" explorer /select,"!SFXOUT!"
)
set "SFXARC=" & set "SFXOUT=" & set "SEC=" & set "SFXT="
pause
if defined XZCP_AUTO goto :QUIT
goto :MAINMENU

:PORTABLE_FULLAPK
if not exist "!SD!build_full_apk.cmd" (
  echo  [错误] 缺少构建脚本 build_full_apk.cmd, 请将构建脚本放在同一目录!
  pause
  goto :PORTABLE
)
echo.
echo  [安卓完整版] 程序图标与包名签名设置 ...
call :ASK_ICON
call :ASK_APKSIGN
call :ASK_API
echo.
echo  [安卓完整版] 正在构建安卓完整版压缩程序 ...
set "FAPKARGS="
if defined XZ_ICON set "FAPKARGS=!FAPKARGS! /icon:"!XZ_ICON!""
if defined XZ_PKG set "FAPKARGS=!FAPKARGS! /pkg:"!XZ_PKG!""
if defined XZ_ALIAS set "FAPKARGS=!FAPKARGS! /alias:"!XZ_ALIAS!""
if defined XZ_API set "FAPKARGS=!FAPKARGS! /api:!XZ_API!"
call "!SD!build_full_apk.cmd"!FAPKARGS!
if exist "!SD!XZ完整压缩.apk" start "" explorer /select,"!SD!XZ完整压缩.apk"
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :MAINMENU

:PORTABLE_FULLEXE
if not exist "!SD!build_full_exe.cmd" (
  echo  [错误] 缺少构建脚本 build_full_exe.cmd, 请将构建脚本放在同一目录!
  pause
  goto :PORTABLE
)
echo.
echo  [Windows完整版] 程序图标设置（0=无 1=ico 2=图片）...
call :ASK_ICON
echo.
echo  [Windows完整版] 正在构建 Windows 完整版压缩程序 ...
call "!SD!build_full_exe.cmd" "!XZ_ICON!"
if exist "!SD!XZ完整版压缩工具.exe" start "" explorer /select,"!SD!XZ完整版压缩工具.exe"
if exist "!SD!XZ完整版.exe" start "" explorer /select,"!SD!XZ完整版.exe"
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :MAINMENU

rem ============ 创建安装程序 ============
:MAKE_INSTALLER
set "MISRC="
set "MIFILE="
set "MINAME="
set "MIVER="
set "MIEULA="
set "MIICO="
cls
echo.
echo  ============================================================
echo    创建安装程序（安装向导）
echo  ============================================================
echo    将整个程序目录打包为一个带安装向导的 EXE：
echo    文件以明文形式嵌入安装器，安装时直接释放；
echo    支持自定义软件名称、版本、用户协议与图标，
echo    安装后自带 [修改 / 修复 / 卸载] 维护与开始菜单卸载项。
echo.
if not exist "!SD!tools\obf_pack.ps1" (
  echo  [错误] 缺少打包器 tools\obf_pack.ps1，无法创建安装程序。
  pause
  goto :PORTABLE
)
if defined XZCP_AUTO if defined XZCP_MISRC set "MISRC=!XZCP_MISRC!"
if not defined MISRC (
  echo  [选择] 请在文件资源管理器中选择要打包的程序目录 ...
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='选择要打包的程序目录（含主程序）'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.SelectedPath,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择目录, 已取消。
    if defined XZCP_AUTO goto :QUIT
    goto :PORTABLE
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "MISRC=%%L"
  del "!PICK!" >nul 2>&1
)
if not exist "!MISRC!" (
  echo  [错误] 目录不存在: !MISRC!
  pause
  goto :PORTABLE
)
echo    已选源目录: !MISRC!
echo.
set "MINAME=XZ压缩工具"
if defined XZCP_AUTO if defined XZCP_MINAME set "MINAME=!XZCP_MINAME!"
if not defined XZCP_AUTO set /p "MINAME=软件名称（直接回车=XZ压缩工具）: "
if "!MINAME!"=="" set "MINAME=XZ压缩工具"
set "MIVER=正式版 1.0"
if defined XZCP_AUTO if defined XZCP_MIVER set "MIVER=!XZCP_MIVER!"
if not defined XZCP_AUTO set /p "MIVER=版本号（直接回车=正式版 1.0）: "
if "!MIVER!"=="" set "MIVER=正式版 1.0"
set "MIEULAOPT="
echo.
echo  用户协议：
echo    [0] 使用默认协议（已含开源署名）
echo    [1] 从文件选择协议文本 (.txt)
if defined XZCP_AUTO if defined XZCP_MIEULAOPT set "MIEULAOPT=!XZCP_MIEULAOPT!"
if not defined MIEULAOPT set /p "MIEULAOPT=请选择 0 / 1（直接回车=0）: "
if not defined MIEULAOPT set "MIEULAOPT=0"
if defined XZCP_AUTO if defined XZCP_MIEULA set "MIEULA=!XZCP_MIEULA!"
if "!MIEULAOPT!"=="1" if not defined MIEULA (
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择用户协议文本'; $f.Filter='文本文件|*.txt|所有文件|*.*'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
  if exist "!PICK!" (
    for /f "usebackq delims=" %%L in ("!PICK!") do set "MIEULA=%%L"
    del "!PICK!" >nul 2>&1
  )
)
echo.
echo  [安装程序图标] 直接回车或选 0 将使用内置默认图标；也可自定义。
call :ASK_ICON
if defined XZ_ICON set "MIICO=!XZ_ICON!"
set "MIFILE="
if defined XZCP_AUTO if defined XZCP_MIFILE set "MIFILE=!XZCP_MIFILE!"
if not defined MIFILE (
  echo.
  echo  [选择] 请在“另存为”窗口选择安装程序保存位置 ...
  set "PICK=%TEMP%\xz_save_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $s=New-Object System.Windows.Forms.SaveFileDialog; $s.Title='保存安装程序'; $s.Filter='EXE 安装程序|*.exe'; $s.FileName='!MINAME!_安装程序.exe'; if($s.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$s.FileName,[Text.Encoding]::Default)}"
  if exist "!PICK!" (
    for /f "usebackq delims=" %%L in ("!PICK!") do set "MIFILE=%%L"
    del "!PICK!" >nul 2>&1
  )
)
if not defined MIFILE (
  echo  [提示] 未选择保存位置, 已取消。
  if defined XZCP_AUTO goto :QUIT
  goto :PORTABLE
)
rem 图片图标先转 ico
if defined MIICO if /i not "!MIICO:~-4!"==".ico" (
  echo  [图标] 正在把图片转换为 .ico ...
  set "MIICONV=%TEMP%\xzmi_!RANDOM!.ico"
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\imgtool.ps1" "!MIICO!" "!MIICONV!" ico
  if exist "!MIICONV!" (set "MIICO=!MIICONV!") else (set "MIICO=")
)
echo.
echo  正在生成安装程序（打包，可能需要一两分钟）...
set "MIARGS=-SrcDir "!MISRC!" -OutExe "!MIFILE!" -AppName "!MINAME!" -AppVersion "!MIVER!""
if defined MIEULA set "MIARGS=!MIARGS! -EulaFile "!MIEULA!""
if defined MIICO set "MIARGS=!MIARGS! -Icon "!MIICO!""
"!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\obf_pack.ps1" !MIARGS!
set "MIEC=!ERRORLEVEL!"
if not "!MIEC!"=="0" (
  echo  [错误] 安装程序生成失败（退出码 !MIEC!），请查看上方信息。
  call :LOG "安装程序生成失败 ec=!MIEC!"
  pause
  goto :PORTABLE
)
if exist "!MIFILE!" (
  echo.
  echo  [完成] 安装程序已生成: !MIFILE!
  echo         双击运行安装向导；再次运行可 修改 / 修复 / 卸载。
  call :LOG "安装程序已生成: !MIFILE!"
  if exist "!MIFILE!" start "" explorer /select,"!MIFILE!"
) else (
  echo  [错误] 未找到生成的安装程序文件。
)
rem ---- 品牌同步：用相同名称/版本/图标生成 EXE / APK ----
set "MISYNC="
if defined XZCP_AUTO if defined XZCP_MISYNC set "MISYNC=!XZCP_MISYNC!"
if not defined MISYNC (
  echo.
  echo  品牌同步：是否用相同名称/版本/图标生成其他版本？
  echo    [1] 同步生成 Windows 完整版 EXE
  echo    [2] 同步生成安卓完整版 APK
  echo    [3] 两者都生成
  echo    [0] 不需要
  set /p "MISYNC=请选择 0/1/2/3（直接回车=0）: "
)
if not defined MISYNC set "MISYNC=0"
if "!MISYNC!"=="1" call :SYNC_EXE
if "!MISYNC!"=="2" call :SYNC_APK
if "!MISYNC!"=="3" ( call :SYNC_EXE & call :SYNC_APK )
set "MISRC=" & set "MIFILE=" & set "MINAME=" & set "MIVER=" & set "MIEULA=" & set "MIICO=" & set "XZ_ICON=" & set "MIARGS="
pause
if defined XZCP_AUTO goto :QUIT
goto :MAINMENU

rem ============ 鸿蒙 HarmonyOS 版 ============
:HARMONY
set "HM="
cls
echo.
echo  ============================================================
echo    鸿蒙 HarmonyOS 版
echo  ============================================================
echo.
echo      [1] 鸿蒙兼容版（HarmonyOS 4.x 及更早）
echo          这些版本兼容安卓应用，直接生成 APK 即可在手机安装。
echo      [2] 纯血鸿蒙 HarmonyOS NEXT（5.0+）
echo          NEXT 仅支持 APP/HAP，不支持 APK；此处提供官方
echo          DevEco Studio 下载入口与工程模板，需用华为工具编译。
echo      [Q] 返回
echo.
if defined XZCP_AUTO if defined XZCP_HM set "HM=!XZCP_HM!"
if not defined HM set /p "HM=请选择: "
if /i "!HM!"=="q" goto :PORTABLE
if "!HM!"=="1" goto :PORTABLE_FULLAPK
if "!HM!"=="2" goto :HM_NEXT
goto :HARMONY

:HM_NEXT
set "HN="
cls
echo.
echo  ============================================================
echo    纯血鸿蒙 HarmonyOS NEXT 说明
echo  ============================================================
echo.
echo   HarmonyOS NEXT 不再兼容安卓 APK，应用必须为 HAP/APP，
echo   并使用华为官方 DevEco Studio 与 HarmonyOS SDK 编译签名。
echo.
echo   本工具当前环境无法直接产出可安装的鸿蒙 APP，可为你：
echo      [1] 打开 DevEco Studio 官方下载页
echo      [2] 打开华为开发者联盟（文档 / SDK / 签名）
echo      [3] 在桌面生成鸿蒙工程模板与移植说明
echo      [Q] 返回
echo.
if defined XZCP_AUTO if defined XZCP_HN set "HN=!XZCP_HN!"
if not defined HN set /p "HN=请选择: "
if /i "!HN!"=="q" goto :HARMONY
if "!HN!"=="1" start "" "https://developer.huawei.com/consumer/cn/deveco-studio/"
if "!HN!"=="2" start "" "https://developer.huawei.com/consumer/cn/doc/"
if "!HN!"=="3" call :HM_TEMPLATE
if defined XZCP_AUTO goto :QUIT
pause
goto :HM_NEXT

:HM_TEMPLATE
echo.
echo  [模板] 正在桌面生成鸿蒙工程模板 ...
"!PSH!" -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\hm_template.ps1"
if errorlevel 1 (
  echo  [错误] 模板生成失败。
) else (
  echo  [完成] 已在桌面生成「鸿蒙压缩工具_工程模板」文件夹。
  echo         用 DevEco Studio 打开，按其中 README 移植并签名即可。
  if exist "%USERPROFILE%\Desktop\鸿蒙压缩工具_工程模板" start "" explorer /select,"%USERPROFILE%\Desktop\鸿蒙压缩工具_工程模板"
)
exit /b 0

:HELP
echo.
echo  %APP% %VER%   使用方法:
echo  ============================================================
echo   方式1: 把 文件/文件夹 直接拖到本脚本图标上
echo   方式2: 双击运行, 按菜单操作
echo.
echo   压缩等级: 固定极限 9（体积最小, 不再选择档位）
echo   输出格式:  .xz 通用压缩包
echo              .exe 自解压程序 （任意电脑双击即解压, 无需装软件）
echo              .apk 安卓自解压安装包 （安装后一键解压到手机）
echo              .zip 通用压缩包 （兼容性最好）
echo              .7z 高压缩率压缩包
echo   图标:       exe/apk 每次生成都会询问, 可用图片或 .ico, 输入 0 不设置
echo   APK签名:    每次生成询问 默认/自定义包名、签名别名, 并询问安卓 API 级别
echo   解压模式:   主菜单 [0] 可解压 xz/zip/7z/exe/apk 文件
echo   加密:       zip/7z/exe 可设密码; 支持 传统/AES-256/AES-256+头部加密;
echo               xz 格式不支持原生加密, 选择密码时自动生成加密容器
echo   工具下载:   主菜单 [5] 检测工具状态并打开 7-Zip 官网 / 一键下载
echo   两类脚本:   本精简版依赖系统环境; 便携版EXE/安卓APK 无环境可用
echo   文件夹/多文件 会自动打包为 tar.xz 再压缩
echo   主菜单 [1] 压缩文件（文件/文件夹/批量列表）; [4] 创建便携式压缩程序
echo.
echo   日志文件: !LOG!
echo  ============================================================
pause
goto :QUIT
goto :QUIT

:END
call :LOG "结束"
echo.
echo  按任意键退出 ...
pause >nul
goto :QUIT

:QUIT
call :LOG "程序退出"
endlocal
exit /b 0

rem ============================================================
rem 日志
rem ============================================================
rem ============ 图标设置 ============
:ASK_ICON
set "ICONOPT="
echo.
echo  ============================================================
echo    图标设置 (exe/apk 可自定义图标)
echo  ============================================================
echo      [0] 不设置图标 (默认)
echo      [1] 使用 .ico 图标文件
echo      [2] 使用图片文件 (.png/.jpg 自动转换)
echo.
if defined XZCP_AUTO if defined XZCP_ICONOPT set "ICONOPT=!XZCP_ICONOPT!"
if not defined ICONOPT set /p "ICONOPT=请选择 0 / 1 / 2 (直接回车=0): "
if "!ICONOPT!"=="" set "ICONOPT=0"
if "!ICONOPT!"=="0" (
  set "XZ_ICON="
  exit /b 0
)
set "ICONPATH="
if defined XZCP_AUTO if defined XZCP_ICONPATH set "ICONPATH=!XZCP_ICONPATH!"
if not defined ICONPATH (
  echo  [选择] 请在文件资源管理器中选择图标文件 ...
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择图标文件 (.ico/.png/.jpg)'; $f.Filter='图标|*.ico|图片|*.png;*.jpg'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择图标, 取消图标。
    set "XZ_ICON="
    exit /b 0
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "ICONPATH=%%L"
  del "!PICK!" >nul 2>&1
  if not defined ICONPATH (
    echo  [提示] 未选择图标, 取消图标。
    set "XZ_ICON="
    exit /b 0
  )
)
if not defined ICONPATH (
  echo  [错误] 未输入图标路径, 取消图标。
  set "XZ_ICON="
  exit /b 0
)
if not exist "!ICONPATH!" (
  echo  [错误] 找不到图标文件: !ICONPATH!
  echo         取消图标, 继续压缩。
  set "XZ_ICON="
  exit /b 0
)
set "XZ_ICON=!ICONPATH!"
call :LOG "图标: !ICONPATH!"
exit /b 0

rem ============ APK 自定义包名/签名 ============
:ASK_APKSIGN
set "SIGNOPT="
echo.
echo  ============================================================
echo    APK 包名与签名
echo  ============================================================
echo      [0] 默认包名签名  com.xzport / 自动生成密钥
echo      [1] 自定义包名和签名
echo.
if defined XZCP_AUTO if defined XZCP_SIGNOPT set "SIGNOPT=!XZCP_SIGNOPT!"
if not defined SIGNOPT set /p "SIGNOPT=请选择 0 / 1 (直接回车=0): "
if "!SIGNOPT!"=="" set "SIGNOPT=0"
if "!SIGNOPT!"=="0" (
  set "XZ_PKG="
  set "XZ_ALIAS="
  set "XZ_SPASS="
  set "XZ_KPASS="
  set "XZ_DNAME="
  exit /b 0
)
set "XZ_PKG="
if defined XZCP_AUTO if defined XZCP_PKG set "XZ_PKG=!XZCP_PKG!"
if not defined XZ_PKG set /p "XZ_PKG=请输入包名 (如 com.example.app): "
if not defined XZ_PKG (
  echo  [错误] 未输入包名, 使用默认。
  set "XZ_PKG="
  set "XZ_ALIAS="
  set "XZ_SPASS="
  set "XZ_KPASS="
  set "XZ_DNAME="
  exit /b 0
)
set "XZ_ALIAS="
if defined XZCP_AUTO if defined XZCP_ALIAS set "XZ_ALIAS=!XZCP_ALIAS!"
if not defined XZ_ALIAS set /p "XZ_ALIAS=请输入签名别名 (直接回车=默认): "
set "XZ_SPASS="
if defined XZCP_AUTO if defined XZCP_SPASS set "XZ_SPASS=!XZCP_SPASS!"
if not defined XZ_SPASS set /p "XZ_SPASS=请输入存储密码 (直接回车=默认): "
set "XZ_KPASS="
if defined XZCP_AUTO if defined XZCP_KPASS set "XZ_KPASS=!XZCP_KPASS!"
if not defined XZ_KPASS set /p "XZ_KPASS=请输入密钥密码 (直接回车=默认): "
set "XZ_DNAME="
if defined XZCP_AUTO if defined XZCP_DNAME set "XZ_DNAME=!XZCP_DNAME!"
if not defined XZ_DNAME set /p "XZ_DNAME=请输入证书 CN (如 CN=MyName 或 CN=MyName,OU=XZ, 直接回车=默认): "
call :LOG "APK 签名: 包名=!XZ_PKG! 别名=!XZ_ALIAS! CN=!XZ_DNAME!"
exit /b 0

rem ============ APK 安卓 API 级别 ============
:ASK_API
set "XZ_API="
echo.
echo  ============================================================
echo    安卓版本 (目标 SDK)
echo  ============================================================
echo     目标安卓版本, 决定编译 API 级别（避免安装时解析包失败）:
echo     常用: 14=Android14(API34)  15=Android15(API35)  16=Android16(API36)
echo.
if defined XZCP_AUTO if defined XZCP_API set "XZ_API=!XZCP_API!"
if not defined XZ_API set /p "XZ_API=请输入安卓版本 14/15/16 (直接回车=16): "
if "!XZ_API!"=="" set "XZ_API=16"
set "XZ_APIVER=!XZ_API!"
rem ---- 安卓版本 -> API 级别映射 (兼容直接输入 API 数字) ----
if "!XZ_API!"=="10" set "XZ_API=29"
if "!XZ_API!"=="11" set "XZ_API=30"
if "!XZ_API!"=="12" set "XZ_API=31"
if "!XZ_API!"=="13" set "XZ_API=33"
if "!XZ_API!"=="14" set "XZ_API=34"
if "!XZ_API!"=="15" set "XZ_API=35"
if "!XZ_API!"=="16" set "XZ_API=36"
call :LOG "APK 目标安卓版本: !XZ_APIVER! (API !XZ_API!)"
exit /b 0

rem ============ 品牌同步：生成 Windows 完整版 EXE ============
:SYNC_EXE
if not exist "!SD!build_full_exe.cmd" (
  echo  [同步] 缺少 build_full_exe.cmd，跳过 Windows EXE。
  exit /b 0
)
set "SEOUT="
if defined XZCP_AUTO if defined XZCP_MIEXEOUT set "SEOUT=!XZCP_MIEXEOUT!"
if not defined SEOUT (
  echo.
  echo  [同步EXE] 请在“另存为”窗口选择 EXE 保存位置 ...
  set "PICK=%TEMP%\xz_save_!RANDOM!.txt"
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $s=New-Object System.Windows.Forms.SaveFileDialog; $s.Title='保存Windows完整版EXE'; $s.Filter='EXE程序|*.exe'; $s.FileName='!MINAME!.exe'; if($s.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$s.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [同步] 已取消 Windows EXE。
    exit /b 0
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "SEOUT=%%L"
  del "!PICK!" >nul 2>&1
)
echo  [同步EXE] 正在生成 !MINAME! ...
set "SEARGS=/name:"!MINAME!" /version:"!MIVER!" /out:"!SEOUT!""
if defined MIICO set "SEARGS=!SEARGS! /icon:"!MIICO!""
call "!SD!build_full_exe.cmd" !SEARGS!
if exist "!SEOUT!" (
  echo  [同步完成] Windows EXE: !SEOUT!
  call :LOG "品牌同步EXE: !SEOUT!"
) else (
  echo  [同步] Windows EXE 未生成，请查看上方信息。
)
set "SEOUT=" & set "SEARGS="
exit /b 0

rem ============ 品牌同步：生成安卓完整版 APK ============
:SYNC_APK
if not exist "!SD!build_full_apk.cmd" (
  echo  [同步] 缺少 build_full_apk.cmd，跳过安卓 APK。
  exit /b 0
)
set "SAPKG="
if defined XZCP_AUTO if defined XZCP_PKG set "SAPKG=!XZCP_PKG!"
if not defined SAPKG if not defined XZCP_AUTO (
  set /p "SAPKG=安卓包名（直接回车=com.xzfull，可改如 com.company.app）: "
)
if not defined SAPKG set "SAPKG=com.xzfull"
call :ASK_API
set "SAOUT="
if defined XZCP_AUTO if defined XZCP_MIAPKOUT set "SAOUT=!XZCP_MIAPKOUT!"
if not defined SAOUT (
  echo.
  echo  [同步APK] 请在“另存为”窗口选择 APK 保存位置 ...
  set "PICK=%TEMP%\xz_save_!RANDOM!.txt"
  "!PSH!" -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $s=New-Object System.Windows.Forms.SaveFileDialog; $s.Title='保存安卓完整版APK'; $s.Filter='安卓安装包|*.apk'; $s.FileName='!MINAME!.apk'; if($s.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$s.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [同步] 已取消安卓 APK。
    exit /b 0
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "SAOUT=%%L"
  del "!PICK!" >nul 2>&1
)
echo  [同步APK] 正在生成 !MINAME!（包名 !SAPKG!，安卓 !XZ_APIVER!）...
set "SAARGS=/name:"!MINAME!" /ver:"!MIVER!" /pkg:"!SAPKG!" /api:!XZ_API! /out:"!SAOUT!""
if defined MIICO set "SAARGS=!SAARGS! /icon:"!MIICO!""
call "!SD!build_full_apk.cmd" !SAARGS!
if exist "!SAOUT!" (
  echo  [同步完成] 安卓 APK: !SAOUT!
  call :LOG "品牌同步APK: !SAOUT!"
) else (
  echo  [同步] 安卓 APK 未生成，请查看上方信息（通常是缺 JDK/Android SDK）。
)
set "SAOUT=" & set "SAARGS=" & set "SAPKG="
exit /b 0

rem ============ 检查 zip 引擎 ============
rem ============ v11 压缩档位（快速/标准/极限） ============
:ASK_LEVEL
if defined XZCP_AUTO (
  if defined XZCP_LEVEL set "LV=!XZCP_LEVEL!"
  exit /b 0
)
echo.
echo  ============================================================
echo    压缩档位（速度与体积）
echo  ============================================================
echo      [1] 快速   等级 3（最快, 体积略大）
echo      [2] 标准   等级 6（均衡）
echo      [3] 极限   等级 9（最慢, 体积最小, 默认）
echo.
set "LCHO="
set /p "LCHO=请选择 1/2/3 (直接回车=3): "
if "!LCHO!"=="1" set "LV=3"
if "!LCHO!"=="2" set "LV=6"
if "!LCHO!"=="3" set "LV=9"
if "!LCHO!"=="" set "LV=9"
call :LOG "压缩档位: !LV!"
exit /b 0

rem ============ v11 高级压缩参数 ============
:ASK_ADVOPTS
if defined XZCP_AUTO goto :BUILD_ZOPTS
set "VOLI="
set "SOLIDI="
set "DICTI="
set "MTNI="
set "RRI="
set "BEEPI="
set "SHAI="
echo.
echo  ============================================================
echo    高级参数（直接回车 = 推荐默认, 追求最小体积）
echo  ============================================================
if "!FMAT!"=="zip" if "!PACK!"=="0" set /p "VOLI=分卷大小(如 100m / 1g / 700m, 回车=不分卷): "
if "!FMAT!"=="7z" if "!PACK!"=="0" set /p "VOLI=分卷大小(如 100m / 1g, 回车=不分卷): "
if "!FMAT!"=="7z" set /p "SOLIDI=固实压缩? 体积更小 [Y/n] (回车=Y): "
if "!FMAT!"=="7z" set /p "DICTI=字典大小(如 64m / 256m / 512m, 回车=自动): "
if "!FMAT!"=="7z" set /p "MTNI=压缩线程数(回车=自动): "
set /p "BEEPI=完成后播放提示音? [y/N]: "
set /p "SHAI=生成 SHA256 校验文件? [y/N]: "
if defined VOLI set "VOL=!VOLI!"
if /i "!SOLIDI!"=="n" (set "SOLID=") else (set "SOLID=on")
if not "!FMAT!"=="7z" set "SOLID="
if defined DICTI set "DICT=!DICTI!"
if defined MTNI set "MTN=!MTNI!"
if /i "!BEEPI!"=="y" set "DOBEEP=1"
if /i "!SHAI!"=="y" set "DOSHA=1"
goto :BUILD_ZOPTS

rem ============ v11 组装 7z 引擎压缩参数 ============
:BUILD_ZOPTS
set "ZOPTS=-mx=!LV! -mmt=on"
set "ZOPTSS=-mx=!LV! -mmt=on"
if "!FMAT!"=="zip" (
  set "ZOPTS=-mx=!LV! -mmt=on -mcu=on"
  set "ZOPTSS=-mx=!LV! -mmt=on -mcu=on"
)
if "!FMAT!"=="7z" (
  set "ZOPTS=-mx=!LV! -mmt=on"
  set "ZOPTSS=-mx=!LV! -mmt=on"
  if "!SOLID!"=="on" (
    set "ZOPTS=!ZOPTS! -ms=on"
    set "ZOPTSS=!ZOPTSS! -ms=on"
  )
  if defined DICT (
    set "ZOPTS=!ZOPTS! -md=!DICT!"
    set "ZOPTSS=!ZOPTSS! -md=!DICT!"
  )
  if defined MTN (
    set "ZOPTS=!ZOPTS! -mmt=!MTN!"
    set "ZOPTSS=!ZOPTSS! -mmt=!MTN!"
  )
)
if defined VOL if "!PACK!"=="0" set "ZOPTS=!ZOPTS! -v!VOL!"
if defined VOL if not "!PACK!"=="0" echo  [提示] 自解压 EXE/APK 不支持分卷, 已忽略分卷设置
call :LOG "压缩参数: !ZOPTS! | !ZOPTSS!"
exit /b 0

rem ============ 计算字符串长度 :STRLEN "字符串" 输出变量 ============
:STRLEN
setlocal enabledelayedexpansion
set "GS=%~1"
set "GN=0"
:SL_LOOP
if defined GS (
  set "GS=!GS:~1!"
  set /a GN+=1
  goto :SL_LOOP
)
endlocal & set "%2=%GN%"
exit /b 0

:ASK_PASS
set "PASS="
set "PWARG="
echo.
echo  ============================================================
echo    压缩加密 (zip/7z/exe 支持, 多形式; xz 加密自动生成加密容器)
echo  ============================================================
echo      [0] 不加密 (默认)
echo      [1] 设置密码
echo.
if defined XZCP_AUTO if defined XZCP_PASSOPT set "PASSOPT=!XZCP_PASSOPT!"
if not defined PASSOPT set /p "PASSOPT=请选择 0 / 1 (直接回车=0): "
if "!PASSOPT!"=="" set "PASSOPT=0"
if "!PASSOPT!"=="0" (
  set "PASS="
  set "PWARG="
  exit /b 0
)
if defined XZCP_AUTO if defined XZCP_PASS set "PASS=!XZCP_PASS!"
if not defined PASS set /p "PASS=请输入压缩密码: "
if not defined PASS (
  echo  [提示] 未输入密码, 本次不加密。
  set "PWARG="
  exit /b 0
)
if not defined XZCP_AUTO (
  set "PASS2="
  set /p "PASS2=请再次输入密码确认: "
  if not "!PASS2!"=="!PASS!" (
    echo  [错误] 两次输入的密码不一致, 请重新设置。
    set "PASSOPT="
    goto :ASK_PASS
  )
  set "PLEN=0"
  call :STRLEN "!PASS!" PLEN
  if !PLEN! lss 8 echo  [提示] 密码强度: 弱（建议至少 8 位并混合字母、数字、符号）
  if !PLEN! geq 8 if !PLEN! lss 12 echo  [提示] 密码强度: 中等
  if !PLEN! geq 12 echo  [提示] 密码强度: 强
)
set "PWARG=-p!PASS!"
rem ---- 加密方式 ----
set "ENCTYPE="
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
call :LOG "加密: 方式=!ENCTYPE!"
exit /b 0
:CK_ZIP
if defined SZIP exit /b 0
echo  [错误] 缺少 zip 压缩引擎。
echo         zip 压缩需要 7-Zip, 当前未检测到。
echo         可选: [1] 一键下载安装 7-Zip   [0] 取消  （也可主菜单 [5] 打开官网）
set "DLO="
set /p "DLO=请选择: "
if /i "!DLO!"=="1" call :DL_7Z
if errorlevel 1 exit /b 1
if defined SZIP exit /b 0
echo  [错误] 仍缺少 7-Zip, 无法压缩 zip。
call :LOG "缺少 7-Zip, zip 失败"
pause
exit /b 1

rem ============ 检查 7z 引擎 ============
:CK_7Z
if defined SZIP exit /b 0
echo  [错误] 缺少 7z 压缩引擎。
echo         7z 压缩需要 7-Zip, 当前未检测到。
echo         可选: [1] 一键下载安装 7-Zip   [0] 取消  （也可主菜单 [5] 打开官网）
set "DLO="
set /p "DLO=请选择: "
if /i "!DLO!"=="1" call :DL_7Z
if errorlevel 1 exit /b 1
if defined SZIP exit /b 0
echo  [错误] 仍缺少 7-Zip, 无法压缩 7z。
call :LOG "缺少 7-Zip, 7z 失败"
pause
exit /b 1

rem ============ 检查 gz/bz2/tgz 引擎 ============
:CK_GZ
if not "!ISDIR!"=="1" if not "!MULTI!"=="1" (
  if defined SZIP exit /b 0
  echo  [错误] 单文件压成 .gz/.bz2 需要 7-Zip, 当前未检测到。
  echo         可改压文件夹（用 tar.gz）或按菜单 [4] 一键安装 7-Zip。
  set "DLO="
  set /p "DLO=是否现在下载安装 7-Zip? [1]是 [0]否: "
  if /i "!DLO!"=="1" call :DL_7Z
  if errorlevel 1 exit /b 1
  if defined SZIP exit /b 0
  pause
  exit /b 1
)
if defined TAREXE exit /b 0
if defined SZIP exit /b 0
echo  [错误] 文件夹/多文件压成 tar.gz/tar.bz2 需要系统 tar.exe 或 7-Zip。
call :LOG "缺少 tar/7z, 无法压缩 !FMAT!"
pause
exit /b 1

rem ============ 一键下载安装 7-Zip ============
:DL_7Z
echo.
echo  [下载] 正在下载 7-Zip 安装包 ...
set "DLURL=https://www.7-zip.org/a/7z2409-x64.exe"
set "DLFILE=%TEMP%z_setup_!RANDOM!.exe"
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -Uri '%DLURL%' -OutFile '%DLFILE%' -UseBasicParsing;exit 0}catch{exit 1}"
if not exist "%DLFILE%" (
  echo  [错误] 下载失败, 请手动访问 https://www.7-zip.org 安装 7-Zip。
  call :LOG "下载 7-Zip 失败"
  exit /b 1
)
echo  [下载] 下载完成, 正在安装（若弹出用户账户控制请点"是"）...
rem 提权并等待安装进程真正结束（start /wait 对提权进程可能提前返回）
powershell -NoProfile -ExecutionPolicy Bypass -Command "try{Start-Process -FilePath '%DLFILE%' -ArgumentList '/S' -Verb RunAs -Wait;exit 0}catch{exit 1}"
rem 轮询等待检测到 7-Zip（最多 60 秒），兜底安装器延迟
set "DLWAIT=0"
:DL_WAITL
call :DETECT
if defined SZIP goto :DL_OK
set /a DLWAIT+=1
if !DLWAIT! geq 60 goto :DL_FAIL
ping -n 2 127.0.0.1 >nul
goto :DL_WAITL
:DL_FAIL
del "%DLFILE%" >nul 2>&1
echo  [错误] 安装后仍未检测到 7-Zip, 请手动安装。
call :LOG "7-Zip 安装后未检测到"
exit /b 1
:DL_OK
del "%DLFILE%" >nul 2>&1
echo  [通过] 7-Zip 已就绪。
call :LOG "7-Zip 一键安装完成（等待 !DLWAIT! 秒后检测到）"
exit /b 0

rem ============ 压缩为 zip ============
:RUN_ZIP
set "ZARG="
if defined PASS (
  set "ZARG=!PWARG!"
  if not "!ENCTYPE!"=="1" set "ZARG=!PWARG! -mem=AES256"
)
echo.
echo  [zip] 正在压缩为 .zip ...
set "PROGCMD=a -tzip -bsp1 !ZOPTS! !ZARG! "!OUT!" "!IN!""
if "!MULTI!"=="1" set "PROGCMD=a -tzip -bsp1 !ZOPTS! !ZARG! "!OUT!" !ALLARGS!"
set "PMODE=add"
call :RUN_PROG
call :LOG "7-Zip 退出码: !EC!"
if "!EC!"=="0" exit /b 0
if "!EC!"=="1" (
  echo  [警告] 7-Zip 发出了警告, 已忽略。
  call :LOG "警告: 7-Zip 退出码 1"
  exit /b 0
)
goto :FAIL_7Z

rem ============ 压缩为 7z ============
:RUN_7Z
set "S7ARGS="
if defined PASS (
  set "S7ARGS=!PWARG!"
  if "!ENCTYPE!"=="3" set "S7ARGS=!PWARG! -mhe=on"
)
echo.
echo  [7z] 正在压缩为 .7z ...
set "PROGCMD=a -t7z -bsp1 !ZOPTS! !S7ARGS! "!OUT!" "!IN!""
if "!MULTI!"=="1" set "PROGCMD=a -t7z -bsp1 !ZOPTS! !S7ARGS! "!OUT!" !ALLARGS!"
set "PMODE=add"
call :RUN_PROG
call :LOG "7-Zip 退出码: !EC!"
if "!EC!"=="0" exit /b 0
if "!EC!"=="1" (
  echo  [警告] 7-Zip 发出了警告, 已忽略。
  call :LOG "警告: 7-Zip 退出码 1"
  exit /b 0
)
goto :FAIL_7Z

rem ============ 解压模式 ============
rem ============ 打开压缩文件 (归档管理器) ============
:OPENARC
set "EXIN="
echo.
echo  ============================================================
echo    打开压缩文件 (查看 / 添加 / 解压 / 移除 / 取消加密)
echo  ============================================================
echo  支持: .xz .zip .7z .rar .exe .apk
if defined XZCP_AUTO if defined XZCP_EXIN set "EXIN=!XZCP_EXIN!"
if not defined EXIN (
  echo  [选择] 请选择要打开的压缩文件 ...
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要打开的压缩文件'; $f.Filter='压缩文件|*.zip;*.7z;*.xz;*.rar;*.exe;*.apk|所有文件|*.*'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择文件, 取消操作
    pause
    if defined XZCP_AUTO goto :QUIT
    goto :MAINMENU
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "EXIN=%%L"
  del "!PICK!" >nul 2>&1
  if not defined EXIN (
    echo  [提示] 未选择文件, 取消操作
    pause
    if defined XZCP_AUTO goto :QUIT
    goto :MAINMENU
  )
)
if not exist "!EXIN!" (
  echo  [错误] 找不到文件: !EXIN!
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :MAINMENU
)
for %%F in ("!EXIN!") do set "EXT2=%%~xF"
if not defined EXT2 (
  echo  [错误] 无法识别文件扩展名: !EXIN!
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :MAINMENU
)
call :LOG "打开压缩文件: !EXIN! (格式 !EXT2!)"

:ARC_MENU
echo.
echo  ============================================================
echo    [已打开] !EXIN!
echo    格式: !EXT2!
echo  ============================================================
echo      [1] 查看内容列表
echo      [2] 添加文件
echo      [3] 解压文件
echo      [4] 移除文件
echo      [5] 取消加密
echo      [6] 注释 (查看/添加/移除)
echo      [7] 搜索包内文件
echo      [8] 预览文本文件
echo      [9] 修复 zip 中文文件名乱码
echo      [Q] 返回主菜单
echo.
set "AMENU="
if defined XZCP_AUTO if defined XZCP_AMENU set "AMENU=!XZCP_AMENU!"
if not defined AMENU set /p "AMENU=请选择: "
if defined XZCP_AUTO if not defined AMENU goto :QUIT
if /i "!AMENU!"=="q" goto :MAINMENU
if "!AMENU!"=="1" goto :ARC_LIST
if "!AMENU!"=="2" goto :ARC_ADD
if "!AMENU!"=="3" goto :ARC_EXTRACT
if "!AMENU!"=="4" goto :ARC_REMOVE
if "!AMENU!"=="5" goto :ARC_UNENC
if "!AMENU!"=="6" goto :ARC_COMMENT
if "!AMENU!"=="7" goto :ARC_SEARCH
if "!AMENU!"=="8" goto :ARC_PREVIEW
if "!AMENU!"=="9" goto :ARC_ZIPENC
echo  [错误] 请输入 1-9 或 Q
goto :ARC_MENU

:ARC_LIST
echo.
echo  [列表] !EXIN!
echo  ----------------------------------------
"!SZIP!" l "!EXIN!"
set "EC=!errorlevel!"
call :LOG "归档列表: !EXIN! (退出码 !EC!)"
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

rem ---- 搜索包内文件 ----
:ARC_SEARCH
echo.
set "KW="
set /p "KW=输入文件名关键词(支持部分匹配, 不区分大小写): "
if not defined KW goto :ARC_MENU
echo.
echo  [搜索] 包含 "!KW!" 的条目:
echo  ----------------------------------------
"!SZIP!" l "!EXIN!" 2>nul | findstr /i /c:"!KW!"
echo  ----------------------------------------
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

rem ---- 预览包内文本文件 ----
:ARC_PREVIEW
echo.
echo  [预览] 包内内容列表:
"!SZIP!" l "!EXIN!" 2>nul
echo.
set "PF="
set /p "PF=输入要预览的【包内文件名】(如 readme.txt, 不区分大小写): "
if not defined PF goto :ARC_MENU
set "PVPASS="
set /p "PVPASS=密码(未加密直接回车): "
set "PVPA="
if not "!PVPASS!"=="" set "PVPA=-p"!PVPASS!""
set "PT=%TEMP%\xzprev_!RANDOM!"
mkdir "!PT!" 2>nul
"!SZIP!" e -y !PVPA! -o"!PT!" "!EXIN!" "!PF!" >nul 2>&1
set "PVF="
for /f "delims=" %%F in ('dir /b /s /a-d "!PT!" 2^>nul') do set "PVF=%%F"
if not defined PVF (
  echo  [错误] 未找到该文件, 可能文件名不匹配或密码错误。
  pause
  rd /s /q "!PT!" 2>nul
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
for %%F in ("!PVF!") do set "PVX=%%~xF"
set "PVOK="
for %%E in (.txt .md .log .json .xml .csv .ini .html .htm .js .css .bat .cmd .java .py .c .cpp .h .cfg .conf .properties .yaml .yml .sql .sh .gradle) do if /i "!PVX!"=="%%E" set "PVOK=1"
if not defined PVOK (
  echo  [提示] 文件类型 !PVX! 不是文本, 无法预览（二进制/图片/音视频等）。
  pause
  rd /s /q "!PT!" 2>nul
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
echo.
echo  ============================================================
echo    预览: !PF!
echo  ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\preview.ps1" "!PVF!"
echo  ============================================================
pause
rd /s /q "!PT!" 2>nul
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

rem ---- 修复 zip 中文文件名乱码 ----
:ARC_ZIPENC
if /i not "!EXT2!"==".zip" (
  echo  [提示] 该功能仅用于 .zip 文件, 用于修复中文文件名乱码。
  echo         当前文件格式: !EXT2!
  pause
  goto :ARC_MENU
)
echo.
echo  说明: 旧版工具打包的 zip 可能用 GBK 编码文件名, 导致部分软件显示乱码。
echo        本功能将文件名重新转为标准 UTF-8（自动备份 .bak）。
set "ZCP="
set /p "ZCP=源代码页(回车=936 简体GBK; 繁体中文填 950): "
if not defined ZCP set "ZCP=936"
powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\zipencoding.ps1" "!EXIN!" -cp !ZCP!
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

:ARC_ADD
echo.
echo  [添加] 选择要加入此压缩文件的文件 (可多选) ...
set "PICK="
set "ADDLIST="
if defined XZCP_AUTO if defined XZCP_ADDIN (
  rem 自动模式: XZCP_ADDIN 为分号分隔的路径列表
  set "PICK="
  for %%P in (!XZCP_ADDIN!) do set "ADDLIST=!ADDLIST! "%%~P""
)
if not defined XZCP_AUTO (
  set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要添加的文件'; $f.Multiselect=$true; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',($f.FileNames -join [char]10),[Text.Encoding]::Default)}"
  if not exist "!PICK!" (
    echo  [提示] 未选择文件, 取消
    pause
    if defined XZCP_AUTO goto :QUIT
    goto :ARC_MENU
  )
  for /f "usebackq delims=" %%L in ("!PICK!") do set "ADDLIST=!ADDLIST! "%%L""
  del "!PICK!" >nul 2>&1
)
if not defined ADDLIST (
  echo  [错误] 未选择任何文件
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)

rem ---- xz: 解包 -> 放入 -> 重打包 ----
if /i "!EXT2!"==".xz" (
  call :XZ_UNPACK
  if errorlevel 1 (
    echo  [提示] 该 .xz 是单文件流, 无法追加（仅 tar.xz 容器支持; 可先解压再重新压缩）
    pause
    if defined XZCP_AUTO goto :QUIT
    goto :ARC_MENU
  )
  echo  [添加] 正在放入文件 ...
  for %%F in (!ADDLIST!) do copy /y "%%~F" "!XZWT!\" >nul 2>&1
  call :XZ_REPACK
  set "EC=!errorlevel!"
  if "!EC!"=="0" (echo  [通过] 添加成功并已重新压缩) else (echo  [错误] 重新压缩失败, 退出码 !EC!)
  call :LOG "xz 归档添加: !ADDLIST! -> !EXIN! (退出码 !EC!)"
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)

set "ADDPASS="
if defined XZCP_AUTO if defined XZCP_EXPASS set "ADDPASS=!XZCP_EXPASS!"
if not defined XZCP_AUTO set /p "ADDPASS=归档密码 (加密归档添加需密码, 无直接回车): "
set "PARG="
if not "!ADDPASS!"=="" set "PARG=-p"!ADDPASS!""
echo  [添加] 正在添加 ...
set "PROGCMD=a -bsp1 "!EXIN!" !ADDLIST! !PARG! -y"
set "PMODE=add"
call :RUN_PROG
if "!EC!"=="0" (
  echo  [通过] 添加成功
) else (
  echo  [错误] 添加失败, 退出码 !EC!
)
call :LOG "归档添加: !ADDLIST! -> !EXIN! (退出码 !EC!)"
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

:ARC_EXTRACT
echo.
echo  ============================================================
echo    解压文件
echo  ============================================================
set "EXOUT="
if defined XZCP_AUTO if defined XZCP_EXOUT set "EXOUT=!XZCP_EXOUT!"
if not defined EXOUT set /p "EXOUT=解压到目录 (直接回车=同目录): "
if not defined EXOUT for %%F in ("!EXIN!") do set "EXOUT=%%~dpF"
set "EXPASS="
if defined XZCP_AUTO if defined XZCP_EXPASS set "EXPASS=!XZCP_EXPASS!"
if not defined EXPASS set /p "EXPASS=加密密码 (文件已加密则输入, 无密码直接回车): "
set "PASSARG="
if not "!EXPASS!"=="" set "PASSARG=-p"!EXPASS!""
set "EXENGINE="
set "EXPROGCMD="
if /i "!EXT2!"==".zip" set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
if /i "!EXT2!"==".7z" set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
if /i "!EXT2!"==".rar" (
  if defined RAREXE set "EXENGINE=!RAREXE!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
  if not defined RAREXE set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
)
if /i "!EXT2!"==".xz" call :XZ_PICK_EXTRACT
if /i "!EXT2!"==".exe" (
  if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
  if not defined SZIP set "EXENGINE=start" & set "EXPROGCMD="!EXIN!""
)
if /i "!EXT2!"==".apk" (
  echo  [提示] APK 是安卓安装包，可安装到手机/模拟器，也可用 7-Zip 打开查看内容。
  if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
)
if defined XZDEC goto :XZ_DEC_SINGLE
if not defined EXENGINE (
  echo  [错误] 不支持的文件类型: !EXIN!
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
echo  [解压] 正在解压 ...
if /i "!EXENGINE!"=="start" (
  start "" !EXPROGCMD!
  set "EC=0"
) else (
  set "SZIP=!EXENGINE!"
  set "PROGCMD=!EXPROGCMD!"
  set "PMODE=extract"
  call :RUN_PROG
)
if "!EC!"=="0" (
  echo  [通过] 解压完成, 输出目录: !EXOUT!
) else (
  echo  [错误] 解压失败, 退出码 !EC!
)
call :LOG "解压: !EXIN! 密码=!EXPASS! (退出码 !EC!)"
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

:ARC_REMOVE
if /i "!EXT2!"==".xz" goto :ARC_REMOVE_XZ
echo.
echo  [移除] 正在读取归档内容 ...
set "ARCLST=%TEMP%\xz_arclist_!RANDOM!.txt"
"!SZIP!" l -slt -ba "!EXIN!" > "!ARCLST!" 2>nul
set "EC=!errorlevel!"
if not "!EC!"=="0" (
  echo  [错误] 读取归档失败, 退出码 !EC!
  if exist "!ARCLST!" del "!ARCLST!"
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
set "AN=0"
for /f "tokens=1,* delims==" %%a in ('findstr /b "Path =" "!ARCLST!"') do (
  set /a AN+=1
  set "ARC_!AN!=%%b"
)
if exist "!ARCLST!" del "!ARCLST!"
if !AN! equ 0 (
  echo  [提示] 归档为空或无法解析
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
echo  归档内条目（!AN! 个）:
for /l %%i in (1,1,!AN!) do (
  call set "ITEM=%%ARC_%%i%%"
  for /f "tokens=*" %%x in ("!ITEM!") do set "ITEM=%%x"
  echo    %%i. !ITEM!
)
echo.
set "RMNUM="
if defined XZCP_AUTO if defined XZCP_RMNUM set "RMNUM=!XZCP_RMNUM!"
if not defined RMNUM set /p "RMNUM=输入要移除的条目序号 (直接回车=取消): "
if not defined RMNUM (
  echo  [提示] 已取消
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
set "RMNUM=!RMNUM: =!"
if !RMNUM! geq 1 if !RMNUM! leq !AN! (
  call set "ARCITEM=%%ARC_!RMNUM!%%"
  for /f "tokens=*" %%x in ("!ARCITEM!") do set "ARCITEM=%%x"
  echo  [移除] 条目: !ARCITEM!
  set "ARPASS="
  if defined XZCP_AUTO if defined XZCP_EXPASS set "ARPASS=!XZCP_EXPASS!"
  if not defined ARPASS set /p "ARPASS=归档密码 (加密归档移除需密码, 无直接回车): "
  set "DARG="
  if not "!ARPASS!"=="" set "DARG=-p"!ARPASS!""
  set "PROGCMD=d -bsp1 "!EXIN!" "!ARCITEM!" !DARG! -y"
  set "PMODE=add"
  call :RUN_PROG
  if "!EC!"=="0" (
    echo  [通过] 移除成功
  ) else (
    echo  [错误] 移除失败, 退出码 !EC!
  )
  call :LOG "归档移除: !ARCITEM! <- !EXIN! (退出码 !EC!)"
) else (
  echo  [错误] 无效序号: !RMNUM!
)
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

:ARC_UNENC
echo.
echo  ============================================================
echo    取消加密（解压后用原格式重新打包为无密码归档）
echo  ============================================================
if /i "!EXT2!"==".xz" (
  echo  [提示] xz 加密形式为加密容器（.enc.zip）, 取消加密将解出内部的 .xz 文件
)
if /i "!EXT2!"==".rar" (
  echo  [提示] rar 不支持就地取消加密, 请先解压再重新压缩
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
set "UPASS="
if defined XZCP_AUTO if defined XZCP_EXPASS set "UPASS=!XZCP_EXPASS!"
if not defined UPASS set /p "UPASS=输入当前加密密码: "
set "PARG="
if not "!UPASS!"=="" set "PARG=-p"!UPASS!""
set "UTMP=%TEMP%\xz_unenc_!RANDOM!"
mkdir "!UTMP!" >nul 2>&1
echo  [解压] 正在用密码解压到临时目录 ...
"!SZIP!" x "!EXIN!" -o"!UTMP!\" !PARG! -y
set "EC=!errorlevel!"
if not "!EC!"=="0" (
  echo  [错误] 解压失败（退出码 !EC!）, 密码可能错误
  rmdir /s /q "!UTMP!" >nul 2>&1
  call :LOG "取消加密: 解压失败 !EXIN! (退出码 !EC!)"
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
echo  [重新打包] 无密码重新打包 ...
set "NEW="
if /i "!EXT2!"==".zip" set "NEW=!EXIN!_nopass.zip"
if /i "!EXT2!"==".7z" set "NEW=!EXIN!_nopass.7z"
if /i "!EXT2!"==".xz" (
  for /f "delims=" %%f in ('dir /b /a-d "!UTMP!" 2^>nul') do set "XZOUT=%%f"
  if not defined XZOUT (
    echo  [错误] 未在容器内找到 xz 文件
    rmdir /s /q "!UTMP!" >nul 2>&1
    pause
    if defined XZCP_AUTO goto :QUIT
    goto :ARC_MENU
  )
  move /y "!UTMP!\!XZOUT!" "!EXIN!_去密.xz" >nul 2>&1
  set "NEW=!EXIN!_去密.xz"
)
if not defined NEW (
  echo  [错误] 该格式不支持取消加密（zip/7z/xz 支持）
  rmdir /s /q "!UTMP!" >nul 2>&1
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
if /i "!EXT2!"==".zip" "!SZIP!" a -tzip "!NEW!" "!UTMP!\*" -y >nul 2>&1
if /i "!EXT2!"==".7z" "!SZIP!" a -t7z "!NEW!" "!UTMP!\*" -y >nul 2>&1
set "EC=!errorlevel!"
rmdir /s /q "!UTMP!" >nul 2>&1
if not "!EC!"=="0" (
  echo  [错误] 重新打包失败, 退出码 !EC!（原文件未改动）
  if exist "!NEW!" del /f /q "!NEW!" >nul 2>&1
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
echo  [替换] 删除原加密归档, 以无密码版本替换 ...
del /f /q "!EXIN!" >nul 2>&1
move /y "!NEW!" "!EXIN!" >nul 2>&1
set "EC=!errorlevel!"
if "!EC!"=="0" (
  echo  [通过] 取消加密完成, 已替换为无密码归档: !EXIN!
) else (
  echo  [错误] 替换失败, 无密码版本保留为: !NEW!
)
call :LOG "取消加密: !EXIN! (退出码 !EC!)"
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

:ARC_COMMENT
echo.
echo  ============================================================
echo    压缩包注释  （当前: !EXT2!）
echo  ============================================================
echo      [1] 查看注释
echo      [2] 添加 / 修改注释
echo      [3] 移除注释
echo      [Q] 返回
echo.
set "CMENU="
if defined XZCP_AUTO if defined XZCP_CMENU set "CMENU=!XZCP_CMENU!"
if not defined CMENU set /p "CMENU=请选择: "
if defined XZCP_AUTO if not defined CMENU goto :QUIT
if /i "!CMENU!"=="q" goto :ARC_MENU
if not "!CMENU!"=="1" if not "!CMENU!"=="2" if not "!CMENU!"=="3" (
  echo  [错误] 请输入 1、2、3 或 Q
  goto :ARC_COMMENT
)
set "CMTNAME=__压缩包注释__.txt"

rem ---- 查看 ----
if "!CMENU!"=="1" goto :CMT_GET
goto :CMT_GET_END
:CMT_GET
if /i "!EXT2!"==".zip" (
  echo  ----------------------------------------
  powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\zipcomment.ps1" "!EXIN!" get
  echo  ----------------------------------------
)
if /i "!EXT2!"==".7z" (
  set "CMTT=%TEMP%\xzcmt_!RANDOM!"
  mkdir "!CMTT!" >nul 2>&1
  "!SZIP!" e "!EXIN!" "!CMTNAME!" -o"!CMTT!\" -y >nul 2>&1
  if exist "!CMTT!\!CMTNAME!" (
    echo  ----------------------------------------
    type "!CMTT!\!CMTNAME!"
    echo  ----------------------------------------
  ) else (
    echo  [提示] 该压缩包没有注释
  )
  rmdir /s /q "!CMTT!" >nul 2>&1
)
if /i "!EXT2!"==".xz" (
  call :XZ_UNPACK
  if errorlevel 1 (
    echo  [提示] 单文件 .xz 不支持注释
  ) else (
    if exist "!XZWT!\!CMTNAME!" (
      echo  ----------------------------------------
      type "!XZWT!\!CMTNAME!"
      echo  ----------------------------------------
    ) else (
      echo  [提示] 该压缩包没有注释
    )
    rmdir /s /q "!XZWT!" >nul 2>&1
  )
)
if /i not "!EXT2!"==".zip" if /i not "!EXT2!"==".7z" if /i not "!EXT2!"==".xz" (
  echo  [提示] 仅 zip/7z/xz 支持注释
)
call :LOG "注释查看: !EXIN!"
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU
:CMT_GET_END

rem ---- 添加 / 修改 ----
if "!CMENU!"=="2" goto :CMT_SET
goto :CMT_SET_END
:CMT_SET
set "CMTF=%TEMP%\xzcmt_in_!RANDOM!.txt"
if defined XZCP_AUTO if defined XZCP_CMFILE set "CMTF=!XZCP_CMFILE!"
if not defined XZCP_AUTO (
  echo 请在弹出的记事本中输入注释内容, 保存后关闭记事本 ...
  >"!CMTF!" echo 在此输入压缩包注释
  notepad "!CMTF!"
)
if not exist "!CMTF!" (
  echo  [提示] 已取消
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
if /i "!EXT2!"==".zip" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\zipcomment.ps1" "!EXIN!" set "!CMTF!"
  echo  [通过] 注释已写入 zip
)
if /i "!EXT2!"==".7z" (
  set "CMTD=%TEMP%\xzcmt_add_!RANDOM!"
  mkdir "!CMTD!" >nul 2>&1
  copy /y "!CMTF!" "!CMTD!\!CMTNAME!" >nul 2>&1
  pushd "!CMTD!"
  "!SZIP!" a "!EXIN!" "!CMTNAME!" -y >nul 2>&1
  popd
  set "EC=!errorlevel!"
  rmdir /s /q "!CMTD!" >nul 2>&1
  if "!EC!"=="0" (echo  [通过] 注释已写入 7z) else (echo  [错误] 写入失败, 退出码 !EC!)
)
if /i "!EXT2!"==".xz" (
  call :XZ_UNPACK
  if errorlevel 1 (
    echo  [提示] 单文件 .xz 不支持注释
  ) else (
    copy /y "!CMTF!" "!XZWT!\!CMTNAME!" >nul 2>&1
    call :XZ_REPACK
    set "EC=!errorlevel!"
    if "!EC!"=="0" (echo  [通过] 注释已写入并重新压缩) else (echo  [错误] 重新压缩失败, 退出码 !EC!)
  )
)
if /i not "!EXT2!"==".zip" if /i not "!EXT2!"==".7z" if /i not "!EXT2!"==".xz" (
  echo  [提示] 仅 zip/7z/xz 支持注释
)
call :LOG "注释添加: !EXIN!"
if not defined XZCP_AUTO if not defined XZCP_CMFILE pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU
:CMT_SET_END

rem ---- 移除 ----
if "!CMENU!"=="3" goto :CMT_CLR
goto :CMT_CLR_END
:CMT_CLR
if /i "!EXT2!"==".zip" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\zipcomment.ps1" "!EXIN!" clear
  echo  [通过] zip 注释已移除
)
if /i "!EXT2!"==".7z" (
  "!SZIP!" d "!EXIN!" "!CMTNAME!" -y >nul 2>&1
  echo  [通过] 7z 注释已移除
)
if /i "!EXT2!"==".xz" (
  call :XZ_UNPACK
  if errorlevel 1 (
    echo  [提示] 单文件 .xz 不支持注释
  ) else (
    if exist "!XZWT!\!CMTNAME!" del /f /q "!XZWT!\!CMTNAME!" >nul 2>&1
    call :XZ_REPACK
    echo  [通过] xz 注释已移除并重新压缩
  )
)
if /i not "!EXT2!"==".zip" if /i not "!EXT2!"==".7z" if /i not "!EXT2!"==".xz" (
  echo  [提示] 仅 zip/7z/xz 支持注释
)
call :LOG "注释移除: !EXIN!"
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU
:CMT_CLR_END
goto :ARC_MENU

rem ============ xz 管理器: 移除条目 ============
:ARC_REMOVE_XZ
echo.
echo  [移除] 正在读取 tar.xz 内容 ...
call :XZ_UNPACK
if errorlevel 1 (
  echo  [错误] 单文件 .xz 流不支持移除条目（仅 tar.xz 容器支持）
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
set "XN=0"
for /f "delims=" %%F in ('dir /b /s /a-d "!XZWT!" 2^>nul') do (
  set /a XN+=1
  set "XZF_!XN!=%%F"
)
if !XN! equ 0 (
  echo  [提示] 归档为空
  rmdir /s /q "!XZWT!" >nul 2>&1
  pause
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
echo  归档内文件（!XN! 个）:
for /l %%i in (1,1,!XN!) do (
  call set "XF=%%XZF_%%i%%"
  call set "XR=%%XF:!XZWT!\=%%"
  echo    %%i. !XR!
)
echo.
set "XRM="
if defined XZCP_AUTO if defined XZCP_RMNUM set "XRM=!XZCP_RMNUM!"
if not defined XRM set /p "XRM=输入要移除的序号 (回车=取消): "
if not defined XRM (
  echo  [提示] 已取消
  rmdir /s /q "!XZWT!" >nul 2>&1
  if defined XZCP_AUTO goto :QUIT
  goto :ARC_MENU
)
if !XRM! geq 1 if !XRM! leq !XN! (
  call set "XDEL=%%XZF_!XRM!%%"
  del /f /q "!XDEL!" >nul 2>&1
  echo  [移除] 已删除, 正在重新压缩 ...
  call :XZ_REPACK
  set "EC=!errorlevel!"
  if "!EC!"=="0" (echo  [通过] 移除成功) else (echo  [错误] 重新压缩失败, 退出码 !EC!)
  call :LOG "xz 归档移除序号 !XRM! <- !EXIN! (退出码 !EC!)"
) else (
  echo  [错误] 无效序号: !XRM!
  rmdir /s /q "!XZWT!" >nul 2>&1
)
pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU

rem ============ xz 解包/重打包 (管理器共用) ============
:XZ_PICK_EXTRACT
rem 选择 .xz 解压方式：.tar.xz/.txz 用 tar；纯 .xz 单文件用 xz.exe
set "XZDEC="
set "XZISTAR="
echo !EXIN! | findstr /l /i /c:".tar.xz" >nul 2>&1 && set "XZISTAR=1"
echo !EXIN! | findstr /l /i /c:".txz" >nul 2>&1 && set "XZISTAR=1"
if defined XZISTAR (
  if defined TAREXE set "EXENGINE=!TAREXE!" & set "EXPROGCMD=-xf "!EXIN!" -C "!EXOUT!""
  if not defined TAREXE if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
  set "XZISTAR="
  goto :eof
)
if defined XZEXE set "XZDEC=1"
if not defined XZDEC if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""
if not defined XZDEC if not defined EXENGINE echo  [错误] 没有可用的 xz 解压引擎（需要 xz.exe / 7z / tar）
goto :eof

:XZ_DEC_SINGLE
rem 纯 .xz 单文件用原生 xz.exe 解压，输出文件名 = 归档名去掉 .xz
if not exist "!EXOUT!" mkdir "!EXOUT!" >nul 2>&1
set "XZWORK=!EXIN!"
set "XZSRCDIR="
for %%F in ("!EXIN!") do set "XZSRCDIR=%%~dpF"
if /i not "!XZSRCDIR!"=="!EXOUT!\" (
  for %%F in ("!EXIN!") do copy /y "!EXIN!" "!EXOUT!\%%~nxF" >nul 2>&1
  for %%F in ("!EXIN!") do set "XZWORK=!EXOUT!\%%~nxF"
)
echo  [解压] 原生 xz 解压中 ...
set "PROGEXE=!XZEXE!"
set "PROGCMD=-d -k -f -v "!XZWORK!""
set "PMODE=extract"
call :RUN_PROG
set "EC=!errorlevel!"
if "!EC!"=="0" (
  echo  [通过] 原生 xz 解压完成, 目标目录: !EXOUT!
) else (
  echo  [错误] 原生 xz 解压失败, 退出码 !EC!
)
call :LOG "原生xz解压: !EXIN! -^> !EXOUT! (退出码 !EC!)"
set "XZDEC="
if not defined XZCP_AUTO pause
if defined XZCP_AUTO goto :QUIT
goto :ARC_MENU


:XZ_UNPACK
set "XZWT=%TEMP%\xzedit_%RANDOM%_%RANDOM%"
mkdir "!XZWT!" >nul 2>&1
set "XZMODE="
if defined TAREXE (
  "!TAREXE!" -xf "!EXIN!" -C "!XZWT!" >nul 2>&1
  if not errorlevel 1 (
    dir /b "!XZWT!" >nul 2>&1 && set "XZMODE=tar"
  )
)
if not defined XZMODE if defined SZIP (
  set "XZSTG1=%TEMP%\xzstg1_%RANDOM%_%RANDOM%"
  mkdir "!XZSTG1!" >nul 2>&1
  "!SZIP!" x "!EXIN!" -o"!XZSTG1!\" -y >nul 2>&1
  set "TARF="
  for /f "delims=" %%F in ('dir /b "!XZSTG1!\*.tar" 2^>nul') do set "TARF=%%F"
  if defined TARF (
    "!SZIP!" x "!XZSTG1!\!TARF!" -o"!XZWT!\" -y >nul 2>&1
    set "XZMODE=tar"
  ) else (
    set "XZMODE=plain"
  )
  rmdir /s /q "!XZSTG1!" >nul 2>&1
)
if not defined XZMODE (
  rmdir /s /q "!XZWT!" >nul 2>&1
  exit /b 1
)
if "!XZMODE!"=="plain" (
  rmdir /s /q "!XZWT!" >nul 2>&1
  exit /b 1
)
exit /b 0

:XZ_REPACK
set "XZNEW=!EXIN!.new.tar.xz"
if defined TAREXE (
  pushd "!XZWT!"
  "!TAREXE!" -a -c -J --options compression-level=9 -f "!XZNEW!" *
  set "EC=!errorlevel!"
  popd
) else (
  pushd "!XZWT!"
  set "PROGCMD=a -txz -mx=9 -mmt=on -bsp1 "!XZNEW!" *"
  set "PMODE=add"
  call :RUN_PROG
  popd
)
if not "!EC!"=="0" (
  echo  [错误] 重新压缩失败, 退出码 !EC!
  rmdir /s /q "!XZWT!" >nul 2>&1
  exit /b 1
)
del /f /q "!EXIN!" >nul 2>&1
move /y "!XZNEW!" "!EXIN!" >nul 2>&1
set "EC=!errorlevel!"
rmdir /s /q "!XZWT!" >nul 2>&1
exit /b !EC!

rem ============================================================
rem  v11 命令行参数解析（顶层 goto 循环，避免 shift 展开陷阱）
rem  示例: xz-compressor.cmd a.txt b.txt --format 7z --level 9 --pass 123 --volume 100m --solid --sfx exe --out x.7z
rem ============================================================
:PARSE_CLI
rem 无参数直接进入交互菜单（空变量做 :--= 替换会产生字面量 --=，必须先判空）
if "%~1"=="" goto :PARSE_CLI_RET
rem 纯字符串检测是否含 --（避免 echo|findstr 管道在重定向输入时吞掉 stdin）
set "HASDD=%*"
if "!HASDD:--=!"=="!HASDD!" goto :PARSE_CLI_RET
set "CLIPOS=1"
set "CLI_FILES="
set "CLIFIRST="
set "CLIFMT="
set "CLILV="
set "CLIPASS="
set "CLIVOL="
set "CLISOLID="
set "CLIMD="
set "CLIMMT="
set "CLIRR="
set "CLISFX="
set "CLIOUT="
set "CLIBEEP="
set "CLISHA="
set "CLIYES="
set "NEEDNEXT="
set "CN=0"
:PCL_LOOP
if not defined NEEDNEXT goto :PCL_READ
set "!NEEDNEXT!=%~1"
set "NEEDNEXT="
shift
goto :PCL_LOOP
:PCL_READ
if "%~1"=="" goto :PCL_DONE
set "PA=%~1"
set "PA2=!PA:~0,2!"
if /i "!PA2!"=="--" (
  if /i "!PA!"=="--format" (set "NEEDNEXT=CLIFMT" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--level"  (set "NEEDNEXT=CLILV"  & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--pass"   (set "NEEDNEXT=CLIPASS" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--volume" (set "NEEDNEXT=CLIVOL" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--md"     (set "NEEDNEXT=CLIMD"  & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--mmt"    (set "NEEDNEXT=CLIMMT" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--rr"     (set "NEEDNEXT=CLIRR"  & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--sfx"    (set "NEEDNEXT=CLISFX" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--out"    (set "NEEDNEXT=CLIOUT" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--solid"  (set "CLISOLID=1" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--beep"   (set "CLIBEEP=1" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--sha256" (set "CLISHA=1" & shift & goto :PCL_LOOP)
  if /i "!PA!"=="--yes"    (set "CLIYES=1" & shift & goto :PCL_LOOP)
  echo  [错误] 未知参数: !PA!
  echo  用 --help 查看帮助
  goto :QUIT
) else (
  set /a CN+=1
  if not defined CLIFIRST set "CLIFIRST=!PA!"
  set "CLI_FILES=!CLI_FILES! "!PA!""
  shift
  goto :PCL_LOOP
)
:PCL_DONE
if !CN! equ 0 (
  echo  [错误] 命令行模式未提供要压缩的文件
  echo  示例: xz-compressor.cmd 文件.txt --format 7z --level 9
  goto :QUIT
)
set "XZCP_AUTO=1"
set "XZCP_VF=n"
set "XZCP_AGAIN=q"
if not defined CLIFMT set "CLIFMT=xz"
if not defined CLILV set "CLILV=9"
set "FMAT=!CLIFMT!"
set "LV=!CLILV!"
if defined CLIVOL set "VOL=!CLIVOL!"
if defined CLISOLID set "SOLID=on"
if defined CLIMD set "DICT=!CLIMD!"
if defined CLIMMT set "MTN=!CLIMMT!"
if defined CLIRR echo  [提示] 7-Zip 命令行不支持恢复记录(WinRAR 特性), --rr 已忽略。
if defined CLIBEEP set "DOBEEP=1"
if defined CLISHA set "DOSHA=1"
if defined CLIYES set "XZCP_OW=y"
if defined CLIPASS (
  set "PASS=!CLIPASS!"
  set "PWARG=-p"!CLIPASS!""
  set "ENCTYPE=2"
  set "XZCP_PASSOPT=1"
  set "XZCP_PASS=!CLIPASS!"
  set "XZCP_ENCTYPE=2"
) else (
  set "XZCP_PASSOPT=0"
)
if /i "!CLISFX!"=="exe" set "PACK=1"
if /i "!CLISFX!"=="apk" set "PACK=2"
if /i "!CLISFX!"=="none" set "PACK=0"
if not defined PACK set "PACK=0"
set "IN=!CLIFIRST!"
if !CN! geq 2 (
  set "MULTI=1"
  set "ALLARGS=!CLI_FILES!"
) else (
  set "MULTI=0"
  set "ALLARGS="!IN!""
)
set "XZCP_FMAT=!FMAT!"
set "XZCP_PACK=!PACK!"
call :LOG "CLI模式: fmt=!FMAT! lv=!LV! pack=!PACK! 数量=!CN!"
call :DETECT
call :CHECK_INPUT
if errorlevel 1 goto :END
goto :AFTER_INPUT

rem ============================================================
rem  工具集  v11
rem ============================================================
:TOOLSET
set "TM="
cls
echo.
echo  ============================================================
echo    工具集
echo  ============================================================
echo.
echo    [0] 批量加密 / 改密 / 去密   （多个 zip/7z 统一处理）
echo    [1] 压缩率对比报告          （多格式/多档位体积与耗时）
echo    [2] 生成校验值              （MD5 / SHA256）
echo    [3] 定时备份                （计划任务自动压缩）
echo    [4] 资源管理器右键菜单       （添加/移除）
echo    [5] 图形界面 GUI            （完整版提供）
echo    [6] 历史记录                （最近生成的压缩包）
echo    [7] 压缩预设                （保存/使用常用配置）
echo    [9] 自检                    （各格式压缩与校验）
echo    [Q] 返回主菜单
echo.
if defined XZCP_AUTO if defined XZCP_TM set "TM=!XZCP_TM!"
if not defined TM set /p "TM=请选择: "
if /i "!TM!"=="q" (if defined XZCP_AUTO (goto :QUIT) else (goto :MAINMENU))
if "!TM!"=="0" goto :TS_BATCH
if "!TM!"=="1" goto :TS_COMPARE
if "!TM!"=="2" goto :TS_HASH
if "!TM!"=="3" goto :TS_BACKUP
if "!TM!"=="4" goto :TS_CTXMENU
if "!TM!"=="5" goto :TS_GUI
if "!TM!"=="6" goto :TS_HISTORY
if "!TM!"=="7" goto :TS_PRESET
if "!TM!"=="9" goto :TS_SELFTEST
goto :TOOLSET

rem ---- 批量加密/改密/去密 ----
:TS_BATCH
set "BA="
cls
echo.
echo  ============================================================
echo    批量加密 / 改密 / 去密
echo  ============================================================
echo.
echo    [1] 批量加密（未加密的 zip/7z 加密码）
echo    [2] 批量改密（旧密码 -^> 新密码）
echo    [3] 批量去密（移除密码）
echo    [Q] 返回
echo.
if defined XZCP_AUTO if defined XZCP_TSUB set "BA=!XZCP_TSUB!"
if not defined BA set /p "BA=请选择: "
if /i "!BA!"=="q" goto :TOOLSET
if "!BA!"=="1" (set "BACT=add" & goto :TS_BATCH_RUN)
if "!BA!"=="2" (set "BACT=change" & goto :TS_BATCH_RUN)
if "!BA!"=="3" (set "BACT=remove" & goto :TS_BATCH_RUN)
goto :TS_BATCH
:TS_BATCH_RUN
echo.
echo  [提示] 请在弹窗中选择要处理的文件（可多选）。
powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\batch_enc.ps1" -Action !BACT! -SevenZ "!SZIP!"
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :TOOLSET

rem ---- 压缩率对比 ----
:TS_COMPARE
echo.
echo  [提示] 请在弹窗中选择要对比的文件。
powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\compare.ps1" -SevenZ "!SZIP!"
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :TOOLSET

rem ---- 校验值 ----
:TS_HASH
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要计算校验值的文件'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
if not exist "!PICK!" goto :TOOLSET
for /f "usebackq delims=" %%L in ("!PICK!") do set "HF=%%L"
del "!PICK!" >nul 2>&1
if not defined HF goto :TOOLSET
cls
echo.
echo  ============================================================
echo    文件校验值
echo  ============================================================
echo    文件: !HF!
echo.
echo    [MD5]
certutil -hashfile "!HF!" MD5 | findstr /v ":"
echo.
echo    [SHA256]
certutil -hashfile "!HF!" SHA256 | findstr /v ":"
echo  ============================================================
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :TOOLSET

rem ---- 图形界面 ----
:TS_GUI
if exist "!SD!tools\XZGui.exe" (
  start "" "!SD!tools\XZGui.exe"
  goto :TOOLSET
)
if exist "!SD!XZGui.exe" (
  start "" "!SD!XZGui.exe"
  goto :TOOLSET
)
if exist "!SD!XZ完整版.exe" (
  echo  [提示] 启动 Windows 完整版（内含图形界面）...
  start "" "!SD!XZ完整版.exe"
  goto :TOOLSET
)
echo.
echo  [提示] 图形界面随 Windows 完整版提供。
echo         请在主菜单 [3] 创建便携式压缩程序 -^> Windows 完整版 生成。
echo.
pause
goto :TOOLSET

rem ---- 历史记录 ----
:TS_HISTORY
set "HISTF=!SD!xz-history.txt"
cls
echo.
echo  ============================================================
echo    历史记录（最近生成的压缩包, 最多显示最近 30 条）
echo  ============================================================
if not exist "!HISTF!" (
  echo    （暂无历史记录）
) else (
  powershell -NoProfile -Command "Get-Content -LiteralPath $env:HISTF -Tail 30 -Encoding Default"
)
echo  ============================================================
echo    [C] 清空历史    [Q] 返回
echo.
set "HC="
if defined XZCP_AUTO if defined XZCP_TSUB set "HC=!XZCP_TSUB!"
if not defined HC set /p "HC=请选择: "
if /i "!HC!"=="c" (
  del "!HISTF!" >nul 2>&1
  echo  [提示] 历史已清空。
  pause
)
if defined XZCP_AUTO goto :QUIT
goto :TOOLSET

:ADD_HISTORY
if not defined OUT exit /b 0
set "HISTF=!SD!xz-history.txt"
>>"!HISTF!" echo %date% %time%  !OUT!
exit /b 0


rem ---- 自检 ----
:TS_SELFTEST
echo.
echo  [自检] 开始运行各格式压缩与校验测试 ...
echo.
call "!SD!tools\selftest.cmd"
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :TOOLSET

rem ---- 右键菜单 ----
:TS_CTXMENU
set "CM="
cls
echo.
echo  ============================================================
echo    资源管理器右键菜单
echo  ============================================================
echo.
echo    [1] 添加右键菜单“用 XZ 压缩”（文件/文件夹/空白处）
echo    [2] 移除右键菜单
echo    [Q] 返回
echo.
if defined XZCP_AUTO if defined XZCP_TSUB set "CM=!XZCP_TSUB!"
if not defined CM set /p "CM=请选择: "
if /i "!CM!"=="q" goto :TOOLSET
if "!CM!"=="1" goto :CTXMENU_ADD
if "!CM!"=="2" goto :CTXMENU_DEL
goto :TS_CTXMENU
:CTXMENU_ADD
set "MAINCMD=!SD!xz-compressor.cmd"
reg add "HKCU\Software\Classes\*\shell\XZCompress" /ve /d "用 XZ 压缩..." /f >nul
reg add "HKCU\Software\Classes\*\shell\XZCompress\command" /ve /d "\"!MAINCMD!\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\shell\XZCompress" /ve /d "用 XZ 压缩..." /f >nul
reg add "HKCU\Software\Classes\Directory\shell\XZCompress\command" /ve /d "\"!MAINCMD!\" \"%%1\"" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\XZCompress" /ve /d "用 XZ 压缩当前文件夹" /f >nul
reg add "HKCU\Software\Classes\Directory\Background\shell\XZCompress\command" /ve /d "\"!MAINCMD!\" \"%%V\"" /f >nul
echo  [完成] 已添加右键菜单（仅当前用户, 无需管理员）。
echo.
pause
goto :TOOLSET
:CTXMENU_DEL
reg delete "HKCU\Software\Classes\*\shell\XZCompress" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\shell\XZCompress" /f >nul 2>&1
reg delete "HKCU\Software\Classes\Directory\Background\shell\XZCompress" /f >nul 2>&1
echo  [完成] 已移除右键菜单。
echo.
pause
goto :TOOLSET

rem ---- 定时备份 ----
:TS_BACKUP
set "BKM="
cls
echo.
echo  ============================================================
echo    定时备份（计划任务自动压缩为 7z）
echo  ============================================================
echo.
echo    [1] 新建定时备份
echo    [2] 查看已注册的 XZ 备份任务
echo    [3] 删除备份任务
echo    [Q] 返回
echo.
if defined XZCP_AUTO if defined XZCP_TSUB set "BKM=!XZCP_TSUB!"
if not defined BKM set /p "BKM=请选择: "
if /i "!BKM!"=="q" goto :TOOLSET
if "!BKM!"=="1" goto :BK_NEW
if "!BKM!"=="2" goto :BK_LIST
if "!BKM!"=="3" goto :BK_DEL
goto :TS_BACKUP
:BK_NEW
set "BKSRC="
set "BKDST="
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='选择要备份的【源文件夹】'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.SelectedPath,[Text.Encoding]::Default)}"
if not exist "!PICK!" goto :TS_BACKUP
for /f "usebackq delims=" %%L in ("!PICK!") do set "BKSRC=%%L"
del "!PICK!" >nul 2>&1
if not defined BKSRC goto :TS_BACKUP
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='选择备份文件【保存位置】'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.SelectedPath,[Text.Encoding]::Default)}"
if not exist "!PICK!" goto :TS_BACKUP
for /f "usebackq delims=" %%L in ("!PICK!") do set "BKDST=%%L"
del "!PICK!" >nul 2>&1
if not defined BKDST goto :TS_BACKUP
set "BKN="
set /p "BKN=任务名称(英文/数字, 默认 Backup1): "
if not defined BKN set "BKN=Backup1"
set "BKTM="
set /p "BKTM=每天执行时间 HH:MM (默认 21:00): "
if not defined BKTM set "BKTM=21:00"
set "BKSC="
set /p "BKSC=频率 [1]每天 [2]每周 [3]开机 (默认1): "
if not defined BKSC set "BKSC=1"
if "!BKSC!"=="2" (set "SC=weekly" & set "SCD=/d MON") else (set "SC=daily" & set "SCD=")
if "!BKSC!"=="3" (set "SC=onlogon" & set "SCD=")
if not "!BKSC!"=="3" set "SCD=/st !BKTM!"
if not exist "!SD!tools\backups" mkdir "!SD!tools\backups"
set "BKWRAP=!SD!tools\backups\!BKN!.cmd"
>"!BKWRAP!" echo @echo off
>>"!BKWRAP!" echo setlocal enabledelayedexpansion
>>"!BKWRAP!" echo for /f "delims=" %%%%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "TS=%%%%i"
>>"!BKWRAP!" echo call "!SD!xz-compressor.cmd" "!BKSRC!" --format 7z --level 9 --solid --out "!BKDST!\!BKN!_%%TS%%.7z" --yes ^< NUL
schtasks /create /tn "XZBackup_!BKN!" /tr "\"!BKWRAP!\"" /sc !SC! !SCD! /rl limited /f
if !errorlevel! EQU 0 (
  echo  [完成] 已注册定时备份任务: XZBackup_!BKN!
  echo         备份文件将保存到: !BKDST!\!BKN!_时间.7z
) else (
  echo  [错误] 注册计划任务失败。
)
echo.
pause
goto :TS_BACKUP
:BK_LIST
echo.
echo    已注册的 XZ 备份任务:
schtasks /query /fo list 2>nul | findstr /i "XZBackup_"
echo.
pause
goto :TS_BACKUP
:BK_DEL
set "DKN="
set /p "DKN=输入要删除的任务名(不带前缀, 如 Backup1): "
if not defined DKN goto :TS_BACKUP
schtasks /delete /tn "XZBackup_!DKN!" /f
del "!SD!tools\backups\!DKN!.cmd" >nul 2>&1
echo.
pause
goto :TS_BACKUP

rem ---- 压缩预设 ----
:TS_PRESET
set "PM="
cls
echo.
echo  ============================================================
echo    压缩预设
echo  ============================================================
echo.
echo    [1] 保存当前配置为预设
echo    [2] 使用预设压缩（弹窗选文件）
echo    [3] 列出 / 删除预设
echo    [Q] 返回
echo.
if defined XZCP_AUTO if defined XZCP_TSUB set "PM=!XZCP_TSUB!"
if not defined PM set /p "PM=请选择: "
if /i "!PM!"=="q" goto :TOOLSET
if "!PM!"=="1" goto :PRESET_SAVE
if "!PM!"=="2" goto :PRESET_USE
if "!PM!"=="3" goto :PRESET_MANAGE
goto :TS_PRESET
:PRESET_SAVE
set "PF=!SD!presets.ini"
set "PN="
set /p "PN=预设名称(英文/数字): "
if not defined PN goto :TS_PRESET
set "PFMT="
set /p "PFMT=格式 [1]xz [2]zip [3]7z [4]gz [5]bz2 [6]tgz (默认3): "
if not defined PFMT set "PFMT=3"
set "PLV="
set /p "PLV=档位 [3]快速 [6]标准 [9]极限 (默认9): "
if not defined PLV set "PLV=9"
set "PARGS=--format "
if "!PFMT!"=="1" set "PARGS=!PARGS!xz"
if "!PFMT!"=="2" set "PARGS=!PARGS!zip"
if "!PFMT!"=="3" set "PARGS=!PARGS!7z"
if "!PFMT!"=="4" set "PARGS=!PARGS!gz"
if "!PFMT!"=="5" set "PARGS=!PARGS!bz2"
if "!PFMT!"=="6" set "PARGS=!PARGS!tgz"
set "PARGS=!PARGS! --level !PLV!"
set "PSOL="
set /p "PSOL=启用固实压缩(仅7z)? [y/N]: "
if /i "!PSOL!"=="y" set "PARGS=!PARGS! --solid"
set "PRR="
set /p "PRR=恢复记录百分比 0-10(仅7z, 0=不启用, 默认0): "
if defined PRR if not "!PRR!"=="0" set "PARGS=!PARGS! --rr !PRR!"
set "PVOL="
set /p "PVOL=分卷大小(如 100m, 直接回车=不分卷): "
if defined PVOL set "PARGS=!PARGS! --volume !PVOL!"
set "PPASS="
set /p "PPASS=设置密码(直接回车=不加密): "
if defined PPASS set "PARGS=!PARGS! --pass !PPASS!"
>>"!PF!" echo !PN!=!PARGS!
echo  [完成] 已保存预设 !PN!: !PARGS!
echo.
pause
goto :TS_PRESET
:PRESET_USE
set "PF=!SD!presets.ini"
if not exist "!PF!" (
  echo  [提示] 还没有预设, 请先保存。
  pause
  goto :TS_PRESET
)
cls
echo    可用预设:
set /a PLI=0
for /f "usebackq eol=; tokens=1 delims==" %%a in ("!PF!") do (
  set /a PLI+=1
  echo    [!PLI!] %%a
)
echo.
set "PUSE="
set /p "PUSE=输入预设名称: "
if not defined PUSE goto :TS_PRESET
set "PARGS="
for /f "usebackq eol=; tokens=1,* delims==" %%a in ("!PF!") do if /i "%%a"=="!PUSE!" set "PARGS=%%b"
if not defined PARGS (
  echo  [错误] 找不到预设 !PUSE!
  pause
  goto :TS_PRESET
)
set "PICK=%TEMP%\xz_pick_!RANDOM!.txt"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Title='选择要压缩的文件'; if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$f.FileName,[Text.Encoding]::Default)}"
if not exist "!PICK!" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Add-Type -AssemblyName System.Windows.Forms; $d=New-Object System.Windows.Forms.FolderBrowserDialog; $d.Description='选择要压缩的文件夹'; if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){[IO.File]::WriteAllText('!PICK!',$d.SelectedPath,[Text.Encoding]::Default)}"
)
if not exist "!PICK!" goto :TS_PRESET
for /f "usebackq delims=" %%L in ("!PICK!") do set "PTARGET=%%L"
del "!PICK!" >nul 2>&1
if not defined PTARGET goto :TS_PRESET
echo  [压缩] 使用预设 !PUSE!: !PARGS!
call "!SD!xz-compressor.cmd" "!PTARGET!" !PARGS! --yes < NUL
echo.
pause
if defined XZCP_AUTO goto :QUIT
goto :TOOLSET
:PRESET_MANAGE
set "PF=!SD!presets.ini"
cls
echo  ============================================================
echo    当前预设:
echo  ============================================================
if not exist "!PF!" (echo    （暂无预设）) else (type "!PF!")
echo  ============================================================
echo    [D] 删除全部预设   [Q] 返回
echo.
set "PMM="
set /p "PMM=请选择: "
if /i "!PMM!"=="d" (
  del "!PF!" >nul 2>&1
  echo  [提示] 已删除全部预设。
  pause
)
goto :TS_PRESET


:LOG
set "TS=%date% %time%"
>>"!LOG!" echo [%TS%] %*
exit /b 0

rem ============================================================
rem 内嵌 C# 自解压器源码 (base64) — 无 7-Zip 时的备用 exe 引擎
rem 由 :EXE_CSC 提取后经 certutil 还原, 再用 csc 编译
rem ============================================================
CSCB64:dXNpbmcgU3lzdGVtOwp1c2luZyBTeXN0ZW0uQ29sbGVjdGlvbnMuR2VuZXJpYzsKdXNpbmcgU3lz
CSCB64:dGVtLkRpYWdub3N0aWNzOwp1c2luZyBTeXN0ZW0uSU87CnVzaW5nIFN5c3RlbS5SZWZsZWN0aW9u
CSCB64:Owp1c2luZyBTeXN0ZW0uVGV4dDsKClthc3NlbWJseTogQXNzZW1ibHlUaXRsZSgiWFogU2VsZi1F
CSCB64:eHRyYWN0aW5nIEFyY2hpdmUiKV0KW2Fzc2VtYmx5OiBBc3NlbWJseVByb2R1Y3QoIlhaIOiHquin
CSCB64:o+WOi+aho+ahiCIpXQpbYXNzZW1ibHk6IEFzc2VtYmx5Q29tcGFueSgiWFog5Y6L57yp5bel5YW3
CSCB64:IildClthc3NlbWJseTogQXNzZW1ibHlDb3B5cmlnaHQoIkdlbmVyYXRlZCBieSBYWiDmnoHpgJ/l
CSCB64:jovnvKnlt6XlhbciKV0KW2Fzc2VtYmx5OiBBc3NlbWJseVZlcnNpb24oIjAuMS4wLjAiKV0KW2Fz
CSCB64:c2VtYmx5OiBBc3NlbWJseUZpbGVWZXJzaW9uKCIwLjEuMC4wIildCgpjbGFzcyBTZWxmRXh0cmFj
CSCB64:dG9yCnsKICAgIHN0YXRpYyBzdHJpbmcgTG9nUGF0aAogICAgewogICAgICAgIGdldAogICAgICAg
CSCB64:IHsKICAgICAgICAgICAgdHJ5IHsgcmV0dXJuIFBhdGguQ29tYmluZShQYXRoLkdldFRlbXBQYXRo
CSCB64:KCksICJzZnhfZXh0cmFjdC5sb2ciKTsgfQogICAgICAgICAgICBjYXRjaCB7IHJldHVybiAic2Z4
CSCB64:X2V4dHJhY3QubG9nIjsgfQogICAgICAgIH0KICAgIH0KCiAgICBzdGF0aWMgdm9pZCBMb2coc3Ry
CSCB64:aW5nIG1zZykKICAgIHsKICAgICAgICB0cnkgeyBGaWxlLkFwcGVuZEFsbFRleHQoTG9nUGF0aCwg
CSCB64:IlsiICsgRGF0ZVRpbWUuTm93LlRvU3RyaW5nKCJ5eXl5LU1NLWRkIEhIOm1tOnNzIikgKyAiXSAi
CSCB64:ICsgbXNnICsgIlxyXG4iLCBFbmNvZGluZy5VVEY4KTsgfQogICAgICAgIGNhdGNoIHsgfQogICAg
CSCB64:fQoKICAgIHN0YXRpYyBzdHJpbmcgQjY0VG9TdHIoc3RyaW5nIGIpCiAgICB7CiAgICAgICAgdHJ5
CSCB64:CiAgICAgICAgewogICAgICAgICAgICBpZiAoc3RyaW5nLklzTnVsbE9yRW1wdHkoYikpIHJldHVy
CSCB64:biAiIjsKICAgICAgICAgICAgcmV0dXJuIEVuY29kaW5nLlVURjguR2V0U3RyaW5nKENvbnZlcnQu
CSCB64:RnJvbUJhc2U2NFN0cmluZyhiLlRyaW0oKSkpOwogICAgICAgIH0KICAgICAgICBjYXRjaCB7IHJl
CSCB64:dHVybiAiIjsgfQogICAgfQoKICAgIC8vIOivu+WPluWPr+mAieeahCBzZnguY2ZnIOW1jOWFpei1
CSCB64:hOa6kO+8iOmUruWAvOWdh+S4uiBVVEYtOCBiYXNlNjTvvIzpmaQgREVGQVVMVERJUiDmoIforrDl
CSCB64:pJbvvIkKICAgIHN0YXRpYyBEaWN0aW9uYXJ5PHN0cmluZyxzdHJpbmc+IExvYWRDb25maWcoQXNz
CSCB64:ZW1ibHkgYXNtKQogICAgewogICAgICAgIERpY3Rpb25hcnk8c3RyaW5nLHN0cmluZz4gY2ZnID0g
CSCB64:bmV3IERpY3Rpb25hcnk8c3RyaW5nLHN0cmluZz4oU3RyaW5nQ29tcGFyZXIuT3JkaW5hbElnbm9y
CSCB64:ZUNhc2UpOwogICAgICAgIHRyeQogICAgICAgIHsKICAgICAgICAgICAgZm9yZWFjaCAoc3RyaW5n
CSCB64:IG4gaW4gYXNtLkdldE1hbmlmZXN0UmVzb3VyY2VOYW1lcygpKQogICAgICAgICAgICB7CiAgICAg
CSCB64:ICAgICAgICAgICBpZiAobi5FcXVhbHMoInNmeC5jZmciLCBTdHJpbmdDb21wYXJpc29uLk9yZGlu
CSCB64:YWxJZ25vcmVDYXNlKSkKICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICB1c2lu
CSCB64:ZyAoU3RyZWFtIHMgPSBhc20uR2V0TWFuaWZlc3RSZXNvdXJjZVN0cmVhbShuKSkKICAgICAgICAg
CSCB64:ICAgICAgICAgICB1c2luZyAoU3RyZWFtUmVhZGVyIHNyID0gbmV3IFN0cmVhbVJlYWRlcihzLCBF
CSCB64:bmNvZGluZy5VVEY4KSkKICAgICAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgIHN0cmluZyBhbGwgPSBzci5SZWFkVG9FbmQoKTsKICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:Zm9yZWFjaCAoc3RyaW5nIHJhdyBpbiBhbGwuU3BsaXQobmV3IGNoYXJbXXsnXG4nLCdccid9KSkK
CSCB64:ICAgICAgICAgICAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgICAgICAgICAgICAgc3Ry
CSCB64:aW5nIGxpbmUgPSByYXcuVHJpbSgpOwogICAgICAgICAgICAgICAgICAgICAgICAgICAgaWYgKGxp
CSCB64:bmUuTGVuZ3RoID09IDAgfHwgbGluZS5TdGFydHNXaXRoKCIjIikpIGNvbnRpbnVlOwogICAgICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICAgaW50IGVxID0gbGluZS5JbmRleE9mKCc9Jyk7CiAgICAgICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICBpZiAoZXEgPD0gMCkgY29udGludWU7CiAgICAgICAgICAgICAg
CSCB64:ICAgICAgICAgICAgICBjZmdbbGluZS5TdWJzdHJpbmcoMCwgZXEpLlRyaW0oKV0gPSBsaW5lLlN1
CSCB64:YnN0cmluZyhlcSArIDEpLlRyaW0oKTsKICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAg
CSCB64:ICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICBicmVhazsKICAgICAgICAgICAgICAg
CSCB64:IH0KICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICBjYXRjaCAoRXhjZXB0aW9uIGV4KSB7
CSCB64:IExvZygiTG9hZENvbmZpZyBmYWlsZWQ6ICIgKyBleC5NZXNzYWdlKTsgfQogICAgICAgIHJldHVy
CSCB64:biBjZmc7CiAgICB9CgogICAgc3RhdGljIGludCBSdW4oc3RyaW5nIGV4ZSwgc3RyaW5nIGFyZ3Ms
CSCB64:IHN0cmluZyB3b3JrRGlyKQogICAgewogICAgICAgIHRyeQogICAgICAgIHsKICAgICAgICAgICAg
CSCB64:UHJvY2Vzc1N0YXJ0SW5mbyBwc2kgPSBuZXcgUHJvY2Vzc1N0YXJ0SW5mbyhleGUsIGFyZ3MpOwog
CSCB64:ICAgICAgICAgICBwc2kuVXNlU2hlbGxFeGVjdXRlID0gZmFsc2U7CiAgICAgICAgICAgIHBzaS5D
CSCB64:cmVhdGVOb1dpbmRvdyA9IGZhbHNlOwogICAgICAgICAgICBwc2kuV29ya2luZ0RpcmVjdG9yeSA9
CSCB64:IHdvcmtEaXI7CiAgICAgICAgICAgIFByb2Nlc3MgcCA9IFByb2Nlc3MuU3RhcnQocHNpKTsKICAg
CSCB64:ICAgICAgICAgcC5XYWl0Rm9yRXhpdCgpOwogICAgICAgICAgICByZXR1cm4gcC5FeGl0Q29kZTsK
CSCB64:ICAgICAgICB9CiAgICAgICAgY2F0Y2ggKEV4Y2VwdGlvbiBleCkKICAgICAgICB7CiAgICAgICAg
CSCB64:ICAgIExvZygiUnVuIGZhaWxlZDogIiArIGV4ZSArICIgIiArIGFyZ3MgKyAiIDogIiArIGV4Lk1l
CSCB64:c3NhZ2UpOwogICAgICAgICAgICByZXR1cm4gLTk5OTsKICAgICAgICB9CiAgICB9CgogICAgc3Rh
CSCB64:dGljIGludCBNYWluKHN0cmluZ1tdIGFyZ3MpCiAgICB7CiAgICAgICAgLy8g5Y+C5pWwOiAteSDo
CSCB64:h6rliqg7IC1vPOi3r+W+hD4g5oyH5a6a55uu5b2VOyAtcnVuIOiHquWKqOaooeW8j+S4i+S5n+WF
CSCB64:geiuuOino+WOi+WQjui/kOihjCjlkKbliJnkuI3ov5DooYwpCiAgICAgICAgYm9vbCBhdXRvTW9k
CSCB64:ZSA9IGZhbHNlOwogICAgICAgIGJvb2wgZm9yY2VSdW4gPSBmYWxzZTsKICAgICAgICBzdHJpbmcg
CSCB64:dGFyZ2V0T3ZlcnJpZGUgPSBudWxsOwogICAgICAgIGZvciAoaW50IGkgPSAwOyBpIDwgYXJncy5M
CSCB64:ZW5ndGg7IGkrKykKICAgICAgICB7CiAgICAgICAgICAgIHN0cmluZyBhID0gYXJnc1tpXTsKICAg
CSCB64:ICAgICAgICAgc3RyaW5nIGFsID0gYS5Ub0xvd2VySW52YXJpYW50KCk7CiAgICAgICAgICAgIGlm
CSCB64:IChhbCA9PSAiLXkiIHx8IGFsID09ICIveSIpIGF1dG9Nb2RlID0gdHJ1ZTsKICAgICAgICAgICAg
CSCB64:aWYgKGFsID09ICItcnVuIiB8fCBhbCA9PSAiL3J1biIgfHwgYWwgPT0gIi1hdXRvcnVuIikgZm9y
CSCB64:Y2VSdW4gPSB0cnVlOwogICAgICAgICAgICBpZiAoYWwuU3RhcnRzV2l0aCgiLW8iKSB8fCBhbC5T
CSCB64:dGFydHNXaXRoKCIvbyIpKQogICAgICAgICAgICB7CiAgICAgICAgICAgICAgICBpZiAoYS5MZW5n
CSCB64:dGggPiAyKSB0YXJnZXRPdmVycmlkZSA9IGEuU3Vic3RyaW5nKDIpOwogICAgICAgICAgICAgICAg
CSCB64:ZWxzZSBpZiAoaSArIDEgPCBhcmdzLkxlbmd0aCkgeyB0YXJnZXRPdmVycmlkZSA9IGFyZ3NbaSAr
CSCB64:IDFdOyBpKys7IH0KICAgICAgICAgICAgfQogICAgICAgIH0KICAgICAgICB0cnkgeyBDb25zb2xl
CSCB64:Lk91dHB1dEVuY29kaW5nID0gU3lzdGVtLlRleHQuRW5jb2RpbmcuVVRGODsgfSBjYXRjaCB7IH0K
CSCB64:CiAgICAgICAgQXNzZW1ibHkgYXNtID0gQXNzZW1ibHkuR2V0RXhlY3V0aW5nQXNzZW1ibHkoKTsK
CSCB64:ICAgICAgICBEaWN0aW9uYXJ5PHN0cmluZyxzdHJpbmc+IGNmZyA9IExvYWRDb25maWcoYXNtKTsK
CSCB64:ICAgICAgICBzdHJpbmcgdGl0bGUgPSBCNjRUb1N0cihjZmcuQ29udGFpbnNLZXkoIlRJVExFX0I2
CSCB64:NCIpID8gY2ZnWyJUSVRMRV9CNjQiXSA6ICIiKTsKICAgICAgICBzdHJpbmcgd2VsY29tZSA9IEI2
CSCB64:NFRvU3RyKGNmZy5Db250YWluc0tleSgiV0VMQ09NRV9CNjQiKSA/IGNmZ1siV0VMQ09NRV9CNjQi
CSCB64:XSA6ICIiKTsKICAgICAgICBzdHJpbmcgZXVsYSA9IEI2NFRvU3RyKGNmZy5Db250YWluc0tleSgi
CSCB64:RVVMQV9CNjQiKSA/IGNmZ1siRVVMQV9CNjQiXSA6ICIiKTsKICAgICAgICBzdHJpbmcgcnVuQWZ0
CSCB64:ZXIgPSBCNjRUb1N0cihjZmcuQ29udGFpbnNLZXkoIlJVTl9CNjQiKSA/IGNmZ1siUlVOX0I2NCJd
CSCB64:IDogIiIpOwogICAgICAgIHN0cmluZyBkZWZEaXIgPSBjZmcuQ29udGFpbnNLZXkoIkRFRkFVTFRE
CSCB64:SVIiKSA/IGNmZ1siREVGQVVMVERJUiJdLlRvVXBwZXJJbnZhcmlhbnQoKSA6ICJDVVJSRU5UIjsK
CSCB64:ICAgICAgICBpZiAoc3RyaW5nLklzTnVsbE9yRW1wdHkodGl0bGUpKSB0aXRsZSA9ICJTZWxmLUV4
CSCB64:dHJhY3RpbmcgQXJjaGl2ZSI7CiAgICAgICAgdHJ5IHsgQ29uc29sZS5UaXRsZSA9IHRpdGxlOyB9
CSCB64:IGNhdGNoIHsgfQoKICAgICAgICBDb25zb2xlLldyaXRlTGluZSgiPT09PT09PT09PT09PT09PT09
CSCB64:PT09PT09PT09PT09PT09PT09PT09PT09PT09PSIpOwogICAgICAgIENvbnNvbGUuV3JpdGVMaW5l
CSCB64:KCIgICIgKyB0aXRsZSk7CiAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoIj09PT09PT09PT09PT09
CSCB64:PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0iKTsKICAgICAgICBpZiAoIXN0cmluZy5J
CSCB64:c051bGxPckVtcHR5KHdlbGNvbWUpKQogICAgICAgIHsKICAgICAgICAgICAgQ29uc29sZS5Xcml0
CSCB64:ZUxpbmUod2VsY29tZSk7CiAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCItLS0tLS0tLS0t
CSCB64:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIik7CiAgICAgICAgfQoKICAgICAg
CSCB64:ICB0cnkKICAgICAgICB7CiAgICAgICAgICAgIHN0cmluZ1tdIG5hbWVzID0gYXNtLkdldE1hbmlm
CSCB64:ZXN0UmVzb3VyY2VOYW1lcygpOwogICAgICAgICAgICBzdHJpbmcgYXJjTmFtZSA9IG51bGw7CiAg
CSCB64:ICAgICAgICAgIHN0cmluZyBhcmNFeHQgPSBudWxsOwogICAgICAgICAgICBib29sIGhhc0VuZyA9
CSCB64:IGZhbHNlOwogICAgICAgICAgICBmb3JlYWNoIChzdHJpbmcgbiBpbiBuYW1lcykKICAgICAgICAg
CSCB64:ICAgewogICAgICAgICAgICAgICAgc3RyaW5nIGxuID0gbi5Ub0xvd2VySW52YXJpYW50KCk7CiAg
CSCB64:ICAgICAgICAgICAgICBpZiAobG4uU3RhcnRzV2l0aCgiYXJjLiIpKSB7IGFyY05hbWUgPSBuOyBh
CSCB64:cmNFeHQgPSBsbi5TdWJzdHJpbmcoNCk7IH0KICAgICAgICAgICAgICAgIGlmIChsbiA9PSAiZW5n
CSCB64:N3ouZXhlIikgaGFzRW5nID0gdHJ1ZTsKICAgICAgICAgICAgfQogICAgICAgICAgICBpZiAoYXJj
CSCB64:TmFtZSA9PSBudWxsKQogICAgICAgICAgICB7CiAgICAgICAgICAgICAgICBDb25zb2xlLldyaXRl
CSCB64:TGluZSgiW0VSUk9SXSBBcmNoaXZlIGRhdGEgbWlzc2luZy4gRmlsZSBtYXkgYmUgY29ycnVwdGVk
CSCB64:LiIpOwogICAgICAgICAgICAgICAgTG9nKCJFUlJPUjogYXJjaGl2ZSByZXNvdXJjZSBtaXNzaW5n
CSCB64:Iik7CiAgICAgICAgICAgICAgICByZXR1cm4gMTsKICAgICAgICAgICAgfQoKICAgICAgICAgICAg
CSCB64:c3RyaW5nIHRtcERpciA9IFBhdGguQ29tYmluZShQYXRoLkdldFRlbXBQYXRoKCksICJzZnhfIiAr
CSCB64:IEd1aWQuTmV3R3VpZCgpLlRvU3RyaW5nKCJOIikpOwogICAgICAgICAgICBEaXJlY3RvcnkuQ3Jl
CSCB64:YXRlRGlyZWN0b3J5KHRtcERpcik7CiAgICAgICAgICAgIHN0cmluZyBhcmNGaWxlID0gUGF0aC5D
CSCB64:b21iaW5lKHRtcERpciwgImFyYy4iICsgYXJjRXh0KTsKICAgICAgICAgICAgdHJ5CiAgICAgICAg
CSCB64:ICAgIHsKICAgICAgICAgICAgICAgIHVzaW5nIChTdHJlYW0gcnMgPSBhc20uR2V0TWFuaWZlc3RS
CSCB64:ZXNvdXJjZVN0cmVhbShhcmNOYW1lKSkKICAgICAgICAgICAgICAgIHVzaW5nIChGaWxlU3RyZWFt
CSCB64:IGZzID0gRmlsZS5DcmVhdGUoYXJjRmlsZSkpCiAgICAgICAgICAgICAgICB7CiAgICAgICAgICAg
CSCB64:ICAgICAgICAgcnMuQ29weVRvKGZzKTsKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAg
CSCB64:IHN0cmluZyBlbmdFeGUgPSBudWxsOwogICAgICAgICAgICAgICAgaWYgKGhhc0VuZykKICAgICAg
CSCB64:ICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICBmb3JlYWNoIChzdHJpbmcgbiBpbiBuYW1l
CSCB64:cykKICAgICAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAgICAgIHN0cmluZyBs
CSCB64:biA9IG4uVG9Mb3dlckludmFyaWFudCgpOwogICAgICAgICAgICAgICAgICAgICAgICBzdHJpbmcg
CSCB64:b3V0TmFtZSA9IG51bGw7CiAgICAgICAgICAgICAgICAgICAgICAgIGlmIChsbiA9PSAiZW5nN3ou
CSCB64:ZXhlIikgb3V0TmFtZSA9ICI3ei5leGUiOwogICAgICAgICAgICAgICAgICAgICAgICBlbHNlIGlm
CSCB64:IChsbiA9PSAiZW5nN3ouZGxsIikgb3V0TmFtZSA9ICI3ei5kbGwiOwogICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICBpZiAob3V0TmFtZSAhPSBudWxsKQogICAgICAgICAgICAgICAgICAgICAgICB7CiAg
CSCB64:ICAgICAgICAgICAgICAgICAgICAgICAgICB1c2luZyAoU3RyZWFtIHJzID0gYXNtLkdldE1hbmlm
CSCB64:ZXN0UmVzb3VyY2VTdHJlYW0obikpCiAgICAgICAgICAgICAgICAgICAgICAgICAgICB1c2luZyAo
CSCB64:RmlsZVN0cmVhbSBmcyA9IEZpbGUuQ3JlYXRlKFBhdGguQ29tYmluZSh0bXBEaXIsIG91dE5hbWUp
CSCB64:KSkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICBycy5Db3B5VG8oZnMpOwogICAgICAgICAgICAgICAgICAgICAgICAgICAgfQogICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAg
CSCB64:ICAgICAgIGVuZ0V4ZSA9IFBhdGguQ29tYmluZSh0bXBEaXIsICI3ei5leGUiKTsKICAgICAgICAg
CSCB64:ICAgICAgIH0KCiAgICAgICAgICAgICAgICBsb25nIGRhdGFTaXplID0gbmV3IEZpbGVJbmZvKGFy
CSCB64:Y0ZpbGUpLkxlbmd0aDsKICAgICAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCIgIEFyY2hp
CSCB64:dmU6ICIgKyBhcmNOYW1lICsgIiAgKCIgKyAoZGF0YVNpemUgLyAxMDQ4NTc2LjApLlRvU3RyaW5n
CSCB64:KCIwLjAwIikgKyAiIE1CKSIpOwogICAgICAgICAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoIi0t
CSCB64:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0t
CSCB64:LS0tIik7CgogICAgICAgICAgICAgICAgLy8gLS0tLSDorrjlj6/ljY/orq4gLS0tLQogICAgICAg
CSCB64:ICAgICAgICAgaWYgKCFzdHJpbmcuSXNOdWxsT3JFbXB0eShldWxhKSkKICAgICAgICAgICAgICAg
CSCB64:IHsKICAgICAgICAgICAgICAgICAgICBDb25zb2xlLldyaXRlTGluZSgiICBbTGljZW5zZSBBZ3Jl
CSCB64:ZW1lbnRdIik7CiAgICAgICAgICAgICAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoZXVsYSk7CiAg
CSCB64:ICAgICAgICAgICAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoIi0tLS0tLS0tLS0tLS0tLS0tLS0t
CSCB64:LS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tLS0tIik7CiAgICAgICAgICAg
CSCB64:ICAgICAgICAgaWYgKGF1dG9Nb2RlKQogICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAg
CSCB64:ICAgICAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoIiAgW0F1dG9dIExpY2Vuc2UgYWdyZWVtZW50
CSCB64:IGFjY2VwdGVkLiIpOwogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICBl
CSCB64:bHNlCiAgICAgICAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgICAgICAgICBDb25zb2xl
CSCB64:LldyaXRlKCIgIEFjY2VwdCBhbmQgY29udGludWU/IChZL04pOiAiKTsKICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICAgc3RyaW5nIGFjYyA9IENvbnNvbGUuUmVhZExpbmUoKTsKICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICAgaWYgKCEoYWNjICE9IG51bGwgJiYgYWNjLlRyaW0oKS5Ub1VwcGVySW52YXJpYW50
CSCB64:KCkgPT0gIlkiKSkKICAgICAgICAgICAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoIiAgRXh0cmFjdGlvbiBjYW5jZWxsZWQgKGxpY2Vu
CSCB64:c2Ugbm90IGFjY2VwdGVkKS4iKTsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIExvZygiVXNl
CSCB64:ciBkaWQgbm90IGFjY2VwdCBFVUxBOyBjYW5jZWxsZWQuIik7CiAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICByZXR1cm4gNTsKICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAg
CSCB64:ICAgICAgIH0KICAgICAgICAgICAgICAgIH0KCiAgICAgICAgICAgICAgICBzdHJpbmcgdGFyZ2V0
CSCB64:OwogICAgICAgICAgICAgICAgaWYgKHRhcmdldE92ZXJyaWRlICE9IG51bGwpCiAgICAgICAgICAg
CSCB64:ICAgICB7CiAgICAgICAgICAgICAgICAgICAgdGFyZ2V0ID0gdGFyZ2V0T3ZlcnJpZGU7CiAgICAg
CSCB64:ICAgICAgICAgICB9CiAgICAgICAgICAgICAgICBlbHNlIGlmIChhdXRvTW9kZSkKICAgICAgICAg
CSCB64:ICAgICAgIHsKICAgICAgICAgICAgICAgICAgICB0YXJnZXQgPSBSZXNvbHZlRGVmYXVsdChkZWZE
CSCB64:aXIsIGFzbSk7CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICBlbHNlCiAgICAgICAg
CSCB64:ICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAgQ29uc29sZS5Xcml0ZUxpbmUoIiAgU2VsZWN0
CSCB64:IGRlc3RpbmF0aW9uOiIpOwogICAgICAgICAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCIg
CSCB64:ICAgWzFdIEN1cnJlbnQgZm9sZGVyIChkZWZhdWx0KSIpOwogICAgICAgICAgICAgICAgICAgIENv
CSCB64:bnNvbGUuV3JpdGVMaW5lKCIgICAgWzJdIEZvbGRlciBvZiB0aGlzIEVYRSIpOwogICAgICAgICAg
CSCB64:ICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCIgICAgWzNdIEN1c3RvbSBmb2xkZXIiKTsKICAg
CSCB64:ICAgICAgICAgICAgICAgICBDb25zb2xlLldyaXRlKCIgIEVudGVyIFsxLzIvM10gKGRlZmF1bHQg
CSCB64:MSk6ICIpOwogICAgICAgICAgICAgICAgICAgIHN0cmluZyBjaG9pY2UgPSBDb25zb2xlLlJlYWRM
CSCB64:aW5lKCk7CiAgICAgICAgICAgICAgICAgICAgaWYgKGNob2ljZSA9PSBudWxsIHx8IGNob2ljZS5U
CSCB64:cmltKCkgPT0gIiIpIGNob2ljZSA9IERlZmF1bHRNZW51KGRlZkRpcik7CiAgICAgICAgICAgICAg
CSCB64:ICAgICAgaWYgKGNob2ljZSA9PSAiMiIpIHRhcmdldCA9IFBhdGguR2V0RGlyZWN0b3J5TmFtZShh
CSCB64:c20uTG9jYXRpb24pOwogICAgICAgICAgICAgICAgICAgIGVsc2UgaWYgKGNob2ljZSA9PSAiMyIp
CSCB64:CiAgICAgICAgICAgICAgICAgICAgewogICAgICAgICAgICAgICAgICAgICAgICBDb25zb2xlLldy
CSCB64:aXRlKCIgIFRhcmdldCBmb2xkZXIgKGF1dG8tY3JlYXRlZCk6ICIpOwogICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICBzdHJpbmcgY3VzdG9tID0gQ29uc29sZS5SZWFkTGluZSgpOwogICAgICAgICAgICAg
CSCB64:ICAgICAgICAgICBpZiAoY3VzdG9tICE9IG51bGwgJiYgY3VzdG9tLlRyaW0oKS5MZW5ndGggPiAw
CSCB64:KSB0YXJnZXQgPSBjdXN0b20uVHJpbSgpOwogICAgICAgICAgICAgICAgICAgICAgICBlbHNlIHRh
CSCB64:cmdldCA9IFJlc29sdmVEZWZhdWx0KGRlZkRpciwgYXNtKTsKICAgICAgICAgICAgICAgICAgICB9
CSCB64:CiAgICAgICAgICAgICAgICAgICAgZWxzZSB0YXJnZXQgPSBEaXJlY3RvcnkuR2V0Q3VycmVudERp
CSCB64:cmVjdG9yeSgpOwogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgaWYgKHN0cmluZy5J
CSCB64:c051bGxPckVtcHR5KHRhcmdldCkpIHRhcmdldCA9IERpcmVjdG9yeS5HZXRDdXJyZW50RGlyZWN0
CSCB64:b3J5KCk7CgogICAgICAgICAgICAgICAgdHJ5IHsgRGlyZWN0b3J5LkNyZWF0ZURpcmVjdG9yeSh0
CSCB64:YXJnZXQpOyB9CiAgICAgICAgICAgICAgICBjYXRjaCAoRXhjZXB0aW9uIGV4KQogICAgICAgICAg
CSCB64:ICAgICAgewogICAgICAgICAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCJbRVJST1JdIENh
CSCB64:bm5vdCBjcmVhdGUgdGFyZ2V0IGZvbGRlcjogIiArIGV4Lk1lc3NhZ2UpOwogICAgICAgICAgICAg
CSCB64:ICAgICAgIExvZygiRVJST1I6IGNhbm5vdCBjcmVhdGUgIiArIHRhcmdldCArICIgOiAiICsgZXgu
CSCB64:TWVzc2FnZSk7CiAgICAgICAgICAgICAgICAgICAgcmV0dXJuIDM7CiAgICAgICAgICAgICAgICB9
CSCB64:CiAgICAgICAgICAgICAgICBMb2coIkV4dHJhY3QgIiArIGFyY05hbWUgKyAiIHRvICIgKyB0YXJn
CSCB64:ZXQpOwoKICAgICAgICAgICAgICAgIGludCByYyA9IC0xOwogICAgICAgICAgICAgICAgaWYgKGFy
CSCB64:Y0V4dCA9PSAidGFyLnh6IikKICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICBy
CSCB64:YyA9IFJ1bigidGFyIiwgIi14ZiBcIiIgKyBhcmNGaWxlICsgIlwiIC1DIFwiIiArIHRhcmdldCAr
CSCB64:ICJcIiIsIHRtcERpcik7CiAgICAgICAgICAgICAgICAgICAgaWYgKHJjICE9IDAgJiYgRmlsZS5F
CSCB64:eGlzdHMoZW5nRXhlKSkKICAgICAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgIHN0cmluZyBpbm5lciA9IFBhdGguQ29tYmluZSh0bXBEaXIsICJpbm5lciIpOwogICAgICAg
CSCB64:ICAgICAgICAgICAgICAgICBEaXJlY3RvcnkuQ3JlYXRlRGlyZWN0b3J5KGlubmVyKTsKICAgICAg
CSCB64:ICAgICAgICAgICAgICAgICAgaW50IHIxID0gUnVuKGVuZ0V4ZSwgInggLXkgXCIiICsgYXJjRmls
CSCB64:ZSArICJcIiAtb1wiIiArIGlubmVyICsgIlwiIiwgdG1wRGlyKTsKICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICAgaWYgKHIxID09IDApCiAgICAgICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAg
CSCB64:ICAgICAgICAgICAgICAgIHN0cmluZ1tdIHRhcnMgPSBEaXJlY3RvcnkuR2V0RmlsZXMoaW5uZXIs
CSCB64:ICIqLnRhciIpOwogICAgICAgICAgICAgICAgICAgICAgICAgICAgaWYgKHRhcnMuTGVuZ3RoID4g
CSCB64:MCkKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICByYyA9IFJ1bihlbmdFeGUsICJ4IC15
CSCB64:IFwiIiArIHRhcnNbMF0gKyAiXCIgLW9cIiIgKyB0YXJnZXQgKyAiXCIiLCB0bXBEaXIpOwogICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICAgICAgZWxzZQogICAgICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgIHJjID0gLTE7CiAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAg
CSCB64:ICB9CiAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAg
CSCB64:ICB7CiAgICAgICAgICAgICAgICAgICAgc3RyaW5nIGVuZ2luZSA9IEZpbGUuRXhpc3RzKGVuZ0V4
CSCB64:ZSkgPyBlbmdFeGUgOiBudWxsOwogICAgICAgICAgICAgICAgICAgIGlmIChlbmdpbmUgPT0gbnVs
CSCB64:bCkgZW5naW5lID0gRmluZFN5c3RlbTd6KCk7CiAgICAgICAgICAgICAgICAgICAgaWYgKGVuZ2lu
CSCB64:ZSA9PSBudWxsKQogICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:Q29uc29sZS5Xcml0ZUxpbmUoIltFUlJPUl0gTm8gNy1aaXAgZW5naW5lIGF2YWlsYWJsZSBhbmQg
CSCB64:YXJjaGl2ZSBpcyBub3QgdGFyLnh6LiIpOwogICAgICAgICAgICAgICAgICAgICAgICBMb2coIkVS
CSCB64:Uk9SOiBubyBlbmdpbmUgZm9yICIgKyBhcmNFeHQpOwogICAgICAgICAgICAgICAgICAgICAgICBy
CSCB64:ZXR1cm4gMjsKICAgICAgICAgICAgICAgICAgICB9CiAgICAgICAgICAgICAgICAgICAgcmMgPSBS
CSCB64:dW4oZW5naW5lLCAieCAteSBcIiIgKyBhcmNGaWxlICsgIlwiIC1vXCIiICsgdGFyZ2V0ICsgIlwi
CSCB64:IiwgdG1wRGlyKTsKICAgICAgICAgICAgICAgIH0KCiAgICAgICAgICAgICAgICBpZiAocmMgIT0g
CSCB64:MCkKICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICBDb25zb2xlLldyaXRlTGlu
CSCB64:ZSgiW0VSUk9SXSBFeHRyYWN0aW9uIGZhaWxlZCAoY29kZSAiICsgcmMgKyAiKS4iKTsKICAgICAg
CSCB64:ICAgICAgICAgICAgICBDb25zb2xlLldyaXRlTGluZSgiICBQb3NzaWJsZSBjYXVzZXM6IHdyb25n
CSCB64:IHBhc3N3b3JkIChlbmNyeXB0ZWQgYXJjaGl2ZSksIG5vIHdyaXRlIHBlcm1pc3Npb24sIG91dCBv
CSCB64:ZiBkaXNrIHNwYWNlLCBkYXRhIGNvcnJ1cHRlZC4iKTsKICAgICAgICAgICAgICAgICAgICBMb2co
CSCB64:IkVSUk9SOiBleHRyYWN0aW9uIHJjPSIgKyByYyArICIgdGFyZ2V0PSIgKyB0YXJnZXQpOwogICAg
CSCB64:ICAgICAgICAgICAgICAgIHJldHVybiAyOwogICAgICAgICAgICAgICAgfQogICAgICAgICAgICAg
CSCB64:ICAgQ29uc29sZS5Xcml0ZUxpbmUoIltPS10gRXh0cmFjdGVkIHRvOiAiICsgdGFyZ2V0KTsKICAg
CSCB64:ICAgICAgICAgICAgIExvZygiT0s6IGV4dHJhY3RlZCB0byAiICsgdGFyZ2V0KTsKCiAgICAgICAg
CSCB64:ICAgICAgICAvLyAtLS0tIOino+WOi+WQjui/kOihjO+8iOWuieWFqO+8mum7mOiupOS4jemdmem7
CSCB64:mOi/kOihjO+8jOW/hemhu+aYjuehruehruiupOaIliAtcnVu77yJLS0tLQogICAgICAgICAgICAg
CSCB64:ICAgaWYgKCFzdHJpbmcuSXNOdWxsT3JFbXB0eShydW5BZnRlcikpCiAgICAgICAgICAgICAgICB7
CSCB64:CiAgICAgICAgICAgICAgICAgICAgc3RyaW5nIHJ1bkZpbGUgPSBQYXRoLkNvbWJpbmUodGFyZ2V0
CSCB64:LCBydW5BZnRlcik7CiAgICAgICAgICAgICAgICAgICAgaWYgKEZpbGUuRXhpc3RzKHJ1bkZpbGUp
CSCB64:KQogICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICAgICAgYm9vbCBkb1J1
CSCB64:biA9IGZhbHNlOwogICAgICAgICAgICAgICAgICAgICAgICBpZiAoZm9yY2VSdW4pIGRvUnVuID0g
CSCB64:dHJ1ZTsKICAgICAgICAgICAgICAgICAgICAgICAgZWxzZSBpZiAoYXV0b01vZGUpIGRvUnVuID0g
CSCB64:ZmFsc2U7IC8vIC15IOS7heino+WOi++8jOS4jeaTheiHqui/kOihjOeoi+W6jwogICAgICAgICAg
CSCB64:ICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAg
CSCB64:ICAgICAgICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCIiKTsKICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICAgIENvbnNvbGUuV3JpdGVMaW5lKCIgICMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMj
CSCB64:IyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIik7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBD
CSCB64:b25zb2xlLldyaXRlTGluZSgiICAjICBOT1RJQ0U6IFRoaXMgYXJjaGl2ZSB3YW50cyB0byBydW4g
CSCB64:YWZ0ZXIgZXh0cmFjdDoiKTsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIENvbnNvbGUuV3Jp
CSCB64:dGVMaW5lKCIgICMgICAgICAiICsgcnVuQWZ0ZXIpOwogICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgQ29uc29sZS5Xcml0ZUxpbmUoIiAgIyAgT25seSBydW4gaXQgaWYgeW91IHRydXN0IHRoZSBz
CSCB64:b3VyY2UuIik7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICBDb25zb2xlLldyaXRlTGluZSgi
CSCB64:ICAjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyIpOwog
CSCB64:ICAgICAgICAgICAgICAgICAgICAgICAgICAgQ29uc29sZS5Xcml0ZSgiICBSdW4gaXQgbm93PyAo
CSCB64:WS9OLCBkZWZhdWx0IE4pOiAiKTsKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHN0cmluZyBy
CSCB64:ID0gQ29uc29sZS5SZWFkTGluZSgpOwogICAgICAgICAgICAgICAgICAgICAgICAgICAgaWYgKHIg
CSCB64:IT0gbnVsbCAmJiByLlRyaW0oKS5Ub1VwcGVySW52YXJpYW50KCkgPT0gIlkiKSBkb1J1biA9IHRy
CSCB64:dWU7CiAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICAgICAgaWYg
CSCB64:KGRvUnVuKQogICAgICAgICAgICAgICAgICAgICAgICB7CiAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICB0cnkKICAgICAgICAgICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAg
CSCB64:ICAgICAgICAgICAgICBQcm9jZXNzU3RhcnRJbmZvIHJwc2kgPSBuZXcgUHJvY2Vzc1N0YXJ0SW5m
CSCB64:byhydW5GaWxlKTsKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICBycHNpLlVzZVNoZWxs
CSCB64:RXhlY3V0ZSA9IHRydWU7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgcnBzaS5Xb3Jr
CSCB64:aW5nRGlyZWN0b3J5ID0gdGFyZ2V0OwogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIFBy
CSCB64:b2Nlc3MuU3RhcnQocnBzaSk7CiAgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgTG9nKCJS
CSCB64:YW4gYWZ0ZXIgZXh0cmFjdDogIiArIHJ1bkZpbGUpOwogICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:ICAgfQogICAgICAgICAgICAgICAgICAgICAgICAgICAgY2F0Y2ggKEV4Y2VwdGlvbiBleCkKICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgICAgICAgICAgICAgICAg
CSCB64:ICBDb25zb2xlLldyaXRlTGluZSgiW1dBUk5dIEZhaWxlZCB0byBydW4gIiArIHJ1bkFmdGVyICsg
CSCB64:IjogIiArIGV4Lk1lc3NhZ2UpOwogICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgIExvZygi
CSCB64:UnVuLWFmdGVyIGZhaWxlZDogIiArIHJ1bkFmdGVyICsgIiA6ICIgKyBleC5NZXNzYWdlKTsKICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICAgICAgfQogICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICAgICAgICAgIHsKICAgICAg
CSCB64:ICAgICAgICAgICAgICAgICAgICAgIExvZygiVXNlciBkZWNsaW5lZCBhdXRvLXJ1bjogIiArIHJ1
CSCB64:bkFmdGVyKTsKICAgICAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgIH0K
CSCB64:ICAgICAgICAgICAgICAgICAgICBlbHNlCiAgICAgICAgICAgICAgICAgICAgewogICAgICAgICAg
CSCB64:ICAgICAgICAgICAgICBDb25zb2xlLldyaXRlTGluZSgiW1dBUk5dIFJ1bi1hZnRlciB0YXJnZXQg
CSCB64:bm90IGZvdW5kOiAiICsgcnVuQWZ0ZXIpOwogICAgICAgICAgICAgICAgICAgICAgICBMb2coIlJ1
CSCB64:bi1hZnRlciB0YXJnZXQgbWlzc2luZzogIiArIHJ1bkZpbGUpOwogICAgICAgICAgICAgICAgICAg
CSCB64:IH0KICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgIHJldHVybiAwOwogICAgICAgICAg
CSCB64:ICB9CiAgICAgICAgICAgIGZpbmFsbHkKICAgICAgICAgICAgewogICAgICAgICAgICAgICAgdHJ5
CSCB64:IHsgRGlyZWN0b3J5LkRlbGV0ZSh0bXBEaXIsIHRydWUpOyB9IGNhdGNoIHsgfQogICAgICAgICAg
CSCB64:ICB9CiAgICAgICAgfQogICAgICAgIGNhdGNoIChFeGNlcHRpb24gZXgpCiAgICAgICAgewogICAg
CSCB64:ICAgICAgICBDb25zb2xlLldyaXRlTGluZSgiW0VSUk9SXSAiICsgZXguTWVzc2FnZSk7CiAgICAg
CSCB64:ICAgICAgIExvZygiRVJST1I6ICIgKyBleC5Ub1N0cmluZygpKTsKICAgICAgICAgICAgQ29uc29s
CSCB64:ZS5Xcml0ZUxpbmUoIiAgVGlwOiBjaGVjayBkaXNrIHNwYWNlIGFuZCBwZXJtaXNzaW9ucywgb3Ig
CSCB64:Y29weSB0aGlzIGZpbGUgdG8gYSBsb2NhbCBkaXNrLiIpOwogICAgICAgICAgICByZXR1cm4gNDsK
CSCB64:ICAgICAgICB9CiAgICB9CgogICAgc3RhdGljIHN0cmluZyBSZXNvbHZlRGVmYXVsdChzdHJpbmcg
CSCB64:ZGVmRGlyLCBBc3NlbWJseSBhc20pCiAgICB7CiAgICAgICAgaWYgKGRlZkRpciA9PSAiRVhFIikg
CSCB64:cmV0dXJuIFBhdGguR2V0RGlyZWN0b3J5TmFtZShhc20uTG9jYXRpb24pOwogICAgICAgIGlmIChk
CSCB64:ZWZEaXIgPT0gIkNVUlJFTlQiIHx8IHN0cmluZy5Jc051bGxPckVtcHR5KGRlZkRpcikpIHJldHVy
CSCB64:biBEaXJlY3RvcnkuR2V0Q3VycmVudERpcmVjdG9yeSgpOwogICAgICAgIC8vIOWFtuS9meinhuS4
CSCB64:uuiHquWumuS5iei3r+W+hO+8iERFRkFVTFRESVIg5Y6f5aeL5YC877yM6Z2e5qCH6K6w77yJCiAg
CSCB64:ICAgICAgcmV0dXJuIGRlZkRpcjsKICAgIH0KCiAgICBzdGF0aWMgc3RyaW5nIERlZmF1bHRNZW51
CSCB64:KHN0cmluZyBkZWZEaXIpCiAgICB7CiAgICAgICAgaWYgKGRlZkRpciA9PSAiRVhFIikgcmV0dXJu
CSCB64:ICIyIjsKICAgICAgICBpZiAoZGVmRGlyID09ICJDVVJSRU5UIiB8fCBzdHJpbmcuSXNOdWxsT3JF
CSCB64:bXB0eShkZWZEaXIpKSByZXR1cm4gIjEiOwogICAgICAgIHJldHVybiAiMSI7CiAgICB9CgogICAg
CSCB64:c3RhdGljIHN0cmluZyBGaW5kU3lzdGVtN3ooKQogICAgewogICAgICAgIHRyeQogICAgICAgIHsK
CSCB64:ICAgICAgICAgICAgc3RyaW5nW10gY2FuZGlkYXRlcyA9IG5ldyBzdHJpbmdbXQogICAgICAgICAg
CSCB64:ICB7CiAgICAgICAgICAgICAgICBQYXRoLkNvbWJpbmUoRW52aXJvbm1lbnQuR2V0Rm9sZGVyUGF0
CSCB64:aChFbnZpcm9ubWVudC5TcGVjaWFsRm9sZGVyLlByb2dyYW1GaWxlcyksICI3LVppcCIsICI3ei5l
CSCB64:eGUiKSwKICAgICAgICAgICAgICAgIFBhdGguQ29tYmluZShFbnZpcm9ubWVudC5HZXRGb2xkZXJQ
CSCB64:YXRoKEVudmlyb25tZW50LlNwZWNpYWxGb2xkZXIuUHJvZ3JhbUZpbGVzWDg2KSwgIjctWmlwIiwg
CSCB64:Ijd6LmV4ZSIpCiAgICAgICAgICAgIH07CiAgICAgICAgICAgIGZvcmVhY2ggKHN0cmluZyBjIGlu
CSCB64:IGNhbmRpZGF0ZXMpCiAgICAgICAgICAgIHsKICAgICAgICAgICAgICAgIGlmIChGaWxlLkV4aXN0
CSCB64:cyhjKSkgcmV0dXJuIGM7CiAgICAgICAgICAgIH0KICAgICAgICAgICAgUHJvY2Vzc1N0YXJ0SW5m
CSCB64:byBwc2kgPSBuZXcgUHJvY2Vzc1N0YXJ0SW5mbygid2hlcmUiLCAiN3oiKTsKICAgICAgICAgICAg
CSCB64:cHNpLlVzZVNoZWxsRXhlY3V0ZSA9IGZhbHNlOwogICAgICAgICAgICBwc2kuUmVkaXJlY3RTdGFu
CSCB64:ZGFyZE91dHB1dCA9IHRydWU7CiAgICAgICAgICAgIHBzaS5DcmVhdGVOb1dpbmRvdyA9IHRydWU7
CSCB64:CiAgICAgICAgICAgIFByb2Nlc3MgcCA9IFByb2Nlc3MuU3RhcnQocHNpKTsKICAgICAgICAgICAg
CSCB64:c3RyaW5nIG91dHB1dCA9IHAuU3RhbmRhcmRPdXRwdXQuUmVhZFRvRW5kKCk7CiAgICAgICAgICAg
CSCB64:IHAuV2FpdEZvckV4aXQoKTsKICAgICAgICAgICAgZm9yZWFjaCAoc3RyaW5nIGxpbmUgaW4gb3V0
CSCB64:cHV0LlNwbGl0KCdcbicpKQogICAgICAgICAgICB7CiAgICAgICAgICAgICAgICBzdHJpbmcgdCA9
CSCB64:IGxpbmUuVHJpbSgpOwogICAgICAgICAgICAgICAgaWYgKHQuTGVuZ3RoID4gMCAmJiBGaWxlLkV4
CSCB64:aXN0cyh0KSkgcmV0dXJuIHQ7CiAgICAgICAgICAgIH0KICAgICAgICB9CiAgICAgICAgY2F0Y2gg
CSCB64:eyB9CiAgICAgICAgcmV0dXJuIG51bGw7CiAgICB9Cn0K
