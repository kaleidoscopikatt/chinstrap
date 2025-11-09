<img width="830" height="218" alt="chinstrap banner" src="https://github.com/user-attachments/assets/352fd069-f16d-47ba-a240-e8da821b40ae" />

---
Chinstrap is a lightweight, human-readable shader language designed specifically for direct integration with Unity and a C#/Rust-friendly syntax. It is purpose-built for ease of use and maintainability, without the verbosity of traditional HLSL, which it compiles directly into. The compiler for Chinstrap is written in Rust, with Lua acting as the parser.

## Features
* **Friendly syntax**: Type non-specific function & variable declarations (fn), readable indenting (moving away from HLSL boilerplate), Unity-like types (`Vector3`/`float3`, `Vector4`/`float4`/`Color`, `Array`/`RWStructuredBuffer<T>`).
* **Logical backwards** compatability with HLSL, whilst having more readable methods alongside it. (e.g. `Vector3` and `float3` both get compiled into a `float3`)
* **Lightweight compiler**: The compiler is designed to be fast and minimal, parsing .csp files efficiently with a Lua-based parser, making it suitable for iterative development and quick testing.
* **VSCode support**: A dedicated extension provides syntax highlighting, snippets for syntax (fn, @uniform, @property, tables), and integrated in-editor compilation.
  
## Example
```
@property("MainTex", 2D); $ Single-property declaration
@uniform(Props); $ Multi-property declaration

Props = {
    MainTex_sampler: SamplerState,
    Tint: Color = Color(1.0, 1.0, 1.0, 1.0),
    LightDir: Vector3 = Vector3(0.0, 0.0, 1.0),
}

myVariable = "Hello, World!";

fn frag(Vector2 uv) {
    final = sample(uv.x, uv.y);
    return final;
};
```

## TODO

**Current Task:** Compilation - _Generic Denotions_<br>
**Description:** Making sure that things such as `n = "hi"`, `n:append()` could work the same as `"hi":append()` - making `"hi"` and `n` be identified the same in compilation.

**‣ May possibly extend out into Compilation - _Expressions_**

| **Task** | **Completed** |
| :------- | :-----------: |
| **Lexer** | ✅ |
| _Single-token_ Parsing | ✅ |
| _Lookahead(1)_ Parsing | ✅ |
| Compilation - _Generic Denotions_ | ❌ |
| Compilation - _Expressions_ | ❌ |
| Compilation - _Assign_ | ❌ |
| Compilation - _Arrays_ | ❌ |
| Compilation - _Non-specific Types_ | ❌ |
| **Compiles fully into HLSL** | ❌ |
| **Tests** | ❌ |
| Compilation for Compute Shaders | ❌ |
| **Full Release** | ❌ |

## Error List

| **Error Code** | Meaning |
| :------------: | :------ |
| E000 |  Unknown Error |
| E001 |  Unexpected Token |
| E002 |  Unexpected EOF |
| E003 |  Invalid Character |
| E004 |  Invalid Identifier |
| E005 |  Invalid Literal |
| E006 |  Invalid Type |
| E007 |  Type Mismatch |
| E008 |  Missing Semicolon |
| E009 |  Missing Colon |
| E010 |  Missing Comma |
| E011 |  Missing BraceOpen |
| E012 |  Missing BraceClose |
| E013 |  Missing ParenOpen |
| E014 |  Missing ParenClose |
| E015 |  Missing BracketOpen |
| E016 |  Missing BracketClose |
| E017 |  Duplicate Definition |
| E018 |  Undefined Symbol |
| E019 |  Undefined Property |
| E020 |  Undefined Uniform |
| E021 |  Invalid Decorator |
| E022 |  Invalid Assignment |
| E023 |  Illegal Operation |
| E024 |  Out Of Range |
| E025 |  Not Callable |
| E026 |  Not Indexable |
| E027 |  Not Assignable |
| E028 |  Unexpected Keyword |
| E029 |  Forbidden Keyword |
| E030 |  Invalid Function Call |
| E031 |  Wrong Parameter Count |
| E032 |  Wrong Parameter Type |
| E033 |  Invalid TableSyntax |
| E034 |  Invalid PropertySyntax |
| E035 |  Invalid UniformSyntax |
| E036 |  Missing Return |
| E037 |  Invalid Return Type |
| E038 |  Internal Compiler Error |
| E039 |  IO Failure |
| E040 |  Preprocess Failure |