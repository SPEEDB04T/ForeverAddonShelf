# Puts one addon version on the shelf, in one go:
#   1. copies the addon's files from its working folder into addons/<Name> (the released source in this repo)
#   2. zips them and publishes the zip as the release "<Name>-v<version>" of this repo (asset "<Name>-<version>.zip")
#   3. adds the addon to addons.config.json if it is new, rebuilds the shelf list, commits and pushes
# Installers on people's machines pick the new version up from addons.tsv the next time they run.
# Afterwards republish the shelf page (see README.md).
#
# Usage: powershell -NoProfile -File release-addon.ps1 -Name TotemCouncil
#   -Source <folder>  the addon's working folder; default ..\<Name>
#   -Force            replace the zip of a version that is already released
#   -NoPush           stop before git push
param([Parameter(Mandatory = $true)][string]$Name, [string]$Source, [switch]$Force, [switch]$NoPush)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
if ($Name -notmatch '^[A-Za-z0-9_!\-]+$') { throw "'$Name' is not a plain addon folder name." }
if (-not $Source) { $Source = Join-Path $here "..\$Name" }
if (-not (Test-Path -LiteralPath $Source -PathType Container)) { throw "No folder $Source" }
$Source = (Resolve-Path -LiteralPath $Source).Path.TrimEnd('\')
$toc = Join-Path $Source "$Name.toc"
if (-not (Test-Path -LiteralPath $toc)) { throw "No $Name.toc in $Source" }

$meta = @{}
foreach ($line in Get-Content -LiteralPath $toc -Encoding UTF8) { if ($line -match '^##\s*([^:]+):\s*(.*)$') { $meta[$Matches[1].Trim()] = $Matches[2].Trim() } }
$version = $meta['Version']
if (-not $version -or $version -notmatch '^[0-9A-Za-z.\-]+$') { throw "$Name.toc needs a plain '## Version:' line (found '$version')." }
$title = $(if ($meta['Title']) { $meta['Title'] -replace '\|c[0-9a-fA-F]{8}', '' -replace '\|r', '' } else { $Name })

$configPath = Join-Path $here 'addons.config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json
$repo = [string]$config.repo
$tag = "$Name-v$version"
$zipName = "$Name-$version.zip"

# Native commands are run through cmd so their error text never trips PowerShell's error handling.
function Invoke-Quiet([string]$command) { cmd /c "$command >nul 2>nul"; return $LASTEXITCODE }
function Invoke-Checked([string]$what, [scriptblock]$run) { & $run; if ($LASTEXITCODE -ne 0) { throw "$what failed (exit $LASTEXITCODE)." } }

$exists = (Invoke-Quiet "gh release view $tag --repo $repo") -eq 0
if ($exists -and -not $Force) { throw "$title $version is already released ($tag). Bump '## Version' in $Name.toc, or pass -Force to replace its zip." }

# 1. The released source: everything in the working folder except dot files and dot folders (.git and the like).
$dest = Join-Path $here "addons\$Name"
if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
$files = @(Get-ChildItem -LiteralPath $Source -Recurse -File | Where-Object { $_.FullName.Substring($Source.Length) -notmatch '[\\/]\.' } | Sort-Object FullName)
if (-not $files.Count) { throw "Nothing to release in $Source" }
foreach ($f in $files) {
    $target = Join-Path $dest $f.FullName.Substring($Source.Length).TrimStart('\')
    New-Item -ItemType Directory -Force (Split-Path $target -Parent) | Out-Null
    Copy-Item -LiteralPath $f.FullName -Destination $target
}

# 2. The zip: one top folder named after the addon, forward slashes in the entry names.
$dist = Join-Path $here 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zip = Join-Path $dist $zipName
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($f in $files) {
        $entry = "$Name/" + ($f.FullName.Substring($Source.Length).TrimStart('\') -replace '\\', '/')
        [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $f.FullName, $entry, 'Optimal')
    }
} finally { $archive.Dispose() }

# The release. --latest=false keeps the installer as the repo's "latest" release, which the download links rely on.
$notes = Join-Path $Source 'CHANGELOG.md'
if ($exists) {
    Invoke-Checked 'Uploading the zip' { gh release upload $tag $zip --repo $repo --clobber }
} elseif (Test-Path -LiteralPath $notes) {
    Invoke-Checked 'Creating the release' { gh release create $tag $zip --repo $repo --title "$title $version" --notes-file $notes --latest=false }
} else {
    Invoke-Checked 'Creating the release' { gh release create $tag $zip --repo $repo --title "$title $version" --notes "$title $version" --latest=false }
}
$latest = (gh api "repos/$repo/releases/latest" --jq .tag_name)
if ($latest -notmatch '^v\d+$') {
    $installer = @(gh release list --repo $repo --limit 200 --json tagName --jq '.[].tagName') | Where-Object { $_ -match '^v\d+$' } |
        Sort-Object { [int]($_ -replace '^v', '') } | Select-Object -Last 1
    if ($installer) { Invoke-Checked 'Marking the installer as latest' { gh release edit $installer --repo $repo --latest } }
}

# 3. The shelf list.
if (@($config.addons) -notcontains $Name) {
    $names = @($config.addons) + $Name
    $esc = { param($s) ([string]$s).Replace('\', '\\').Replace('"', '\"') }
    $json = "{`n" +
        "  `"game`": `"$(& $esc $config.game)`",`n" +
        "  `"addonsPath`": `"$(& $esc $config.addonsPath)`",`n" +
        "  `"repo`": `"$(& $esc $config.repo)`",`n" +
        "  `"shelfPage`": `"$(& $esc $config.shelfPage)`",`n" +
        "  `"addons`": [" + (($names | ForEach-Object { "`"$_`"" }) -join ', ') + "]`n}`n"
    [IO.File]::WriteAllText($configPath, $json, (New-Object Text.UTF8Encoding($false)))
}
Invoke-Checked 'build.ps1' { powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'build.ps1') }

Invoke-Checked 'git add' { git -C $here add -- "addons/$Name" addons.tsv addons.config.json }
if ((Invoke-Quiet "git -C `"$here`" diff --cached --quiet") -ne 0) {
    Invoke-Checked 'git commit' { git -C $here commit -q -m "Release $title $version" }
}
if (-not $NoPush) { Invoke-Checked 'git push' { git -C $here push -q origin main } }

"Released $title $version"
"  https://github.com/$repo/releases/download/$tag/$zipName"
"Next: republish the shelf page so it shows the new version (README.md, 'Republishing the page')."
