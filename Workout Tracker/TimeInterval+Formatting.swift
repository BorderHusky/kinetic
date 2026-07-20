import Foundation

enum DurationFormatStyle {
    case workout
    case detailed
}

extension TimeInterval {
    func formattedAsDuration(style: DurationFormatStyle = .workout) -> String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let seconds = Int(self) % 60

        switch style {
        case .workout:
            if hours > 0 { return "\(hours)h \(minutes)m" }
            if minutes > 0 { return "\(minutes)m" }
            return "<1m"
        case .detailed:
            if minutes > 0 {
                return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
            }
            return "\(seconds)s"
        }
    }
}
