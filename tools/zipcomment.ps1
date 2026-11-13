param(
    [Parameter(Mandatory=$true, Position=0)][string]$Zip,
    [Parameter(Mandatory=$true, Position=1)][string]$Action,
    [Parameter(Position=2)][string]$CommentFile
)
# ZIP EOCD (End of Central Directory) comment read/write/clear
# Action: get | set | clear
# set: comment text read from $CommentFile (UTF-8)
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Find-Eocd([byte[]]$b) {
    # EOCD signature 0x06054b50; search backwards within last 64KB+22
    $start = [Math]::Max(0, $b.Length - 65557)
    for ($i = $b.Length - 22; $i -ge $start; $i--) {
        if ($b[$i] -eq 0x50 -and $b[$i+1] -eq 0x4B -and $b[$i+2] -eq 0x05 -and $b[$i+3] -eq 0x06) {
            return $i
        }
    }
    return -1
}

if (-not (Test-Path -LiteralPath $Zip)) {
    Write-Output "[ERROR] file not found: $Zip"
    exit 1
}
$bytes = [System.IO.File]::ReadAllBytes($Zip)
$pos = Find-Eocd $bytes
if ($pos -lt 0) {
    Write-Output "[ERROR] not a valid zip archive (EOCD not found)"
    exit 2
}
$commentLen = [BitConverter]::ToUInt16($bytes, $pos + 20)

switch ($Action.ToLowerInvariant()) {
    'get' {
        if ($commentLen -eq 0) { Write-Output ""; exit 0 }
        $commentBytes = New-Object byte[] $commentLen
        [Array]::Copy($bytes, $pos + 22, $commentBytes, 0, $commentLen)
        # decode: UTF-8 first, fallback to GBK; strip BOM if present
        $text = [System.Text.Encoding]::UTF8.GetString($commentBytes)
        if ($text.Contains([char]0xFFFD)) {
            $text = [System.Text.Encoding]::GetEncoding(936).GetString($commentBytes)
        }
        $text = $text.TrimStart([char]0xFEFF)
        Write-Output $text
        exit 0
    }
    'set' {
        if (-not $CommentFile -or -not (Test-Path -LiteralPath $CommentFile)) {
            Write-Output "[ERROR] comment file missing"
            exit 1
        }
        $comment = [System.IO.File]::ReadAllText($CommentFile, [System.Text.Encoding]::UTF8)
        $comment = $comment -replace "`r`n", "`n"
        $comment = $comment.TrimEnd("`n","`r")
        $newBytes = [System.Text.Encoding]::UTF8.GetBytes($comment)
        if ($newBytes.Length -gt 65535) {
            Write-Output "[ERROR] comment too long (max 65535 bytes)"
            exit 3
        }
        $head = New-Object byte[] ($pos + 20)
        [Array]::Copy($bytes, 0, $head, 0, $pos + 20)
        $lenBytes = [BitConverter]::GetBytes([UInt16]$newBytes.Length)
        $out = New-Object System.IO.MemoryStream
        $out.Write($head, 0, $head.Length)
        $out.Write($lenBytes, 0, 2)
        $out.Write($newBytes, 0, $newBytes.Length)
        [System.IO.File]::WriteAllBytes($Zip, $out.ToArray())
        Write-Output "[OK] comment set ($($newBytes.Length) bytes)"
        exit 0
    }
    'clear' {
        if ($commentLen -eq 0) { Write-Output "[OK] no comment"; exit 0 }
        $head = New-Object byte[] ($pos + 20)
        [Array]::Copy($bytes, 0, $head, 0, $pos + 20)
        $zero = [BitConverter]::GetBytes([UInt16]0)
        $out = New-Object System.IO.MemoryStream
        $out.Write($head, 0, $head.Length)
        $out.Write($zero, 0, 2)
        [System.IO.File]::WriteAllBytes($Zip, $out.ToArray())
        Write-Output "[OK] comment cleared"
        exit 0
    }
    default {
        Write-Output "[ERROR] action must be get/set/clear"
        exit 1
    }
}
