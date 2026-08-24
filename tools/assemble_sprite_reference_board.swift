import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outputURL = root.appendingPathComponent("renders/approved/farinuff-25d-sprite-reference-board.png")
let boardWidth = 1280
let boardHeight = 900
let columns = 4
let rows = 3
let cellWidth = boardWidth / columns
let cellHeight = (boardHeight - 72) / rows

let entries: [(String, String)] = [
    ("PLAYER SHIP", "assets/sprites/generated/v2p5d_player_idle_strip.png"),
    ("BASIC ENEMY", "assets/sprites/generated/v2p5d_basic_enemy_gen1_idle_strip.png"),
    ("FAST ENEMY", "assets/sprites/generated/v2p5d_fast_enemy_gen1_idle_strip.png"),
    ("BOMBER ENEMY", "assets/sprites/generated/v2p5d_bomber_enemy_gen1_idle_strip.png"),
    ("SNIPER ENEMY", "assets/sprites/generated/v2p5d_sniper_enemy_gen1_idle_strip.png"),
    ("TANK ENEMY", "assets/sprites/generated/v2p5d_tank_enemy_gen1_idle_strip.png"),
    ("ASSAULT BOSS", "assets/sprites/generated/v2p5d_boss_assault_idle_strip.png"),
    ("BULWARK BOSS", "assets/sprites/generated/v2p5d_boss_bulwark_idle_strip.png"),
    ("TEMPEST BOSS", "assets/sprites/generated/v2p5d_boss_tempest_idle_strip.png"),
    ("VOID HARBINGER", "assets/sprites/generated/v2p5d_boss_void_harbinger_idle_strip.png"),
    ("TEMPEST CORE", "assets/sprites/generated/v2p5d_boss_tempest_core_idle_strip.png"),
    ("STYLE LOCKED", "STYLE_REFERENCE.md")
]

func loadImage(_ url: URL) -> CGImage? {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create board output")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("Could not write board output") }
}

guard let context = CGContext(
    data: nil,
    width: boardWidth,
    height: boardHeight,
    bitsPerComponent: 8,
    bytesPerRow: boardWidth * 4,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("Could not create board context") }

context.setFillColor(CGColor(red: 0.008, green: 0.012, blue: 0.035, alpha: 1.0))
context.fill(CGRect(x: 0, y: 0, width: boardWidth, height: boardHeight))
context.setFillColor(CGColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1.0))
context.fill(CGRect(x: 0, y: boardHeight - 72, width: boardWidth, height: 72))

var textSize: CGFloat = 18
var textColor = CGColor(red: 0.55, green: 0.90, blue: 1.0, alpha: 1.0)
context.textPosition = CGPoint(x: 28, y: boardHeight - 32)
func showText(_ text: String) {
    let font = CTFontCreateWithName("Menlo" as CFString, textSize, nil)
    let attributes: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): textColor
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    CTLineDraw(line, context)
}
showText("FARINUFF FLIGHT 2.5D PIXEL FLEET  |  1280x720  |  128px FRAME  |  64px ANCHOR")
textSize = 11
textColor = CGColor(red: 0.45, green: 0.55, blue: 0.78, alpha: 1.0)
context.textPosition = CGPoint(x: 28, y: boardHeight - 53)
showText("Reference board: isolated runtime identities rendered with the approved low-poly / nearest-neighbor style lock.")

for (index, entry) in entries.enumerated() {
    let column = index % columns
    let row = index / columns
    let x = column * cellWidth
    let y = boardHeight - 72 - (row + 1) * cellHeight
    let panel = CGRect(x: x + 10, y: y + 10, width: cellWidth - 20, height: cellHeight - 20)

    let accent = index == 0
        ? CGColor(red: 0.0, green: 0.78, blue: 1.0, alpha: 0.85)
        : (index >= 6 && index <= 10
            ? CGColor(red: 0.85, green: 0.18, blue: 1.0, alpha: 0.85)
            : CGColor(red: 0.22, green: 0.40, blue: 0.70, alpha: 0.75))
    context.setFillColor(CGColor(red: 0.012, green: 0.018, blue: 0.055, alpha: 1.0))
    context.fill(panel)
    context.setStrokeColor(accent)
    context.setLineWidth(1.0)
    context.stroke(panel)

    if entry.1 == "STYLE_REFERENCE.md" {
        context.setFillColor(CGColor(red: 0.20, green: 0.12, blue: 0.42, alpha: 1.0))
        context.fill(CGRect(x: panel.minX + 20, y: panel.minY + 58, width: panel.width - 40, height: panel.height - 105))
        textSize = 27
        textColor = CGColor(red: 1.0, green: 0.26, blue: 0.84, alpha: 1.0)
        context.textPosition = CGPoint(x: panel.minX + 56, y: panel.midY + 10)
        showText("STYLE")
        context.textPosition = CGPoint(x: panel.minX + 38, y: panel.midY - 22)
        showText("REFERENCE")
    } else if let strip = loadImage(root.appendingPathComponent(entry.1)),
              let frame = strip.cropping(to: CGRect(x: 0, y: 0, width: 128, height: 128)) {
        context.interpolationQuality = .none
        let drawSize = min(panel.width - 42, panel.height - 78)
        let frameRect = CGRect(
            x: panel.midX - drawSize / 2,
            y: panel.minY + 46,
            width: drawSize,
            height: drawSize
        )
        context.draw(frame, in: frameRect)
    }

    textSize = 15
    textColor = CGColor(red: 0.76, green: 0.86, blue: 1.0, alpha: 1.0)
    context.textPosition = CGPoint(x: panel.minX + 16, y: panel.minY + 21)
    showText(entry.0)
}

guard let board = context.makeImage() else { fatalError("Could not finalize board") }
writePNG(board, to: outputURL)
print("Wrote \(outputURL.path) (\(boardWidth)x\(boardHeight))")
