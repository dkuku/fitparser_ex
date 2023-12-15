use fitparser::FitDataRecord;
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
pub fn load_fit<'a>(env: Env<'a>, bin: Binary<'a>) -> Result<ResponseTerm<'a>, RustlerError> {
    let data = match fitparser::from_bytes(&bin) {
        Ok(data) => convert_records(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    convert_to_term(env, data)
}

#[rustler::nif]
pub fn from_fit<'a>(env: Env<'a>, path: &str) -> Result<ResponseTerm<'a>, RustlerError> {
    let mut fp = match File::open(path) {
        Ok(file) => file,
        Err(_e) => return Err(RustlerError::Term(Box::new("Error opening file"))),
    };

    let data = match fitparser::from_reader(&mut fp) {
        Ok(data) => convert_records(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };
    convert_to_term(env, data)
}

fn convert_to_term<'a>(
    env: Env<'a>,
    data: HashMap<fitparser::profile::MesgNum, Vec<FitDataRecord>>,
) -> Result<ResponseTerm<'a>, RustlerError> {
    match serde_rustler::to_term(env, &data) {
        Ok(term) => Ok(ResponseTerm {
            status: atoms::ok(),
            message: term,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    }
}
fn convert_records(
    data: Vec<FitDataRecord>,
) -> HashMap<fitparser::profile::MesgNum, Vec<FitDataRecord>> {
    let mut record: HashMap<fitparser::profile::MesgNum, Vec<FitDataRecord>> = HashMap::new();
    data.into_iter()
        .for_each(|rec| record.entry(rec.kind()).or_default().push(rec));
    return record;
}

rustler::init!("Elixir.Fitparser.Native", [load_fit, from_fit]);
