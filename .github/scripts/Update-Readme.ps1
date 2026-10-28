param(
    [string] $RepositoryRoot = (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
)

$ErrorActionPreference = 'Stop'
$readmePath = Join-Path $RepositoryRoot 'README.md'
$artifactsPath = Join-Path $RepositoryRoot 'artifacts'
$readme = [System.IO.File]::ReadAllText($readmePath)
$pattern = '(?s)<!-- artifacts:start -->.*?<!-- artifacts:end -->'
if ([regex]::Matches($readme, $pattern).Count -ne 1) {
    throw 'README.md must contain exactly one artifacts:start / artifacts:end marker pair.'
}

$entries = @(
    if (Test-Path -LiteralPath $artifactsPath) {
        Get-ChildItem -LiteralPath $artifactsPath -Filter 'maven-metadata.xml' -Recurse -File |
            Sort-Object FullName |
            ForEach-Object {
                $file = $_
                [xml] $metadata = [System.IO.File]::ReadAllText($file.FullName)
                # Version-level snapshot metadata is not an artifact version listing.
                if ($null -eq $metadata.metadata.versioning.versions) {
                    if ($null -ne $metadata.metadata.version) {
                        return
                    }
                    throw "Missing version listing in $($file.FullName)"
                }
                $group = [string] $metadata.metadata.groupId
                $latest = [string] $metadata.metadata.versioning.latest
                $updated = [string] $metadata.metadata.versioning.lastUpdated
                if ([string]::IsNullOrWhiteSpace($group) -or
                    [string]::IsNullOrWhiteSpace($latest) -or
                    $updated -notmatch '^\d{14}$') {
                    throw "Missing or invalid groupId, latest or lastUpdated in $($file.FullName)"
                }
                $timestamp = [datetime]::ParseExact(
                    $updated, 'yyyyMMddHHmmss', [System.Globalization.CultureInfo]::InvariantCulture
                )
                $groupPath = Split-Path $file.DirectoryName -Parent
                $relativePath = $groupPath.Substring($RepositoryRoot.TrimEnd('\', '/').Length + 1)
                $link = ($relativePath -split '[/\\]' | ForEach-Object {
                    [uri]::EscapeDataString($_)
                }) -join '/'
                [pscustomobject] @{
                    Group = $group
                    Latest = $latest
                    Updated = $timestamp
                    Link = $link
                }
            }
    }
)

$lines = @(
    '<!-- artifacts:start -->'
    ''
    '| Artifact group | Latest version |'
    '| --- | --- |'
    $entries | Group-Object Group -CaseSensitive | Sort-Object Name | ForEach-Object {
        $latest = $_.Group | Sort-Object Updated -Descending | Select-Object -First 1
        $groupText = $latest.Group.Replace('|', '&#124;').Replace('[', '&#91;').Replace(']', '&#93;')
        $versionText = $latest.Latest.Replace('&', '&amp;').Replace('<', '&lt;').Replace('|', '&#124;').Replace('`', '&#96;')
        '| [{0}]({1}) | <code>{2}</code> |' -f $groupText, $latest.Link, $versionText
    }
    ''
    '<!-- artifacts:end -->'
)
$newline = if ($readme.Contains("`r`n")) { "`r`n" } else { "`n" }
$table = $lines -join $newline
$result = [regex]::Replace($readme, $pattern, [System.Text.RegularExpressions.MatchEvaluator] { param($match) $table })
if ($result -cne $readme) {
    [System.IO.File]::WriteAllText($readmePath, $result, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Updated README.md with $( @($entries | Group-Object Group -CaseSensitive).Count ) artifact groups."
}
