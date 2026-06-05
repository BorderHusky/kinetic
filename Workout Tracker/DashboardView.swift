//
//  DashboardView.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//
 
import SwiftUI
import SwiftData
 
// MARK: - Time Range
 
enum TimeRange: String, CaseIterable {
    case week = "This Week"
    case month = "This Month"
    case allTime = "All Time"
}
 
// MARK: - Dashboard View
 
struct DashboardView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
 
    @State private var selectedRange: TimeRange = .allTime
 
    var filteredWorkouts: [Workout] {
        let now = Date()
        switch selectedRange {
        case .week:
            let start = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return workouts.filter { $0.date >= start }
        case .month:
            let start = Calendar.current.dateInterval(of: .month, for: now)?.start ?? now
            return workouts.filter { $0.date >= start }
        case .allTime:
            return workouts
        }
    }
 
    var totalWorkouts: Int {
        filteredWorkouts.count
    }
 
    var totalDuration: TimeInterval {
        filteredWorkouts.compactMap { $0.duration }.reduce(0, +)
    }
 
    var totalWeight: Double {
        filteredWorkouts
            .flatMap { $0.exercises }
            .flatMap { $0.sets }
            .filter { $0.isComplete }
            .reduce(0) { $0 + $1.weight }
    }
 
    var mostRecentWorkout: Workout? {
        workouts.first
    }
 
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
 
                    // Time range picker
                    Picker("Time Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
 
                    // Stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        StatCard(
                            title: "Workouts",
                            value: "\(totalWorkouts)",
                            icon: "calendar.badge.checkmark"
                        )
 
                        StatCard(
                            title: "Time",
                            value: formatDuration(totalDuration),
                            icon: "clock"
                        )
 
                        StatCard(
                            title: "Weight Lifted",
                            value: formatWeight(totalWeight),
                            icon: "scalemass"
                        )
 
                        StatCard(
                            title: "Avg Duration",
                            value: totalWorkouts > 0 ? formatDuration(totalDuration / Double(totalWorkouts)) : "--",
                            icon: "timer"
                        )
                    }
                    .padding(.horizontal)
 
                    // Most recent workout
                    if let recent = mostRecentWorkout {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Last Workout")
                                .font(.headline)
                                .padding(.horizontal)
 
                            NavigationLink(destination: WorkoutDetailView(workout: recent)) {
                                RecentWorkoutCard(workout: recent)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal)
                        }
                    } else {
                        ContentUnavailableView(
                            "No Workouts Yet",
                            systemImage: "figure.strengthtraining.traditional",
                            description: Text("Complete your first workout to see your stats.")
                        )
                        .padding(.top, 20)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Dashboard")
        }
    }
 
    // MARK: - Formatters
 
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
 
    private func formatWeight(_ weight: Double) -> String {
        if weight >= 1000 {
            return String(format: "%.1fk", weight / 1000)
        }
        return String(format: "%.0f", weight)
    }
}
 
// MARK: - Stat Card
 
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
 
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.accentColor)
                    .font(.subheadline)
                Spacer()
            }
 
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
 
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
 
// MARK: - Recent Workout Card
 
struct RecentWorkoutCard: View {
    let workout: Workout
 
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name ?? "Workout")
                        .font(.headline)
 
                    Text(workout.date.formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
 
                Spacer()
 
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
 
            Divider()
 
            HStack(spacing: 24) {
                Label("\(workout.exercises.count) exercises", systemImage: "dumbbell")
 
                if let duration = workout.duration {
                    Label(formatDuration(duration), systemImage: "clock")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
 
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
}
