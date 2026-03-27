# lml-compile

A .NET global tool that compiles Logic Apps Data Mapper (`.lml`) files to XSLT.

Used by the [xslt skill](../../skills/xslt/SKILL.md) hooks for Claude Code to auto-compile LML files on save — no running Logic Apps host required.

## Install

```bash
dotnet tool install -g lml-compile
```

## Usage

```bash
lml-compile <input.lml> <output.xslt>
```

**Example:**

```bash
lml-compile Artifacts/MapDefinitions/OrderToShipment.lml Artifacts/Maps/OrderToShipment.xslt
```

## How it works

The Logic Apps Data Mapper compiles `.lml` (YAML mapping definitions) to XSLT 3.0 using the `DataMapTestExecutor` from `Microsoft.Azure.Workflows.WebJobs.Tests.Extension`. This tool wraps that API as a standalone CLI so it can be called from hooks and scripts without a running host.

The compiled `.xslt` output can be debugged immediately with the [XSLT Debugger](https://marketplace.visualstudio.com/items?itemName=danieljonathan.xsltdebugger-darwin) VS Code extension (press F5).

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success |
| `1` | Error (message written to stderr) |

## Build from source

```bash
cd tools/lml-compile
dotnet pack -c Release -o ./nupkg
dotnet tool install -g lml-compile --add-source ./nupkg
```

To update after changes:

```bash
dotnet pack -c Release -o ./nupkg
dotnet tool update -g lml-compile --add-source ./nupkg
```
