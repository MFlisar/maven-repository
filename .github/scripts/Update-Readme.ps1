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
                $artifact = [string] $metadata.metadata.artifactId
                $latest = [string] $metadata.metadata.versioning.latest
                $updated = [string] $metadata.metadata.versioning.lastUpdated
                if ([string]::IsNullOrWhiteSpace($group) -or
                    [string]::IsNullOrWhiteSpace($artifact) -or
                    [string]::IsNullOrWhiteSpace($latest) -or
                    $updated -notmatch '^\d{14}$') {
                    throw "Missing or invalid groupId, artifactId, latest or lastUpdated in $($file.FullName)"
                }
                $pomPath = Join-Path (Join-Path $file.DirectoryName $latest) "$artifact-$latest.pom"
                if (-not (Test-Path -LiteralPath $pomPath -PathType Leaf)) {
                    throw "Missing latest POM for artifact group '$group' in $pomPath."
                }
                [xml] $pom = [System.IO.File]::ReadAllText($pomPath)
                $repositoryName = [string] $pom.project.name
                $repositoryUrl = [string] $pom.project.scm.url
                if ([string]::IsNullOrWhiteSpace($repositoryUrl)) {
                    $repositoryUrl = [string] $pom.project.url
                }
                $repositoryUri = $null
                if (-not [uri]::TryCreate($repositoryUrl, [System.UriKind]::Absolute, [ref] $repositoryUri) -or
                    $repositoryUri.Scheme -ne 'https' -or
                    $repositoryUri.Host -ne 'github.com' -or
                    ($repositoryUri.AbsolutePath.Trim('/') -split '/').Count -ne 2) {
                    throw "Latest POM must define a GitHub repository URL in scm.url or project.url in $pomPath."
                }
                if ([string]::IsNullOrWhiteSpace($repositoryName)) {
                    $repositoryName = [uri]::UnescapeDataString(($repositoryUri.AbsolutePath.Trim('/') -split '/')[-1])
                }
                $repositoryUrl = $repositoryUri.GetLeftPart([System.UriPartial]::Path).TrimEnd('/')
                if ($repositoryUrl.EndsWith('.git', [System.StringComparison]::OrdinalIgnoreCase)) {
                    $repositoryUrl = $repositoryUrl.Substring(0, $repositoryUrl.Length - 4)
                }
                $timestamp = [datetime]::ParseExact(
                    $updated, 'yyyyMMddHHmmss', [System.Globalization.CultureInfo]::InvariantCulture
                )
                $groupPath = Split-Path $file.DirectoryName -Parent
                $relativePath = $groupPath.Substring($RepositoryRoot.TrimEnd('\', '/').Length + 1)
                $link = ($relativePath -split '[/\\]' | ForEach-Object {
                    [uri]::EscapeDataString($_)
                }) -join '/'
                $link = "https://github.com/MFlisar/maven-repository/tree/main/$link"
                [pscustomobject] @{
                    Group = $group
                    Latest = $latest
                    Updated = $timestamp
                    Link = $link
                    RepositoryName = $repositoryName
                    RepositoryUrl = $repositoryUrl
                }
            }
    }
)

$lines = @(
    '<!-- artifacts:start -->'
    ''
    '| Artifact group | Latest version | Repository |'
    '| --- | --- | --- |'
    $entries | Group-Object Group -CaseSensitive | Sort-Object Name | ForEach-Object {
        $latest = $_.Group | Sort-Object Updated -Descending | Select-Object -First 1
        $groupText = $latest.Group.Replace('|', '&#124;').Replace('[', '&#91;').Replace(']', '&#93;')
        $versionText = $latest.Latest.Replace('&', '&amp;').Replace('<', '&lt;').Replace('|', '&#124;').Replace('`', '&#96;')
        $repositoryText = $latest.RepositoryName.Replace('&', '&amp;').Replace('|', '&#124;').Replace('[', '&#91;').Replace(']', '&#93;')
        '| [{0}]({1}) | <code>{2}</code> | [{3}]({4}) |' -f $groupText, $latest.Link, $versionText, $repositoryText, $latest.RepositoryUrl
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
