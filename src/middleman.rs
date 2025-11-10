/*
 * @name: middleman.rs
 * @author: kaleidoscopicat
 * @desc: Acts as the middleman between Rust and Lua, communicating between them to pass
 *        data around the compiler properly.
 */

use crate::ioreader::*;
use mlua::prelude::*;
use mlua::{Table, Result as LuaResult};
use std::fs;
use std::path::PathBuf;

const RESET: &str = "\x1b[0m";
const CYAN: &str = "\x1b[36m";
const GREEN: &str = "\x1b[32m";
const YELLOW: &str = "\x1b[33m";
const MAGENTA: &str = "\x1b[35m";

/* !NOW OUTDATED! */
/* If you want modifiable parsers, use load_lua_files */
fn load_lua_files() -> (String, String) {
    let exe_path = std::env::current_exe().expect("Failed to get current exe path");
    let exe_dir = exe_path.parent().expect("Failed to get parent directory");

    let mut lexer_path = PathBuf::from(exe_dir);
    lexer_path.push("lua/tokenizer.lua");

    let mut parser_path = PathBuf::from(exe_dir);
    parser_path.push("lua/parser.lua");

    let lexer = fs::read_to_string(lexer_path).expect("Failed to read tokenizer.lua");
    let parser = fs::read_to_string(parser_path).expect("Failed to read parser.lua");

    return (lexer, parser);
}

fn print_boxed_header(file: &str) -> usize {
    let width = file.len() + 4;
    println!("╭─[{}]{}╮", file, "─".repeat(2));
    width
}

fn print_box_line(line: &str) {
    println!("│ {} │", line);
}

fn print_box_footer(success: bool, code: i32) {
    let color = if success { GREEN } else { "\x1b[31m" };
    println!("│ {}Finished with code {}{} │", color, code, RESET);
    println!("╰{}╯", "─".repeat(2));
}

fn print_node(node: &LuaValue, prefix: &str, is_last: bool) -> LuaResult<()> {
    let branch = if is_last { "╰─" } else { "├─" };
    let child_prefix = if is_last { "  " } else { "│ " };

    if let LuaValue::Table(table) = node {
        if let Ok(class) = table.get::<String>("class") {
            println!("{}{}{}{}{}", prefix, branch, CYAN, class, RESET);
        }

        if let Ok(contents) = table.get::<String>("contents") {
            println!("{}{}{}Contents: {}{}", prefix, child_prefix, GREEN, contents, RESET);
        }

        if let Ok(children) = table.get::<Table>("children") {
            let mut iter = children.sequence_values::<LuaValue>();
            let mut nodes = vec![];
            while let Some(child) = iter.next() {
                nodes.push(child?);
            }

            for (i, child) in nodes.iter().enumerate() {
                let last = i == nodes.len() - 1;
                let new_prefix = format!("{}{}", prefix, child_prefix);
                print_node(child, &new_prefix, last)?;
            }
        }
    } else {
        println!("{}{}{:?}", prefix, branch, node);
    }

    Ok(())
}

fn print_loaded(text: &str) {
    let text = format!(" Loaded {} ", text);
    let width = text.len();

    println!("{}╭{}╮{}", GREEN, "─".repeat(width), RESET);
    println!("{}│{}│{}", GREEN, text, RESET);
    println!("{}╰{}╯{}", GREEN, "─".repeat(width), RESET);
}

pub fn passthru(token_list: Vec<String>) -> LuaResult<()> {
    let lua = Lua::new();

    //let (lexer, parser) = load_lua_files();

    /* include_str!() means the lua code gets compiled with the .exe! */
    
    // modules
    let pretty = include_str!("../lua/pretty.lua");
    let m_globals = include_str!("../lua/globals.lua");

    // code
    let lexer = include_str!("../lua/tokenizer.lua");
    let parser = include_str!("../lua/parser.lua");

    // loaded modules
    let globals_mod: Table = match lua.load(m_globals).eval() {
        Ok(v) => v,
        Err(e) => {
            println!("globals error: {}", e);
            return Ok(());
        }
    };
    let pretty_mod: Table = match lua.load(pretty).eval() {
        Ok(v) => v,
        Err(e) => {
            println!("globals error: {}", e);
            return Ok(());
        }
    };


    // register modules
    lua.register_module("globals", globals_mod)?; // register globals first - pretty.lua uses them.
    lua.register_module("pretty", pretty_mod)?;


    // execute code
    lua.load(lexer).exec().expect("Failed to execute tokenizer.lua");
    print_loaded("tokenizer.lua");
    
    lua.load(parser).exec().expect("Failed to execute parser.lua");
    print_loaded("parser.lua");

    // setup function calls
    let globals = lua.globals();

    // call functions
    let retrieve_tokens: LuaFunction = globals.get("RetrieveTokens")?;
    let lua_tokens: LuaValue = retrieve_tokens.call((token_list,))?;

    let parse_tokens: LuaFunction = globals.get("ParseTokens")?;
    let parse_result: LuaValue = parse_tokens.call((lua_tokens,))?;

    // cool break
    println!("");

    // display AST
    if let LuaValue::Table(table) = parse_result {
        let mut iter: LuaTableSequence<'_, LuaValue> = table.sequence_values::<LuaValue>();
        let mut nodes: Vec<LuaValue> = vec![];
        while let Some(node) = iter.next() {
            nodes.push(node?);
        }

        for (i, node) in nodes.iter().enumerate() {
            let last = i == nodes.len() - 1;
            print_node(node, "", last)?;
        }
    }

    // i still hate this no-return method, but i'll probably maybe get used to it.
    Ok(())
}