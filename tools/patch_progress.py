# -*- coding: utf-8 -*-
import io
p = r'C:\Users\PC\Doubao\chats\2026-10-16\new-chat-1\xz-compressor.cmd'
with io.open(p, 'r', encoding='gbk', newline='') as f:
    lines = f.read().replace('\r\n', '\n').split('\n')

# 替换定义: (start1, end1, [newlines], anchor_must_contain)
RUN_PROG = [
':RUN_PROG',
'rem 输入: PMODE=add|extract, PROGCMD=参数行, SZIP=引擎路径',
'set "XZ_CMDLINE=!PROGCMD!"',
'call :LOG "进度条执行: !SZIP! !PROGCMD!"',
'powershell -NoProfile -ExecutionPolicy Bypass -File "!SD!tools\\runprog.ps1" -Exe "!SZIP!" -Mode !PMODE!',
'set "EC=!errorlevel!"',
'set "XZ_CMDLINE="',
'exit /b !EC!',
'',
]

XZ7Z = [
'set "PROGCMD=a -txz -mx=!LV! -mmt=on -bsp1 "!OUT!" "!IN!""',
'echo.',
'echo  [7-Zip] 正在压缩为 .xz ...',
'set "PMODE=add"',
'call :RUN_PROG',
]

XZFIN = [
'  set "PROGCMD=a -tzip -mem=AES256 -bsp1 !PWARG! "!OUT!.enc.zip" "!OUT!""',
'  set "PMODE=add"',
'  call :RUN_PROG',
'  set "ECE=!EC!"',
]

EXE7Z_M = '  set "PROGCMD=a -sfx"!SFXMOD!" -bsp1 !ZOPTSS! !EXEARGS! "!OUT!" !ALLARGS!"'
EXE7Z_S = '  set "PROGCMD=a -sfx"!SFXMOD!" -bsp1 !ZOPTSS! !EXEARGS! "!OUT!" "!IN!""'
EXE7Z_EXEC = [
'echo.',
'echo  [7-Zip] 正在生成自解压 exe ...',
'set "PMODE=add"',
'call :RUN_PROG',
]

GZ = [
'set "PROGCMD=a -tgzip -mx=!LV! -bsp1 "!OUT!" "!IN!""',
'set "PMODE=add"',
'call :RUN_PROG',
]
BZ2 = [
'set "PROGCMD=a -tbzip2 -mx=!LV! -bsp1 "!OUT!" "!IN!""',
'set "PMODE=add"',
'call :RUN_PROG',
]
ZIP = [
'set "PROGCMD=a -tzip -bsp1 !ZOPTS! !ZARG! "!OUT!" "!IN!""',
'if "!MULTI!"=="1" set "PROGCMD=a -tzip -bsp1 !ZOPTS! !ZARG! "!OUT!" !ALLARGS!"',
'set "PMODE=add"',
'call :RUN_PROG',
]
SZ = [
'set "PROGCMD=a -t7z -bsp1 !ZOPTS! !S7ARGS! "!OUT!" "!IN!""',
'if "!MULTI!"=="1" set "PROGCMD=a -t7z -bsp1 !ZOPTS! !S7ARGS! "!OUT!" !ALLARGS!"',
'set "PMODE=add"',
'call :RUN_PROG',
]
ADD = [
'set "PROGCMD=a -bsp1 "!EXIN!" !ADDLIST! !PARG! -y"',
'set "PMODE=add"',
'call :RUN_PROG',
]

EXTRACT = [
'set "EXENGINE="',
'set "EXPROGCMD="',
'if /i "!EXT2!"==".zip" set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
'if /i "!EXT2!"==".7z" set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
'if /i "!EXT2!"==".rar" (',
'  if defined RAREXE set "EXENGINE=!RAREXE!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
'  if not defined RAREXE set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
')',
'if /i "!EXT2!"==".xz" (',
'  if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
'  if not defined SZIP set "EXENGINE=tar" & set "EXPROGCMD=-xf "!EXIN!" -C "!EXOUT!""',
')',
'if /i "!EXT2!"==".exe" (',
'  if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
'  if not defined SZIP set "EXENGINE=start" & set "EXPROGCMD="!EXIN!""',
')',
'if /i "!EXT2!"==".apk" (',
'  echo  [提示] APK 是安卓安装包，可安装到手机/模拟器，也可用 7-Zip 打开查看内容。',
'  if defined SZIP set "EXENGINE=!SZIP!" & set "EXPROGCMD=x -y -bsp1 !PASSARG! -o"!EXOUT!" "!EXIN!""',
')',
'if not defined EXENGINE (',
'  echo  [错误] 不支持的文件类型: !EXIN!',
'  pause',
'  if defined XZCP_AUTO goto :QUIT',
'  goto :ARC_MENU',
')',
'echo  [解压] 正在解压 ...',
'if /i "!EXENGINE!"=="start" (',
'  start "" !EXPROGCMD!',
'  set "EC=0"',
') else (',
'  set "SZIP=!EXENGINE!"',
'  set "PROGCMD=!EXPROGCMD!"',
'  set "PMODE=extract"',
'  call :RUN_PROG',
')',
]

RM = [
'  set "PROGCMD=d -bsp1 "!EXIN!" "!ARCITEM!" !DARG! -y"',
'  set "PMODE=add"',
'  call :RUN_PROG',
]

REPACK = [
'  set "PROGCMD=a -txz -mx=9 -mmt=on -bsp1 "!XZNEW!" *"',
'  set "PMODE=add"',
'  call :RUN_PROG',
]

# (start,end,new,anchor)  1-based, 从后往前
edits = [
(2808, 2809, REPACK, 'a -txz -mx=9'),
(2464, 2465, RM, ' d "!EXIN!"'),
(2375, 2402, EXTRACT, 'set "EXCMD="'),
(2349, 2350, ADD, 'a "!EXIN!"'),
(2110, 2114, SZ, 'a -t7z'),
(2087, 2091, ZIP, 'a -tzip'),
(1284, 1287, BZ2, 'a -tbzip2'),
(1269, 1272, GZ, 'a -tgzip'),
(890, 891, EXE7Z_EXEC, '!CMD!'),
(887, 887, ['echo.'], 'call :LOG'),
(885, 885, [EXE7Z_S], 'a -sfx'),
(883, 883, [EXE7Z_M], 'a -sfx'),
(860, 863, XZFIN, 'a -tzip -mem=AES256'),
(794, 799, XZ7Z, 'a -txz'),
(761, 761, RUN_PROG + [':DO_COMPRESS'], ':DO_COMPRESS'),
]

for (st, en, new, anchor) in edits:
    block = '\n'.join(lines[st-1:en])
    if anchor not in block:
        print('ANCHOR FAIL lines %d-%d: %s' % (st, en, anchor))
        print('  got: ' + repr(block[:80]))
        raise SystemExit(1)
    lines[st-1:en] = new
    print('OK %d-%d -> %d lines' % (st, en, len(new)))

out = '\n'.join(lines).replace('\n', '\r\n')
with io.open(p, 'w', encoding='gbk', newline='') as f:
    f.write(out)
print('written, total lines now: %d' % len(lines))
