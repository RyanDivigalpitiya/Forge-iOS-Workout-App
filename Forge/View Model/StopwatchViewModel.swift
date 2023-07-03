import Foundation
import Combine
import UIKit

class StopwatchViewModel: ObservableObject {
    @Published var stopwatchText = "00:00:00"
    @Published var isPaused = false
    @Published var currentTime: TimeInterval = 0
    @Published var breakTimeRemaining = 60 // This will represent the remaining time for the break timer

    var breakDuration = 60
    var stopwatchTimer: Cancellable? = nil
    var breakTimer: Cancellable? = nil  // New timer for the break
    var startDate = Date()
    var isRunning = true
    var timeElapsedWhenStopped: TimeInterval = 0
    
    var breakTimeElapsedPublisher: AnyPublisher<Bool, Never> {
          $breakTimeRemaining
              .map { $0 == 0 }
              .eraseToAnyPublisher()
      }

    
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
        print("\nTIMER STOPPED\n")
        breakTimer?.cancel()  // Cancel the break timer
        breakTimeRemaining = breakDuration
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let center = UNUserNotificationCenter.current()
            center.getPendingNotificationRequests { requests in
                let idsToRemove = requests.filter { $0.content.categoryIdentifier == "workoutCategory" }.map { $0.identifier }
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }

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
    
    func startBreakTimer() {
        print("\nTIMER STARTED\n")
        breakTimer?.cancel()
        breakTimeRemaining = breakDuration
        breakTimer = Timer.publish(every: 1, on: .current, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.breakTimeRemaining > 0 {
                    self.breakTimeRemaining -= 1
                } else {
                    print("\nTimer is about to complete.\n")
                    self.breakTimer?.cancel()
                    print("\nTimer cancelled. Should send notification now.\n")
//                    self.sendNotification() // Send notification to user that timer is over and to start next set
                }
            }
    }

    
    func sendNotification() {
        print("\nsendNotification called!\n")
        let content = UNMutableNotificationContent()
        content.title = "Start your next set!"
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "workoutCategory"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(breakDuration), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("\nError scheduling notification: \(error)\n")
            } else {
                print("\nNotification scheduled!\n")
            }
        }
    }


}
