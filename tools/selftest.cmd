@echo off
setlocal enabledelayedexpansion
chcp 936 >nul 2>&1 <nul
title XZ压缩工具 自检
set "MAIN=%~dp0..\xz-compressor.cmd"
set "PSH=%WINDIR%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PSH%" set "PSH=powershell"
set "SZ="
if exist "C:\Program Files\7-Zip\7z.exe" set "SZ=C:\Program Files\7-Zip\7z.exe"
if exist "C:\Program Files (x86)\7-Zip\7z.exe" set "SZ=C:\Program Files (x86)\7-Zip\7z.exe"
if not exist "%MAIN%" echo [错误] 找不到主脚本 & goto FAILEND
if not defined SZ echo [错误] 未找到 7-Zip，自检需要 & goto FAILEND
set "T=%TEMP%\xzself_test"
rmdir /s /q "%T%" 2>nul
mkdir "%T%" 2>nul
mkdir "%T%\folder" 2>nul
set /a PASS=0, FAIL=0
"%PSH%" -NoProfile -Command "$s=('XZ自检内容ABC123#'*20000);[IO.File]::WriteAllText($env:T+'\sample.txt',$s);$d=('目录内容XYZ789@'*10000);[IO.File]::WriteAllText($env:T+'\folder\f2.txt',$d)" 2>nul
echo ============================================================
echo   XZ 压缩工具 自检开始
echo ============================================================
call :RUNCASE gz sample.txt gz 3 .gz
call :RUNCASE bz2 sample.txt bz2 9 .bz2
call :RUNCASE tgz folder tgz 6 .tar.gz
call :RUNCASE xz folder xz 9 .tar.xz
call :RUNCASE zip sample.txt zip 6 .zip --pass selftest123
call :RUNCASE 7z sample.txt 7z 9 .7z --solid
echo ------------------------------------------------------------
echo   自检结果: 通过 !PASS! 项, 失败 !FAIL! 项
echo ============================================================
if !FAIL! GTR 0 (
  echo [自检] 存在失败项，下面是各日志，临时目录保留于: %T%
  for %%L in ("%T%\log_*.txt") do (
    echo ----- %%~nL -----
    type "%%L" 2>nul
  )
  goto FAILEND
)
rmdir /s /q "%T%" 2>nul
echo [自检] 全部通过。
goto ENDOK
:RUNCASE
set "CN=%~1"
set "CSRC=%~2"
set "CFMT=%~3"
set "CLV=%~4"
set "EXT=%~5"
set "COUT=%T%\t_%CN%%EXT%"
del /f /q "%COUT%" 2>nul
call "%MAIN%" "%T%\!CSRC!" --format !CFMT! --level !CLV! --out "%COUT%" %6 %7 %8 %9 --yes < NUL > "%T%\log_!CN!.txt" 2>&1
if not exist "%COUT%" (
  echo [失败] !CN!  未生成产物
  set /a FAIL+=1
  goto :eof
)
if /i "!CN!"=="zip" (
  "!SZ!" t "%COUT%" "-pselftest123" >nul 2>&1
) else (
  "!SZ!" t "%COUT%" >nul 2>&1
)
if !errorlevel! EQU 0 (
  echo [通过] !CN!   t_!CN!!EXT!
  set /a PASS+=1
) else (
  echo [失败] !CN!  校验未通过
  set /a FAIL+=1
)
goto :eof
:FAILEND
echo [自检] 自检未通过，请检查环境或查看日志。
exit /b 1
:ENDOK
exit /b 0
