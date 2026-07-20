//
//  Untitled.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import Foundation

// MARK: - Settings View (stub)

struct SettingsView: View {
    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lbs }

    @Environment(\.modelContext) private var context

    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Weight Unit", selection: $weightUnitRaw) {
                        ForEach(WeightUnit.allCases, id: \.rawValue) { unit in
                            Text(unit == .lbs ? "Pounds (lbs)" : "Kilograms (kg)").tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Backup & Restore") {
                    Button("Export Data") {
                        exportDatabase(context: context) { url in
                            guard let url = url else { return }
                            let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let root = windowScene.windows.first?.rootViewController {
                                root.present(av, animated: true)
                            }
                        }
                    }

                    Button("Import Data") {
                        showImporter = true
                    }
                }

                if let importError {
                    Text("Import error: \(importError)")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    guard url.startAccessingSecurityScopedResource() else {
                        importError = "Could not access file."
                        return
                    }
                    defer { url.stopAccessingSecurityScopedResource() }
                    try importDatabase(from: url, context: context)
                    importError = nil
                } catch {
                    importError = "\(error)"
                    print("Import failed: \(error)")
                }
            case .failure(let error):
                importError = error.localizedDescription
                print("Importer error: \(error)")
            }
        }
    }
}

// Fallback backup/restore implementations (can be removed if BackupRestore.swift is in target)

private struct _ExerciseDTO: Codable, Identifiable { var id: UUID; var name: String; var muscleGroup: String; var equipment: String; var notes: String?; var isCustom: Bool }
private struct _ExerciseSetDTO: Codable, Identifiable { var id: UUID; var setNumber: Int; var reps: Int; var weight: Double; var isComplete: Bool }
private struct _WorkoutExerciseDTO: Codable, Identifiable { var id: UUID; var order: Int; var exerciseID: UUID; var exerciseName: String?; var sets: [_ExerciseSetDTO] }
private struct _WorkoutDTO: Codable, Identifiable { var id: UUID; var date: Date; var duration: TimeInterval?; var exercises: [_WorkoutExerciseDTO] }
private struct _ExportBundle: Codable { var version: Int; var exportedAt: Date; var exercises: [_ExerciseDTO]; var workouts: [_WorkoutDTO] }

func exportDatabase(context: ModelContext, completion: @escaping (URL?) -> Void) {
    Task {
        do {
            let allExercises: [Exercise] = try context.fetch(FetchDescriptor<Exercise>())
            let allWorkoutExercises: [WorkoutExercise] = try context.fetch(FetchDescriptor<WorkoutExercise>())
            let allWorkouts: [Workout] = try context.fetch(FetchDescriptor<Workout>())
            let exercisesByWorkoutID = Dictionary(grouping: allWorkoutExercises, by: { $0.workout?.id ?? UUID() })

            let exerciseDTOs = allExercises.map { _ExerciseDTO(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup.rawValue, equipment: $0.equipment.rawValue, notes: $0.notes, isCustom: $0.isCustom) }
            let workoutDTOs: [_WorkoutDTO] = allWorkouts.map { w in
                let wes = exercisesByWorkoutID[w.id] ?? []
                let weDTOs: [_WorkoutExerciseDTO] = wes.sorted { $0.order < $1.order }.map { we in
                    let setDTOs: [_ExerciseSetDTO] = we.sets.sorted { $0.setNumber < $1.setNumber }.map { s in
                        _ExerciseSetDTO(id: s.id, setNumber: s.setNumber, reps: s.reps, weight: s.weight, isComplete: s.isComplete)
                    }
                    return _WorkoutExerciseDTO(id: we.id, order: we.order, exerciseID: we.exercise?.id ?? UUID(), sets: setDTOs)
                }
                return _WorkoutDTO(id: w.id, date: w.date, duration: w.duration, exercises: weDTOs)
            }

            let bundle = _ExportBundle(version: 1, exportedAt: Date(), exercises: exerciseDTOs, workouts: workoutDTOs)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(bundle)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("WorkoutTracker-\(ISO8601DateFormatter().string(from: Date())).json")
            try data.write(to: url)
            completion(url)
        } catch {
            print("Export failed: \(error)")
            completion(nil)
        }
    }
}

func importDatabase(from url: URL, context: ModelContext) throws {
    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let bundle = try decoder.decode(_ExportBundle.self, from: data)

    var exerciseByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Exercise>())).map { ($0.id, $0) })
    var workoutByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<Workout>())).map { ($0.id, $0) })
    var workoutExerciseByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<WorkoutExercise>())).map { ($0.id, $0) })
    var setByID = Dictionary(uniqueKeysWithValues: (try context.fetch(FetchDescriptor<ExerciseSet>())).map { ($0.id, $0) })

    for dto in bundle.exercises {
        if let ex = exerciseByID[dto.id] {
            ex.name = dto.name
            ex.muscleGroup = MuscleGroup(rawValue: dto.muscleGroup) ?? ex.muscleGroup
            ex.equipment = Equipment(rawValue: dto.equipment) ?? ex.equipment
            ex.notes = dto.notes
            ex.isCustom = dto.isCustom
        } else {
            let ex = Exercise(id: dto.id, name: dto.name, muscleGroup: MuscleGroup(rawValue: dto.muscleGroup) ?? .chest, equipment: Equipment(rawValue: dto.equipment) ?? .barbell, notes: dto.notes, isCustom: dto.isCustom)
            context.insert(ex)
            exerciseByID[dto.id] = ex
        }
    }

    for w in bundle.workouts {
        let workout: Workout
        if let existing = workoutByID[w.id] {
            existing.date = w.date
            existing.duration = w.duration
            workout = existing
        } else {
            let new = Workout(id: w.id, date: w.date, name: nil, notes: nil, duration: w.duration)
            context.insert(new)
            workoutByID[w.id] = new
            workout = new
        }

        for we in w.exercises {
            guard let ex = exerciseByID[we.exerciseID] else { continue }
            let workoutExercise: WorkoutExercise
            if let existing = workoutExerciseByID[we.id] {
                existing.order = we.order
                existing.exerciseName = we.exerciseName ?? ex.name
                existing.workout = workout
                existing.exercise = ex
                workoutExercise = existing
            } else {
                let new = WorkoutExercise(id: we.id, order: we.order, exerciseName: we.exerciseName ?? ex.name, workout: workout, exercise: ex)
                context.insert(new)
                workoutExerciseByID[we.id] = new
                workoutExercise = new
            }

            for s in we.sets {
                if let existing = setByID[s.id] {
                    existing.setNumber = s.setNumber
                    existing.reps = s.reps
                    existing.weight = s.weight
                    existing.isComplete = s.isComplete
                    existing.workoutExercise = workoutExercise
                } else {
                    let new = ExerciseSet(id: s.id, setNumber: s.setNumber, reps: s.reps, weight: s.weight, unit: .lbs, isComplete: s.isComplete, workoutExercise: workoutExercise)
                    context.insert(new)
                    setByID[s.id] = new
                }
            }
        }
    }

    try context.save()
}
