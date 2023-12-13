use fitparser;
use std::fs::File;


#[rustler::nif]
fn read(path: &str) -> String {
    // Open file and handle any errors
    let mut fp = File::open(path).expect("Failed to open file");

    // Parse file data and handle any errors
    let data = fitparser::from_reader(&mut fp).expect("Failed to parse file data");

    // Convert data to JSON string and handle any errors
    let json = serde_json::to_string(&data).expect("Failed to convert data to JSON");

    // Return JSON string
    return json;
}

rustler::init!("Elixir.Fitparser.Native", [read]);
