# 生成自解压壳的 sfx.cfg（文本值用 UTF-8 base64，DEFAULTDIR 为 CURRENT/EXE 或字面路径）
param(
  [Parameter(Mandatory=$true)][string]$out,
  [string]$title = "",
  [string]$welcome = "",
  [string]$eulaFile = "",
  [string]$defdir = "CURRENT",
  [string]$run = ""
)
function B64($s){
  if([string]::IsNullOrEmpty($s)){ return "" }
  return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($s))
}
function Read-Auto($path){
  $b=[IO.File]::ReadAllBytes($path)
  $u=New-Object Text.UTF8Encoding($false,$true)
  try{ return $u.GetString($b) } catch { return [Text.Encoding]::GetEncoding(936).GetString($b) }
}
$eula=""
if($eulaFile -and (Test-Path -LiteralPath $eulaFile)){ $eula=Read-Auto $eulaFile }
$lines=@(
  "TITLE_B64=$(B64 $title)",
  "WELCOME_B64=$(B64 $welcome)",
  "EULA_B64=$(B64 $eula)",
  "DEFAULTDIR=$defdir",
  "RUN_B64=$(B64 $run)"
)
[IO.File]::WriteAllLines($out,$lines,(New-Object Text.UTF8Encoding($false)))
Write-Host "[OK] sfx.cfg generated: $out"
