import SwiftUI

struct FitOverlayChart: View {
    let headWidth: Double
    let headDepth: Double
    let shellWidth: Double
    let shellDepth: Double

    var body: some View {
        Canvas { context, size in
            let padding: CGFloat = 14
            let available = CGSize(width: size.width - padding * 2, height: size.height - padding * 2)
            let scale = min(available.width / max(shellDepth, 1), available.height / max(shellWidth, 1))
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            let shellRect = CGRect(
                x: center.x - shellDepth / 2 * scale,
                y: center.y - shellWidth / 2 * scale,
                width: shellDepth * scale,
                height: shellWidth * scale
            )
            let shellPath = Path(ellipseIn: shellRect)
            context.fill(shellPath, with: .color(.gray.opacity(0.15)))
            context.stroke(shellPath, with: .color(.gray), lineWidth: 1.5)

            let headRect = CGRect(
                x: center.x - headDepth / 2 * scale,
                y: center.y - headWidth / 2 * scale,
                width: headDepth * scale,
                height: headWidth * scale
            )
            let headPath = Path(ellipseIn: headRect)
            context.fill(headPath, with: .color(.blue.opacity(0.25)))
            context.stroke(headPath, with: .color(.blue), lineWidth: 2)

            var arrow = Path()
            arrow.move(to: CGPoint(x: center.x - shellDepth / 2 * scale - 8, y: center.y))
            arrow.addLine(to: CGPoint(x: center.x - shellDepth / 2 * scale - 2, y: center.y))
            context.stroke(arrow, with: .color(.secondary), lineWidth: 1.5)
        }
        .frame(height: 150)
    }
}
