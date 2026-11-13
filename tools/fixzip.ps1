param([string]$src)
# fixzip.ps1 -- 修复 aapt2 在 Windows 上生成的 zip entry 分隔符 bug
# aapt2 link -A 时子目录分隔符写成反斜杠 (assets/tools\xxx.jar),
# Android AssetManager 无法按正斜杠路径打开。本脚本把所有 entry 名中
# 的反斜杠统一替换为正斜杠, 并保持压缩方式与内容不变。
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File fixzip.ps1 <apk>
Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
$tmp = "$src.fix"
$zin = [System.IO.Compression.ZipFile]::OpenRead($src)
$fs = [System.IO.File]::Create($tmp)
$zout = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
$fixed = 0
foreach ($e in $zin.Entries) {
    $n = $e.FullName.Replace('\', '/')
    $sr = $e.Open()
    $ms = New-Object System.IO.MemoryStream
    $sr.CopyTo($ms)
    $sr.Dispose()
    $data = $ms.ToArray()
    $ms.Dispose()
    # resources.arsc 必须 STORED 且 4 字节对齐 (API 30+ 硬性要求)
    if ($n -eq 'resources.arsc' -or $e.CompressedLength -eq $e.Length) {
        $ce = $zout.CreateEntry($n, [System.IO.Compression.CompressionLevel]::NoCompression)
    } else {
        $ce = $zout.CreateEntry($n, [System.IO.Compression.CompressionLevel]::Optimal)
    }
    $cw = $ce.Open()
    $cw.Write($data, 0, $data.Length)
    $cw.Dispose()
    if ($n -ne $e.FullName) { $fixed++ }
}
$zout.Dispose()
$fs.Dispose()
$zin.Dispose()
Remove-Item $src
Move-Item $tmp $src
Write-Output "fixzip: $fixed entry name(s) fixed"
