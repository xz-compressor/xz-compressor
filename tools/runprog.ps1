# runprog.ps1 -- 带进度条运行 7-Zip（压缩/解压通用），重定向安全
# 命令行通过环境变量 XZ_CMDLINE 传入（原样保留引号，无需转义）
# 用法: powershell -File runprog.ps1 -Exe <7z.exe> -Mode <add|extract> [-BarWidth 34]
# 退出码: 透传 7z 退出码（0 成功, 1 警告, 2 致命错误, 7 参数错误）
# 说明: 7z 输出写入临时文件，主循环以共享方式 tail 解析百分比，
#       因此无论 stdout 是控制台还是被重定向到文件/管道都不会死锁。
param(
  [string]$Exe = "",
  [string]$Mode = "add",
  [int]$BarWidth = 34
)

$ErrorActionPreference = "Stop"
if ([string]::IsNullOrEmpty($Exe) -or -not (Test-Path -LiteralPath $Exe)) {
  [Console]::Error.WriteLine("  [runprog] 找不到引擎: $Exe")
  exit 7
}

$argLine = [Environment]::GetEnvironmentVariable("XZ_CMDLINE")
if ($null -eq $argLine) { $argLine = "" }

# ---- 检测是否交互式控制台（被重定向/管道时静默，不画进度条）----
$script:Interactive = $false
try {
  $w = [Console]::WindowWidth
  if ($w -gt 0) {
    $flag = [bool]([Console].GetProperty("IsOutputRedirected"))
    if ($flag) {
      if (-not [Console]::IsOutputRedirected) { $script:Interactive = $true }
    } else {
      $script:Interactive = $true
    }
  }
} catch { $script:Interactive = $false }

function Draw-Bar([int]$pct) {
  if (-not $script:Interactive) { return }
  if ($pct -lt 0) { $pct = 0 }
  if ($pct -gt 100) { $pct = 100 }
  $filled = [int]($pct * $BarWidth / 100)
  if ($filled -gt $BarWidth) { $filled = $BarWidth }
  $bar = ("#" * $filled) + ("-" * ($BarWidth - $filled))
  $verb = if ($Mode -eq "extract") { "解压" } else { "压缩" }
  $line = "  {0}  [{1}] {2,3}%  " -f $verb, $bar, $pct
  try { [Console]::Write("`r" + $line + "  ") } catch {}
}

# ---- 临时文件接收 7z 输出（避免管道死锁）----
$outFile = [IO.Path]::Combine($env:TEMP, ("xzprog_{0}.out" -f $PID))
$errFile = [IO.Path]::Combine($env:TEMP, ("xzprog_{0}.err" -f $PID))
Remove-Item $outFile,$errFile -Force -ErrorAction SilentlyContinue

$code = 1
try {
  $proc = Start-Process -FilePath $Exe -ArgumentList $argLine -NoNewWindow -PassThru `
          -RedirectStandardOutput $outFile -RedirectStandardError $errFile
  $lastPct = -1
  $shownZero = $false
  while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 150
    try {
      # 同时读取 stdout 与 stderr（7z 进度走 stdout，xz -v 进度走 stderr）
      $text = ""
      foreach ($tf in @($outFile, $errFile)) {
        if (Test-Path -LiteralPath $tf) {
          try {
            $fs2 = [IO.File]::Open($tf, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
            $sr2 = New-Object IO.StreamReader($fs2, [Text.Encoding]::GetEncoding(936))
            $text += $sr2.ReadToEnd()
            $sr2.Close(); $fs2.Close()
          } catch {}
        }
      }
      $ms = [regex]::Matches($text, "(\d{1,3})\s*%")
      if ($ms.Count -gt 0) {
        $pct = [int]$ms[$ms.Count - 1].Groups[1].Value
        if ($pct -ge 0 -and $pct -le 100 -and $pct -ge $lastPct -and $pct -ne $lastPct) {
          $lastPct = $pct
          Draw-Bar $pct
        }
      } elseif ($lastPct -lt 0 -and -not $shownZero) {
        Draw-Bar 0; $shownZero = $true
      }
    } catch {}
  }
  $proc.WaitForExit()
  $code = $proc.ExitCode
} catch {
  try { [Console]::Error.WriteLine("  [runprog] 运行异常: $($_.Exception.Message)") } catch {}
  exit 1
} finally {
  if ($code -eq 0 -or $code -eq 1) {
    Draw-Bar 100
    if ($script:Interactive) { [Console]::WriteLine() }
  } else {
    if ($script:Interactive) { [Console]::WriteLine() }
    # 失败时把 7z 的错误输出透传到 stderr
    try {
      if (Test-Path $errFile) {
        $et = [IO.File]::ReadAllText($errFile, [Text.Encoding]::GetEncoding(936))
        if ($et) { [Console]::Error.Write($et) }
      }
    } catch {}
  }
  Remove-Item $outFile,$errFile -Force -ErrorAction SilentlyContinue
}
exit $code