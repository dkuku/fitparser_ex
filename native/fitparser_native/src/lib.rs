use fitparser;
use rustler::{Atom, Binary, Env, Error as RustlerError, NifTuple, Term};
use std::collections::HashMap;
use std::fs::File;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[derive(NifTuple)]
struct ResponseJson {
    status: Atom,
    message: String,
}
#[derive(NifTuple)]
struct ResponseTerm<'a> {
    status: Atom,
    message: Term<'a>,
}

#[rustler::nif]
pub fn to_term<'a>(env: Env<'a>, bin: Binary<'a>) -> Result<ResponseTerm<'a>, RustlerError> {
    let data = match fitparser::from_bytes(&bin) {
        Ok(data) => convert_data(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    println!("{:#?}", data);
    return match serde_rustler::to_term(env, &data) {
        Ok(term) => Ok(ResponseTerm {
            status: atoms::ok(),
            message: term,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    };
}
#[rustler::nif]
pub fn read_to_term<'a>(env: Env<'a>, path: &str) -> Result<ResponseTerm<'a>, RustlerError> {
    // Open file and handle any errors
    let mut fp = match File::open(path) {
        Ok(file) => file,
        Err(_e) => return Err(RustlerError::Term(Box::new("Error opening file"))),
    };

    // Parse file data and handle any errors
    let data = match fitparser::from_reader(&mut fp) {
        Ok(data) => convert_data(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    return match serde_rustler::to_term(env, &data) {
        Ok(term) => Ok(ResponseTerm {
            status: atoms::ok(),
            message: term,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    };
}
#[rustler::nif]
pub fn to_json<'a>(bin: Binary<'a>) -> Result<ResponseJson, RustlerError> {
    let data = match fitparser::from_bytes(&bin) {
        Ok(data) => convert_data(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    return match serde_json::to_string(&data) {
        Ok(json) => Ok(ResponseJson {
            status: atoms::ok(),
            message: json,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    };
}

#[rustler::nif]
pub fn read_to_json(path: &str) -> Result<ResponseJson, RustlerError> {
    // Open file and handle any errors
    let mut fp = match File::open(path) {
        Ok(file) => file,
        Err(_e) => return Err(RustlerError::Term(Box::new("Error opening file"))),
    };

    // Parse file data and handle any errors
    let data = match fitparser::from_reader(&mut fp) {
        Ok(data) => convert_data(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    return match serde_json::to_string(&data) {
        Ok(json) => Ok(ResponseJson {
            status: atoms::ok(),
            message: json,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    };
}
fn convert_data(
    data: Vec<fitparser::FitDataRecord>,
) -> HashMap<fitparser::profile::MesgNum, Vec<HashMap<String, String>>> {
    let mut record: HashMap<fitparser::profile::MesgNum, Vec<HashMap<String, String>>> =
        HashMap::new();
    data.into_iter().for_each(|rec| {
        record
            .entry(rec.kind())
            // If there's no entry for the key, create a new Vec and return a mutable ref to it
            .or_default()
            // and insert the item onto the Vec
            .push(convert_fields(rec.fields().to_vec()))
    });
    return record;
}
fn convert_fields(data: Vec<fitparser::FitDataField>) -> HashMap<String, String> {
    let mut record: HashMap<String, String> = HashMap::new();
    data.into_iter().for_each(|field| {
        record.insert(field.name().to_string(), field.value().to_string());
    });
    return record;
}

rustler::init!(
    "Elixir.Fitparser.Native",
    [to_json, read_to_json, to_term, read_to_term]
);
