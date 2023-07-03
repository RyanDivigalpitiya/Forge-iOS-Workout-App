import Foundation
import Combine

class StopwatchViewModel: ObservableObject {
    @Published var stopwatchText = "00:00:00"
    @Published var breakTimeRemaining = 5 // This will represent the remaining time for the break timer
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0

    var stopwatchTimer: Cancellable? = nil
    var breakTimer: Cancellable? = nil  // New timer for the break
    var startDate = Date()
    var isRunning = true
    var timeElapsedWhenStopped: TimeInterval = 0
    
    func startStopTapped() {
        if isRunning {
            stopwatchTimer?.cancel()
            breakTimer?.cancel()  // Cancel the break timer
            isPaused = true
            timeElapsedWhenStopped = Date().timeIntervalSince(startDate)
        } else {
            startDate = Date().addingTimeInterval(-timeElapsedWhenStopped)
            startStopwatch()
            startBreakTimer()  // Start the break timer
            isPaused = false
        }
        isRunning.toggle()
    }
    
    func startStopWatch() {
        startDate = Date()
        startStopwatch()
    }
    
    func stopStopWatch() {
        stopwatchTimer?.cancel()
    }
    
    func startTimer() {
        startBreakTimer()  // Start the break timer
    }
    
    func stopTimer() {
        breakTimer?.cancel()  // Cancel the break timer
    }
    
    private func startStopwatch() {
        stopwatchTimer = Timer.publish(every: 1, on: .current, in: .common)
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
    
    private func startBreakTimer() {
        // Reset the break time to _ seconds when starting
        breakTimeRemaining = 5
        breakTimer = Timer.publish(every: 1, on: .current, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.breakTimeRemaining > 0 {
                    self.breakTimeRemaining -= 1
                } else {
                    // If the break time reaches 0, we stop the break timer
                    self.breakTimer?.cancel()
                }
            }
    }
}
