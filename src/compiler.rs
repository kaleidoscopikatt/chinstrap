use mlua::{self, FromLua, Lua, Table, TableSequence, Value};
use std::io;

use crate::ioreader::config;

fn assign_comp(obj: Table, isOpenGL: bool) -> bool {
    if !isOpenGL {
        // TODO: implement
    }

    false
}

fn breakdown(table: Table) {
    // run assign_comp later... icba rn
}

pub fn compile(lua: &Lua, ast_result: Table, cnfg: config) -> i32 {
    let mut iter: TableSequence<'_, Value> = ast_result.sequence_values::<Value>();
    while let Some(Ok(node)) = iter.next() {
        if let Value::Table(table) = node {
            breakdown(table);
        }
    }

    -1
}