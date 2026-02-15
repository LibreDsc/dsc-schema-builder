<#
.SYNOPSIS
    Build script for DscSchemaBuilder PowerShell module.

.DESCRIPTION
    Builds the .NET library, assembles the PowerShell module into an output
    directory ready for publishing, and optionally runs Pester tests.

.PARAMETER Configuration
    Build configuration. Valid values are 'Debug' or 'Release'. Default is 'Release'.

.PARAMETER Clean
    Remove previous build artifacts before building.

.PARAMETER OutputPath
    Output directory for the built module. Default is './output'.

.PARAMETER Test
    Run Pester tests after building.

.PARAMETER TestPath
    Path to test files or folder. Can be a directory or a single .Tests.ps1 file.
    Default is './tests/Unit'.

.PARAMETER CodeCoverage
    Enable code coverage reporting when running tests.

.EXAMPLE
    ./build.ps1
    Builds the module with Release configuration.

.EXAMPLE
    ./build.ps1 -Clean -Configuration Debug
    Cleans previous builds and builds with Debug configuration.

.EXAMPLE
    ./build.ps1 -Test
    Builds the module and runs all Pester tests.

.EXAMPLE
    ./build.ps1 -Test -TestPath ./tests/Unit/Get-DscResourceAstInfo.Tests.ps1
    Builds the module and runs a single test file.

.EXAMPLE
    ./build.ps1 -Test -CodeCoverage
    Builds the module, runs tests, and generates code coverage report.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [Parameter()]
    [switch]$Clean,

    [Parameter()]
    [string]$OutputPath = "$PSScriptRoot/output",

    [Parameter()]
    [switch]$Test,

    [Parameter()]
    [string]$TestPath = "$PSScriptRoot/tests/Unit",

    [Parameter()]
    [switch]$CodeCoverage
)

$ErrorActionPreference = 'Stop'

# Project paths
$script:ModuleName = 'DscSchemaBuilder'
$script:SrcPath = "$PSScriptRoot/src"
$script:CSharpProjectPath = "$SrcPath/MofConverter"
$script:CSharpProjectFile = "$CSharpProjectPath/MofConverter.csproj"

# Read version from module manifest
$script:ManifestPath = "$SrcPath/$ModuleName.psd1"
$script:ManifestData = Import-PowerShellDataFile -Path $ManifestPath
$script:ModuleVersion = $ManifestData.ModuleVersion
$script:ModuleOutputPath = "$OutputPath/$ModuleName/$ModuleVersion"

Write-Host "Building $ModuleName v$ModuleVersion..." -ForegroundColor Cyan
Write-Verbose -Verbose -Message "Configuration: $Configuration"
Write-Verbose -Verbose -Message "Project file: $CSharpProjectFile"
Write-Verbose -Verbose -Message "Module output: $ModuleOutputPath"

#region Clean
if ($Clean) {
    Write-Host "Cleaning previous build..." -ForegroundColor Yellow

    $pathsToClean = @(
        "$CSharpProjectPath/bin"
        "$CSharpProjectPath/obj"
        $OutputPath
    )

    foreach ($path in $pathsToClean) {
        if (Test-Path $path) {
            Write-Verbose -Verbose -Message "Removing: $path"
            Remove-Item -Path $path -Recurse -Force -ErrorAction Stop
        }
    }
}
#endregion Clean

#region Build .NET
Write-Host "Building .NET project..." -ForegroundColor Green

# Get dotnet.exe command path
$dotnetCommand = Get-Command -Name 'dotnet' -ErrorAction Ignore

if ($null -eq $dotnetCommand) {
    Write-Verbose -Verbose -Message "dotnet cannot be found in current path. Looking in ProgramFiles path."
    $dotnetCommandPath = Join-Path -Path $env:ProgramFiles -ChildPath "dotnet/dotnet.exe"
    $dotnetCommand = Get-Command -Name $dotnetCommandPath -ErrorAction Ignore

    if ($null -eq $dotnetCommand) {
        throw "dotnet.exe cannot be found. Please install .NET SDK."
    }
}

Write-Verbose -Verbose -Message "dotnet command found: $($dotnetCommand.Source)"
Write-Verbose -Verbose -Message "dotnet version: $(& $dotnetCommand --version)"

# Publish the MofConverter project – output goes to src/lib via PublishDir in .csproj
Push-Location $CSharpProjectPath
try {
    Write-Verbose -Verbose -Message "Executing: dotnet publish --configuration $Configuration"

    & $dotnetCommand publish --configuration $Configuration
    if ($LASTEXITCODE -ne 0) {
        throw "dotnet publish failed with exit code: $LASTEXITCODE"
    }

    # Verify expected binary was created in the lib folder
    $expectedBinary = "$SrcPath/lib/DscSchemaBuilder.MofConverter.dll"
    if (-not (Test-Path -Path $expectedBinary)) {
        throw "Expected binary was not created: $expectedBinary"
    }

    Write-Verbose -Verbose -Message "Build successful: $expectedBinary"
}
catch {
    Write-Error "Build failed with error: $_"
    throw
}
finally {
    Pop-Location
}
#endregion Build .NET

#region Package
Write-Host "Assembling module to output directory..." -ForegroundColor Green

$null = New-Item -Path $ModuleOutputPath -ItemType Directory -Force

# Copy module manifest and root module
Write-Verbose -Verbose -Message "Copying module manifest and root module"
Copy-Item -Path "$SrcPath/$ModuleName.psd1" -Destination $ModuleOutputPath -Force
Copy-Item -Path "$SrcPath/$ModuleName.psm1" -Destination $ModuleOutputPath -Force

# Copy Private and Public function scripts
foreach ($subfolder in @('Private', 'Public')) {
    $srcSubfolder = "$SrcPath/$subfolder"
    if (Test-Path $srcSubfolder) {
        Write-Verbose -Verbose -Message "Copying $subfolder scripts"
        Copy-Item -Path $srcSubfolder -Destination $ModuleOutputPath -Recurse -Force
    }
}

# Copy lib folder (compiled .NET assemblies and their dependencies)
$libSource = "$SrcPath/lib"
if (Test-Path $libSource) {
    Write-Verbose -Verbose -Message "Copying lib folder (compiled assemblies)"
    $libDest = "$ModuleOutputPath/lib"
    $null = New-Item -Path $libDest -ItemType Directory -Force

    # Copy DLLs and PDBs – skip .deps.json files as they are not needed at runtime
    Get-ChildItem -Path "$libSource/*" -Include '*.dll', '*.pdb' | ForEach-Object {
        Write-Verbose -Verbose -Message "  $($_.Name)"
        Copy-Item -Path $_.FullName -Destination $libDest -Force
    }
}
else {
    throw "lib folder not found at: $libSource. Did the .NET build succeed?"
}

# Copy LICENSE
if (Test-Path "$PSScriptRoot/LICENSE") {
    Write-Verbose -Verbose -Message "Copying LICENSE"
    Copy-Item -Path "$PSScriptRoot/LICENSE" -Destination $ModuleOutputPath -Force
}

# Copy docs folder
$docsSource = "$PSScriptRoot/docs"
if (Test-Path $docsSource) {
    Write-Verbose -Verbose -Message "Copying docs folder"
    Copy-Item -Path $docsSource -Destination $ModuleOutputPath -Recurse -Force
}
#endregion Package

#region Test
if ($Test) {
    Write-Host ""
    Write-Host "Running Pester tests..." -ForegroundColor Cyan

    # Check if Pester is installed
    $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $pesterModule -or $pesterModule.Version -lt [Version]'5.0.0') {
        Write-Host "Installing Pester 5.x..." -ForegroundColor Yellow
        Install-Module -Name Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck -Scope CurrentUser
        $pesterModule = Get-Module -Name Pester -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    }

    Write-Verbose -Verbose -Message "Using Pester version: $($pesterModule.Version)"
    Import-Module Pester -MinimumVersion 5.0.0 -Force

    # Build Pester configuration
    $pesterConfig = [PesterConfiguration]::Default
    $pesterConfig.Run.Path = $TestPath
    $pesterConfig.Run.Exit = $false
    $pesterConfig.Output.Verbosity = 'Detailed'
    $pesterConfig.TestResult.Enabled = $true
    $pesterConfig.TestResult.OutputPath = "$PSScriptRoot/TestResults.xml"
    $pesterConfig.TestResult.OutputFormat = 'NUnitXml'

    if ($CodeCoverage) {
        Write-Verbose -Verbose -Message "Code coverage enabled"
        $pesterConfig.CodeCoverage.Enabled = $true
        $pesterConfig.CodeCoverage.Path = @(
            "$ModuleOutputPath/$ModuleName.psm1"
            "$ModuleOutputPath/Private/*.ps1"
            "$ModuleOutputPath/Public/*.ps1"
        )
        $pesterConfig.CodeCoverage.OutputPath = "$PSScriptRoot/CodeCoverage.xml"
        $pesterConfig.CodeCoverage.OutputFormat = 'JaCoCo'
    }

    # Run tests
    $testResults = Invoke-Pester -Configuration $pesterConfig

    # Display summary
    Write-Host ""
    Write-Host "Test Results Summary:" -ForegroundColor Cyan
    Write-Host "  Total:   $($testResults.TotalCount)" -ForegroundColor White
    Write-Host "  Passed:  $($testResults.PassedCount)" -ForegroundColor Green
    Write-Host "  Failed:  $($testResults.FailedCount)" -ForegroundColor $(if ($testResults.FailedCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Skipped: $($testResults.SkippedCount)" -ForegroundColor Yellow

    if ($testResults.FailedCount -gt 0) {
        Write-Host ""
        Write-Host "Failed Tests:" -ForegroundColor Red
        $testResults.Failed | ForEach-Object {
            Write-Host "  - $($_.ExpandedPath)" -ForegroundColor Red
        }
        throw "Pester tests failed. $($testResults.FailedCount) test(s) failed."
    }
}
#endregion Test

#region Summary
Write-Host ""
Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Output location: $ModuleOutputPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "To use the module:" -ForegroundColor Yellow
Write-Host "  Import-Module '$ModuleOutputPath/$ModuleName.psd1'" -ForegroundColor White
Write-Host ""
Write-Host "To run a single test:" -ForegroundColor Yellow
Write-Host "  ./build.ps1 -Test -TestPath ./tests/Unit/Get-DscResourceAstInfo.Tests.ps1" -ForegroundColor White
#endregion Summary