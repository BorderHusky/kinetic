//
//  MuscleGroup.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//

import Foundation
import SwiftData

// MARK: - Enums

enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case fullBody = "Full Body"
}

enum Equipment: String, Codable, CaseIterable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case kettlebell = "Kettlebell"
    case bodyweight = "Bodyweight"
    case machine = "Machine"
    case cable = "Cable"
    case other = "Other"
}

enum WeightUnit: String, Codable, CaseIterable {
    case lbs = "lbs"
    case kg = "kg"
}

// MARK: - Exercise

@Model
final class Exercise {
    var id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    var notes: String?
    var isCustom: Bool

    @Relationship(deleteRule: .nullify, inverse: \WorkoutExercise.exercise)
    var workoutExercises: [WorkoutExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        notes: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.notes = notes
        self.isCustom = isCustom
    }
}

// MARK: - Workout

@Model
final class Workout {
    var id: UUID
    var date: Date
    var name: String?
    var notes: String?
    var duration: TimeInterval?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutExercise.workout)
    var exercises: [WorkoutExercise] = []

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        name: String? = nil,
        notes: String? = nil,
        duration: TimeInterval? = nil
    ) {
        self.id = id
        self.date = date
        self.name = name
        self.notes = notes
        self.duration = duration
    }

    var sortedExercises: [WorkoutExercise] {
        exercises.sorted { $0.order < $1.order }
    }

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}

// MARK: - WorkoutExercise

@Model
final class WorkoutExercise {
    var id: UUID
    var order: Int
    var exerciseName: String

    var workout: Workout?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.workoutExercise)
    var sets: [ExerciseSet] = []

    init(
            id: UUID = UUID(),
            order: Int,
            exerciseName: String = "",
            workout: Workout? = nil,
            exercise: Exercise? = nil
        ) {
            self.id = id
            self.order = order
            self.exerciseName = exerciseName
            self.workout = workout
            self.exercise = exercise
        }

    var sortedSets: [ExerciseSet] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }

    var nextSetNumber: Int {
        (sets.map { $0.setNumber }.max() ?? 0) + 1
    }
}

// MARK: - ExerciseSet

@Model
final class ExerciseSet {
    var id: UUID
    var setNumber: Int
    var reps: Int
    var weight: Double
    var unit: WeightUnit
    var isComplete: Bool

    var workoutExercise: WorkoutExercise?

    init(
        id: UUID = UUID(),
        setNumber: Int,
        reps: Int = 0,
        weight: Double = 0,
        unit: WeightUnit = .lbs,
        isComplete: Bool = false,
        workoutExercise: WorkoutExercise? = nil
    ) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.unit = unit
        self.isComplete = isComplete
        self.workoutExercise = workoutExercise
    }
}

// MARK: - Default Exercise Library

extension Exercise {
    static let defaultExercises: [Exercise] = [
        // Chest
        Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell),
        Exercise(name: "Incline Bench Press", muscleGroup: .chest, equipment: .barbell),
        Exercise(name: "Dumbbell Fly", muscleGroup: .chest, equipment: .dumbbell),
        Exercise(name: "Push Up", muscleGroup: .chest, equipment: .bodyweight),

        // Back
        Exercise(name: "Deadlift", muscleGroup: .back, equipment: .barbell),
        Exercise(name: "Barbell Row", muscleGroup: .back, equipment: .barbell),
        Exercise(name: "Pull Up", muscleGroup: .back, equipment: .bodyweight),
        Exercise(name: "Dumbbell Row", muscleGroup: .back, equipment: .dumbbell),

        // Shoulders
        Exercise(name: "Overhead Press", muscleGroup: .shoulders, equipment: .barbell),
        Exercise(name: "Dumbbell Lateral Raise", muscleGroup: .shoulders, equipment: .dumbbell),
        Exercise(name: "Arnold Press", muscleGroup: .shoulders, equipment: .dumbbell),

        // Biceps
        Exercise(name: "Barbell Curl", muscleGroup: .biceps, equipment: .barbell),
        Exercise(name: "Dumbbell Curl", muscleGroup: .biceps, equipment: .dumbbell),
        Exercise(name: "Hammer Curl", muscleGroup: .biceps, equipment: .dumbbell),

        // Triceps
        Exercise(name: "Skull Crusher", muscleGroup: .triceps, equipment: .barbell),
        Exercise(name: "Tricep Dip", muscleGroup: .triceps, equipment: .bodyweight),
        Exercise(name: "Overhead Tricep Extension", muscleGroup: .triceps, equipment: .dumbbell),

        // Legs
        Exercise(name: "Squat", muscleGroup: .legs, equipment: .barbell),
        Exercise(name: "Romanian Deadlift", muscleGroup: .legs, equipment: .barbell),
        Exercise(name: "Goblet Squat", muscleGroup: .legs, equipment: .kettlebell),
        Exercise(name: "Dumbbell Lunge", muscleGroup: .legs, equipment: .dumbbell),
        Exercise(name: "Leg Press", muscleGroup: .legs, equipment: .machine),

        // Core
        Exercise(name: "Plank", muscleGroup: .core, equipment: .bodyweight),
        Exercise(name: "Crunch", muscleGroup: .core, equipment: .bodyweight),
        Exercise(name: "Dead Bug", muscleGroup: .core, equipment: .bodyweight),
        Exercise(name: "Kettlebell Swing", muscleGroup: .core, equipment: .kettlebell),
    ]
}
