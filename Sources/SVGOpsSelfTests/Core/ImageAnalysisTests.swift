import AppKit
import SVGOpsCore

extension SVGOpsSelfTests {
    @MainActor
    static func runImageAnalysisTests(_ runner: SelfTestRunner) {
        runner.run("black and white image suggests line art") {
            let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: 4,
                pixelsHigh: 4,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .calibratedRGB,
                bytesPerRow: 16,
                bitsPerPixel: 32
            )!

            for y in 0..<4 {
                for x in 0..<4 {
                    let offset = y * rep.bytesPerRow + x * 4
                    let value: UInt8 = (x + y).isMultiple(of: 2) ? 0 : 255
                    rep.bitmapData?[offset] = value
                    rep.bitmapData?[offset + 1] = value
                    rep.bitmapData?[offset + 2] = value
                    rep.bitmapData?[offset + 3] = 255
                }
            }

            let result = ImageAnalysis.analyze(rep: rep)
            runner.expect(result.isMostlyBlackAndWhite)
            runner.expect(result.suggestedMode == .lineArt)
        }
    }
}
