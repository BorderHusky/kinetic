//
//  Workout_TrackerApp.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//

import SwiftUI
import SwiftData

@main
struct Workout_TrackerApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Exercise.self, Workout.self, WorkoutExercise.self, ExerciseSet.self]) { result in
            switch result {
            case .success(let container):
                seedExerciseLibraryIfNeeded(context: container.mainContext)
            case .failure(let error):
                print("ModelContainer failed: \(error)")
            }
        }
    }
}

private func seedExerciseLibraryIfNeeded(context: ModelContext) {
    let descriptor = FetchDescriptor<Exercise>()
    let existingCount = (try? context.fetchCount(descriptor)) ?? 0
    guard existingCount == 0 else { return }

    for exercise in Exercise.defaultExercises {
        context.insert(exercise)
    }

    try? context.save()
}
