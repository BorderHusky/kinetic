//
//  HistoryView.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//

import SwiftUI
import SwiftData

// MARK: - History View

struct HistoryView: View {
    @Query(sort: \Workout.date, order: .reverse) private var workouts: [Workout]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No Workouts Yet",
                        systemImage: "clock",
                        description: Text("Your completed workouts will appear here.")
                    )
                } else {
                    List {
                        ForEach(workouts) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                WorkoutCard(workout: workout)
                            }
                        }
                        .onDelete(perform: deleteWorkouts)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !workouts.isEmpty {
                    EditButton()
                }
            }
        }
    }

    private func deleteWorkouts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(workouts[index])
        }
        try? modelContext.save()
    }
}

// MARK: - Workout Card

struct WorkoutCard: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date
            Text(workout.date.formatted(date: .complete, time: .omitted))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Name or fallback
            Text(workout.name ?? "Workout")
                .font(.headline)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Workout Detail View

struct WorkoutDetailView: View {
    let workout: Workout

    var body: some View {
        List {
            // Header section
            Section {
                if let duration = workout.duration {
                    LabeledContent("Duration", value: formatDuration(duration))
                }
                LabeledContent("Exercises", value: "\(workout.exercises.count)")
                LabeledContent("Total Sets", value: "\(workout.totalSets)")
            }

            // Exercise breakdown
            ForEach(workout.sortedExercises) { workoutExercise in
                Section(workoutExercise.exercise?.name ?? workoutExercise.exerciseName) {
                    ForEach(workoutExercise.sortedSets) { set in
                        HStack {
                            Text("Set \(set.setNumber)")
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)

                            Spacer()

                            Text("\(set.weight.formatted()) \(set.unit.rawValue) x \(set.reps) reps")
                                .font(.subheadline)

                            Spacer()

                            Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(set.isComplete ? .green : Color(.systemGray4))
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(workout.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes == 0 {
            return "\(seconds)s"
        } else if seconds == 0 {
            return "\(minutes)m"
        } else {
            return "\(minutes)m \(seconds)s"
        }
    }
}
