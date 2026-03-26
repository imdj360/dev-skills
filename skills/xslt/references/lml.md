# Logic Apps Mapping Language (LML)

LML is the YAML-based source format produced and consumed by the Logic Apps Data Mapper
visual designer. It compiles to XSLT 3.0 via the design-time API. The generated XSLT is
what actually runs at runtime -- LML itself is a design-time-only artefact.

---

## Project Structure

```
Artifacts/
+-- MapDefinitions/
|   +-- MyMap.lml                        <- LML source (design-time only)
+-- Maps/
|   +-- MyMap.xslt                       <- compiled XSLT 3.0 (runtime)
|   +-- out/                             <- output directory for test results
+-- Schemas/
|   +-- source.xsd
|   +-- target.xsd                       <- or target.json for JSON output
+-- SampleData/
|   +-- Input.xml                        <- sample input XML for testing
|   +-- Output.xml                       <- expected output for verification
+-- DataMapper/
    +-- Extensions/
        +-- Functions/
        |   +-- CustomMathFunctions.xml  <- user-defined function definitions
        |   +-- SampleFunctions.xml      <- more custom functions
        +-- InlineXslt/
            +-- MySnippet.xml            <- inline XSLT snippet (NOT .xslt)
```

Note: Extension files are `.xml`, not `.xslt`. Custom functions go in `Functions/`
subdirectory, inline XSLT snippets go in `InlineXslt/` subdirectory.

---

## LML File Header

Every LML file starts with metadata keys (no `$map:` wrapper -- these are top-level):

```yaml
$version: 1
$input: XML
$output: XML
$sourceSchema: SourceSchema.xsd
$targetSchema: TargetSchema.xsd
$sourceNamespaces:
  ns0: http://example.com/source
  xs: http://www.w3.org/2001/XMLSchema
$targetNamespaces:
  ns0: http://example.com/target
  xs: http://www.w3.org/2001/XMLSchema
```

| Key | Required | Values |
|-----|----------|--------|
| `$version` | Yes | Always `1` |
| `$input` | Yes | `XML` or `JSON` |
| `$output` | Yes | `XML` or `JSON` |
| `$sourceSchema` | Yes | Filename of source schema (`.xsd` or `.json`) |
| `$targetSchema` | Yes | Filename of target schema (`.xsd` or `.json`) |
| `$sourceNamespaces` | If source uses namespaces | Prefix-to-URI mappings |
| `$targetNamespaces` | If target uses namespaces | Prefix-to-URI mappings |

After the header, the body contains the target structure with source mappings.

---

## LML Body -- Mapping Syntax

### Basic field mapping

Target elements as YAML keys, source XPath expressions as values:

```yaml
ns0:Invoice:
  ns0:InvoiceNumber: /ns0:Order/ns0:OrderID
  ns0:InvoiceDate: /ns0:Order/ns0:OrderDate
  ns0:Total: /ns0:Order/ns0:TotalAmount
```

- Namespace prefixes on target elements must match `$targetNamespaces`
- Namespace prefixes in source XPath must match `$sourceNamespaces`
- Relative paths are relative to the current context (e.g. inside a `$for` loop)

### Direct value from relative path

Inside a loop, use plain element names (relative to the loop context):

```yaml
$for(/SourceRoot/Items/Item):
  TargetItem:
    Id: Id
    Name: ProductName
```

### Looping with `$for`

```yaml
ns0:OrderFile:
  Order:
    $for(/ns0:X12_00401_850/ns0:PO1Loop1):
      LineItems:
        PONumber: /ns0:X12_00401_850/ns0:BEG/BEG03
        ItemOrdered: ns0:PO1/PO107
```

- `$for(xpath):` is a **block key** with a trailing colon -- children are indented below it
- The XPath argument selects the repeating source element
- Inside the loop, relative paths are relative to each iteration element
- Absolute paths (starting with `/`) still reference the document root
- Nested loops are supported

### Looping with index variable

```yaml
$for(/SourceRoot/Items/Item, $i):
  TargetItem:
    Position: $i
    Name: Name
```

### Conditionals with `$if`

`$if` is always a **block key** (not inline). Children are emitted only when the condition is true:

```yaml
$if(exists(/ns0:X12_00401_850/ns0:BEG/BEG08)):
  CustomerID: /ns0:X12_00401_850/ns0:BEG/BEG08
```

Common condition patterns:

| Pattern | Purpose | Compiles to |
|---------|---------|-------------|
| `$if(exists(xpath))` | Emit child only if source element exists | `<xsl:when test="exists(...)">` |
| `$if(is-equal(xpath, 'value'))` | Emit child only if value matches | `<xsl:when test="(xpath) = ('value')">` |

Multiple `$if` blocks can be siblings at the same level:

```yaml
Header:
  PODate: /ns0:X12/ns0:BEG/BEG05
  $if(exists(/ns0:X12/ns0:BEG/BEG08)):
    CustomerID: /ns0:X12/ns0:BEG/BEG08
  $if(is-equal(/ns0:X12/ns0:PER/PER01, 'AA')):
    ContactName: /ns0:X12/ns0:PER/PER02
```

### Setting target attributes with `$@`

Use the `$@` prefix to set an XML attribute on the parent element:

```yaml
Phone:
  ContactInfo:
    $@Contact: /ns0:Student/Address/Contact
```

Compiles to:
```xml
<Phone>
  <ContactInfo>
    <xsl:attribute name="Contact">{/ns0_0:Student/Address/Contact}</xsl:attribute>
  </ContactInfo>
</Phone>
```

### Multiline values with YAML `>-`

For long XPath expressions, use YAML folded scalar syntax:

```yaml
Quantity: >-
  xpath("if (../../Net castable as xs:decimal) then
  format-number(xs:decimal(../../Net), '0.0001') else '0.0001'")
```

The `>-` folds newlines into spaces and strips the trailing newline.

### Direct array access

```yaml
FirstItem: /SourceRoot/Items/Item[1]
```

`[n]` is 1-based (XPath convention).

### Source attribute references

`@` is a **reserved character** in LML value position. Attribute access is only valid
when the path starts with an element — bare `@attr` at the start of a value causes a
parse error (`Plain value cannot start with reserved character @`).

```yaml
# Valid — attribute reached via element path
TargetField: /SourceRoot/Element/@attributeName
CountryCode: tns:Address/tns:Country/@code

# INVALID — bare @ at start of value (parse error)
# Line: @lineNum
# custRef: @custId

# Fix — wrap bare attribute references in xpath()
Line: xpath("@lineNum")
custRef: xpath("@custId")
Priority: xpath("string(@priority)")
```

The same applies when passing attributes as function arguments — use `xpath("@attr")`
or route through an element path that ends in the attribute.

### `$value` -- mixed content nodes

```yaml
ComplexField:
  $value: /SourceRoot/SomeField
```

Used when the target type is both `string` and `complex`.

### JSON array items (`*`)

```yaml
$for(/SourceRoot/Items/*, $i):
  TargetItem:
    Name: Name
```

`*` represents `ArrayItem` in a JSON schema.

### JSON output

When `$output: JSON`, the body must start with `root:` as the top-level wrapper:

```yaml
$version: 1
$input: XML
$output: JSON
$sourceSchema: X12_00401_850.xsd
$targetSchema: OrderFile.json
root:
  OrderFile:
    Order:
      Header:
        PODate: /ns0:X12_00401_850/ns0:BEG/BEG05
```

The compiled XSLT uses XPath 3.1 `xml-to-json()` with `<map>`, `<string>`, `<number>`,
`<array>` elements from the `http://www.w3.org/2005/xpath-functions` namespace.

---

## Functions in LML

LML supports calling functions directly in value expressions. Prefer mechanisms in this
order — the compiler handles everything except `xpath()` more cleanly:

### Function priority order

| Priority | Mechanism | Use when |
|----------|-----------|----------|
| 1st | Built-in pseudofunction | Multiplication, existence check, equality |
| 2nd | Direct standard XPath call | `current-date()`, `count()`, `concat()`, `normalize-space()`, `string()` — compiler recognises these without a wrapper |
| 3rd | **Custom extension function** | Any logic beyond a direct field copy — date trimming, string building, conditional flags, aggregate sums. Define once in `DataMapper/Extensions/Functions/*.xml`, call by name. This is the preferred mechanism for non-trivial expressions. |
| 4th | Inline XSLT snippet | Multi-element/attribute structural output that a scalar function cannot produce |
| 5th (last resort) | `xpath("...")` | Truly one-off XPath 3.1 that is too narrow to reuse and too simple to warrant a function file |

**Decision rule:** if you find yourself writing `xpath("concat(...)")`,
`xpath("format-number(...)")`, or `xpath("tokenize(...)[last()]")`, write a custom
extension function instead. Named functions are cleaner in the LML, debuggable by name
in the compiled XSLT (`ef:functionName`), and reusable across maps.

```yaml
# Avoid: raw xpath() strings
ShipDate:  xpath("substring-before(tns:OrderDate, 'T')")
$@shipId:  xpath("concat('SHP-', tokenize(tns:OrderId, '-')[last()])")

# Prefer: named custom functions
ShipDate:  dateOnly(tns:OrderDate)
$@shipId:  shipId(tns:OrderId)
```

### Built-in pseudofunctions

These are recognized by the LML compiler and expanded inline:

| Function | Purpose | Example | Compiles to |
|----------|---------|---------|-------------|
| `multiply(a, b)` | Multiply two values | `multiply(ns0:PO1/PO102, ns0:PO1/PO104)` | `{(ns0:PO1/PO102) * (ns0:PO1/PO104)}` |
| `is-equal(a, b)` | String equality (used in `$if`) | `$if(is-equal(PER01, 'AA'))` | `<xsl:when test="(PER01) = ('AA')">` |
| `exists(xpath)` | Existence check (used in `$if`) | `$if(exists(ns0:PO1/PO107))` | `<xsl:when test="exists(ns0:PO1/PO107)">` |

### Standard XPath functions (direct call)

Standard XPath/XSLT functions can be called directly without `xpath()`:

```yaml
ns0:InvoiceDate: current-date()
ItemCount: count(Items/Item)
```

The compiler recognizes standard functions and emits them as-is.

### Designer built-in function groups

These are available in the Data Mapper designer Functions panel and compile to standard XPath/XSLT:

| Group | Functions |
|-------|-----------|
| **Collection** | Average, Count, Direct Access, Distinct values, Filter, Index, Join, Maximum, Minimum, Reverse, Sort, Subsequence, Sum |
| **Conversion** | To Date, To Integer, To Number, To String |
| **Date and time** | Add Days, Current Date, Current Time, Equals Date |
| **Logical comparison** | Equal, Exists, Greater, Greater or equal, If, If Else, Is Nil, Is Null, Is Number, Is String, Less, Less or Equal, Logical AND, Logical NOT, Logical OR, Not Equal |
| **Math** | Absolute, Add, Arctangent, Ceiling, Cosine, Divide, Exponential, Floor, Integer Divide, Log, Module, Multiply, Power, Round, Sine, Square Root, Subtract, Tangent |
| **String** | Codepoints to String, Concat, Contains, Ends with, Length, Lowercase, Name, Regex Matches, Regex Replace, Replace, Starts with, Substring, Substring after, Substring before, Trim, Uppercase |
| **Utility** | Copy, Error, **Execute XPath**, **Format DateTime**, **Format Number**, **Run XSLT** |

In LML text, these compile to their XPath equivalents. For example `if-else(condition, a, b)` → `if (condition) then a else b`.

### Execute XPath (Utility function)

Use when you need to access deeply nested nodes, attributes, or apply arbitrary XPath
against the source document. In LML this is equivalent to the `xpath("...")` escape hatch:

```yaml
# Designer: Execute XPath with expression "//Address"
# LML equivalent:
DeliveryAddress: xpath("//Address")

# Accessing an attribute deep in structure
$@custRef: xpath("tns:Customer/@custId")
```

### Run XSLT (Utility function)

Embeds a pre-authored XSLT snippet from `Artifacts/DataMapper/Extensions/InlineXslt/`.
Use for structural transformations that scalar functions cannot produce.

In LML the compiled output references the snippet file directly — use the designer to
wire this up, then inspect the compiled `.xslt` to understand the pattern.

### Custom extension functions

User-defined functions from `DataMapper/Extensions/Functions/*.xml` are called by name:

```yaml
Date: toUtcDateTime(/ShipmentConfirmation/Orders/Date)
Age: age(/ns0:Student/DateOfBirth)
ShipDate: dateOnly(tns:OrderDate)
ShipId: shipId(tns:OrderId)
```

The compiler:
1. Resolves the function name against extension XML files
2. Embeds the function as `xsl:function` in the `ef:` namespace
   (`http://azure.workflow.datamapper.extensions`)
3. Replaces the LML call with `ef:functionName(args)` in the compiled XSLT

Simple functions (like `age()`) may be **inlined** -- the compiler substitutes the function
body directly rather than emitting an `xsl:function` element.

**Function argument constraints — critical:**

The LML compiler only resolves **single-step element names** as function arguments.
Multi-step paths and bare attribute references must be wrapped in `xpath("...")`:

```yaml
# Valid — single-step element names in loop context
ShipDate:   dateOnly(tns:OrderDate)
$@weight:   parcelWeight(tns:Qty, tns:Weight)

# INVALID — multi-step path as function arg (compile error: "Source schema node not found")
# DeliveryAddress: formatAddress(tns:Customer/tns:Address/tns:Street, ...)
# $@hazmat: anyHazmat(tns:Items/tns:Item)

# Fix — wrap multi-step paths in xpath()
DeliveryAddress: formatAddress(xpath("tns:Customer/tns:Address/tns:Street"), ...)
$@hazmat:        anyHazmat(xpath("tns:Items/tns:Item"))
$@hazardous:     hazardousFlag(xpath("string(@hazardous)"))
```

Rule of thumb: if the argument contains a `/` or starts with `@`, wrap it in `xpath()`.

### The `xpath()` escape hatch

Last resort. Wraps arbitrary XPath 3.1 expressions for direct embedding:

```yaml
CompanyName: xpath("../CustomerName")
OrderNumber: xpath("concat(../Number, '/', Sequence)")
Name: >-
  xpath("normalize-space(concat(upper-case(/Q{http://example.com}Student/LastName),
  ', ', /Q{http://example.com}Student/FirstName))")
```

- The expression string is inserted directly into the compiled XSLT `{...}` text value template
- Use `Q{namespace-uri}` Clark notation for namespaced elements inside `xpath()` strings
- XPath 3.1 functions are available: `concat()`, `normalize-space()`, `upper-case()`,
  `format-number()`, `string-join()`, `tokenize()`, etc.
- **Limitation:** `xs:simpleContent` elements (text + attribute on the same element) cannot
  be mapped with `$:` — the compiler rejects it. Restructure the target schema to use child
  elements instead.

---

## Custom Function XML Format

Custom functions are defined in XML files under `DataMapper/Extensions/Functions/`.
Multiple files can exist; each contains one or more `<function>` elements.

### XML structure

```xml
<?xml version="1.0" encoding="utf-8" ?>
<customfunctions>
    <function name="functionName" as="returnType" description="Description text">
      <param name="paramName" as="paramType"/>
      <!-- function body: any combination of the elements below -->
    </function>
</customfunctions>
```

### Supported body elements

These mirror XSLT 3.0 instructions but **without** the `xsl:` prefix:

| Element | XSLT equivalent | Purpose |
|---------|-----------------|---------|
| `<value-of select="..."/>` | `<xsl:value-of>` | Return a string value |
| `<sequence select="..."/>` | `<xsl:sequence>` | Return a typed value or empty sequence |
| `<variable name="..." select="..."/>` | `<xsl:variable>` | Declare a local variable |
| `<choose>` | `<xsl:choose>` | Conditional branching |
| `<when test="...">` | `<xsl:when>` | Conditional branch |
| `<otherwise>` | `<xsl:otherwise>` | Default branch |

Parameters are referenced with `$paramName` in XPath expressions.
Variables are referenced with `$varName`.

### Parameter and return types

Use XSD type names:

| Type | Usage |
|------|-------|
| `xs:string` | Text values |
| `xs:integer` | Whole numbers |
| `xs:float` | Decimal numbers |
| `xs:decimal` | Precise decimal |
| `xs:date` | Date values |
| `xs:dateTime` | Date + time values |
| `xs:dateTime?` | Optional dateTime (can return empty sequence) |
| `xs:boolean` | True/false |
| `xs:anyAtomicType` | Any atomic value |

### Complete examples

**Simple function -- single expression:**
```xml
<function name="age" as="xs:float" description="Returns the current age.">
  <param name="inputDate" as="xs:date"/>
  <value-of select="round(days-from-duration(current-date() - xs:date($inputDate)) div 365.25, 1)"/>
</function>
```

**Conditional function:**
```xml
<function name="integer-min" as="xs:integer" description="Returns minimum of two numbers.">
  <param name="number1" as="xs:integer"/>
  <param name="number2" as="xs:integer"/>
  <choose>
    <when test="$number1 le $number2">
      <value-of select="$number1"/>
    </when>
    <otherwise>
      <value-of select="$number2"/>
    </otherwise>
  </choose>
</function>
```

**Complex function with variables and nested conditionals:**
```xml
<function name="toUtcDateTime" as="xs:dateTime?" description="Converts a date/datetime string to UTC.">
  <param name="inputDate" as="xs:string"/>
  <variable name="trim" select="normalize-space($inputDate)"/>
  <choose>
    <when test="$trim = ''">
      <sequence select="()"/>
    </when>
    <otherwise>
      <variable name="norm" select="replace($trim, '\s+', 'T')"/>
      <variable name="dt">
        <choose>
          <when test="contains($norm,'T')">
            <sequence select="xs:dateTime($norm)"/>
          </when>
          <otherwise>
            <sequence select="xs:dateTime(concat($norm, 'T00:00:00'))"/>
          </otherwise>
        </choose>
      </variable>
      <sequence select="adjust-dateTime-to-timezone($dt, xs:dayTimeDuration('PT0H'))"/>
    </otherwise>
  </choose>
</function>
```

**If-then-else function:**
```xml
<function name="custom-if-then-else" as="xs:string" description="Evaluates condition and returns value.">
  <param name="condition" as="xs:boolean"/>
  <param name="thenResult" as="xs:anyAtomicType"/>
  <param name="elseResult" as="xs:anyAtomicType"/>
  <choose>
    <when test="$condition">
      <value-of select="$thenResult"/>
    </when>
    <otherwise>
      <value-of select="$elseResult"/>
    </otherwise>
  </choose>
</function>
```

### How custom functions compile to XSLT

The compiler translates the XML definition into an `xsl:function` in the `ef:` namespace:

```xml
<!-- Extension function from CustomFunctions.xml -->
<xsl:function name="ef:toUtcDateTime" as="xs:dateTime?">
  <xsl:param name="inputDate" as="xs:string"/>
  <xsl:variable name="trim" select="normalize-space($inputDate)"/>
  <xsl:choose>
    <xsl:when test="$trim = ''">
      <xsl:sequence select="()"/>
    </xsl:when>
    <!-- ... rest of body with xsl: prefixes added ... -->
  </xsl:choose>
</xsl:function>
```

The transformation is mechanical: each body element gets the `xsl:` prefix, parameters become
`xsl:param`, variables become `xsl:variable`, and the function is placed at the stylesheet
top level with `name="ef:functionName"`.

---

## Inline XSLT Snippets

Inline XSLT snippets are XML files in `DataMapper/Extensions/InlineXslt/`. They contain
pre-authored XSLT fragments that the Data Mapper can embed in a compiled map.

### XML output snippet

```xml
<ContactInfo xmlns:st="http://StudentEnrollment.Student"
             xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:attribute name="ContactType">
    <xsl:value-of select="/st:Student/Address/ContactType"/>
  </xsl:attribute>
  <xsl:attribute name="Contact">
    <xsl:value-of select="/st:Student/Address/Contact"/>
  </xsl:attribute>
</ContactInfo>
```

### JSON output snippet

For JSON targets, use the XPath 3.1 map/string elements with text value templates:

```xml
<map key="ContactInfo" xmlns:p="http://SourceInstanceNamespace"
     xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:variable name="var1" select="/p:SourceInstance/Address/ContactType"/>
  <string key="ContactType">{$var1}</string>
  <xsl:variable name="var2" select="/p:SourceInstance/Address/Contact"/>
  <string key="Contact">{$var2}</string>
</map>
```

### Generic snippet with variable placeholders

Snippets can use generic namespace prefixes (e.g. `p:`, `var:`) that get resolved
when the Data Mapper embeds them:

```xml
<ContactInfo xmlns:p="http://SourceInstanceNamespace"
             xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
             xmlns:var="http://SourceInstanceVarNamespace">
  <xsl:variable name="var:var1" select="/p:SourceInstance/Address/ContactType"/>
  <xsl:attribute name="ContactType">
    <xsl:value-of select="$var:var1"/>
  </xsl:attribute>
</ContactInfo>
```

---

## Compiled XSLT 3.0 Patterns

Understanding the compiled output helps when debugging. All LML-compiled XSLT shares
these patterns:

### Standard namespaces and structure

```xml
<xsl:stylesheet
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:math="http://www.w3.org/2005/xpath-functions/math"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xmlns:dm="http://azure.workflow.datamapper"
  xmlns:ef="http://azure.workflow.datamapper.extensions"
  exclude-result-prefixes="xsl xs math dm ef"
  version="3.0" expand-text="yes">
```

- `dm:` -- Data Mapper namespace (mode names)
- `ef:` -- Extension functions namespace (custom functions)
- `expand-text="yes"` -- enables `{xpath}` text value templates throughout

### Two-template entry pattern

Every compiled map has this entry point:

```xml
<xsl:template match="/">
  <xsl:apply-templates select="." mode="azure.workflow.datamapper"/>
</xsl:template>
<xsl:template match="/" mode="azure.workflow.datamapper">
  <!-- actual mapping logic here -->
</xsl:template>
```

### Source namespace aliasing

When source and target share the same prefix (e.g. both use `ns0:`), the compiler
creates an alias for the source namespace:

- LML: `ns0:` in source = `http://source.ns`, `ns0:` in target = `http://target.ns`
- Compiled XSLT: `ns0:` = target namespace, `ns0_0:` = source namespace

### Value mapping via text value templates

Field mappings compile to elements with `{xpath}` expressions:

```yaml
# LML
CompanyName: xpath("../CustomerName")
```
```xml
<!-- Compiled XSLT -->
<CompanyName>{../CustomerName}</CompanyName>
```

### JSON output pattern

When `$output: JSON`, the compiled XSLT:
1. Captures the XML output in a variable
2. Converts to JSON via `xml-to-json()`
3. Uses `<map>`, `<string>`, `<number>`, `<array>` elements

```xml
<xsl:output indent="yes" media-type="text/json" method="text" omit-xml-declaration="yes"/>
<xsl:template match="/">
  <xsl:variable name="xmloutput">
    <xsl:apply-templates select="." mode="azure.workflow.datamapper"/>
  </xsl:variable>
  <xsl:value-of select="xml-to-json($xmloutput, map{'indent':true()})"/>
</xsl:template>
<xsl:template match="/" mode="azure.workflow.datamapper">
  <map>
    <map key="OrderFile">
      <string key="PODate">{/ns0:X12/ns0:BEG/BEG05}</string>
      <array key="LineItems">
        <xsl:for-each select="...">
          <map>
            <string key="Name">{...}</string>
            <number key="Qty">{...}</number>
          </map>
        </xsl:for-each>
      </array>
    </map>
  </map>
</xsl:template>
```

---

## LML -> XSLT 3.0 Compilation

The design-time API compiles LML to XSLT 3.0. The generated XSLT:
- Is self-contained -- embeds any referenced user-defined functions and inline XSLT snippets
- Is the only file needed at runtime
- Uses the Saxon .NET engine (same as the XSLT Debugger's `saxonnet` engine)
- Is stored in `Artifacts/Maps/<MapName>.xslt`

### Compile by saving in VS Code (preferred)
Saving the `.lml` in the Data Mapper designer **automatically writes both the `.lml` and
the compiled `.xslt`**. This is the normal workflow — no API call needed.

### Compile via SDK (no host required)
Use `DataMapTestExecutor` from `Microsoft.Azure.Workflows.WebJobs.Tests.Extension` v1.0.1+:

```csharp
var executor = new DataMapTestExecutor("path/to/logic-app-project");

// By map name (reads from Artifacts/MapDefinitions/<name>.lml)
var xslt = await executor.GenerateXslt("MyMap");

// By content
var input = new GenerateXsltInput { MapContent = lmlContent };
var xslt = await executor.GenerateXslt(input);

// Run transform and get result
var result = await executor.RunMapAsync(xslt, inputXmlBytes);
// result is JObject: { "$content-type": "application/xml", "$content": "<base64>" }
var xml = Encoding.UTF8.GetString(Convert.FromBase64String(result["$content"].Value<string>()));
```

A standalone `lml-compile` CLI tool in `Tools/lml-compile/` wraps this for hook use.
Install once as a global .NET tool:
```bash
cd Tools/lml-compile
dotnet pack -c Release -o ./nupkg
dotnet tool install -g lml-compile --add-source ./nupkg
```

Then compile any map directly (no project path needed):
```bash
lml-compile Artifacts/MapDefinitions/MyMap.lml Artifacts/Maps/MyMap.xslt
```

To update after changes: `dotnet tool update -g lml-compile --add-source ./nupkg`

### Compile via design-time REST API (requires running host)
```
POST http://localhost:7071/runtime/webhooks/workflow/api/management/generateXslt

Body: { "mapContent": "<lml file contents>" }
Response: { "xsltContent": "<compiled xslt>" }
```
Requires Azurite + `func host start` running.

---

## Testing the Compiled XSLT

Once compiled, test via the XSLT Debugger extension exactly as with any hand-authored XSLT:
- Engine: `saxonnet` (compiled output is XSLT 3.0)
- Stylesheet: `Artifacts/Maps/MyMap.xslt`
- Input XML: your test input file

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "xslt",
      "request": "launch",
      "name": "Debug MyMap (compiled from LML)",
      "engine": "saxonnet",
      "stylesheet": "${workspaceFolder}/Artifacts/Maps/MyMap.xslt",
      "xml": "${workspaceFolder}/Tests/MyMap-input.xml",
      "stopOnEntry": false,
      "logLevel": "log"
    }
  ]
}
```

You can also test via the design-time Test Map API:
```
POST http://localhost:<port>/runtime/webhooks/workflow/api/management/maps/MyMap/testMap

Body:
{
  "InputInstanceMessage": {
    "$content-type": "application/xml",
    "$content": "<base64-encoded input XML>"
  }
}

Response:
{
  "outputInstance": {
    "$content-type": "application/xml",
    "$content": "<base64-encoded output XML>"
  }
}
```

---

## LML vs Hand-authored XSLT

| Aspect | LML + Data Mapper | Hand-authored XSLT |
|--------|------------------|--------------------|
| Authoring | Visual drag-and-drop in VS Code | Direct XSLT editing |
| Source format | `.lml` (YAML, design-time only) | `.xslt` (source = runtime file) |
| Runtime file | `.xslt` compiled from LML | `.xslt` directly |
| XSLT version output | Always 3.0 | Any version |
| Complexity ceiling | Medium -- complex conditionals, loops, custom functions | Unlimited |
| Debuggable | Debug the **compiled `.xslt`**, not the LML source | Full debugger support |
| Version control | LML diffs cleanly; generated XSLT is verbose | XSLT diffs directly |
| Inline C# | Not supported | Via `msxsl:script` (1.0 only) |
| Custom functions | XML definition in Extensions, auto-compiled | `xsl:function` directly |

**Key point for debugging:** You always debug the compiled `.xslt` file, not the `.lml` source.
The LML is not executable. If the generated XSLT has a bug, fix it either:
- In the LML (re-save to recompile), or
- By switching to a fully hand-authored XSLT and abandoning the LML

---

## Claude Code Hooks — Automated LML/XSLT Pipeline

Two PostToolUse hooks are wired in `.claude/settings.json`. They fire automatically
whenever Claude writes or edits a file — **no manual steps needed**.

### Hook chain

```
Claude edits .lml
  → generate-xslt-from-lml.sh   (compiles LML → XSLT via lml-compile tool)
    → writes Artifacts/Maps/<name>.xslt
      → run-xslt-after-edit.sh  (runs the XSLT transform via XSLT Debugger API)
        → transform output visible in Claude's context
```

The second hook fires because writing the `.xslt` is itself a `Write` tool call,
which matches the same `Write|Edit` matcher.

### Hook 1 — LML compile (`generate-xslt-from-lml.sh`)

**Location:** `.claude/hooks/generate-xslt-from-lml.sh`
**Trigger:** any `Write|Edit` on a `*.lml` file
**What it does:**
- Reads the file path from the hook JSON stdin
- Calls `lml-compile <input.lml> <output.xslt>` (installed as a global .NET tool)
- Uses `DataMapTestExecutor.GenerateXslt()` from the SDK — **no running host required**
- Writes compiled XSLT to `Artifacts/Maps/<basename>.xslt`
- Returns `systemMessage` with success or error

**The `lml-compile` tool** is at `Tools/lml-compile/` — a .NET 8 console project using
`Microsoft.Azure.Workflows.WebJobs.Tests.Extension` v1.0.1. Install globally with
`dotnet tool install -g lml-compile --add-source Tools/lml-compile/nupkg`.

### Hook 2 — XSLT transform (`run-xslt-after-edit.sh`)

**Location:** `/Users/danieljonathan/Workspace/LearnDJ/TestXslt/.claude/hooks/run-xslt-after-edit.sh`
**Trigger:** any `Write|Edit` on a `*.xslt` file
**What it does:**
- Reads the file path from hook JSON stdin
- Looks up the matching `launch.json` config by stylesheet path
- Calls the XSLT Debugger HTTP API at `http://127.0.0.1:<port>/run-transform`
- Port is read from `~/.xslt-debugger-port` (written by the VS Code extension)
- Returns transform output as `hookSpecificOutput.additionalContext` so Claude sees it

**Requirements:** XSLT Debugger VS Code extension must be running (open any `.xslt` file).

### Settings.json hook config

```json
"hooks": {
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "bash .../run-xslt-after-edit.sh",
          "timeout": 30,
          "statusMessage": "Running XSLT transform..."
        },
        {
          "type": "command",
          "command": "bash .../generate-xslt-from-lml.sh",
          "timeout": 35,
          "statusMessage": "Compiling LML to XSLT..."
        }
      ]
    }
  ]
}
```

Both hooks run on every `Write|Edit`. Each silently exits 0 if the file type
doesn't match (`.lml` check and `*/Artifacts/Maps/*.xslt` check respectively).

### What this means when developing maps

- **Fix an LML bug** → Claude edits `.lml` → XSLT recompiled → transform runs → result in context
- **Fix a compiled XSLT directly** → Claude edits `.xslt` → transform runs immediately
- **Add a custom function** → edit `DataMapper/Extensions/Functions/*.xml` → edit `.lml` to use it → full chain fires
- **Transform output errors** appear in the hook's `additionalContext` — Claude sees them and can fix the LML/XSLT directly
- **Compile errors** appear in the `systemMessage` from hook 1 — fix the LML and save again

### Required VS Code Extensions

| Extension | ID | Purpose |
|-----------|-----|---------|
| **Azure Logic Apps (Standard)** | `ms-azuretools.vscode-azurelogicapps` | Data Mapper designer, `.lml` visual editor, `generateXslt` API, `func host start` task |
| **XSLT Debugger** (macOS) | `DanielJonathan.xsltdebugger-darwin` | Runs XSLT transforms, exposes HTTP API on `~/.xslt-debugger-port`, F5 debugging |
| **XSLT Debugger** (Windows) | `DanielJonathan.xsltdebugger-windows` | Same as above, Windows variant |

**Important:** The XSLT Debugger must be active (open any `.xslt` file) for hook 2 to work.
The port file `~/.xslt-debugger-port` is created by the extension when it starts.

The Azure Logic Apps extension merges the former separate Data Mapper extension — if you have
the old Data Mapper extension installed, remove it to avoid conflicts.

### Troubleshooting hooks

| Symptom | Cause | Fix |
|---------|-------|-----|
| `XSLT Debugger not running` | Port file missing | Open a `.xslt` file in VS Code to start extension |
| `No launch.json config found` | XSLT has no matching debug config | Add config to `.vscode/launch.json` |
| `LML compile failed: ...` | Syntax error in LML | Read error, fix LML, re-save |
| Hook fires but no XSLT written | `lml-compile` not on PATH | Run `dotnet tool install -g lml-compile --add-source Tools/lml-compile/nupkg` |
| `Connection refused` (old hook) | Old REST API hook path — replaced by SDK | Use current `generate-xslt-from-lml.sh` |

---

## LML Pseudofunction and Syntax Reference

| Syntax | Purpose | Compiles to |
|--------|---------|-------------|
| `$for(path)` | Loop over repeating source element | `<xsl:for-each select="path">` |
| `$for(path, $var)` | Loop with index variable | `<xsl:for-each>` + position variable |
| `$if(exists(xpath))` | Conditional on element existence | `<xsl:when test="exists(...)">` |
| `$if(is-equal(a, b))` | Conditional on value equality | `<xsl:when test="(a) = (b)">` |
| `$@attrName` | Set XML attribute on parent | `<xsl:attribute name="attrName">` |
| `[n]` | Direct array/sequence access (1-based) | XPath predicate |
| `@attr` | Reference source XML attribute | XPath `@attr` |
| `$value` | Map mixed content (string + complex) node | Direct text value |
| `*` | JSON ArrayItem in schema | XPath wildcard |
| `../` | Parent reference in nested loop | XPath parent axis |
| `.` | Current node reference in loop | XPath self |
| `$varname` | Auto-generated scoped index variable | `position()` binding |
| `xpath("expr")` | Arbitrary XPath 3.1 expression | `{expr}` in text value template |
| `multiply(a, b)` | Arithmetic multiplication | `{(a) * (b)}` |
| `exists(xpath)` | Existence check (in `$if`) | `exists(...)` |
| `is-equal(a, b)` | String comparison (in `$if`) | `(a) = (b)` |
| `current-date()` | Current date (standard XPath) | `{current-date()}` |
| `age(date)` | Custom function call | `{ef:age(date)}` or inlined |
| `toUtcDateTime(str)` | Custom function call | `{ef:toUtcDateTime(str)}` |
| `>-` (YAML) | Multiline folded scalar | Newlines folded to spaces |
| `Q{uri}local` | Clark notation in xpath() | Namespaced element reference |
