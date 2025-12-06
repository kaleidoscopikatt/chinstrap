use mlua::{self, BorrowedStr, FromLua, Lua, String, Table, TableSequence, Value};
use std::{alloc::alloc, arch::x86_64::_CMP_FALSE_OQ, fs::File, io::{self, Write}, ptr::null};

use crate::ioreader::Config;

const ASSIGN_CLASS: &str = "Assign";

pub struct FileStream<'a> {
    pub file: &'a mut File,
    indent: usize
}

impl <'a> FileStream<'a> {
    pub fn write_line(&mut self, line: &str) -> bool {
        let curr_line = ("    ").repeat(self.indent) + line + "\n";
        self.file.write_all(curr_line.as_bytes()).unwrap();
        true
    }

    pub fn push_indent(&mut self) {
        self.indent += 1;
    }

    pub fn pull_indent(&mut self) {
        self.indent -= 1;
    }

    pub fn base_declaration(&mut self, title: &str) {
        self.write_line(title);
        self.write_line("{");
        self.push_indent();
    }

    pub fn close_bracket(&mut self) {
        self.pull_indent();
        self.write_line("}");
    }

    pub fn empty_line(&mut self) {
        self.write_line("");
    }

    pub fn build_boilerplate(&mut self, cnfg: &Config) {
        if !cnfg.is_open_gl {
            self.base_declaration(("Shader \"Unlit/".to_owned() + cnfg.file_stem.as_str() + "\"").as_str());
            self.base_declaration("Properties");
            self.empty_line();
            self.close_bracket();
            self.empty_line();
            self.base_declaration("SubShader");
            self.base_declaration("Pass");
            self.write_line("HLSLPROGRAM");
            self.write_line("#pragma vertex vert");
            self.write_line("#pragma fragment frag");
            self.write_line("#include \"UnityCG.cginc\"");
            self.empty_line();
            self.base_declaration("float4 vert(float4 vertex : POSITION) : SV_POSITION");
            self.write_line("return mul(UNITY_MATRIX_MVP, vertex);");
            self.close_bracket();
            self.base_declaration("fixed4 frag () : SV_Target");
            self.write_line("return _Color;");
            self.close_bracket();
            self.write_line("ENDHLSL");
            self.close_bracket();
            self.close_bracket();
            self.close_bracket();
        }
    }
}

fn assign_comp(stream: &mut FileStream, obj: Table, is_open_gl: bool) -> Option<Vec<String>> {
    if !is_open_gl {
        // TODO: implement
        println!("Assign Node -> NOT OpenGL");
    }

    None
}

fn breakdown(stream: &mut FileStream, lua: &Lua, cnfg: &Config, table: Table) -> bool {
    let class: String = match table.get("class") {
        Ok(v) => v,
        Err(e) => {
            eprintln!("Cannot cast <class> to LuaString! {:?}", e);
            return false;
        }
    };

    match class.to_string_lossy() {
        class_str => {
            if (class_str == ASSIGN_CLASS.to_string()) {
                let is_assign = assign_comp(stream, table, cnfg.is_open_gl);

                return (is_assign.is_some())
            }
        }
    }

    false
}

pub fn compile(cwd: &str, lua: &Lua, ast_result: Table, cnfg: &Config) -> i32 {
    let file_ext = if cnfg.is_open_gl { ".shader" } else { ".shader" };

    let file_path = cnfg.file_stem.clone() + file_ext;
    let mut file = File::create(file_path).expect("Cannot create compiled file!");
    let mut iter: TableSequence<'_, Value> = ast_result.sequence_values::<Value>();

    let mut stream = FileStream {
        file: &mut file,
        indent: 0
    };

    while let Some(Ok(node)) = iter.next() {
        if let Value::Table(table) = node {
            breakdown(&mut stream, lua, &cnfg, table);
        }
    }

    // This function will jam in properties and such AFTER they've been read...
    // More complex stuff can also happen after, but this makes life way easier.
    stream.build_boilerplate(&cnfg);

    -1
}