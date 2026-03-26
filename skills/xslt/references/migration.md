# XSLT Version Migration — Pattern Reference

Only used when the user **explicitly requests** a version change. Never suggest migration unprompted.

## Core rule

Preserve behavior first. Do not silently modernize logic beyond what the user asked for.

---

## 1.0 → 3.0 Common Patterns

| Old (1.0) | New (3.0) | Notes |
|-----------|-----------|-------|
| `exsl:node-set($rtf)` | Just use `$var` directly | Sequences are native in 2.0+ |
| Named template as function | `xsl:function` | Cleaner, typed |
| Muenchian grouping | `xsl:for-each-group group-by="..."` | Far simpler |
| `concat(a, ' ', b)` | `string-join((a, b), ' ')` | Or keep concat, both work |
| `translate()` for case | `upper-case()` / `lower-case()` | XPath 2.0+ |
| Regex via msxsl:script | `matches()`, `replace()`, `tokenize()` | XPath 2.0+ |
| Date via msxsl:script | `format-date()`, `xs:date()` | XPath 2.0+ |
| `xsl:variable` RTF workaround | `xsl:variable as="xs:string"` etc. | Typed sequences |
| No error handling | `xsl:try` / `xsl:catch` | 3.0 only |

### Upgrade checklist

1. Remove Microsoft-specific extension dependencies unless explicitly required.
2. Replace result-tree-fragment workarounds with normal variables and sequences.
3. Replace grouping hacks with `xsl:for-each-group` when it materially improves clarity.
4. Keep namespaces and output structure identical unless the user requests cleanup.

### Muenchian grouping → xsl:for-each-group

**1.0 (Muenchian):**
```xml
<xsl:key name="by-category" match="Item" use="Category"/>
<xsl:for-each select="Items/Item[generate-id() = generate-id(key('by-category', Category)[1])]">
  <Group name="{Category}">
    <xsl:for-each select="key('by-category', Category)">
      <xsl:copy-of select="."/>
    </xsl:for-each>
  </Group>
</xsl:for-each>
```

**3.0:**
```xml
<xsl:for-each-group select="Items/Item" group-by="Category">
  <Group name="{current-grouping-key()}">
    <xsl:apply-templates select="current-group()"/>
  </Group>
</xsl:for-each-group>
```

---

## 1.0 → 1.0 with msxsl:script

When adding C# to an existing 1.0 stylesheet:
1. Add `xmlns:msxsl="urn:schemas-microsoft-com:xslt"` and your script prefix to `xsl:stylesheet`
2. Add `exclude-result-prefixes="msxsl myprefix"`
3. Add `<msxsl:script>` block before any templates
4. Replace XPath workarounds with C# method calls

---

## 3.0 → 1.0 Downgrade (flag every loss)

Always state explicitly what is being replaced and why the workaround is limited.

| Lost feature | 1.0 workaround | Limitation |
|-------------|---------------|------------|
| `xsl:function` | Named template | Can't return typed values, no recursion shorthand |
| `xsl:for-each-group` | Muenchian grouping | Verbose, only one grouping key |
| `upper-case()` | `translate()` with full alphabet | Doesn't handle non-ASCII |
| `matches()` | `contains()` / `starts-with()` | No regex — use msxsl:script if available |
| `xsl:try/catch` | Conditional checks | Can't catch runtime errors |
| `string-join()` | Recursive named template | Verbose |
| Typed sequences | Result tree fragments + exsl:node-set | Requires EXSLT or msxsl |
| `xsl:map` | `xsl:key` lookup tables | More limited |

---

## 2.0 → 3.0 Additions (small delta)

- `xsl:try` / `xsl:catch`
- `xsl:map` / `xsl:map-entry` / `map:get()` etc.
- `xsl:accumulator` for stateful processing
- `fn:json-to-xml()` / `fn:xml-to-json()`
- `xsl:on-empty` / `xsl:on-non-empty`
- Arrow operator `=>`
- `xsl:stream` / `xsl:iterate` for streaming large documents
- Shadow attributes for AVTs on any element

---

## Runtime Migration Guidance

### BizTalk or Logic Apps safe target

Prefer:
- pure XSLT 1.0
- no host-specific scripts unless explicitly approved
- simple XPath 1.0 expressions
- explicit namespace declarations

Avoid:
- Saxon-only constructs
- 2.0/3.0 functions
- assumptions about extension assemblies

### Saxon target

Prefer:
- standard XSLT 2.0/3.0 constructs
- `xsl:function` instead of script code
- grouping and regex functions when they simplify the transform

Avoid:
- `msxsl:script`
- BizTalk host assumptions
