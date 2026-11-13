# 修复 ZIP 内中文文件名乱码：按源代码页(默认GBK/936)读取条目名，重新打包为 UTF-8 标准 ZIP
param(
  [Parameter(Mandatory=$true)][string]$src,
  [int]$cp = 936
)
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
if(-not (Test-Path -LiteralPath $src)){ Write-Host "[错误] 找不到文件: $src"; exit 2 }
Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null
$enc = [Text.Encoding]::GetEncoding($cp)
$tmp = "$src.encfix"
if(Test-Path $tmp){ Remove-Item $tmp -Force }
$fsIn = [IO.File]::OpenRead($src)
try{
  $zin = New-Object IO.Compression.ZipArchive($fsIn, [IO.Compression.ZipArchiveMode]::Read, $false, $enc)
  $fsOut = [IO.File]::Create($tmp)
  $zout = New-Object IO.Compression.ZipArchive($fsOut, [IO.Compression.ZipArchiveMode]::Create, [Text.Encoding]::UTF8)
  $count = 0
  foreach($e in $zin.Entries){
    $n = $e.FullName
    if($e.Length -gt 0 -and $e.CompressedLength -ge $e.Length){
      $lvl = [IO.Compression.CompressionLevel]::NoCompression
    } else {
      $lvl = [IO.Compression.CompressionLevel]::Optimal
    }
    $ce = $zout.CreateEntry($n, $lvl)
    $rs = $e.Open(); $ws = $ce.Open()
    $rs.CopyTo($ws)
    $ws.Dispose(); $rs.Dispose()
    $count++
  }
  $zout.Dispose(); $fsOut.Dispose()
  $zin.Dispose()
} finally {
  $fsIn.Dispose()
}
Copy-Item -LiteralPath $src ($src + '.bak') -Force
Move-Item -LiteralPath $tmp -Destination $src -Force
Write-Host "[完成] 已修复 $count 个条目的文件名编码（源代码页 $cp）。原文件备份为 .bak。"
exit 0
