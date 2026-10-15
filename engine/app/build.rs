//! Generates the Protobuf command/event types from proto/framix/v1/engine.proto.

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let proto = "../../proto/framix/v1/engine.proto";
    println!("cargo:rerun-if-changed={proto}");
    let descriptors = protox::compile([proto], ["../../proto"])?;
    prost_build::Config::new().compile_fds(descriptors)?;
    Ok(())
}
