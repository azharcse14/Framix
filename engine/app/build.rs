//! Generates the Protobuf types: command/event (engine.proto) and the project file
//! (project.proto).

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let protos = [
        "../../proto/framix/v1/engine.proto",
        "../../proto/framix/project/v1/project.proto",
    ];
    for proto in protos {
        println!("cargo:rerun-if-changed={proto}");
    }
    let descriptors = protox::compile(protos, ["../../proto"])?;
    prost_build::Config::new().compile_fds(descriptors)?;
    Ok(())
}
