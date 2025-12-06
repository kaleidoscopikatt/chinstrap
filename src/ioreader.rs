/*
 * @name: ioreader.rs
 * @author: kaleidoscopicat
 * @desc: Helper function(s) for reading Chinstrap code.
 */

use std::clone;
use std::fmt::Error;
use std::io::{self, BufReader};
use std::io::prelude::*;
use std::fs::File;
use std::path::Path;

#[derive(Clone)]
pub struct Config {
    pub file_name: String,
    pub file_stem: String,
    pub is_open_gl: bool,
    pub is_loud: bool,
    pub other_flags: Vec<String>,
}

impl Config {
    pub fn empty() -> Config {
        return Config {
            file_name: String::from(""),
            file_stem: String::from(""),
            is_open_gl: false,
            is_loud: false,
            other_flags: vec![]
        }
    }
}

pub fn get_config(args: Vec<String>, file_path: &String) -> Config {
    let mut is_open_gl = false;
    let mut is_loud = false;
    let mut other_flags: Vec<String> = vec![];

    for mut arg in args {
        arg = arg.to_lowercase();
        if arg == String::from("-opengl") || arg == String::from("-glsl") {
            is_open_gl = true;
            continue;
        }

        if arg == String::from("-l") || arg == String::from("-loud") {
            is_loud = true;
            continue;
        }

        if arg.starts_with("-") {
            other_flags.push(arg);
        }
    }

    let path = Path::new(file_path);
    let file_name = match path.file_name()
        .and_then(|n| n.to_str())
        .map(|s| s.to_string()) {
            Some(v) => v,
            None => {
                eprint!("Cannot convert file path to filename!");
                return Config::empty();
            }
        };

    let file_stem = match path.file_stem()
        .and_then(|n| n.to_str())
        .map(|s| s.to_string()) {
            Some(v) => v,
            None => {
                eprint!("Cannot convert file path to filestem!");
                return Config::empty()
            }
        };

    Config {
        file_name: file_name,
        file_stem: file_stem,
        is_open_gl: is_open_gl,
        is_loud: is_loud,
        other_flags: other_flags
    }
}

pub fn get_source(file_path: &String) -> io::Result<Vec<String>>
{
    let file = File::open(file_path)?;
    let reader = BufReader::new(file);
    
    let mut lines = Vec::new();

    for line in reader.lines() {
        lines.push(line?);
    }
    
    return Ok(lines);
}

pub fn has_watermark(root: &String) -> bool
{
    let path = (root.clone() + "\\watermark.txt");
    let file = Path::new(&path);
    file.exists()
}


pub fn make_watermark(root: &String) -> io::Result<()>
{
    let path = (root.clone() + "\\watermark.txt");
    let expect_msg = ("Cannot create file at path ").to_owned() + &path;

    let mut file = File::create(path).expect(&expect_msg);
    file.write_all(b"This is just here to show this project has been ran before to stop displaying first-time warnings. The content of this file is pretty much useless.")?;

    Ok(())
}