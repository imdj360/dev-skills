---
name: xslt
description: >
  Expert XSLT authoring, debugging, migration, and platform-compatibility skill for XML
  transformation work. Use this skill whenever the user mentions XSLT, XSL transformations,
  XML mapping, xsl:stylesheet, XPath, Saxon, BizTalk maps, Logic Apps Transform XML, or any
  XML-to-XML transformation task — even if they just paste two XML samples and say "transform this".
  Handles five modes: (1) generate XSLT from sample XML in+out or natural language description,
  (2) debug and explain broken or misbehaving XSLT, (3) migrate between XSLT versions on request,
  (4) check compatibility for Microsoft BizTalk, Logic Apps, XslCompiledTransform, or Saxon/SaxonCS,
  and (5) read, write, explain, or debug LML (Logic Apps Mapping Language) files and their compiled XSLT.
  Supports XSLT 1.0 (including msxsl:script inline C#), XSLT 2.0, and XSLT 3.0 / SaxonCS.
  For Generate and LML tasks, produces a ready-to-debug bundle: .xslt file + input XML +
  launch.json for the XSLT Debugger VS Code extension (press F5 to test immediately).
  Trigger on: "write an XSLT", "transform XML", "fix my XSLT", "xsl:template", "XPath",
  "msxsl:script", "BizTalk map", "Logic Apps transform", "LML", "Data Mapper",
  or any XML-to-XML transformation request.
---

# XSLT Skill

Expert XSLT authoring, debugging, migration, and platform-compatibility guidance for:
- **BizTalk / .NET compiled XSLT 1.0**
- **Microsoft Logic Apps Transform XML workflows**
- **Saxon / SaxonCS for XSLT 1.0, 2.0, and 3.0**

The primary goal is always to produce **correct, testable XSLT** that matches the user's
requested engine and deployment target. The user can run and debug immediately with the
XSLT Debugger VS Code extension (danieljonathan.xsltdebugger-windows / xsltdebugger-darwin).

**Version and engine policy:** always use the version and engine the user specifies, or the
version already present in their stylesheet. Never auto-upgrade. If the version or runtime
is ambiguous, ask whether the target is **BizTalk / Logic Apps / XslCompiledTransform** or
**Saxon / SaxonCS** before writing code.

## Workflow

1. Detect the task mode.
2. Detect the target engine and deployment platform.
3. Apply the platform rules before writing or changing the stylesheet.
4. Generate, debug, migrate, validate compatibility, or handle LML.
5. For Generate and LML modes: end with a runnable [Output Bundle](#output-bundle).
   For Debug, Migrate, and Compatibility modes: produce file artifacts only when the user
   requests files or when a fix requires code changes.

---

## Detect Mode First

| Mode | Trigger | Go to |
|------|---------|-------|
| **Generate** | Two XML samples, natural language description, "write me an XSLT", XSD/JSON schemas, mapping specification document, field mapping table, mapping requirements / business rules document | [Generate](#generate-mode) |
| **Debug** | Broken XSLT pasted, error message, wrong output | [Debug](#debug-mode) |
| **Migrate** | Explicit request: "convert to 3.0", "upgrade", "rewrite as 1.0" | [Migrate](#migrate-mode) |
| **Compatibility** | "Will this run in BizTalk?", "Does Logic Apps support this?", "Can SaxonCS run this?" | [Compatibility](#compatibility-mode) |
| **LML** | `.lml` file mentioned, Data Mapper, "compile to XSLT", LML syntax question | [LML](#lml-mode) |

For Generate and LML modes, end with the [Output Bundle](#output-bundle).
For Debug, Migrate, and Compatibility modes, produce file artifacts only when needed.

---

## Detect Engine and Platform

Classify the target before authoring:

- **BizTalk / XslCompiledTransform / .NET compiled / msxsl:script** → treat as **XSLT 1.0 compiled** unless the user explicitly says otherwise.
- **Logic Apps Consumption or Standard using Transform XML / integration account maps** → default to **Microsoft-compatible XSLT 1.0** unless the user explicitly says they are using Saxon externally.
- **Saxon / SaxonCS / HE / PE / EE / XSLT 2.0 / XSLT 3.0** → use Saxon rules.

If the user says "Logic Apps or BizTalk" and does not ask for Saxon specifically, prefer the most portable answer: **pure XSLT 1.0 without extension functions**, and warn separately when `msxsl:script` would limit portability.

---

## Generate Mode

**Inputs accepted (in order of preference):**
1. Sample input XML + desired output XML — best; infer all mappings directly
2. Source XSD/schema + target XSD/schema — derive element structure, generate sample XML from schema, proceed as (1)
3. Mapping specification / field mapping table (Word/Excel/table/CSV) listing source field → target field, transformations, and conditions — extract the field map, generate sample XMLs, proceed as (1)
4. Mapping requirements document (functional spec, integration requirements, business rules doc) describing what the transformation must do — derive field map and logic, generate samples, proceed as (1)
5. Sample input XML + mapping requirements or field mapping table — combine (1) and (4); XML defines structure, requirements define logic
6. Source XSD + mapping requirements — combine (2) and (4)
7. Sample input XML + natural language description of target structure
8. Source XSD + natural language description of target
9. Existing stylesheet + requested changes
10. Natural language only — generate plausible input/output skeletons, state assumptions, proceed

**When mapping requirements are shared:** extract each rule explicitly before writing any XSLT. List the derived field map as a numbered table (Source → Target → Transformation logic) and confirm with the user before proceeding to code if anything is ambiguous.

**Steps:**
1. Identify target platform and XSLT version — ask if not stated, do not assume
2. Analyse source and target structure — element mappings, conditionals, repeating nodes, namespaces
3. Choose the safest constructs for the requested engine
4. Draft XSLT following [Authoring Rules](#authoring-rules) for the target version
5. Mental dry-run — trace through the sample input, verify output matches expectation
6. Annotate non-obvious templates with `<!-- WHY: ... -->`
7. Produce [Output Bundle](#output-bundle)

---

## XSLT 1.0 with Inline C# (`msxsl:script`)

XSLT 1.0 supports embedded C# via the `msxsl:script` extension — a powerful feature available
in the .NET `XslCompiledTransform` engine and in the debugger's `compiled` engine.

### Namespace declarations required
```xml
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:msxsl="urn:schemas-microsoft-com:xslt"
  xmlns:my="urn:my-scripts">
```
- `msxsl` — the Microsoft XSLT extension namespace (fixed URI)
- `my` (or any prefix) — your script namespace; must match `implements-prefix` on the script block

### Script block structure
```xml
<msxsl:script language="C#" implements-prefix="my">
  <![CDATA[
    // Full C# method bodies here
    // Can use: System, System.Text, System.Xml, System.Collections, System.Text.RegularExpressions
    // Cannot use: async/await, custom assemblies not pre-loaded by the host

    public string FormatDate(string rawDate) {
      if (DateTime.TryParse(rawDate, out DateTime dt))
        return dt.ToString("yyyy-MM-dd");
      return rawDate;
    }

    public string PadLeft(string value, double width) {
      return value.PadLeft((int)width, '0');
    }
  ]]>
</msxsl:script>
```

### Calling C# from XPath
```xml
<xsl:value-of select="my:FormatDate(OrderDate)"/>
<xsl:value-of select="my:PadLeft(string(OrderId), 8)"/>
```

### Type mapping — XPath → C# parameter types
| XPath value | C# parameter type |
|-------------|------------------|
| String | `string` |
| Number | `double` |
| Boolean | `bool` |
| Node-set | `XPathNodeIterator` |
| Result tree fragment | `XPathNavigator` |

Always use `double` not `int` for numeric XPath values — XPath numbers are always doubles.
Cast inside C# if you need an integer: `(int)myParam`.

### Return types from C#
| C# return type | XPath sees it as |
|----------------|-----------------|
| `string` | string |
| `double` / `int` / `float` | number |
| `bool` | boolean |
| `XPathNavigator` | node-set |
| `XPathNodeIterator` | node-set |

### Available namespaces in script (no using statements needed)
- `System`
- `System.Text`
- `System.Xml`
- `System.Xml.XPath`
- `System.Collections`
- `System.Text.RegularExpressions`

### Canonical 1.0 + C# skeleton
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:msxsl="urn:schemas-microsoft-com:xslt"
  xmlns:fn="urn:my-functions"
  exclude-result-prefixes="msxsl fn">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <msxsl:script language="C#" implements-prefix="fn">
    <![CDATA[
      public string FormatDate(string raw) {
        if (System.DateTime.TryParse(raw, out System.DateTime dt))
          return dt.ToString("yyyy-MM-dd");
        return raw;
      }
    ]]>
  </msxsl:script>

  <xsl:template match="/">
    <Output>
      <xsl:apply-templates/>
    </Output>
  </xsl:template>

  <!-- templates here -->

</xsl:stylesheet>
```

### msxsl:script limitations
- No `async`/`await` — synchronous code only
- No custom assembly references — only what the host pre-loads
- Stepping into C# code is skipped by the debugger (Roslyn logs entry/return to console)
- Not supported in Saxon engine — msxsl:script is .NET-only; use `compiled` engine in launch.json

---

## Debug Mode

**Steps:**
1. Identify what the user has: input XML + stylesheet + expected vs actual output
2. Classify the bug using the taxonomy below
3. Explain in plain language exactly what is happening and why
4. Provide corrected XSLT with `<!-- FIXED: ... -->` and `<!-- WAS: ... -->` comments
5. Note the underlying pitfall to avoid next time

**Bug taxonomy:**

| Category | Common causes |
|----------|--------------|
| **Namespace mismatch** | Default namespace on source not declared in stylesheet; wrong prefix |
| **Template priority conflict** | Two templates match same node; wrong one fires |
| **XPath version mismatch** | Using XPath 2.0/3.0 functions (`string-join`, `tokenize`) in a 1.0 stylesheet |
| **Context node confusion** | Lost context inside `xsl:for-each`; `current()` vs `.` |
| **Output pollution** | Extra namespace declarations in output; unwanted XML declaration |
| **Type errors (2.0/3.0)** | String vs node-set; sequence where singleton expected |
| **msxsl:script type mismatch** | Passing XPath number as `string` param; node-set not as `XPathNodeIterator` |
| **Empty output** | XPath selects nothing — usually namespace or wrong axis |
| **Engine incompatibility** | Works in Saxon but not BizTalk/Logic Apps, or vice versa |

**Common Saxon error codes:**
| Code | Meaning |
|------|---------|
| `XPDY0002` | Context item absent — template called without matching node |
| `XTTE0570` | Type mismatch — wrong type passed to function or param |
| `XPST0081` | Undeclared namespace prefix in XPath |
| `XPTY0004` | Wrong cardinality — sequence where singleton expected |
| `FODT0001` | Invalid date/time string passed to `xs:date()` etc. |

**Namespace mismatch — the #1 bug. Quick debug template:**
```xml
<xsl:template match="/">
  <debug>
    <root-ns><xsl:value-of select="namespace-uri(/*)"/></root-ns>
    <root-name><xsl:value-of select="local-name(/*)"/></root-name>
  </debug>
</xsl:template>
```
Add, run, remove after confirming the namespace.

---

## Compatibility Mode

Use this mode when the user asks whether a stylesheet or approach will run on a specific Microsoft or Saxon target.

### BizTalk compatibility checklist

Treat BizTalk as **XSLT 1.0 plus Microsoft extensions**:
- Allow `msxsl:script` when the user explicitly wants inline C# and the runtime supports it.
- Do not use XPath 2.0 or 3.0 functions.
- Do not use `xsl:function`, `xsl:for-each-group`, `xsl:sequence`, maps, arrays, or try/catch.
- Be careful with extension objects and external assembly assumptions.
- Prefer deterministic, side-effect-free transforms.

Read [`references/biztalk-xslt.md`](references/biztalk-xslt.md) for BizTalk-specific guidance.

### Logic Apps compatibility checklist

Treat Logic Apps mapping scenarios as **portability-sensitive**:
- Prefer pure XSLT 1.0 unless the user clearly states a different runtime path.
- Warn that `msxsl:script` and BizTalk-specific features may not be portable to Logic Apps.
- Flag any dependency on local assemblies, debugger-only behavior, or host-specific extensions.
- When the user mentions Integration Account maps or Transform XML, keep recommendations focused on deployable map files and XML inputs/outputs.

Read [`references/logicapps-xslt.md`](references/logicapps-xslt.md) for Logic Apps deployment and portability notes.

### Saxon / SaxonCS compatibility checklist

Treat Saxon as feature-rich but engine-specific:
- Confirm whether the requested solution needs 2.0 or 3.0 features.
- Use standard XSLT/XPath functions before Saxon extensions unless the user explicitly wants Saxon-only code.
- Note when a stylesheet will no longer run on BizTalk or Logic Apps due to version or feature choice.
- `msxsl:script` is not supported in Saxon.

Read [`references/saxoncs-quirks.md`](references/saxoncs-quirks.md) for Saxon engine quirks and error codes.

---

## Migrate Mode

Only enter this mode when the user **explicitly requests** a version change.
Never suggest migration unprompted. Never auto-upgrade existing stylesheets.

Read [`references/migration.md`](references/migration.md) for full pattern mappings.

Summary of what to do:
- State clearly what features are gained and what are lost
- For downgrades (3.0 → 1.0): always list every feature being replaced and provide the workaround
- For upgrades: provide the modern equivalent side-by-side with the old pattern
- Preserve all logic; never silently drop functionality
- When migrating from BizTalk-safe 1.0 to Saxon 3.0, keep a note of which sections are now Saxon-only
- When migrating from Saxon 2.0/3.0 to BizTalk or Logic Apps portability, replace unsupported constructs with 1.0 patterns

---

## LML Mode

LML (Logic Apps Mapping Language) is the YAML-based source format of the Data Mapper visual
designer. It compiles to XSLT 3.0. Read [`references/lml.md`](references/lml.md) for the full
format reference, pseudofunction syntax, and compile/test API details.

**Key things to know:**
- LML is design-time only — the compiled `.xslt` is what runs and what you debug
- Always debug `Artifacts/Maps/<n>.xslt` (compiled output), not the `.lml` source
- The compiled XSLT uses `saxonnet` engine in the debugger
- Inline C# (`msxsl:script`) is not available in LML-generated maps — use Extensions instead

**When user asks to read/explain/edit an LML file:**
1. Read the LML format reference
2. Explain what the mappings do in plain language
3. If they want to test: point them at the compiled `.xslt` in `Artifacts/Maps/` + generate launch.json

**When user asks to write LML from scratch or from XML samples:**
1. **Generate XSD schemas first** if they don't exist — infer from the sample XML and write to `Artifacts/Schemas/`. Use `xs:string` for free-text dates, `xs:integer` for counts/IDs, `xs:decimal` for prices. No `targetNamespace` unless the sample XML uses one.
2. Determine source and target schema paths (just created or already present)
3. **Name the LML file with a `-lml` suffix** — e.g. `OrderToShipment-lml.lml` — so the Data Mapper compiles it to `OrderToShipment-lml.xslt` and never overwrites a hand-authored XSLT of the same base name.
4. Write LML YAML using the pseudofunction syntax from the reference
5. Note they need to save in Data Mapper (or call Generate XSLT API) to recompile to `.xslt`
6. Still produce a `launch.json` pointing at the compiled `<name>-lml.xslt` for debugging

**Choosing the right expression mechanism for complex logic in LML:**

Prefer mechanisms in this order: built-in first, then direct standard XPath, then custom
extension functions, then inline XSLT snippets, and `xpath()` last. The compiler handles
everything except `xpath()` more cleanly — it inlines simple functions and avoids the
`{...}` text value template wrapper that `xpath()` always produces.

| Priority | Mechanism | Use when | LML call |
|----------|-----------|----------|---------|
| 1st | Built-in pseudofunction | Multiplication, existence check, equality — compiler expands inline | `Total: multiply(Qty, Price)` · `$if(exists(Field))` |
| 2nd | Direct standard XPath call | Standard functions the compiler recognises without `xpath()` wrapper: `current-date()`, `count()`, `string()`, `normalize-space()`, `concat()` | `InvoiceDate: current-date()` · `Name: concat(First, Last)` |
| 3rd | Custom extension function | Any logic more complex than a direct field copy — date trimming, string building, conditional flags, aggregate sums. Define once in `DataMapper/Extensions/Functions/*.xml`, call by name everywhere. Compiler inlines simple ones; wraps complex ones as `ef:functionName()` | `ShipDate: dateOnly(OrderDate)` · `ShipId: shipId(OrderId)` · `Address: formatAddress(Street, PostalCode, City, CountryCode)` · `HazFlag: hazardousFlag(Items)` |
| 4th | Inline XSLT snippet | Structural output: multiple sibling elements or attributes from one source fragment — a scalar value function cannot do this | `ContactInfo: InlineXsltContact` |
| 5th (last resort) | `xpath("...")` | Truly one-off XPath 3.1 that is too narrow to reuse AND too simple to warrant a function file — e.g. a single `substring-before()` or `upper-case()` call used exactly once | `Priority: xpath("upper-case(@priority)")` |

**Decision rule:** if you are writing `xpath("concat(...)")`, `xpath("format-number(...)")`,
`xpath("tokenize(...)[last()]")`, or any multi-argument expression, write a custom extension
function instead. It is cleaner, debuggable by name in the compiled XSLT, and reusable
across maps without copy-pasting `xpath()` strings.

**Example — same logic, two styles:**

```yaml
# Avoid: raw xpath() strings scattered through the LML
ShipDate: xpath("substring-before(tns:OrderDate, 'T')")
$@shipId: xpath("concat('SHP-', tokenize(tns:OrderId, '-')[last()])")
DeliveryAddress: xpath("string-join((normalize-space(tns:Street), ...), ', ')")

# Prefer: named custom functions — readable, reusable, compiler-inlined
ShipDate: dateOnly(tns:OrderDate)
$@shipId: shipId(tns:OrderId)
DeliveryAddress: formatAddress(tns:Street, tns:PostalCode, tns:City, tns:Country/@code)
```

**Custom function file structure** (from `SampleFunctions.xml` / `CustomMathFunctions.xml`):
```xml
<?xml version="1.0" encoding="utf-8" ?>
<customfunctions>
  <!-- Single expression — inlined by compiler -->
  <function name="age" as="xs:float" description="Returns current age in years.">
    <param name="inputDate" as="xs:date"/>
    <value-of select="round(days-from-duration(current-date() - xs:date($inputDate)) div 365.25, 1)"/>
  </function>

  <!-- Conditional with choose/when/otherwise -->
  <function name="integer-min" as="xs:integer" description="Returns minimum of two integers.">
    <param name="number1" as="xs:integer"/>
    <param name="number2" as="xs:integer"/>
    <choose>
      <when test="$number1 le $number2"><value-of select="$number1"/></when>
      <otherwise><value-of select="$number2"/></otherwise>
    </choose>
  </function>

  <!-- Variables + nested conditionals + sequence (empty sequence for null) -->
  <function name="toUtcDateTime" as="xs:dateTime?" description="Parses date/datetime string to UTC.">
    <param name="inputDate" as="xs:string"/>
    <variable name="trim" select="normalize-space($inputDate)"/>
    <choose>
      <when test="$trim = ''"><sequence select="()"/></when>
      <otherwise>
        <variable name="norm" select="replace($trim, '\s+', 'T')"/>
        <variable name="dt">
          <choose>
            <when test="contains($norm,'T')"><sequence select="xs:dateTime($norm)"/></when>
            <otherwise><sequence select="xs:dateTime(concat($norm, 'T00:00:00'))"/></otherwise>
          </choose>
        </variable>
        <sequence select="adjust-dateTime-to-timezone($dt, xs:dayTimeDuration('PT0H'))"/>
      </otherwise>
    </choose>
  </function>
</customfunctions>
```

**Inline XSLT snippet** (from `InlineXsltContact.xml`) — use for multi-attribute structural output:
```xml
<ContactInfo xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
             xmlns:st="http://StudentEnrollment.Student">
  <xsl:attribute name="ContactType">
    <xsl:value-of select="/st:Student/Address/ContactType"/>
  </xsl:attribute>
  <xsl:attribute name="Contact">
    <xsl:value-of select="/st:Student/Address/Contact"/>
  </xsl:attribute>
</ContactInfo>
```

Never use `msxsl:script` in LML — it is not supported. Use `xpath()` or custom extension functions instead.

**When user has LML but wants hand-authored XSLT instead:**
- This is a valid and often better choice for complex maps
- Generate the XSLT 3.0 equivalent directly
- Note that abandoning LML means the Data Mapper visual designer can no longer edit the map

---

## Authoring Rules

### Always
- Match the version the user specified — do not silently change it
- Declare every namespace used in XPath at the stylesheet root
- `exclude-result-prefixes` for all non-output namespaces (msxsl, xs, fn, etc.)
- Prefer `xsl:apply-templates` over `xsl:for-each` where structure allows
- `xsl:output method="xml" indent="yes" encoding="UTF-8"`
- `xsl:strip-space elements="*"` unless layout matters
- Prefer the most portable solution that still satisfies the requested target

### Never
- Never auto-upgrade the XSLT version
- Never use 2.0 or 3.0 features in a 1.0 target
- Never use `disable-output-escaping` — fragile and engine-dependent
- Never leave namespace prefixes undeclared in XPath
- Never assume Saxon features are safe for BizTalk or Logic Apps

### Canonical 1.0 portable skeleton
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="/">
    <Output>
      <xsl:apply-templates/>
    </Output>
  </xsl:template>

</xsl:stylesheet>
```

### Canonical 3.0 skeleton
```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema"
  xmlns:fn="http://www.w3.org/2005/xpath-functions"
  exclude-result-prefixes="xs fn">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>
  <xsl:strip-space elements="*"/>

  <xsl:template match="@* | node()">
    <xsl:copy>
      <xsl:apply-templates select="@* | node()"/>
    </xsl:copy>
  </xsl:template>

</xsl:stylesheet>
```

---

## Output Bundle

For Generate mode, produce up to three artifacts (launch config, input XML, XSLT).
For LML mode, produce up to four artifacts (launch config, input XML, LML, then XSLT last).
For Debug, Migrate, and Compatibility modes, produce artifacts only when the user requests
files or when a fix requires code changes. Files go into the project's existing directories.

**Write order:**
- Generate: 3 → 2 → 1 (launch config, then input, then stylesheet last)
- LML: 3 → 2 → LML → 1 (launch config, then input, then `.lml`, then compiled `.xslt` last)

Writing the stylesheet last ensures the launch config is in place if a PostToolUse hook
fires on `.xslt` writes. In LML mode the hook compiles the `.lml` to `.xslt` automatically;
the transform does **not** auto-run after LML compile — the run hook only fires on files
Claude writes directly, not files written by the compile hook. To verify the output, read
the generated `.xslt` or run the transform manually via the debug config.

### 3. Launch configuration — append to existing `launch.json`

**Do NOT create a new `.vscode/launch.json`.** Read the existing one and append a new
configuration to the `configurations` array. If a configuration with the same `name`
already exists, update it in place.

**Engine selection:**
| XSLT version | engine |
|-------------|--------|
| 1.0 (plain or with msxsl:script C#) | `compiled` |
| 2.0 or 3.0 (Saxon) | `saxonnet` |
| Unknown / not specified | ask the user |

**Configuration template to append:**

For standalone projects (`compiled/` or `saxon/` directories):
```json
{
  "type": "xslt",
  "request": "launch",
  "name": "Debug <n>",
  "engine": "<engine>",
  "stylesheet": "${workspaceFolder}/<compiled|saxon>/<n>.xslt",
  "xml": "${workspaceFolder}/TestFiles/<n>-input.xml",
  "stopOnEntry": true,
  "debug": true,
  "logLevel": "log"
}
```

For LML / Logic Apps Data Mapper projects:
```json
{
  "type": "xslt",
  "request": "launch",
  "name": "Debug <n> (compiled from LML)",
  "engine": "saxonnet",
  "stylesheet": "${workspaceFolder}/Artifacts/Maps/<n>.xslt",
  "xml": "${workspaceFolder}/Artifacts/SampleData/<n>-input.xml",
  "stopOnEntry": true,
  "debug": true,
  "logLevel": "log"
}
```

Match the `stylesheet` and `xml` paths to the directory where each file was actually written.

**logLevel guide:**
- `"log"` — normal development
- `"trace"` — breakpoints, execution flow
- `"traceall"` — variables not showing or breakpoints not hitting (~15-20% overhead)
- `"none"` + `"debug": false` — pure performance run, no debugging

**Known debugger limitations (mention when relevant):**
- `xsl:apply-templates` dynamic matching: limited step-through
- Content-body variables (`<xsl:variable>...</xsl:variable>`): not yet shown in Variables pane
- C# inside `msxsl:script`: not steppable — Roslyn logs entry/return to Debug Console
- `xsl:message`: visible in Debug Console (saxonnet engine only)
- No step-back — forward-only debugging

### 2. `<n>-input.xml` — the test input

Write path depends on mode:
- **Generate mode** (standalone): `TestFiles/<n>-input.xml`
- **LML mode** (Data Mapper project): `Artifacts/SampleData/<n>-input.xml`

Use the user's sample input verbatim if provided. If not, generate a realistic skeleton
that exercises all templates.

### 1. `<n>.xslt` — the stylesheet (write last)

**Where to write:**

Determine the output directory by checking the task mode and workspace structure:

1. **LML mode** (always): `Artifacts/Maps/<n>.xslt` — LML-compiled maps always live here
   regardless of what other directories exist in the workspace.
2. **Non-LML, standalone debugger project** (workspace has `compiled/` and/or `saxon/`):
   - XSLT 1.0 → `compiled/<n>.xslt`
   - XSLT 2.0/3.0 → `saxon/<n>.xslt`
3. **Non-LML, Logic Apps Data Mapper project** (workspace has `Artifacts/MapDefinitions/`
   **and** `Artifacts/Maps/` — both must exist, no mere `Artifacts/` folder):
   - Any version → `Artifacts/Maps/<n>.xslt`
4. Otherwise, ask the user where to write the file.

Writing the stylesheet last ensures the launch config is in place if a PostToolUse hook
fires on save.

### After writing

Tell the user which files were created/updated and that they can press F5 to debug.
A PostToolUse hook may auto-run the transform — if it does, check the OUTPUT panel
for errors and fix if needed.

---

## Version Feature Matrix

| Feature | 1.0 | 1.0 + msxsl | 2.0 | 3.0 |
|---------|-----|------------|-----|-----|
| `xsl:for-each-group` | ✗ | ✗ | ✓ | ✓ |
| `xsl:function` | ✗ | ✗ | ✓ | ✓ |
| `xsl:try` / `xsl:catch` | ✗ | ✗ | ✗ | ✓ |
| `xsl:map` | ✗ | ✗ | ✗ | ✓ |
| `fn:json-to-xml()` | ✗ | ✗ | ✗ | ✓ |
| Inline C# via msxsl:script | ✗ | ✓ | ✗ | ✗ |
| Regex (`matches()`) | ✗ | via C# | ✓ | ✓ |
| Date formatting | ✗ | via C# | ✓ | ✓ |
| String padding / manipulation | ✗ | via C# | limited | ✓ |
| XPath version | 1.0 | 1.0 | 2.0 | 3.1 |
| Debugger engine | `compiled` | `compiled` | `saxonnet` | `saxonnet` |
| BizTalk portability | ✓ | often ✓ | ✗ | ✗ |
| Logic Apps portability | usually ✓ | caution | depends on runtime | depends on runtime |
| Saxon portability | limited | ✗ | ✓ | ✓ |

---

## Reference Files

- [`references/migration.md`](references/migration.md) — full pattern-by-pattern mappings for
  version migration; read only when user explicitly requests a version change
- [`references/saxoncs-quirks.md`](references/saxoncs-quirks.md) — Saxon/SaxonCS engine quirks,
  error codes; read when debugging Saxon-specific failures
- [`references/logicapps-xslt.md`](references/logicapps-xslt.md) — Logic Apps maps artifact,
  TransformXml action, deployment; read only when user mentions Logic Apps
- [`references/biztalk-xslt.md`](references/biztalk-xslt.md) — BizTalk-specific compatibility
  guidance, safe patterns, and portability labels; read when user mentions BizTalk or functoids
- [`references/lml.md`](references/lml.md) — LML format reference: pseudofunction syntax,
  project structure, compile/test API, LML vs hand-authored XSLT comparison; read for LML mode
