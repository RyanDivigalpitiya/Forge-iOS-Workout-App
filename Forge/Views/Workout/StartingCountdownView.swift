import SwiftUI
import Combine

/// 3-second pre-workout countdown shown before the active workout view fades in.
/// Self-contained: owns its timer state and signals completion via `onCompletion`.
struct StartingCountdownView: View {

    let initialSeconds: Int
    let onCompletion: () -> Void

    @State private var remainingTime: Int
    @State private var totalTime: Int
    @State private var timerSubscription: Cancellable? = nil
    @State private var contentOpacity: Double = 0.0

    @EnvironmentObject var settings: GlobalSettings

    init(initialSeconds: Int = 3, onCompletion: @escaping () -> Void) {
        self.initialSeconds = initialSeconds
        self.onCompletion = onCompletion
        self._remainingTime = State(initialValue: initialSeconds)
        self._totalTime = State(initialValue: initialSeconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            HStack {
                Spacer()
                Text("Starting in ...")
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .foregroundColor(settings.fgColor)
                    .opacity(contentOpacity)
                Spacer()
            }
            Button(action: {
                // Tap to skip — fast-forward by setting the counter to 0.
                // The next timer tick (within ~1s) will trigger completion.
                remainingTime = 0
            }) {
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(Color(.systemGray5))
                    Circle()
                        .trim(from: 0, to: CGFloat(remainingTime) / CGFloat(totalTime))
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundColor(settings.fgColor)
                        .rotationEffect(Angle(degrees: -90))
                        .animation(.easeOut(duration: settings.animationSlow), value: remainingTime)
                        .shadow(color: settings.fgColor.opacity(0.7), radius: 10, x: 0, y: 0)
                    Text("\(remainingTime)")
                        .font(.system(size: 60))
                        .foregroundColor(settings.fgColor)
                        .fontWeight(.bold)
                        .shadow(color: settings.fgColor.opacity(0.7), radius: 10, x: 0, y: 0)
                }
                .opacity(contentOpacity)
                .onAppear {
                    withAnimation(.easeOut(duration: settings.animationStandard)) {
                        contentOpacity = 1.0
                    }
                    startTimer()
                }
                .padding(.vertical, 50)
                .onDisappear {
                    timerSubscription?.cancel()
                }
            }
            Spacer()
        }
        .padding(.horizontal, 40)
        .background(.black)
    }

    private func startTimer() {
        timerSubscription = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if remainingTime > 0 {
                    remainingTime -= 1
                } else {
                    onCompletion()
                    timerSubscription?.cancel()
                    triggerHapticFeedback()
                }
            }
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
}

struct StartingCountdownView_Previews: PreviewProvider {
    static var previews: some View {
        StartingCountdownView(initialSeconds: 3) { }
            .environmentObject(GlobalSettings.shared)
            .preferredColorScheme(.dark)
    }
}
