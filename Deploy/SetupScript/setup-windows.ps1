# Urbs Labyrinthi のセットアップ(Windows 10 / 11、x64)
#
#   setup-windows.bat             遊ぶための準備(エンジンの zip を展開して、確かめる)
#   setup-windows.bat -Dev        上に加えて、開発の道具(Godot 4.7.2、書き出しテンプレート、Python、Node.js)を入れる
#   setup-windows.bat -Check      何も入れず、足りないものだけを調べる
#
# 管理者権限は要らない(Python と Node.js を winget で入れるときだけ、確認が出ることがある)。
param(
    [switch]$Dev,
    [switch]$Check
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"      # Invoke-WebRequest を速くする
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$GodotVer = "4.7.2"
$GodotTag = "$GodotVer-stable"
$BaseUrl = "https://github.com/godotengine/godot/releases/download/$GodotTag"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Deploy = Split-Path -Parent $Here
$WinDir = Join-Path $Deploy "windows"
$Exe = Join-Path $WinDir "UrbsLabyrinthi.exe"
$Zip = Join-Path $WinDir "UrbsLabyrinthi-engine-windows.zip"
$Pck = Join-Path $WinDir "UrbsLabyrinthi.pck"
$Marker = Join-Path $WinDir "engine.sha256"

function Say($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }

function Get-Sha($path, $alg) { (Get-FileHash -Algorithm $alg -Path $path).Hash.ToLower() }

function Fetch-Verified($file, $dest, $sums) {
    $line = $sums -split "`n" | Where-Object { $_ -match [regex]::Escape($file) + "\s*$" } | Select-Object -First 1
    if (-not $line) { throw "SHA512 が見つからない: $file" }
    $want = ($line -split "\s+")[0].ToLower()
    Invoke-WebRequest -Uri "$BaseUrl/$file" -OutFile $dest
    if ((Get-Sha $dest "SHA512") -ne $want) { Remove-Item $dest -Force; throw "SHA512 が合わない: $file" }
}

Say "環境"
if (-not [Environment]::Is64BitOperatingSystem) { throw "64ビットの Windows のみ対応" }
Write-Host ("OS: " + [Environment]::OSVersion.VersionString)

Say "同梱のファイルを確かめる"
$haveZip = Test-Path $Zip
$havePck = Test-Path $Pck
Write-Host ("windows\UrbsLabyrinthi-engine-windows.zip : " + $(if ($haveZip) { "あり" } else { "なし" }))
Write-Host ("windows\UrbsLabyrinthi.pck                : " + $(if ($havePck) { "あり" } else { "なし" }))
Write-Host ("windows\UrbsLabyrinthi.exe                : " + $(if (Test-Path $Exe) { "あり(展開済み)" } else { "なし" }))
if ($Check) { exit 0 }
if (-not $havePck) { throw "windows\UrbsLabyrinthi.pck が無い(exe と同じフォルダに要る)" }

Say "エンジン(exe)を展開する"
$want = if (Test-Path $Marker) { (Get-Content $Marker -Raw).Trim().ToLower() } else { "" }
$ok = (Test-Path $Exe) -and $want -ne "" -and ((Get-Sha $Exe "SHA256") -eq $want)
if ($ok) {
    Write-Host "展開済みで、内容も合っている"
} else {
    if (-not $haveZip) { throw "windows\UrbsLabyrinthi-engine-windows.zip が無い" }
    Expand-Archive -Path $Zip -DestinationPath $WinDir -Force
    if ($want -ne "" -and (Get-Sha $Exe "SHA256") -ne $want) { throw "展開した exe の SHA256 が合わない(zip が壊れている)" }
    Write-Host "展開した: $Exe"
}
Unblock-File -Path $Exe -ErrorAction SilentlyContinue      # ダウンロードの印を外す(SmartScreen の警告が減る)
New-Item -ItemType Directory -Force -Path (Join-Path $WinDir "assets") | Out-Null

if ($Dev) {
    Say "開発の道具を入れる"
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        if (-not $winget) { throw "Python が無い。https://www.python.org/ から入れてから、もう一度実行する" }
        winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
    }
    if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
        if ($winget) { winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements }
        else { Write-Host "Node.js が無い(迷宮データの書き出しにだけ要る)。https://nodejs.org/ から入れる" }
    }
    # winget で入れた直後は、この窓の PATH に載らないので、読み直す
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
    if (Get-Command python -ErrorAction SilentlyContinue) {
        python -m pip install --user --upgrade pip pillow numpy
    }

    Say "Godot $GodotVer を入れる"
    $GodotDir = Join-Path $env:LOCALAPPDATA "Godot\$GodotVer"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("urbs-setup-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $sums = (Invoke-WebRequest -Uri "$BaseUrl/SHA512-SUMS.txt" -UseBasicParsing).Content
        $GodotExe = Join-Path $GodotDir "Godot_v${GodotTag}_win64.exe"
        if (-not (Test-Path $GodotExe)) {
            $z = Join-Path $tmp "godot.zip"
            Fetch-Verified "Godot_v${GodotTag}_win64.exe.zip" $z $sums
            New-Item -ItemType Directory -Force -Path $GodotDir | Out-Null
            Expand-Archive -Path $z -DestinationPath $GodotDir -Force
        }
        Write-Host "godot: $GodotExe"
        [Environment]::SetEnvironmentVariable("GODOT", $GodotExe, "User")

        Say "書き出しテンプレート(約1GB)を入れる"
        $Tpl = Join-Path $env:APPDATA "Godot\export_templates\$GodotVer.stable"
        if (-not ((Test-Path (Join-Path $Tpl "windows_release_x86_64.exe")) -and (Test-Path (Join-Path $Tpl "linux_release.x86_64")))) {
            $t = Join-Path $tmp "templates.zip"
            Fetch-Verified "Godot_v${GodotTag}_export_templates.tpz" $t $sums
            Expand-Archive -Path $t -DestinationPath (Join-Path $tmp "tpl") -Force
            New-Item -ItemType Directory -Force -Path $Tpl | Out-Null
            Copy-Item -Path (Join-Path $tmp "tpl\templates\*") -Destination $Tpl -Recurse -Force
        }
        Write-Host "テンプレート: $Tpl"
    } finally {
        Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    }
    Write-Host ""
    Write-Host "環境変数 GODOT を設定した(新しい窓から有効)。ビルドは、Linux か WSL で tools/build-deploy.sh を使う。"
}

Say "できた"
Write-Host "遊ぶ:  $Exe"
Write-Host "ログを取る:  windows\run-with-log.bat(強制終了などを調べるとき)"
