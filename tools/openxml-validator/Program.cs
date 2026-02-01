using System;
using System.IO;
using System.Linq;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;

namespace OpenXmlValidatorTool;

public static class Program
{
    public static int Main(string[] args)
    {
        if (args.Length != 1)
        {
            Console.Error.WriteLine("usage: openxml-validator <path-to-xlsx>");
            return 2;
        }

        var filePath = args[0];
        if (string.IsNullOrWhiteSpace(filePath))
        {
            Console.Error.WriteLine("error: empty path");
            return 2;
        }

        if (!File.Exists(filePath))
        {
            Console.Error.WriteLine($"error: file not found: {filePath}");
            return 2;
        }

        try
        {
            using var doc = SpreadsheetDocument.Open(filePath, false);
            var validator = new OpenXmlValidator(FileFormatVersions.Office2013);
            var errors = validator.Validate(doc).ToList();
            if (errors.Count == 0)
            {
                return 0;
            }

            foreach (var err in errors.OrderBy(StableKey))
            {
                var xpath = err.Path?.XPath ?? "<no-xpath>";
                var id = string.IsNullOrWhiteSpace(err.Id) ? "<no-id>" : err.Id;
                Console.Error.WriteLine($"{id} {xpath} {err.Description}");
            }

            Console.Error.WriteLine($"validation failed: {errors.Count} error(s)");
            return 1;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(
                $"error: failed to open/validate: {ex.GetType().FullName}: {ex.Message}"
            );
            return 1;
        }
    }

    private static string StableKey(ValidationErrorInfo err)
    {
        var xpath = err.Path?.XPath ?? "";
        var id = err.Id ?? "";
        var desc = err.Description ?? "";
        return $"{id}\n{xpath}\n{desc}";
    }
}
