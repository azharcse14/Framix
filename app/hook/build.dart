import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

/// Builds engine/ffi and bundles it as the `package:framix/engine` code asset.
void main(List<String> args) async {
  await build(args, (input, output) async {
    await const RustBuilder(
      assetName: 'engine',
      cratePath: '../engine/ffi',
    ).run(input: input, output: output);
  });
}
