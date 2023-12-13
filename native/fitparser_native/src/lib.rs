use fitparser;
use std::fs::File;

#[rustler::nif]
fn read(path: &str) -> Option<String> {
    // Open file and handle any errors
    let mut fp = match File::open(path) {
        Ok(file) => file,
        Err(e) => {
            println!("Error opening file: {}", e);
            return None;
        }
    };

    // Parse file data and handle any errors
    let data = match fitparser::from_reader(&mut fp) {
        Ok(data) => data,
        Err(e) => {
            println!("Error parsing file data: {}", e);
            return None;
        }
    };

    // Convert data to JSON string and handle any errors
    let json = match serde_json::to_string(&data) {
        Ok(json) => json,
        Err(e) => {
            println!("Error converting data to JSON: {}", e);
            return None;
        }
    };

    // Return JSON string
    return Some(json);
}

rustler::init!("Elixir.Fitparser.Native", [read]);
