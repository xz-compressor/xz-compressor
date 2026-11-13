# -*- coding: utf-8 -*-
import io
p = r'C:\Users\PC\Doubao\chats\2026-10-16\new-chat-1\xz-compressor.cmd'
with io.open(p, 'r', encoding='gbk', newline='') as f:
    lines = f.read().replace('\r\n', '\n').split('\n')
anchors = ['set "CMD=', '!CMD!', 'set "ENCCMD=', '!ENCCMD!', '!EXCMD!', 'a "!EXIN!"', ' d "!EXIN!"', 'tar -a -c -J', 'a -txz -mx=9']
for i, ln in enumerate(lines, 1):
    for a in anchors:
        if a in ln and ('SZIP' in ln or 'EXCMD' in ln or 'EXIN' in ln or 'tar -a' in ln or 'ENCCMD' in ln or a == '!CMD!'):
            print(i, repr(ln[:90]))
            break
