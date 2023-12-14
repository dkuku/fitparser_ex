use fitparser;
use rustler::{Atom, Error as RustlerError, NifTuple};
use std::fs::File;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[derive(NifTuple)]
struct Response {
    status: Atom,
    message: String,
}

#[rustler::nif]
pub fn to_json(path: &str) -> Result<Response, RustlerError> {
    // Open file and handle any errors
    let mut fp = match File::open(path) {
        Ok(file) => file,
        Err(_e) => return Err(RustlerError::Term(Box::new("Error opening file"))),
    };

    // Parse file data and handle any errors
    let data = match fitparser::from_reader(&mut fp) {
        Ok(data) => data,
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    return match serde_json::to_string(&data) {
        Ok(json) => Ok(Response {
            status: atoms::ok(),
            message: json,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    };
}

rustler::init!("Elixir.Fitparser.Native", [to_json]);
