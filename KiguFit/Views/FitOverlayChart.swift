import SwiftUI

struct FitOverlayChart: View {
    let headWidth: Double
    let headDepth: Double
    let shellWidth: Double
    let shellDepth: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        Canvas { context, size in
            let p = reduceMotion ? 1 : progress
            let padding: CGFloat = 14
            let available = CGSize(width: size.width - padding * 2, height: size.height - padding * 2)
            let scale = min(available.width / max(shellDepth, 1), available.height / max(shellWidth, 1))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            func scaledRect(depth: Double, width: Double, factor: CGFloat) -> CGRect {
                let w = depth * scale * factor
                let h = width * scale * factor
                return CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h)
            }

            let shellPath = Path(ellipseIn: scaledRect(depth: shellDepth, width: shellWidth, factor: 0.9 + 0.1 * p))
            context.fill(shellPath, with: .color(.gray.opacity(0.15 * Double(p))))
            context.stroke(shellPath, with: .color(.gray.opacity(Double(p))), lineWidth: 1.5)

            let headPath = Path(ellipseIn: scaledRect(depth: headDepth, width: headWidth, factor: max(p, 0.001)))
            context.fill(headPath, with: .color(.blue.opacity(0.25 * Double(p))))
            context.stroke(headPath, with: .color(.blue.opacity(Double(p))), lineWidth: 2)

            var arrow = Path()
            arrow.move(to: CGPoint(x: center.x - shellDepth / 2 * scale - 8, y: center.y))
            arrow.addLine(to: CGPoint(x: center.x - shellDepth / 2 * scale - 2, y: center.y))
            context.stroke(arrow, with: .color(.secondary.opacity(Double(p))), lineWidth: 1.5)
        }
        .frame(height: 150)
        .onAppear {
            withAnimation(Motion.smooth.delay(0.15)) {
                progress = 1
            }
        }
    }
}
