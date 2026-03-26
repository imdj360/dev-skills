// lml-compile: Compile a .lml file to XSLT using DataMapTestExecutor.
//
// Usage:
//   lml-compile <path-to.lml> <output-path.xslt>
//
// Exit codes:
//   0 - success
//   1 - error (message written to stderr)

using Microsoft.Azure.Workflows.UnitTesting;
using Microsoft.Azure.Workflows.Data.Entities;

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: lml-compile <input.lml> <output.xslt>");
    return 1;
}

var lmlPath = args[0];
var xsltPath = args[1];

if (!File.Exists(lmlPath))
{
    Console.Error.WriteLine($"File not found: {lmlPath}");
    return 1;
}

// DataMapTestExecutor expects the Logic App project root —
// derive it as the grandparent of the .lml file
// e.g. Artifacts/MapDefinitions/Foo.lml → project root = ../..
var projectRoot = Path.GetFullPath(Path.Combine(Path.GetDirectoryName(lmlPath)!, "..", ".."));

var mapContent = await File.ReadAllTextAsync(lmlPath);
var input = new GenerateXsltInput { MapContent = mapContent };

try
{
    var executor = new DataMapTestExecutor(projectRoot);
    var xsltBytes = await executor.GenerateXslt(input);
    var xsltDir = Path.GetDirectoryName(xsltPath)!;
    if (!string.IsNullOrEmpty(xsltDir))
        Directory.CreateDirectory(xsltDir);
    await File.WriteAllBytesAsync(xsltPath, xsltBytes);
    Console.WriteLine($"OK: {Path.GetFileName(xsltPath)}");
    return 0;
}
catch (Exception ex)
{
    Console.Error.WriteLine($"ERROR: {ex.Message}");
    return 1;
}
