# Merge META-INF/services (append, unique lines) and JAI registry files
# from every dependency jar into a fat-jar staging directory.
# Unpacking jars with `jar xf` keeps only the last copy of each path.
param(
    [Parameter(Mandatory = $true)][string]$Staging,
    [Parameter(Mandatory = $true)][string]$JarDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$services = @{}
$reg = New-Object System.Text.StringBuilder
[void]$reg.AppendLine('# Merged by build-fat.bat')
$regImagen = New-Object System.Text.StringBuilder
[void]$regImagen.AppendLine('# Merged by build-fat.bat')

function Add-RegistryText([System.Text.StringBuilder]$builder, [string]$label, [string]$text) {
    [void]$builder.AppendLine('')
    [void]$builder.AppendLine("# from $label")
    [void]$builder.AppendLine($text)
}

Get-ChildItem -LiteralPath $JarDir -Filter '*.jar' | Where-Object { $_.Name -notmatch 'sfi|stata' } | ForEach-Object {
    $jarName = $_.Name
    $zip = [System.IO.Compression.ZipFile]::OpenRead($_.FullName)
    try {
        foreach ($entry in $zip.Entries) {
            $name = $entry.FullName
            if ($name.StartsWith('META-INF/services/') -and -not $name.EndsWith('/')) {
                $reader = New-Object System.IO.StreamReader($entry.Open())
                try { $text = $reader.ReadToEnd() } finally { $reader.Close() }
                if (-not $services.ContainsKey($name)) {
                    $services[$name] = New-Object System.Collections.Generic.List[string]
                }
                $seen = @{}
                foreach ($existing in $services[$name]) { $seen[$existing] = $true }
                foreach ($line in ($text -split "`r?`n")) {
                    $trimmed = $line.Trim()
                    if ($trimmed -and -not $trimmed.StartsWith('#') -and -not $seen.ContainsKey($trimmed)) {
                        [void]$services[$name].Add($trimmed)
                        $seen[$trimmed] = $true
                    }
                }
            }
            $isRegistry = ($name -eq 'META-INF/registryFile.jai') -or
                ($name -eq 'META-INF/org.eclipse.imagen.registryFile.jai') -or
                ($name.StartsWith('META-INF/') -and $name.Contains('registryFile') -and $name.EndsWith('.jai'))
            if ($isRegistry) {
                $reader = New-Object System.IO.StreamReader($entry.Open())
                try { $text = $reader.ReadToEnd() } finally { $reader.Close() }
                $label = "$jarName!$name"
                Add-RegistryText $reg $label $text
                Add-RegistryText $regImagen $label $text
            }
        }
    } finally {
        $zip.Dispose()
    }
}

$svcRoot = Join-Path $Staging 'META-INF\services'
if (Test-Path -LiteralPath $svcRoot) {
    Remove-Item -LiteralPath $svcRoot -Recurse -Force
}
foreach ($path in $services.Keys) {
    $out = Join-Path $Staging ($path -replace '/', '\')
    $dir = Split-Path -Parent $out
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    [System.IO.File]::WriteAllLines($out, $services[$path])
}

$meta = Join-Path $Staging 'META-INF'
if (-not (Test-Path -LiteralPath $meta)) {
    New-Item -ItemType Directory -Force -Path $meta | Out-Null
}
[System.IO.File]::WriteAllText((Join-Path $meta 'registryFile.jai'), $reg.ToString())
[System.IO.File]::WriteAllText((Join-Path $meta 'org.eclipse.imagen.registryFile.jai'), $regImagen.ToString())
Write-Host ("Merged {0} service descriptors and {1} registry lines" -f $services.Count, ($reg.ToString() -split "`n").Count)
