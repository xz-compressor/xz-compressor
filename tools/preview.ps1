# 文本文件预览：自动识别 UTF-8/GBK，最多显示前 120 行
param([Parameter(Mandatory=$true)][string]$p)
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
if(-not (Test-Path -LiteralPath $p)){ Write-Host "[错误] 找不到文件: $p"; exit 2 }
$b=[IO.File]::ReadAllBytes($p)
# 大文件截断读取，避免刷屏
if($b.Length -gt 1048576){ $b=$b[0..1048575] }
$u=New-Object Text.UTF8Encoding($false,$true)
try{
  $s=$u.GetString($b)
  $encName='UTF-8'
} catch {
  $s=[Text.Encoding]::GetEncoding(936).GetString($b)
  $encName='GBK'
}
$lines=$s -split "`r?`n"
Write-Host ("[编码检测: {0}, 共 {1} 行]" -f $encName,$lines.Count)
Write-Host "------------------------------------------------------------"
if($lines.Count -gt 120){
  $lines[0..119]
  Write-Host "...... 仅显示前 120 行（完整内容请解压后查看）......"
} else {
  $lines
}
