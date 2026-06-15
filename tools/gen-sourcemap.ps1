# gen-sourcemap.ps1 (axe)
# 通过 Rojo 根据 default.project.json 生成 sourcemap.json，供 Luau LSP 使用。
# 用法：
#   .\tools\gen-sourcemap.ps1           # 生成一次
#   .\tools\gen-sourcemap.ps1 -Watch    # 监听目录变动，自动重新生成
#
# 依赖：本机已安装 Rojo，并在 PATH 中，或通过 -RojoPath 指定可执行文件。

param(
    [switch]$Watch,
    [string]$RojoPath = ""
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

function Get-RojoExe {
    param([string]$Explicit)
    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($Explicit) { [void]$candidates.Add($Explicit) }
    $envRojo = [Environment]::GetEnvironmentVariable("ROJO_EXE", "Process")
    if ($envRojo) { [void]$candidates.Add($envRojo) }
    foreach ($x in @(
            "E:\Rojo\rojo.exe",
            (Join-Path $env:USERPROFILE ".cargo\bin\rojo.exe"),
            (Join-Path $env:USERPROFILE ".aftman\bin\rojo.exe")
        )) {
        if ($x) { [void]$candidates.Add($x) }
    }
    $cmd = Get-Command rojo -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { [void]$candidates.Add($cmd.Source) }

    foreach ($c in $candidates | Select-Object -Unique) {
        if (-not $c -or -not (Test-Path $c)) { continue }
        $full = (Resolve-Path $c).Path
        & $full --version 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return $full }
    }
    throw "找不到可用的 Rojo。请安装 Rojo，设置环境变量 ROJO_EXE，或：.\tools\gen-sourcemap.ps1 -RojoPath 'C:\Path\to\rojo.exe'"
}

function Invoke-GenSourcemap {
    $rojo = Get-RojoExe $RojoPath
    $proj = Join-Path $root "default.project.json"
    if (-not (Test-Path $proj)) {
        throw "缺少 default.project.json：$proj"
    }
    & $rojo sourcemap $proj -o (Join-Path $root "sourcemap.json")
    if ($LASTEXITCODE -ne 0) {
        throw "rojo sourcemap 失败，退出码 $LASTEXITCODE"
    }
    $outPath = Join-Path $root "sourcemap.json"
    $size = (Get-Item $outPath).Length
    Write-Host "[Watch] sourcemap.json updated ($size bytes) at $(Get-Date -Format 'HH:mm:ss')"
}

if (-not $Watch) {
    Invoke-GenSourcemap
    Write-Host "完成。若 LSP 未刷新：Ctrl+Shift+P -> Luau LSP: Reload Server"
    exit 0
}

Write-Host "[Watch] Starting file watcher on $root ..."
Invoke-GenSourcemap

$watchDirs = @(
    "ReplicatedCode",
    "ServerCode"
) | ForEach-Object { Join-Path $root $_ } | Where-Object { Test-Path $_ }

$global:_smapAxeSourcemapPending = $false
$action = { $global:_smapAxeSourcemapPending = $true }

foreach ($dir in $watchDirs) {
    foreach ($filter in @("*.luau", "*.lua")) {
        $w = New-Object System.IO.FileSystemWatcher $dir, $filter
        $w.IncludeSubdirectories = $true
        $w.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::DirectoryName
        $w.EnableRaisingEvents = $true
        Register-ObjectEvent $w "Created"  -Action $action | Out-Null
        Register-ObjectEvent $w "Deleted"  -Action $action | Out-Null
        Register-ObjectEvent $w "Renamed"  -Action $action | Out-Null
    }
}

$projPath = Join-Path $root "default.project.json"
if (Test-Path $projPath) {
    $wp = New-Object System.IO.FileSystemWatcher $root, "default.project.json"
    $wp.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite
    $wp.EnableRaisingEvents = $true
    Register-ObjectEvent $wp "Created" -Action $action | Out-Null
    Register-ObjectEvent $wp "Changed" -Action $action | Out-Null
    Register-ObjectEvent $wp "Renamed" -Action $action | Out-Null
}

$lastRun = [datetime]::MinValue
while ($true) {
    Start-Sleep -Milliseconds 300
    if ($global:_smapAxeSourcemapPending) {
        $now = [datetime]::Now
        if (($now - $lastRun).TotalMilliseconds -gt 600) {
            $global:_smapAxeSourcemapPending = $false
            $lastRun = $now
            Start-Sleep -Milliseconds 200
            try {
                Invoke-GenSourcemap
            } catch {
                Write-Host $_ -ForegroundColor Red
                $global:_smapAxeSourcemapPending = $false
            }
        }
    }
}
