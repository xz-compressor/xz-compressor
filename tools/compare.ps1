# 压缩率 / 耗时对比报告
param(
  [string]$Path="",
  [string]$SevenZ="",
  [string]$Tar="",
  [string]$Report=""
)
try{[Console]::OutputEncoding=[Text.Encoding]::UTF8}catch{}
Add-Type -AssemblyName System.Windows.Forms
if(-not $Path){
  $d=New-Object System.Windows.Forms.OpenFileDialog
  $d.Filter="任意文件或文件夹（请选择文件，文件夹请手动传参）|*.*"
  $d.Title="选择要对比压缩的文件"
  if($d.ShowDialog() -ne 'OK'){ Write-Host "已取消。"; exit 2 }
  $Path=$d.FileName
}
if(-not $SevenZ){
  $cand=@("$env:ProgramFiles\7-Zip\7z.exe","${env:ProgramFiles(x86)}\7-Zip\7z.exe")
  $SevenZ=($cand | Where-Object{ Test-Path $_ } | Select-Object -First 1)
}
if(-not (Test-Path $SevenZ)){ Write-Host "[错误] 未找到 7-Zip。"; exit 3 }
$src=Get-Item -LiteralPath $Path
if($src.PSIsContainer){
  $orig=(Get-ChildItem -LiteralPath $Path -Recurse -File | Measure-Object Length -Sum).Sum
} else { $orig=$src.Length }

$work=Join-Path $env:TEMP ("xzcmp_"+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
$rows=New-Object System.Collections.ArrayList
function Test-One($label,$fmt,$level,$solid,$ext){
  $out=Join-Path $work ("a_"+($label -replace '[^\w]','')+$ext)
  $sw=[Diagnostics.Stopwatch]::StartNew()
  $zargs=@('a',('-t'+$fmt),("-mx=$level"),'-mmt=on')
  if($solid){ $zargs+='-ms=on' }
  $zargs+=@($out,$Path)
  & $SevenZ @zargs *> $null
  $sw.Stop()
  if((Test-Path $out)){
    $n=(Get-Item $out).Length
    $ratio=[math]::Round((1-$n/[double]$orig)*100,2)
    $script:rows.Add([pscustomobject]@{方案=$label; 大小KB=[math]::Round($n/1KB,1); 压缩率=$ratio; 耗时秒=[math]::Round($sw.Elapsed.TotalSeconds,2)}) | Out-Null
    Remove-Item $out -Force -ErrorAction SilentlyContinue
  }
}
# 单文件格式
if(-not $src.PSIsContainer){
  Test-One 'zip 快速L3' 'zip' 3 $false '.zip'
  Test-One 'zip 标准L6' 'zip' 6 $false '.zip'
  Test-One 'zip 极限L9' 'zip' 9 $false '.zip'
  Test-One '7z 快速L3' '7z' 3 $true '.7z'
  Test-One '7z 标准L6' '7z' 6 $true '.7z'
  Test-One '7z 极限L9' '7z' 9 $true '.7z'
  Test-One 'gzip L9' 'gzip' 9 $false '.gz'
  Test-One 'bzip2 L9' 'bzip2' 9 $false '.bz2'
} else {
  Test-One 'zip 极限L9' 'zip' 9 $false '.zip'
  Test-One '7z 标准L6' '7z' 6 $true '.7z'
  Test-One '7z 极限L9' '7z' 9 $true '.7z'
}
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
$table=$rows | Sort-Object 大小KB | Format-Table -AutoSize | Out-String
$head="压缩对比报告`n源: $Path`n原始大小: {0} 字节 ({1} KB)`n" -f $orig,[math]::Round($orig/1KB,1)
$best=$rows | Sort-Object 大小KB | Select-Object -First 1
$foot="`n体积最小: $($best.方案)  ($($best.大小KB) KB, 压缩率 $($best.压缩率)%)`n"
Write-Host $head; Write-Host $table; Write-Host $foot
if(-not $Report){ $Report=Join-Path ([Environment]::GetFolderPath('Desktop')) '压缩对比报告.txt' }
($head+$table+$foot) | Out-File -FilePath $Report -Encoding UTF8
Write-Host "报告已保存: $Report"
