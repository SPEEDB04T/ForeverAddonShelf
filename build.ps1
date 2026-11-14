# Rebuilds the shelf from addons/ (the released source of every addon on the shelf). Writes:
#   addons.tsv            the list the installers download each time they run
#   dist/                 the Windows and Linux installers
#   site/addons.json      the shelf page's data, with site/src/ and publish-files.json (the files map for the Artifact publish)
# Usage: powershell -NoProfile -File build.ps1 [-SkipReleaseCheck]
# To put a new addon or version on the shelf, run release-addon.ps1; it calls this.
param([switch]$SkipReleaseCheck)
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$here = $PSScriptRoot
$site = Join-Path $here 'site'
$src = Join-Path $site 'src'
if (Test-Path $src) { Remove-Item $src -Recurse -Force }
New-Item -ItemType Directory -Force $src | Out-Null
$config = Get-Content (Join-Path $here 'addons.config.json') -Raw | ConvertFrom-Json
$repo = [string]$config.repo
if (-not $repo) { throw 'addons.config.json needs "repo" (the one GitHub repo that holds every addon).' }

function Read-Toc([string]$tocPath) {
    $meta = @{}
    foreach ($line in Get-Content $tocPath) {
        if ($line -match '^##\s*([^:]+):\s*(.*)$') {
            $meta[$Matches[1].Trim()] = ($Matches[2].Trim() -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '')
        }
    }
    return $meta
}

# A release download answers with a redirect when it exists and 404 when it doesn't.
function Test-Download([string]$url) {
    try {
        $req = [Net.HttpWebRequest]::Create($url)
        $req.Method = 'HEAD'; $req.AllowAutoRedirect = $false; $req.UserAgent = 'ForeverAddonShelfBuild'; $req.Timeout = 20000
        $res = $req.GetResponse()
        try { return ([int]$res.StatusCode -lt 400) } finally { $res.Close() }
    } catch [Net.WebException] {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404) { return $false }
        throw
    }
}

$entries = @()
$publish = [ordered]@{ 'addons.json' = 'addon-hub/site/addons.json' }
foreach ($name in @($config.addons)) {
    $folder = Join-Path $here "addons\$name"
    $toc = Join-Path $folder "$name.toc"
    if (-not (Test-Path $toc)) { throw "No addons\$name\$name.toc. Release the addon first: release-addon.ps1 -Name $name" }
    $folder = (Resolve-Path $folder).Path
    $meta = Read-Toc $toc
    $files = @(Get-ChildItem $folder -Recurse -File | Where-Object { $_.FullName.Substring($folder.Length) -notmatch '[\\/]\.' } | Sort-Object FullName)
    $list = @()
    $size = 0
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($folder.Length).TrimStart('\', '/') -replace '\\', '/'
        $dest = Join-Path $src "$name/$rel"
        New-Item -ItemType Directory -Force (Split-Path $dest -Parent) | Out-Null
        Copy-Item $f.FullName $dest
        $published = "src/$name/$rel"
        $list += $published
        $size += $f.Length
        $publish[$published] = [ordered]@{ from = "addon-hub/site/$published"; contentType = 'text/plain' }
    }
    $changelog = ''
    $cl = Join-Path $folder 'CHANGELOG.md'
    if (Test-Path $cl) { $changelog = [System.IO.File]::ReadAllText($cl, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n" }
    $version = $(if ($meta['Version']) { $meta['Version'] } else { '0' })
    # Every addon version is a release of the one repo: tag "<Name>-v<version>", asset "<Name>-<version>.zip".
    $downloadUrl = "https://github.com/$repo/releases/download/$name-v$version/$name-$version.zip"
    if (-not $SkipReleaseCheck -and -not (Test-Download $downloadUrl)) {
        throw "$name $version has no release yet ($downloadUrl). Run: release-addon.ps1 -Name $name"
    }
    # When it last changed: the last commit that touched it, or the newest file while it is uncommitted.
    $updated = (& git -C $here log -1 --format=%cs -- "addons/$name") | Select-Object -First 1
    if (-not $updated) { $updated = ($files | Measure-Object LastWriteTime -Maximum).Maximum.ToString('yyyy-MM-dd') }
    $entries += [ordered]@{
        id          = $name
        title       = $(if ($meta['Title']) { $meta['Title'] } else { $name })
        notes       = $meta['Notes']
        version     = $version
        downloadUrl = $downloadUrl
        sourceUrl   = "https://github.com/$repo/tree/main/addons/$name"
        interface = $meta['Interface']
        updated   = $updated
        sizeBytes = $size
        files     = $list
        changelog = $changelog
    }
}

# addons.tsv: the list the installers download at run time (Name, Title, Version, Download address, Notes; tab-separated, UTF-8).
# Committed at the repo root so it's served from raw.githubusercontent.com; the installers embed a copy as a fallback.
# (shelf.tsv next to it is the old list, kept as it is for installer 3, which reads that file.)
$clean = { param($s) ([string]$s -replace '[\t\r\n]+', ' ').Trim() }
$shelfLines = @('# Forever Addon Shelf: Name<TAB>Title<TAB>Version<TAB>Download address<TAB>What it does. Generated by build.ps1.')
$shelfLines += @($entries | ForEach-Object {
    ((& $clean $_.id), (& $clean $(if ($_.title) { $_.title } else { $_.id })), (& $clean $_.version), (& $clean $_.downloadUrl), (& $clean $_.notes)) -join "`t"
})
$shelfTsv = ($shelfLines -join "`n") + "`n"
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $here 'addons.tsv'), $shelfTsv, $utf8)
$shelfB64 = [Convert]::ToBase64String($utf8.GetBytes($shelfTsv))

# The stone behind the Windows installer's panel: our own tileable noise (no game art), as a small PNG.
function New-RockTile([int]$size) {
    Add-Type -AssemblyName System.Drawing
    $rng = New-Object Random 1601
    $sum = New-Object 'double[]' ($size * $size)
    foreach ($o in @(@(4, 1.0), @(8, 0.8), @(16, 0.6), @(32, 0.45), @(64, 0.35))) {
        $n = [int]$o[0]; $gain = [double]$o[1]; $step = $size / $n
        $lat = New-Object 'double[]' ($n * $n)
        for ($i = 0; $i -lt $lat.Length; $i++) { $lat[$i] = $rng.NextDouble() }
        for ($y = 0; $y -lt $size; $y++) {
            $fy = $y / $step; $y0 = [int][Math]::Floor($fy); $ty = $fy - $y0; $ty = $ty * $ty * (3 - 2 * $ty); $y1 = ($y0 + 1) % $n
            for ($x = 0; $x -lt $size; $x++) {
                $fx = $x / $step; $x0 = [int][Math]::Floor($fx); $tx = $fx - $x0; $tx = $tx * $tx * (3 - 2 * $tx); $x1 = ($x0 + 1) % $n
                $top = $lat[$y0 * $n + $x0] * (1 - $tx) + $lat[$y0 * $n + $x1] * $tx
                $bot = $lat[$y1 * $n + $x0] * (1 - $tx) + $lat[$y1 * $n + $x1] * $tx
                $sum[$y * $size + $x] += ($top * (1 - $ty) + $bot * $ty) * $gain
            }
        }
    }
    $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    for ($y = 0; $y -lt $size; $y++) {
        for ($x = 0; $x -lt $size; $x++) {
            $v = [int][Math]::Max(7, [Math]::Min(38, [Math]::Round(19 + ($sum[$y * $size + $x] - 1.6) * 13)))
            $bmp.SetPixel($x, $y, [System.Drawing.Color]::FromArgb($v + 2, $v, [Math]::Max(0, $v - 3)))
        }
    }
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    return [Convert]::ToBase64String($ms.ToArray())
}
$rockB64 = New-RockTile 128

# The installers are the repo's "latest" release; addon releases are published with --latest=false so this never moves.
$repoBase = "https://github.com/$repo/releases/latest/download"
$installerUrl = "$repoBase/Install-ForeverAddons.bat"
$installerShUrl = "$repoBase/install-forever-addons.sh"
$values = @{
    '__SHELF_URL__'        = "https://raw.githubusercontent.com/$repo/main/addons.tsv"
    '__SHELF_PAGE__'       = [string]$config.shelfPage
    '__INSTALLER_URL__'    = [string]$installerUrl
    '__INSTALLER_SH_URL__' = [string]$installerShUrl
    '__SHELF_B64__'        = $shelfB64
    '__ROCK_B64__'         = $rockB64
}
function Fill([string]$text) { foreach ($k in $values.Keys) { $text = $text.Replace($k, $values[$k]) }; return $text }
$dist = Join-Path $here 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

# Windows: ASCII with CRLF line endings, because cmd reads the batch header.
$bat = (Fill ([System.IO.File]::ReadAllText((Join-Path $here 'installer.template.bat')))) -replace "`r?`n", "`r`n"
if ($bat -match '[^\x00-\x7F]') { throw 'installer.template.bat has non-ASCII characters; cmd needs it plain ASCII.' }
[System.IO.File]::WriteAllText((Join-Path $dist 'Install-ForeverAddons.bat'), $bat, (New-Object System.Text.ASCIIEncoding))

# Linux: UTF-8 with LF line endings.
$sh = (Fill ([System.IO.File]::ReadAllText((Join-Path $here 'installer.template.sh')))) -replace "`r`n", "`n"
[System.IO.File]::WriteAllText((Join-Path $dist 'install-forever-addons.sh'), $sh, $utf8)
$manifest = [ordered]@{
    game         = $config.game
    addonsPath   = $config.addonsPath
    installerUrl = $installerUrl
    installerShUrl = $installerShUrl
    built      = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    addons     = $entries
}
[System.IO.File]::WriteAllText((Join-Path $site 'addons.json'), (ConvertTo-Json -InputObject $manifest -Depth 6), $utf8)
[System.IO.File]::WriteAllText((Join-Path $here 'publish-files.json'), (ConvertTo-Json -InputObject $publish -Depth 4 -Compress), $utf8)

"Built $($entries.Count) addon(s):"
$entries | ForEach-Object { "  $($_.id) $($_.version)  $($_.files.Count) files, $($_.sizeBytes) bytes" }
