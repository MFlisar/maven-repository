$ErrorActionPreference = 'Stop'

$versionOutput = & mvn --version '-Dstyle.color=never'
if ($LASTEXITCODE -ne 0) {
    throw "Cannot locate Maven installation: mvn --version exited with $LASTEXITCODE."
}
$plainOutput = ($versionOutput -join "`n") -replace '\x1b\[[0-9;]*m', ''
$homeMatch = [regex]::Match($plainOutput, '(?m)^Maven home:\s*(.+?)\s*$')
if (-not $homeMatch.Success) {
    throw "Cannot read Maven home from mvn --version output: $plainOutput"
}
$libraryPath = Join-Path $homeMatch.Groups[1].Value 'lib'
$jars = @(Get-ChildItem -LiteralPath $libraryPath -Filter 'maven-artifact-*.jar' -File)
if ($jars.Count -ne 1) {
    throw "Expected one Maven artifact library in $libraryPath; found $($jars.Count)."
}
$jars[0].FullName
