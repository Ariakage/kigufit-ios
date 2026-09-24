import SwiftUI

enum Motion {
    static let snappy = Animation.spring(duration: 0.3, bounce: 0.18)
    static let smooth = Animation.spring(duration: 0.45, bounce: 0.08)
    static let bouncy = Animation.spring(duration: 0.5, bounce: 0.3)
    static let gentle = Animation.easeInOut(duration: 0.5)
}

private struct AppearModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(reduceMotion ? 1 : (appeared ? 1 : 0))
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 14))
            .onAppear {
                guard !appeared else { return }
                withAnimation(Motion.smooth.delay(Double(index) * 0.06)) {
                    appeared = true
                }
            }
    }
}

extension View {
    func appear(index: Int = 0) -> some View {
        modifier(AppearModifier(index: index))
    }
}

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.1f"

    var body: some View {
        Text(String(format: format, value))
            .contentTransition(.numericText())
            .animation(Motion.snappy, value: value)
            .monospacedDigit()
    }
}

struct SuccessSymbol: View {
    var systemName: String = "checkmark.seal.fill"
    @State private var trigger = false

    var body: some View {
        Image(systemName: systemName)
            .foregroundStyle(.green)
            .symbolEffect(.bounce, value: trigger)
            .onAppear { trigger = true }
    }
}
