# SaxonCS Quirks in Logic Apps Standard

Reference for known SaxonCS 12.x behaviours specific to the Logic Apps Standard runtime.
Read this when debugging Logic Apps XSLT failures or authoring maps for production.

---

## Runtime Environment

- **Engine**: SaxonCS 12.4+ (C# port of Saxon-HE/PE)
- **XSLT version**: 3.0 supported; 1.0 and 2.0 stylesheets run in backwards-compat mode
- **XPath version**: 3.1
- **Invocation**: via `TransformXml` built-in action (not the managed connector)
- **Input/output**: always UTF-8 strings; no streaming from workflow engine side

---

## Known Quirks and Gotchas

### 1. No `document()` function
`document()` is disabled in the Logic Apps SaxonCS configuration. You cannot load external XML
files from within the transform. Workarounds:
- Pre-fetch external data in the workflow, pass as parameter
- Inline lookup data as `xsl:map` or key tables within the stylesheet itself
- Use multiple `TransformXml` actions chained via expressions

### 2. No extension functions (EXSLT, Saxon-specific)
- `exsl:node-set()` — not available (not needed in 2.0+)
- `saxon:evaluate()` — not available
- `saxon:parse()` — not available
- Use native XSLT 3.0 equivalents: `xsl:map`, `fn:parse-xml()`, `fn:parse-xml-fragment()`

### 3. `disable-output-escaping` is ignored
DOE is not supported in SaxonCS in Logic Apps. If upstream code relies on it:
- Use `xsl:character-map` instead for controlled character substitution
- Or post-process the string in the workflow using expressions

### 4. Namespace handling — the #1 source of bugs
Logic Apps XML inputs often come from HTTP triggers, Service Bus, or SAP with default namespaces.

**Problem pattern:**
```xml
<!-- Input XML -->
<Order xmlns="http://schemas.example.com/Orders">
  <OrderId>12345</OrderId>
</Order>
```
```xml
<!-- WRONG - XPath ignores default namespace, selects nothing -->
<xsl:template match="Order">
```
```xml
<!-- CORRECT - declare and use the namespace -->
<xsl:stylesheet ... xmlns:ord="http://schemas.example.com/Orders">
  <xsl:template match="ord:Order">
    <xsl:value-of select="ord:OrderId"/>
```

**Tip**: If you're not sure what namespace an input uses, add a debug template:
```xml
<xsl:template match="/">
  <debug>
    <ns><xsl:value-of select="namespace-uri(/*)"/></ns>
    <root><xsl:value-of select="local-name(/*)"/></root>
  </debug>
</xsl:template>
```

### 5. `xsl:message` behaviour
`xsl:message` output does not appear in Logic Apps run history. It is silently discarded.
- For debugging: use `xsl:result-document` to a named output (only works locally, not in LA runtime)
- In production: encode debug info into the output XML under a `<_debug>` element, strip later

### 6. `xsl:result-document` is not usable at runtime
Multiple output documents are not supported in the Logic Apps invocation. Only the principal
result tree is returned. `xsl:result-document` will throw at runtime.

### 7. Parameter passing from workflow
You can pass parameters from the workflow into the transform:

Workflow expression:
```json
{
  "type": "Xslt",
  "inputs": {
    "content": "@triggerBody()?['content']",
    "map": { "source": "LogicApp", "name": "MyTransform.xslt" },
    "transformOptions": {
      "xsltParameters": {
        "OrderType": "@triggerBody()?['orderType']"
      }
    }
  }
}
```

Stylesheet:
```xml
<xsl:param name="OrderType" as="xs:string" select="'STANDARD'"/>
```

Note: all parameter values arrive as strings — cast with `xs:integer()`, `xs:boolean()` etc. as needed.

### 8. Character encoding edge cases
- Input is decoded to Unicode before Saxon sees it — don't use `&#xNNN;` numeric references expecting raw bytes
- BOM in `.xslt` files can cause parse errors — save maps as UTF-8 without BOM
- The workflow expression `@body('Transform_XML')` returns the transformed XML as a string;
  use `xml(@body('Transform_XML'))` to parse it back for subsequent XML-aware actions

### 9. XSLT 1.0 backwards compatibility mode
Stylesheets declaring `version="1.0"` run in backwards-compat mode under SaxonCS. This means:
- Most 1.0 stylesheets work, but result tree fragments behave differently
- Type errors are downgraded to warnings
- `xsl:for-each-group`, `xsl:function`, etc. are still not available (they're version-controlled)
- **Recommendation**: declare `version="3.0"` and use `xsl:use-when` for conditional features if needed

### 10. Large document performance
- SaxonCS in Logic Apps is not streaming by default — the whole document is loaded into memory
- For documents > ~10MB, consider chunking in the workflow before transformation
- `xsl:stream` / `xsl:iterate` streaming mode is available in XSLT 3.0 but requires stylesheet
  to be written in streaming style throughout — you can't partially stream

---

## Common Error Messages and Fixes

| Error | Likely cause | Fix |
|-------|-------------|-----|
| `XPDY0002: The context item is absent` | Template called without context node | Check `match` pattern, ensure node exists |
| `XTTE0570: Required item type ... is xs:string; supplied value is ...` | Type mismatch on param or variable | Cast explicitly: `xs:string(...)` |
| `XPST0081: No namespace for prefix "ns0"` | Namespace prefix used but not declared | Add `xmlns:ns0="..."` to `xsl:stylesheet` |
| `SXCH0003: Destination for xsl:result-document unavailable` | Using `xsl:result-document` at LA runtime | Remove; use single output only |
| `TransformXml: Map not found` | Wrong map name or artifact not deployed | Check `Artifacts/Maps/` path, redeploy |
| `TransformXml: The input content is not valid XML` | Input is not well-formed, or has BOM | Validate input; strip BOM in workflow |
| `FODT0001: Invalid date/time` | `xs:date(...)` on non-ISO string | Normalise date string format first |

---

## Debugger Extension Integration

When using the **XSLT Debugger** VS Code extension (danieljonathan.xsltdebugger-windows):

- Set breakpoints on `xsl:template` start tags to inspect context node
- Watch `xsl:variable` bindings in the Variables panel
- The extension runs against local Saxon — same engine as Logic Apps, so results should match
- Use `xsl:message terminate="no"` locally for trace output (appears in Debug Console); strip before deploying to LA
- Test with the same input XML you'd send to the TransformXml action — copy from LA run history

**Recommended local test workflow:**
1. Copy input XML from a failed LA run (available in run history, Inputs of TransformXml action)
2. Open in VS Code with `.xslt` file
3. Set breakpoint at the template you suspect
4. Run debugger — inspect context, verify XPath expressions in Watch panel
5. Fix, verify output, deploy map back to `Artifacts/Maps/`
