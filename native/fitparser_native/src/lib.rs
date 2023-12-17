use fitparser::{FitDataField as FitDataFieldOriginal, FitDataRecord as FitDataRecordOriginal};
use rustler::{Atom, Binary, Env, Error as RustlerError, NifTuple, Term};
use serde::Serialize;
use std::collections::HashMap;
use std::fs::File;
use std::ops::Deref;

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
#[serde(rename = "Elixir.Fitparser.FitDataFieldOriginal")]
struct FitDataField(FitDataFieldOriginal);
impl Deref for FitDataField {
    type Target = FitDataFieldOriginal;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl FitDataField {
    fn new(fdf: &FitDataFieldOriginal) -> Self {
        FitDataField(fdf.clone())
    }
}
#[derive(Serialize)]
#[serde(rename = "Elixir.Fitparser.FitDataRecordOriginal")]
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

rustler::init!("Elixir.Fitparser.Native", [load_fit, from_fit]);
// 3. The use of lifetimes in the `load_fit` and `from_fit` functions is unnecessary and can be removed.
// 4. The `ResponseTerm` struct could be renamed to something more descriptive, as it is not just a response but also contains the status and message.
// 5. The `FitDataField` and `FitDataRecord` structs could be renamed to something more descriptive as well.
// 6. The `convert_records` function could be simplified by using the `entry` API instead of manually checking for the existence of a key.
// 7. It would be helpful to have some error handling in the `convert_records` function in case the `FitDataRecordOriginal` cannot be converted to a `FitDataRecord`.
// 8. The `convert_to_term` function could be simplified by using the `serde_rustler::to_term` function directly instead of manually checking for errors.
// 9. It would be helpful to have some unit tests to ensure the code is functioning as expected.
// 10. Overall, the code looks good and follows Rust best practices. Keep up the good work!
