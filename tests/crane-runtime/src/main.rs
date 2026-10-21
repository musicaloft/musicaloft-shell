use std::process::ExitCode;

fn main() -> ExitCode {
    match crane_runtime::zlib_version() {
        Ok(version) => {
            println!("{}", crane_runtime::describe(&version));
            ExitCode::SUCCESS
        }
        Err(error) => {
            eprintln!("{error}");
            ExitCode::FAILURE
        }
    }
}
