# BizTalk XSLT Notes

## Use this file when
- the user mentions BizTalk, maps, functoids, or `XslCompiledTransform`
- the user wants inline C# helper methods
- the user needs strict Microsoft XSLT 1.0 compatibility

## Safe baseline

For maximum BizTalk compatibility, use:
- XSLT 1.0
- XPath 1.0 only
- explicit namespace declarations
- deterministic templates and keys

## Microsoft-specific features

You may use `msxsl:script` when the user explicitly wants inline C# or when a 1.0-only runtime needs helper logic that would otherwise require unavailable 2.0/3.0 functions.

Good uses:
- date normalization
- string padding
- regular-expression helpers
- narrow conversion helpers

Avoid using script for logic that is easy to express directly in XSLT, because it reduces portability and complicates testing.

## Portability labels

When answering, label the result clearly as one of:
- **BizTalk-safe and portable**
- **BizTalk-safe but not Logic Apps portable**
- **Not BizTalk compatible**
