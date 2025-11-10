/*
 * @name: ioreader.rs
 * @author: kaleidoscopicat
 * @desc: Helper function(s) for reading Chinstrap code.
 */

use std::fmt::Error;
use std::io::{self, BufReader};
use std::io::prelude::*;
use std::fs::File;
use std::path::Path;

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