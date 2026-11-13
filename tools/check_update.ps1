# 检查 7-Zip 更新
param([string]$SevenZ="")
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
if(-not $SevenZ){
  $cand=@("$env:ProgramFiles\7-Zip\7z.exe","${env:ProgramFiles(x86)}\7-Zip\7z.exe")
  $SevenZ=($cand | Where-Object{ Test-Path $_ } | Select-Object -First 1)
}
$localVer="未知"
if(Test-Path $SevenZ){
  $v=(& $SevenZ 2>&1 | Out-String)
  if($v -match "7-Zip\s+(\d+\.\d+)"){ $localVer=$Matches[1] } elseif($v -match "(\d+\.\d+)"){ $localVer=$Matches[1] }
}
Write-Host "本地 7-Zip 版本: $localVer"
try{
  $web=New-Object System.Net.WebClient
  $web.Headers.Add('User-Agent','Mozilla/5.0')
  $html=$web.DownloadString('https://www.7-zip.org/download.html')
  $webVer=$null
  if($html -match 'Download 7-Zip\s+(\d+\.\d+)'){ $webVer=$Matches[1] }
  if(-not $webVer -and $html -match '7-Zip\s+(\d{2,3})'){ $webVer=($Matches[1] -replace '(\d)(\d)','$1.$2') }
  if(-not $webVer){ Write-Host "无法解析官网最新版本（官网结构可能变化）。请到 https://www.7-zip.org 查看。"; exit 0 }
  Write-Host "官网最新版本: $webVer"
  if($localVer -ne '未知' -and [version]$webVer -gt [version]$localVer){
    Write-Host "[提示] 发现新版本 $webVer（当前 $localVer），请到 https://www.7-zip.org 下载。"
  } else {
    Write-Host "[提示] 已是最新（或官网不高于本地版本）。"
  }
} catch {
  Write-Host "[提示] 无法联网检查更新（离线环境）。请在有网络时访问 https://www.7-zip.org 。"
  exit 0
}
