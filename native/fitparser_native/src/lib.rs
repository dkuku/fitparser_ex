use derive_more::Deref;
use fitparser::{FitDataField as FitDataFieldOriginal, FitDataRecord as FitDataRecordOriginal};
use rustler::{serde::to_term, Atom, Binary, Env, Error as RustlerError, NifTuple, Term};
use serde::Serialize;
use std::collections::HashMap;
use std::fs::File;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

#[derive(NifTuple)]
struct ResponseTerm<'a> {
    status: Atom,
    message: Term<'a>,
}

#[derive(Serialize)]
#[serde(rename = "Elixir.Fitparser.FitDataField")]
#[derive(Deref)]
struct FitDataField {
    #[deref]
    value: fitparser::Value,
    name: String,
    number: u8,
    units: Option<String>,
}

impl FitDataField {
    fn new(fdf: &FitDataFieldOriginal) -> Self {
        FitDataField {
            value: fdf.value().clone(),
            name: fdf.name().to_string(),
            number: fdf.number(),
            units: if fdf.units().is_empty() {
                None
            } else {
                Some(fdf.units().to_string())
            },
        }
    }
}
#[derive(Serialize)]
#[serde(rename = "Elixir.Fitparser.FitDataRecord")]
struct FitDataRecord {
    kind: fitparser::profile::MesgNum,
    fields: Vec<FitDataField>,
}
impl FitDataRecord {
    fn new_from_fdr(fdr: FitDataRecordOriginal) -> Self {
        let fields = fdr.fields().into_iter().map(FitDataField::new).collect();
        FitDataRecord {
            kind: fdr.kind(),
            fields,
        }
    }
}

#[rustler::nif]
pub fn load_fit<'a>(env: Env<'a>, bin: Binary<'a>) -> Result<ResponseTerm<'a>, RustlerError> {
    let data = match fitparser::from_bytes(&bin) {
        Ok(data) => transpose_and_convert_records(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };

    convert_to_elixir_term(env, data)
}

#[rustler::nif]
pub fn from_fit<'a>(env: Env<'a>, path: &str) -> Result<ResponseTerm<'a>, RustlerError> {
    let mut fp = match File::open(path) {
        Ok(file) => file,
        Err(_e) => return Err(RustlerError::Term(Box::new("Error opening file"))),
    };

    let data = match fitparser::from_reader(&mut fp) {
        Ok(data) => transpose_and_convert_records(data),
        Err(_e) => return Err(RustlerError::Term(Box::new("Error parsing file"))),
    };
    convert_to_elixir_term(env, data)
}

fn convert_to_elixir_term<'a>(
    env: Env<'a>,
    data: HashMap<fitparser::profile::MesgNum, Vec<FitDataRecord>>,
) -> Result<ResponseTerm<'a>, RustlerError> {
    match to_term(env, &data) {
        Ok(term) => Ok(ResponseTerm {
            status: atoms::ok(),
            message: term,
        }),
        Err(_e) => Err(RustlerError::Term(Box::new("Error serialzing file"))),
    }
}
/*
fitparser returns an Vector of records For easier access we transform
this vector to a hashmap that keeps related records together This
function also changes the type from fitparser types to types controlled
by us
*/
fn transpose_and_convert_records(
    data: Vec<FitDataRecordOriginal>,
) -> HashMap<fitparser::profile::MesgNum, Vec<FitDataRecord>> {
    let mut record: HashMap<fitparser::profile::MesgNum, Vec<FitDataRecord>> = HashMap::new();
    data.into_iter().for_each(|fdr| {
        record
            .entry(fdr.kind())
            .or_default()
            .push(FitDataRecord::new_from_fdr(fdr))
    });
    return record;
}
rustler::init!("Elixir.Fitparser.Native");
