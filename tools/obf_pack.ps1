# ============================================================
#  obf_pack.ps1 — 安装器打包脚本（明文载荷，开源版）
#  用法:
#    powershell -ExecutionPolicy Bypass -File obf_pack.ps1 `
#      -SrcDir "C:\path\to\app" -OutExe "C:\path\to\Setup.exe" [-Icon "a.ico"]
#  说明:
#    把源目录所有文件按明文记录附加到安装器 EXE 末尾（含 SHA256 校验），
#    安装器运行时通过向导写入对应位置。
# ============================================================
param(
  [Parameter(Mandatory=$true)][string]$SrcDir,
  [Parameter(Mandatory=$true)][string]$OutExe,
  [string]$InstallerCs = "",
  [string]$Icon = "",
  [string]$AppName = "XZ压缩工具",
  [string]$AppVersion = "正式版 1.0",
  [string]$EulaFile = "",
  [string]$Csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
)
$ErrorActionPreference = "Stop"
$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
if ($InstallerCs -eq "") { $InstallerCs = Join-Path $scriptRoot "obf_installer.cs" }
if ($Icon -eq "") { $Icon = Join-Path $scriptRoot "xz.ico" }
if (-not (Test-Path -LiteralPath $SrcDir)) { throw "源目录不存在: $SrcDir" }
if (-not (Test-Path -LiteralPath $InstallerCs)) { throw "安装器源码不存在: $InstallerCs" }
if (-not (Test-Path -LiteralPath $Csc)) {
  $Csc = "$env:WINDIR\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

# ---- 自定义文案转义为 C# 字符串安全内容（\n 换行、\" 引号）----
function Escape-CSharp([string]$t) {
  if ($null -eq $t) { return "" }
  $t = $t.Replace('\','\\')
  $t = $t.Replace('"','\"')
  $t = $t.Replace("`r`n",'\n').Replace("`r",'\n').Replace("`n",'\n')
  $t = $t.Replace("`t",'\t')
  return $t
}

# 默认用户协议
$defaultEula = "XZ 压缩工具 使用许可与说明`n================================`n`n" +
  "1. 本软件按「现状」提供，仅供学习与个人使用。`n" +
  "2. 压缩、加密前请自行备份重要数据；因使用本软件造成的`n   数据损失，由使用者自行承担。`n" +
  "3. 请妥善保管压缩密码，密码丢失将无法恢复加密内容。`n" +
  "4. 本软件不包含任何间谍或恶意行为，所有操作均在本地完成。`n" +
  "5. 本软件集成了 XZ Utils（GPL 命令行，liblzma 为 0BSD）、`n   7-Zip（LGPL/BSD）等开源组件，版权归原作者所有。`n`n" +
  "继续安装即表示你已阅读并同意以上说明。"
$eulaText = $defaultEula
if ($EulaFile -ne "" -and (Test-Path -LiteralPath $EulaFile)) {
  $eulaText = [IO.File]::ReadAllText($EulaFile, [Text.Encoding]::UTF8)
}

# ---- 读入安装器源码并替换占位符 ----
$csText = [IO.File]::ReadAllText($InstallerCs, [Text.Encoding]::UTF8)
$csText = $csText.Replace("PLACEHOLDER_APPNAME", (Escape-CSharp $AppName))
$csText = $csText.Replace("PLACEHOLDER_VERSION", (Escape-CSharp $AppVersion))
$csText = $csText.Replace("PLACEHOLDER_EULA", (Escape-CSharp $eulaText))

$work = Join-Path $env:TEMP ("obfpack_" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
$csWork = Join-Path $work "installer.cs"
# 写 UTF-8 BOM，确保 csc 正确识别中文
[IO.File]::WriteAllText($csWork, $csText, (New-Object Text.UTF8Encoding($true)))
$baseExe = Join-Path $work "base.exe"

$cscArgs = @("/nologo","/target:winexe","/platform:anycpu","/out:`"$baseExe`"")
$cscArgs += "/reference:System.Windows.Forms.dll","/reference:System.Drawing.dll","/reference:System.dll"
if ($Icon -ne "" -and (Test-Path -LiteralPath $Icon)) { $cscArgs += "/win32icon:`"$Icon`"" }
$cscArgs += "`"$csWork`""
"编译安装器..."
$c = Start-Process -FilePath $Csc -ArgumentList $cscArgs -NoNewWindow -Wait -PassThru -RedirectStandardOutput (Join-Path $work "csc.out")
if (-not (Test-Path -LiteralPath $baseExe)) {
  throw "安装器编译失败: " + [IO.File]::ReadAllText((Join-Path $work "csc.out"))
}

# ---- 收集文件（明文记录，不再加密）----
$srcFull = (Resolve-Path -LiteralPath $SrcDir).Path
$files = Get-ChildItem -LiteralPath $srcFull -Recurse -File
$ms = New-Object IO.MemoryStream
$bw = New-Object IO.BinaryWriter($ms)
$bw.Write([Text.Encoding]::ASCII.GetBytes("XZOBF"))
$bw.Write([int32]$files.Count)

$sha = [Security.Cryptography.SHA256]::Create()

foreach ($f in $files) {
  $rel = $f.FullName.Substring($srcFull.Length).TrimStart("\","/") -replace "\\","/"
  $data = [IO.File]::ReadAllBytes($f.FullName)
  $fsha = $sha.ComputeHash($data)
  $relBytes = [Text.Encoding]::UTF8.GetBytes($rel)
  $bw.Write([int32]$relBytes.Length); $bw.Write($relBytes)
  $bw.Write([int32]$data.Length); $bw.Write($fsha); $bw.Write($data)
}
$bw.Write([Text.Encoding]::ASCII.GetBytes("XZEND"))
$payload = $ms.ToArray(); $bw.Close(); $ms.Close()

# ---- 拼接 base exe + payload ----
$baseBytes = [IO.File]::ReadAllBytes($baseExe)
$out = New-Object byte[] ($baseBytes.Length + $payload.Length)
[Buffer]::BlockCopy($baseBytes,0,$out,0,$baseBytes.Length)
[Buffer]::BlockCopy($payload,0,$out,$baseBytes.Length,$payload.Length)
$outDir = Split-Path $OutExe -Parent
if ($outDir -ne "" -and -not (Test-Path -LiteralPath $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
[IO.File]::WriteAllBytes($OutExe, $out)
"打包完成: $OutExe  (文件数 $($files.Count), 安装器 $([Math]::Round($baseBytes.Length/1KB))KB + 载荷 $([Math]::Round($payload.Length/1KB))KB)"

# 清理临时编译目录（直接删除，是打包过程的临时文件，非用户产物）
Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue