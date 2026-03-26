# Logic Apps Standard — XSLT Maps Reference

Deep reference for deploying and operating XSLT maps in Azure Logic Apps Standard.
Read this when in Logic Apps Mode or when the user asks about deployment, artifact structure, or workflow integration.

---

## Maps Artifact Structure

```
<LogicAppRoot>/
├── Artifacts/
│   ├── DataMapper/
│   │   └── Extensions/
│   │       ├── Functions/           # custom function XML files (*.xml)
│   │       └── InlineXslt/          # inline XSLT snippets
│   ├── MapDefinitions/              # Data Mapper source files (*.lml) — design-time only
│   │   ├── OrderToShipment.lml
│   │   └── ...
│   ├── Maps/                        # compiled/hand-authored XSLT (deployed to Azure)
│   │   ├── OrderToShipment.xslt
│   │   ├── InvoiceMap.xslt
│   │   └── out/                     # debugger output (local only, not deployed)
│   ├── Rules/
│   ├── SampleData/                  # test input XML for local debugging
│   │   ├── Order.xml
│   │   └── ...
│   └── Schemas/                     # XSD / JSON schemas for source and target
│       ├── OrderSchema.xsd
│       └── ...
├── <WorkflowName>/
│   └── workflow.json
├── connections.json
├── host.json
└── local.settings.json
```

- Only `Artifacts/Maps/` is deployed to Azure — `MapDefinitions/` is design-time source only
- Map files are plain `.xslt` files — no special wrapping required
- File name (including extension) is the map identifier used in workflow actions
- Case-sensitive on Linux (Azure) — use consistent casing between workflow.json and file name
- Data Mapper generates both a `.lml` (in `MapDefinitions/`) and a `.xslt` (in `Maps/`) when saved from VS Code

---

## TransformXml Action — Full Reference

### Basic usage
```json
{
  "type": "Xslt",
  "kind": "Xslt",
  "inputs": {
    "content": "@triggerBody()?['content']",
    "map": {
      "source": "LogicApp",
      "name": "OrderTransform.xslt"
    }
  },
  "runAfter": {}
}
```

### With parameters
```json
{
  "type": "Xslt",
  "inputs": {
    "content": "@body('Parse_XML')",
    "map": {
      "source": "LogicApp",
      "name": "OrderTransform.xslt"
    },
    "transformOptions": {
      "xsltParameters": {
        "Environment": "@appsetting('ENVIRONMENT')",
        "CorrelationId": "@triggerOutputs()?['headers']?['x-correlation-id']"
      }
    }
  }
}
```

### Accessing the output
- `@body('Transform_XML')` — raw string output
- `xml(@body('Transform_XML'))` — parsed as XML for subsequent XML actions
- `@body('Transform_XML')?['root']?['element']` — navigate if output is simple XML (limited)

### Input must be a string
The `content` field expects a string, not a parsed object. If your input comes from an HTTP trigger:
- `@triggerBody()` if Content-Type is `application/xml` (raw string)
- `@string(triggerBody())` if you need to coerce
- If it came through `Parse_XML` action, use `@body('Parse_XML')` which is already a string

---

## Local Development Setup

### Prerequisites
- Logic Apps Standard local runtime (`func` CLI + `Microsoft.Azure.WebJobs.Extensions.Workflow`)
- Azurite for storage emulation
- VS Code with Azure Logic Apps (Standard) extension

### Running locally
Maps in `Artifacts/Maps/` are picked up automatically by the local runtime. No restart needed
after editing a map file — the runtime reloads maps per-invocation.

### Testing a map locally
Option 1 — Run the workflow and check run history in VS Code:
1. Start local runtime (`F5` or `func start`)
2. Trigger the workflow (Postman, REST Client, etc.)
3. Open Run History in VS Code LA extension
4. Click the TransformXml action — view Inputs and Outputs

Option 2 — Test the map in isolation using the XSLT Debugger extension:
1. Open the `.xslt` file and input XML side by side
2. Set breakpoints, run debugger
3. Verify output matches expectation before triggering the full workflow

---

## Deployment

### Azure Portal / VS Code deploy
Maps are deployed as part of the Logic App package — no separate step.
`Artifacts/Maps/` folder contents are zipped and deployed alongside workflows.

### Azure CLI
```bash
az logicapp deployment source config-zip \
  --name <app-name> \
  --resource-group <rg> \
  --subscription <sub> \
  --src <path-to-zip>
```
The zip must include `Artifacts/Maps/` at the root level.

### Bicep / ARM
Maps do not require explicit ARM resources — they are part of the app content.
Reference in workflow definition just uses the map name:
```bicep
// No separate resource needed — maps deploy with the app package
```

### CI/CD pipeline (GitHub Actions example)
```yaml
- name: Zip Logic App contents
  run: zip -r logicapp.zip . -x "*.git*" "local.settings.json"

- name: Deploy to Azure
  uses: azure/functions-action@v1
  with:
    app-name: ${{ env.LOGIC_APP_NAME }}
    package: logicapp.zip
```

---

## Error Patterns in Production

### Map not found at runtime
**Symptom**: `TransformXml failed: Map 'MyTransform.xslt' was not found`
**Causes**:
- Map not in `Artifacts/Maps/` (wrong path)
- Map name casing mismatch (Linux is case-sensitive)
- Map not included in deployment zip

**Fix**: Verify file exists at `Artifacts/Maps/<name>.xslt` exactly as referenced.

### Input XML parsing failure
**Symptom**: `The input content is not a valid XML document`
**Causes**:
- Input is JSON, not XML
- Input has BOM
- Input has XML declaration with wrong encoding attribute
- Input is base64-encoded (common with Service Bus messages)

**Fix for Service Bus base64:**
```
@base64ToString(triggerBody()?['ContentData'])
```

### Empty output / wrong output
**Symptom**: Transform succeeds but output is `<?>` or empty
**Causes**:
- XPath doesn't match due to namespace issue (most common)
- Template priority conflict — wrong template firing
- `xsl:strip-space` stripping expected nodes

**Fix**: Add debug template first (see saxoncs-quirks.md §4), confirm what SaxonCS sees.

### Encoding corruption
**Symptom**: Special characters (accented, CJK, etc.) garbled in output
**Causes**:
- Downstream action treating UTF-8 string as latin-1
- `xml()` expression re-parsing without encoding context

**Fix**: Ensure `encoding="UTF-8"` in `xsl:output`; use `@body(...)` not `@string(@body(...))`.

---

## Integration Patterns

### Pattern: XML → XML transform (standard)
```
HTTP Trigger → TransformXml → HTTP Response
```

### Pattern: JSON → XML → transform → JSON
```
HTTP Trigger (JSON)
→ Compose (json-to-xml via expression or liquid)
→ TransformXml
→ Parse XML
→ Response
```

### Pattern: Service Bus message transform
```
Service Bus trigger (base64)
→ Compose: @base64ToString(triggerBody()?['ContentData'])
→ TransformXml (content: @outputs('Compose'))
→ Service Bus send (transformed)
```

### Pattern: Chained transforms
When one stylesheet is too complex, split into a pipeline:
```
TransformXml (map1.xslt) → TransformXml (map2.xslt) → ...
```
Each action's output feeds the next as `@body('Transform_XML_1')`.

### Pattern: Parameterised routing
Pass a routing key from the workflow into the stylesheet:
```json
"xsltParameters": {
  "TargetSystem": "@triggerBody()?['targetSystem']"
}
```
Stylesheet uses `<xsl:param name="TargetSystem"/>` and branches with `<xsl:choose>`.

---

## Data Mapper vs Hand-authored Maps

| Aspect | Data Mapper (visual) | Hand-authored XSLT |
|--------|---------------------|-------------------|
| Authoring | Drag-and-drop in VS Code | Direct XSLT editing |
| Generated file | `.xslt` (auto-generated) | `.xslt` (hand-written) |
| Runtime | Same SaxonCS engine | Same SaxonCS engine |
| Complexity ceiling | Medium (looping, conditions) | Unlimited |
| Debuggability | Limited | Full debugger support |
| Version control | Difficult (generated XML) | Clean diffs |
| Recommendation | Prototyping, simple maps | Production, complex logic |

Maps from both approaches live in `Artifacts/Maps/` and are invoked identically.
Do not mix: if you hand-author a map that was previously Data Mapper-generated, delete the
Data Mapper source (`.lml` file) to avoid confusion.
