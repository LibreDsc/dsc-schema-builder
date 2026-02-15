# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-15

### Added

- `Convert-MofToDsc` command for converting MOF configuration files to Microsoft DSC
  configuration documents (JSON or YAML output).
- `build.ps1` build automation script to compile the .NET project, assemble the
  module into an output directory, and run Pester tests (individually or all at once).

### Changed

- Module now requires PowerShell 7.4+ (previously 5.1).
- Module manifest declares `lib\DscSchemaBuilder.MofConverter.dll` as a nested module.

## [0.1.0] - 2026-02-15

### Added

- `New-DscResourceManifestFromClass` command for generating DSC resource manifests from
  PowerShell class-based DSC resources.
