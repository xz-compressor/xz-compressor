# -*- coding: utf-8 -*-
"""fixzip.py -- 修复 aapt2 在 Windows 上生成的 zip entry 分隔符 bug
aapt2 link -A 时子目录分隔符写成了反斜杠 (assets/tools\\xxx.jar),
Android AssetManager 无法按正斜杠路径打开。本脚本把所有 entry 名中
的反斜杠统一替换为正斜杠, 并保持每个 entry 的压缩方式与内容不变。
用法: python fixzip.py <apk>  (原地重写)
"""
import zipfile
import sys
import os
import shutil

src = sys.argv[1]
tmp = src + '.fix'
zin = zipfile.ZipFile(src, 'r')
zout = zipfile.ZipFile(tmp, 'w')
fixed = 0
for item in zin.infolist():
    newname = item.filename.replace('\\', '/')
    data = zin.read(item.filename)
    zi = zipfile.ZipInfo(newname, date_time=item.date_time)
    zi.compress_type = item.compress_type
    zi.external_attr = item.external_attr
    zi.internal_attr = item.internal_attr & ~0x8  # 清 data descriptor bit
    zout.writestr(zi, data)
    if newname != item.filename:
        fixed += 1
zin.close()
zout.close()
os.replace(tmp, src)
print('fixzip: %d entry name(s) fixed in %s' % (fixed, os.path.basename(src)))
