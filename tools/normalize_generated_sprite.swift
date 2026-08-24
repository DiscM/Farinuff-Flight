import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 3 else {
    fputs("usage: normalize_generated_sprite <input.png> <output-strip.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let logicalCell = 128
let frameCount = 4

func loadImage(_ url: URL) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fatalError("Could not read \(url.path)")
    }
    return image
}

func makeRGBAContext(width: Int, height: Int, data: UnsafeMutableRawPointer?) -> CGContext {
    guard let context = CGContext(
        data: data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        fatalError("Could not create RGBA context")
    }
    return context
}

func imageFromRGBA(_ pixels: [UInt8], width: Int, height: Int) -> CGImage {
    let data = Data(pixels) as CFData
    guard let provider = CGDataProvider(data: data),
          let image = CGImage(
              width: width,
              height: height,
              bitsPerComponent: 8,
              bitsPerPixel: 32,
              bytesPerRow: width * 4,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
              provider: provider,
              decode: nil,
              shouldInterpolate: false,
              intent: .defaultIntent
          ) else {
        fatalError("Could not create image from RGBA data")
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create PNG destination")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write PNG to \(url.path)")
    }
}

let source = loadImage(inputURL)
let sourceWidth = source.width
let sourceHeight = source.height
var pixels = [UInt8](repeating: 0, count: sourceWidth * sourceHeight * 4)
let sourceContext = makeRGBAContext(width: sourceWidth, height: sourceHeight, data: &pixels)
sourceContext.interpolationQuality = .none
sourceContext.draw(source, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))

// Image generation often represents transparency with a light checkerboard.
// Remove only high-value near-achromatic pixels connected to the canvas edge,
// which keeps the light hull planes protected behind their dark silhouette rim.
func isCheckerboardCandidate(_ pixel: Int) -> Bool {
    let offset = pixel * 4
    let r = Int(pixels[offset])
    let g = Int(pixels[offset + 1])
    let b = Int(pixels[offset + 2])
    let maximum = max(r, max(g, b))
    let minimum = min(r, min(g, b))
    return maximum - minimum <= 18 && minimum >= 220
}

var background = [UInt8](repeating: 0, count: sourceWidth * sourceHeight)
var queue: [Int] = []
queue.reserveCapacity(sourceWidth * 2 + sourceHeight * 2)

func seed(_ pixel: Int) {
    guard background[pixel] == 0, isCheckerboardCandidate(pixel) else { return }
    background[pixel] = 1
    queue.append(pixel)
}

for x in 0..<sourceWidth {
    seed(x)
    seed((sourceHeight - 1) * sourceWidth + x)
}
for y in 0..<sourceHeight {
    seed(y * sourceWidth)
    seed(y * sourceWidth + sourceWidth - 1)
}

var head = 0
while head < queue.count {
    let pixel = queue[head]
    head += 1
    let x = pixel % sourceWidth
    let y = pixel / sourceWidth
    if x > 0 { seed(pixel - 1) }
    if x + 1 < sourceWidth { seed(pixel + 1) }
    if y > 0 { seed(pixel - sourceWidth) }
    if y + 1 < sourceHeight { seed(pixel + sourceWidth) }
}

for pixel in 0..<(sourceWidth * sourceHeight) where background[pixel] == 1 {
    let offset = pixel * 4
    pixels[offset] = 0
    pixels[offset + 1] = 0
    pixels[offset + 2] = 0
    pixels[offset + 3] = 0
}

let cleaned = imageFromRGBA(pixels, width: sourceWidth, height: sourceHeight)
var cellPixels = [UInt8](repeating: 0, count: logicalCell * logicalCell * 4)
let cellContext = makeRGBAContext(width: logicalCell, height: logicalCell, data: &cellPixels)
cellContext.clear(CGRect(x: 0, y: 0, width: logicalCell, height: logicalCell))
cellContext.interpolationQuality = .none
cellContext.draw(cleaned, in: CGRect(x: 0, y: 0, width: logicalCell, height: logicalCell))
let cell = imageFromRGBA(cellPixels, width: logicalCell, height: logicalCell)

let stripWidth = logicalCell * frameCount
let stripContext = makeRGBAContext(width: stripWidth, height: logicalCell, data: nil)
stripContext.clear(CGRect(x: 0, y: 0, width: stripWidth, height: logicalCell))
stripContext.interpolationQuality = .none
for frame in 0..<frameCount {
    stripContext.draw(cell, in: CGRect(x: frame * logicalCell, y: 0, width: logicalCell, height: logicalCell))
}

guard let strip = stripContext.makeImage() else {
    fatalError("Could not assemble sprite strip")
}
writePNG(strip, to: outputURL)
print("Wrote \(outputURL.path) (\(stripWidth)x\(logicalCell), \(queue.count) background pixels removed)")
