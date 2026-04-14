import SwiftUI

/// Full-screen confetti overlay rendered via Canvas + TimelineView for smooth 60fps playback.
/// Supports multiple animation styles controlled by `ConfettiStyle`.
struct ConfettiView: View {

    let colors: [Color]
    let style: ConfettiStyle

    @State private var particles: [Particle] = []
    @State private var startDate: Date = Date()

    private let particleCount = 150
    private let totalDuration: TimeInterval = 2.5

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let elapsed = CGFloat(timeline.date.timeIntervalSince(startDate))

                    for particle in particles {
                        let age = elapsed - particle.spawnDelay
                        guard age > 0 else { continue }

                        let pos = position(for: particle, age: age, screenHeight: size.height)

                        // Skip particles outside the visible area
                        guard pos.y < size.height + 100 && pos.y > -100 else { continue }

                        let rotation = Angle(radians: particle.rotation + particle.angularVelocity * age)

                        // Fade out during the last 0.5 seconds
                        let fadeStart = CGFloat(totalDuration) - 0.5
                        let opacity = age > fadeStart
                            ? max(0, Double(1.0 - (age - fadeStart) / 0.5))
                            : 1.0
                        guard opacity > 0 else { continue }

                        let rect = Path(CGRect(
                            x: -particle.width / 2,
                            y: -particle.height / 2,
                            width: particle.width,
                            height: particle.height
                        ))

                        var ctx = context
                        ctx.opacity = opacity
                        ctx.translateBy(x: pos.x, y: pos.y)
                        ctx.rotate(by: rotation)
                        ctx.fill(rect, with: .color(particle.color))
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .onAppear {
            startDate = Date()
            generateParticles()
        }
    }

    /// Computes particle position based on the active confetti style.
    private func position(for p: Particle, age: CGFloat, screenHeight: CGFloat) -> CGPoint {
        let wobbleX = sin(age * p.wobbleFreq) * p.wobbleAmp

        switch style {
        case .rainDown:
            // Burst from top: upward initial velocity, strong gravity pulls down
            let gravity: CGFloat = 600
            let x = p.startX + p.vx * age + wobbleX
            let y = p.startY + p.vy * age + 0.5 * gravity * age * age
            return CGPoint(x: x, y: y)

        case .burstUp:
            // Shoot up from bottom: strong upward velocity, gentle gravity floats down
            let gravity: CGFloat = 200
            let x = p.startX + p.vx * age + wobbleX
            let y = screenHeight + p.startY + p.vy * age + 0.5 * gravity * age * age
            return CGPoint(x: x, y: y)
        }
    }

    private func generateParticles() {
        let screenWidth = UIScreen.main.bounds.width
        particles = (0..<particleCount).map { _ in
            Particle(
                startX: CGFloat.random(in: -20...(screenWidth + 20)),
                startY: startY(for: style),
                vx: CGFloat.random(in: -150...150),
                vy: initialVY(for: style),
                rotation: CGFloat.random(in: 0...(2 * .pi)),
                angularVelocity: CGFloat.random(in: -8...8),
                width: CGFloat.random(in: 6...12),
                height: CGFloat.random(in: 3...8),
                color: colors[Int.random(in: 0..<colors.count)],
                spawnDelay: CGFloat.random(in: 0...0.3),
                wobbleFreq: CGFloat.random(in: 2...5),
                wobbleAmp: CGFloat.random(in: 10...30)
            )
        }
    }

    private func startY(for style: ConfettiStyle) -> CGFloat {
        switch style {
        case .rainDown: return CGFloat.random(in: -40...0)
        case .burstUp:  return CGFloat.random(in: 0...40)
        }
    }

    private func initialVY(for style: ConfettiStyle) -> CGFloat {
        switch style {
        case .rainDown: return CGFloat.random(in: -400 ... -100)
        case .burstUp:  return CGFloat.random(in: -700 ... -400)
        }
    }
}

private struct Particle {
    let startX: CGFloat
    let startY: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let rotation: CGFloat
    let angularVelocity: CGFloat
    let width: CGFloat
    let height: CGFloat
    let color: Color
    let spawnDelay: CGFloat
    let wobbleFreq: CGFloat
    let wobbleAmp: CGFloat
}
