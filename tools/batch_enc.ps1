# 批量加密 / 改密 / 去密（zip/7z）
param(
  [ValidateSet("add","change","remove")][string]$Action="add",
  [string]$NewPass="",
  [string]$OldPass="",
  [string[]]$Files=@(),
  [string]$SevenZ=""
)
$OutputEncoding=[Text.Encoding]::UTF8
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
Add-Type -AssemblyName System.Windows.Forms
if($Files.Count -eq 0){
  $d=New-Object System.Windows.Forms.OpenFileDialog
  $d.Multiselect=$true
  $d.Filter="压缩包 (*.zip;*.7z)|*.zip;*.7z|所有文件 (*.*)|*.*"
  $d.Title="选择要批量处理的 zip/7z 文件（按住 Ctrl 可多选）"
  if($d.ShowDialog() -ne 'OK'){ Write-Host "已取消。"; exit 2 }
  $Files=$d.FileNames
}
if(-not $SevenZ){
  $cand=@("$env:ProgramFiles\7-Zip\7z.exe","${env:ProgramFiles(x86)}\7-Zip\7z.exe")
  $SevenZ=($cand | Where-Object{ Test-Path $_ } | Select-Object -First 1)
}
if(-not (Test-Path $SevenZ)){ Write-Host "[错误] 未找到 7-Zip，无法批量处理。"; exit 3 }

if($Action -ne 'remove' -and -not $NewPass){
  $p1=Read-Host "请输入新密码"
  $p2=Read-Host "请再次输入新密码"
  if($p1 -ne $p2){ Write-Host "[错误] 两次输入不一致。"; exit 4 }
  $NewPass=$p1
}
if($Action -eq 'change' -and -not $OldPass){
  $OldPass=Read-Host "请输入当前密码（无密码直接回车）"
}
if($Action -eq 'remove' -and -not $OldPass){
  $OldPass=Read-Host "请输入当前密码（无密码直接回车）"
}

$ok=0; $fail=0
foreach($f in $Files){
  if(-not (Test-Path -LiteralPath $f)){ Write-Host "[跳过] 不存在: $f"; $fail++; continue }
  $ext=[IO.Path]::GetExtension($f).ToLower()
  if($ext -ne '.zip' -and $ext -ne '.7z'){ Write-Host "[跳过] 非 zip/7z: $f"; $fail++; continue }
  $tmp=Join-Path $env:TEMP ("xzbe_"+[Guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $tmp -Force | Out-Null
  try{
    $oldArg=if($OldPass){"-p$OldPass"}else{""}
    if($oldArg){ & $SevenZ x $oldArg "-o$tmp" -y $f | Out-Null } else { & $SevenZ x "-o$tmp" -y $f | Out-Null }
    if($LASTEXITCODE -ne 0){ Write-Host "[失败] 解压失败(密码错误或损坏): $f"; $fail++; continue }
    $new=Join-Path $tmp ("new"+$ext)
    if($Action -eq 'remove'){
      & $SevenZ a ("-t"+$ext.TrimStart('.')) $new (Join-Path $tmp '*') | Out-Null
    } else {
      if($ext -eq '.zip'){ & $SevenZ a -tzip -mem=AES256 "-p$NewPass" $new (Join-Path $tmp '*') | Out-Null }
      else { & $SevenZ a -t7z -mhe=on "-p$NewPass" $new (Join-Path $tmp '*') | Out-Null }
    }
    if($LASTEXITCODE -ne 0){ Write-Host "[失败] 重新打包失败: $f"; $fail++; continue }
    Copy-Item -LiteralPath $f ($f+'.bak') -Force
    Copy-Item -LiteralPath $new $f -Force
    Write-Host "[完成] $f"
    $ok++
  } finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
  }
}
Write-Host "=========================================="
Write-Host ("成功 {0} 个, 失败 {1} 个。原文件已备份为 .bak" -f $ok,$fail)
if($fail -gt 0){ exit 1 } else { exit 0 }
