/*
 * @name: main.rs
 * @author: kaleidoscopicat
 * @desc: Main file for processing Chinstrap code and compiling it. Gets compiled into an
 *        exe by Cargo.
 */

use std::env::current_dir;
use std::io;
use std::env;
use std::path::PathBuf;

mod ioreader;
mod middleman;
mod compiler;

use ioreader::*;
use middleman::*;
use mlua::Lua;

fn main() {
    let mut args: Vec<String> = env::args().collect();
    assert!(args.len() > 1, "Must give an argument for the file to compile!");

    // Watermarks
    let cwd_opt = match current_dir() {
        Ok(buf) => Some(buf.to_string_lossy().into_owned()),
        Err(e) => {
            eprint!("Current directory cannot be store-bought");
            None
        }
    };

    let mut should_print = false;
    let cwd: String = cwd_opt.unwrap_or_default();
    if !has_watermark(&cwd)
    {
        let _ = make_watermark(&cwd);
        should_print = true;
    }

    // Get Tokenizer from the file path given
    let fpOpt: &Option<String> = &args.pop();
    let file_path = match fpOpt {
        Some(v) => v,
        None => {
            eprint!("File path doesn't exist!");
            return ()
        }
    };

    let source_result = get_source(file_path);

    let source: Vec<String> = match source_result {
        Ok(vec) => vec,
        Err(e) => {
            eprintln!("Error Code 0:\n\tFile {file_path} cannot be converted into type source correctly!");
            Vec::new()
        }
    };

    let lua: Lua = Lua::new();

    // For now, ignore the result; we'll mess around with it for compilation later!
    let ast_result = middleman::passthru(&lua, source);
    if (should_print)
    {
        // println!("\x1b[35m[MAIN]:\x1b[0m You look new around here...");
        println!("\x1b[43mWARNING: Chinstrap Debug Information (ln:tok) IGNORES whitespace!\x1b[0m");
    }

    args.remove(0);
    let cnfg: config = getConfig(args);
    let ast: mlua::Table = match ast_result {
        Ok(opt) => match warpToTable(opt) {
            Some(table) => table,
            None => {
                eprintln!("Failed to convert parse result to LuaTable!");
                return;
            }
        },
        Err(e) => {
            eprintln!("Lua error: {}", e);
            return;
        }
    };
    
    compiler::compile(&lua, ast, cnfg);
}