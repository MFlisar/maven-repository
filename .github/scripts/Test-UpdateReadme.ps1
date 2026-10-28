$ErrorActionPreference = 'Stop'
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('maven-readme-test-' + [guid]::NewGuid())
$generator = Join-Path $PSScriptRoot 'Update-Readme.ps1'

function Assert-True($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}

function Add-Metadata($Group, $Artifact, $Version, $Updated) {
    $directory = Join-Path $root ('artifacts\' + $Group.Replace('.', '\') + '\' + $Artifact)
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $directory 'maven-metadata.xml'), @"
<metadata><groupId>$Group</groupId><artifactId>$Artifact</artifactId><versioning>
<latest>$Version</latest><versions><version>$Version</version></versions>
<lastUpdated>$Updated</lastUpdated></versioning></metadata>
"@)
}

try {
    [System.IO.Directory]::CreateDirectory($root) | Out-Null
    $readmePath = Join-Path $root 'README.md'
    $original = "# Repository`nBefore`n<!-- artifacts:start -->`n<!-- artifacts:end -->`nAfter`n"
    [System.IO.File]::WriteAllText($readmePath, $original)
    & $generator -RepositoryRoot $root
    $empty = [System.IO.File]::ReadAllText($readmePath)
    Assert-True ($empty.Contains('| Artifact group | Latest version |')) 'Missing empty table.'

    Add-Metadata 'io.github.mflisar.composetable' 'material3' '0.0.1-alpha01' '20261028095223'
    & $generator -RepositoryRoot $root
    Assert-True ([System.IO.File]::ReadAllText($readmePath).Contains(
        '| [io.github.mflisar.composetable](artifacts/io/github/mflisar/composetable) | <code>0.0.1-alpha01</code> |'
    )) 'The published composetable example must be extracted correctly.'
    Add-Metadata 'io.github.mflisar.composetable' 'styled' '0.0.2-alpha01' '20261029095223'
    Add-Metadata 'io.github.mflisar.composetable' 'styled-jvm' '0.0.2-alpha01' '20261029095223'
    Add-Metadata 'a.example' 'core' '10.0.0' '20261028095223'
    # Snapshot-level metadata must not become an extra group row.
    $snapshot = Join-Path $root 'artifacts\a\example\core\10.1-SNAPSHOT'
    [System.IO.Directory]::CreateDirectory($snapshot) | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $snapshot 'maven-metadata.xml'),
        '<metadata><groupId>a.example</groupId><version>10.1-SNAPSHOT</version><versioning /></metadata>')
    & $generator -RepositoryRoot $root
    $result = [System.IO.File]::ReadAllText($readmePath)
    Assert-True ($result.Contains('| [io.github.mflisar.composetable](artifacts/io/github/mflisar/composetable) | <code>0.0.2-alpha01</code> |')) 'Incorrect group, link or latest version.'
    Assert-True ([regex]::Matches($result, '\| \[io.github.mflisar.composetable\]').Count -eq 1) 'Platform variants must share a group row.'
    Assert-True ($result.IndexOf('[a.example]') -lt $result.IndexOf('[io.github')) 'Groups must be sorted.'
    Assert-True ($result.StartsWith("# Repository`nBefore`n") -and $result.EndsWith("`nAfter`n")) 'Content outside markers changed.'
    & $generator -RepositoryRoot $root
    Assert-True ([System.IO.File]::ReadAllText($readmePath) -ceq $result) 'Generator must be idempotent.'

    Add-Metadata 'broken.example' 'core' '' 'invalid'
    $failed = $false
    try { & $generator -RepositoryRoot $root } catch { $failed = $true }
    Assert-True $failed 'Invalid metadata must fail explicitly.'
    Assert-True ([System.IO.File]::ReadAllText($readmePath) -ceq $result) 'Invalid metadata must not overwrite README.'

    [System.IO.File]::WriteAllText($readmePath, '# No markers')
    $failed = $false
    try { & $generator -RepositoryRoot $root } catch { $failed = $true }
    Assert-True $failed 'Missing markers must fail explicitly.'
    Write-Host 'README generator tests passed.'
}
finally {
    if (Test-Path -LiteralPath $root) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
