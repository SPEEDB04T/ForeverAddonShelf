# Rebuilds the addon shelf from source: copies each addon's files to site/src,
# writes site/addons.json, and writes publish-files.json (the files map for the
# Artifact publish). The page zips the files in the viewer's browser.
# Usage: powershell -NoProfile -File build.ps1
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$site = Join-Path $here 'site'
$src = Join-Path $site 'src'
if (Test-Path $src) { Remove-Item $src -Recurse -Force }
New-Item -ItemType Directory -Force $src | Out-Null
$config = Get-Content (Join-Path $here 'addons.config.json') -Raw | ConvertFrom-Json

function Read-Toc([string]$tocPath) {
    $meta = @{}
    foreach ($line in Get-Content $tocPath) {
        if ($line -match '^##\s*([^:]+):\s*(.*)$') {
            $meta[$Matches[1].Trim()] = ($Matches[2].Trim() -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '')
        }
    }
    return $meta
}

$entries = @()
$publish = [ordered]@{ 'addons.json' = 'addon-hub/site/addons.json' }
foreach ($a in $config.addons) {
    $folder = (Resolve-Path (Join-Path $here $a.path)).Path
    $name = Split-Path $folder -Leaf
    $toc = Join-Path $folder "$name.toc"
    if (-not (Test-Path $toc)) { throw "No $name.toc in $folder" }
    $meta = Read-Toc $toc
    # Skip dotfiles and anything under a dot folder (.git).
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
    # Addons with a GitHub repo download the release zip "<Name>-<version>.zip" from tag "v<version>".
    $repo = $a.repo
    $downloadUrl = $(if ($repo) { "https://github.com/$repo/releases/download/v$version/$name-$version.zip" } else { $null })
    $entries += [ordered]@{
        id          = $name
        title       = $(if ($meta['Title']) { $meta['Title'] } else { $name })
        notes       = $meta['Notes']
        version     = $version
        repo        = $repo
        downloadUrl = $downloadUrl
        interface = $meta['Interface']
        updated   = ($files | Measure-Object LastWriteTime -Maximum).Maximum.ToString('yyyy-MM-dd')
        sizeBytes = $size
        files     = $list
        changelog = $changelog
    }
}

# Installer: the template plus this shelf's addon list, ASCII with CRLF line endings for cmd.
# PsLit makes a PowerShell double-quoted literal and spells non-ASCII as $([char]0x....) so the file stays ASCII.
function PsLit([string]$s) {
    $sb = New-Object System.Text.StringBuilder('"')
    foreach ($ch in [string]$s -as [char[]]) {
        $c = [int]$ch
        if ($c -lt 32 -or $c -gt 126) { [void]$sb.Append('$([char]0x' + $c.ToString('X4') + ')') }
        elseif ('"$`'.IndexOf($ch) -ge 0) { [void]$sb.Append('`' + $ch) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}
$addonLines = @($entries | Where-Object { $_.repo } | ForEach-Object {
    "    @{ Name = $(PsLit $_.id); Title = $(PsLit $_.title); Repo = $(PsLit $_.repo); Notes = $(PsLit $_.notes) }"
}) -join ",`n"
$template = [System.IO.File]::ReadAllText((Join-Path $here 'installer.template.bat'))
$installer = ($template.Replace('__ADDONS__', $addonLines) -replace "`r?`n", "`r`n")
$dist = Join-Path $here 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
[System.IO.File]::WriteAllText((Join-Path $dist 'Install-ForeverAddons.bat'), $installer, (New-Object System.Text.ASCIIEncoding))
$installerUrl = $(if ($config.installerRepo) { "https://github.com/$($config.installerRepo)/releases/latest/download/Install-ForeverAddons.bat" } else { $null })

$manifest = [ordered]@{
    game         = $config.game
    addonsPath   = $config.addonsPath
    installerUrl = $installerUrl
    built      = (Get-Date).ToString('yyyy-MM-dd HH:mm')
    addons     = $entries
}
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $site 'addons.json'), (ConvertTo-Json -InputObject $manifest -Depth 6), $utf8)
[System.IO.File]::WriteAllText((Join-Path $here 'publish-files.json'), (ConvertTo-Json -InputObject $publish -Depth 4 -Compress), $utf8)

"Built $($entries.Count) addon(s):"
$entries | ForEach-Object { "  $($_.id) $($_.version)  $($_.files.Count) files, $($_.sizeBytes) bytes" }
