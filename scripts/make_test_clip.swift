// Writes tests/media/color_quadrants_h264_320x240_1s.mp4: 30 frames of four flat quadrants
// (red, green / blue, gray), H.264, BT.709 video range. Flat colors let decode tests compare
// pixels with a tolerance despite lossy coding.
// Usage: swift scripts/make_test_clip.swift <output.mp4>

import AVFoundation
import CoreVideo

let width = 320
let height = 240
let frames = 30
// BGRA per quadrant: top-left, top-right, bottom-left, bottom-right.
let quadrants: [[UInt8]] = [
  [0, 0, 255, 255],  // red
  [0, 255, 0, 255],  // green
  [255, 0, 0, 255],  // blue
  [128, 128, 128, 255],  // gray
]

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(Data("usage: make_test_clip.swift <output.mp4>\n".utf8))
  exit(2)
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.removeItem(at: url)

let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
let input = AVAssetWriterInput(
  mediaType: .video,
  outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoColorPropertiesKey: [
      AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
      AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
      AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ],
  ])
let attributes = CVPixelBufferCreationAttributes(
  pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
  size: CVImageSize(width: width, height: height))
let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
try writer.start()
writer.startSession(atSourceTime: .zero)

for index in 0..<frames {
  var buffer = try CVMutablePixelBuffer(attributes)
  buffer.accessUnsafeMutableRawPlaneBytes { planes in
    let stride = planes[0].properties.bytesPerRow
    let bytes = planes[0].bytes
    for y in 0..<height {
      for x in 0..<width {
        let color = quadrants[(y < height / 2 ? 0 : 2) + (x < width / 2 ? 0 : 1)]
        for c in 0..<4 { bytes[y * stride + x * 4 + c] = color[c] }
      }
    }
  }
  let frame = CVReadOnlyPixelBuffer(buffer)
  let time = CMTime(value: CMTimeValue(index), timescale: 30)
  while try !receiver.appendImmediately(frame, with: time) { usleep(1000) }
}
receiver.finish()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fatalError("finish: \(String(describing: writer.error))") }
