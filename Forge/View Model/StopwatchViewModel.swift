import Foundation
import Combine

class StopwatchViewModel: ObservableObject {
    @Published var stopwatchText = "00:00:00"
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0 
    
    var stopwatchTimer: Cancellable? = nil
    var startDate = Date()
    var isRunning = true
    var timeElapsedWhenStopped: TimeInterval = 0
    
    func startStopTapped() {
        if isRunning {
            stopwatchTimer?.cancel()
            isPaused = true
            timeElapsedWhenStopped = Date().timeIntervalSince(startDate)
        } else {
            startDate = Date().addingTimeInterval(-timeElapsedWhenStopped)
            startStopwatch()
            isPaused = false
        }
        isRunning.toggle()
    }
    
    func viewAppeared() {
        startDate = Date()
        startStopwatch()
    }
    
    func viewDisappeared() {
        stopwatchTimer?.cancel()
    }
    
    private func startStopwatch() {
        stopwatchTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                let elapsed = Date().timeIntervalSince(self.startDate)
                self.currentTime = elapsed  // Update the currentTime property.
                if Int(elapsed) >= 359999 {
                    self.stopwatchTimer?.cancel()
                    self.stopwatchText = "99:59:59"
                    return
                }
                let hours = Int(elapsed) / 3600
                let minutes = Int(elapsed) / 60 % 60
                let seconds = Int(elapsed) % 60
                self.stopwatchText = String(format: "%02i:%02i:%02i", hours, minutes, seconds)
            }
    }
}


