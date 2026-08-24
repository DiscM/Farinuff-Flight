import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 4 else {
    fputs("usage: recolor_sprite_palette <input.png> <output.png> <tempest|core|void>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let paletteName = CommandLine.arguments[3]

struct Palette {
    let shadowHue: Double
    let energyHue: Double
    let shadowSaturation: Double
    let energySaturation: Double
}

let palette: Palette
switch paletteName {
case "tempest":
    // Deep blue structural planes with a readable electric-cyan storm charge.
    palette = Palette(shadowHue: 0.64, energyHue: 0.54, shadowSaturation: 0.84, energySaturation: 0.92)
case "core":
    // Indigo-violet housing with a warm solar-amber core and trim.
    palette = Palette(shadowHue: 0.68, energyHue: 0.10, shadowSaturation: 0.78, energySaturation: 0.92)
case "void":
    // Void-black/indigo housing with spectral emerald and acid-lime energy.
    palette = Palette(shadowHue: 0.68, energyHue: 0.31, shadowSaturation: 0.82, energySaturation: 0.95)
default:
    fputs("unknown palette: \(paletteName)\n", stderr)
    exit(2)
}

guard let source = CGImageSourceCreateWithURL(inputURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Could not read \(inputURL.path)")
}

let width = image.width
let height = image.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
guard let context = CGContext(
    data: &pixels,
    width: width,
    height: height,
    bitsPerComponent: 8,
    bytesPerRow: width * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create RGBA context")
}
context.interpolationQuality = .none
context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

func clamp(_ value: Double, _ lower: Double = 0.0, _ upper: Double = 1.0) -> Double {
    min(upper, max(lower, value))
}

func rgbToHSV(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, v: Double) {
    let maximum = max(r, max(g, b))
    let minimum = min(r, min(g, b))
    let delta = maximum - minimum
    var hue = 0.0
    if delta > 0.0001 {
        if maximum == r {
            hue = ((g - b) / delta).truncatingRemainder(dividingBy: 6.0)
        } else if maximum == g {
            hue = ((b - r) / delta) + 2.0
        } else {
            hue = ((r - g) / delta) + 4.0
        }
        hue /= 6.0
        if hue < 0.0 { hue += 1.0 }
    }
    return (hue, maximum == 0.0 ? 0.0 : delta / maximum, maximum)
}

func hsvToRGB(_ h: Double, _ s: Double, _ v: Double) -> (r: Double, g: Double, b: Double) {
    let hue = (h - floor(h)) * 6.0
    let index = Int(floor(hue)) % 6
    let fraction = hue - floor(hue)
    let p = v * (1.0 - s)
    let q = v * (1.0 - fraction * s)
    let t = v * (1.0 - (1.0 - fraction) * s)
    switch index {
    case 0: return (v, t, p)
    case 1: return (q, v, p)
    case 2: return (p, v, t)
    case 3: return (p, q, v)
    case 4: return (t, p, v)
    default: return (v, p, q)
    }
}

for pixel in 0..<(width * height) {
    let offset = pixel * 4
    let alpha = Double(pixels[offset + 3]) / 255.0
    if alpha <= 0.001 { continue }

    // Decode premultiplied RGB before changing hue so translucent emissive
    // halos do not acquire dark fringes.
    let r = clamp(Double(pixels[offset]) / 255.0 / alpha)
    let g = clamp(Double(pixels[offset + 1]) / 255.0 / alpha)
    let b = clamp(Double(pixels[offset + 2]) / 255.0 / alpha)
    let hsv = rgbToHSV(r, g, b)

    // Preserve white-hot core pixels and near-black occlusion pixels. The
    // middle value bands get a cool structural hue; the brighter bands carry
    // the requested boss-specific energy color.
    if hsv.s >= 0.10 && hsv.v >= 0.10 {
        let isEnergyBand = hsv.v >= 0.42
        let hue = isEnergyBand ? palette.energyHue : palette.shadowHue
        let saturation = isEnergyBand ? palette.energySaturation : palette.shadowSaturation
        let value = hsv.v * (isEnergyBand ? 1.02 : 0.96)
        let recolored = hsvToRGB(hue, clamp(max(hsv.s, saturation)), clamp(value))
        pixels[offset] = UInt8(clamp(recolored.r * alpha) * 255.0)
        pixels[offset + 1] = UInt8(clamp(recolored.g * alpha) * 255.0)
        pixels[offset + 2] = UInt8(clamp(recolored.b * alpha) * 255.0)
    }
}

let data = Data(pixels) as CFData
guard let provider = CGDataProvider(data: data),
      let output = CGImage(
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
      ),
      let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create output image")
}

CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(outputURL.path)")
}
print("Wrote \(outputURL.path) (\(width)x\(height), palette \(paletteName))")
