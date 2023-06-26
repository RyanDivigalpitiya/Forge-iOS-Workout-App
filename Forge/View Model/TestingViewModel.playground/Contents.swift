import Foundation

func numberOfDaysString(from date: Date) -> String {
    /*
        returns "Today" if Date() is sometime between now and 12:00am today,
        or returns "Yesterday" if Date() is sometime between yesterday 11:59pm and yesterday 12:00am,
        or "x Days ago" if Date() is from before yesterday an x number of days ago
    */
    
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return "Today"
    } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
    } else {
        let startOfNow = calendar.startOfDay(for: Date())
        let startOfDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfDate, to: startOfNow)
        if let day = components.day {
            return "\(day) days ago"
        } else {
            return "Date calculation error" //change how error handling is done here
        }
    }
}

let calendar = Calendar.current
let now = Date()

// Today
let today = now

// Yesterday
guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else {
    fatalError("Couldn't calculate yesterday's date")
}

// 2 days ago
guard let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: now) else {
    fatalError("Couldn't calculate the date of 2 days ago")
}

// 5 days ago
guard let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: now) else {
    fatalError("Couldn't calculate the date of 5 days ago")
}

// 10 days ago
guard let tenDaysAgo = calendar.date(byAdding: .day, value: -10, to: now) else {
    fatalError("Couldn't calculate the date of 10 days ago")
}

let datesToTest = [today, yesterday, twoDaysAgo, fiveDaysAgo, tenDaysAgo]

for date in datesToTest {
    print(numberOfDaysString(from: date))
}
