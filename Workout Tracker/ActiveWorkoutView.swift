import SwiftUI
import SwiftData

// MARK: - In-memory models for active session

struct ActiveSet: Identifiable {
    var id = UUID()
    var setNumber: Int
    var reps: Int = 0
    var weight: Double = 0
    var isComplete: Bool = false
}

struct ActiveExercise: Identifiable {
    var id = UUID()
    var exercise: Exercise
    var order: Int
    var sets: [ActiveSet] = []

    var sortedSets: [ActiveSet] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }

    var nextSetNumber: Int {
        (sets.map { $0.setNumber }.max() ?? 0) + 1
    }
}

// MARK: - Start Tab View

struct StartView: View {
    @State private var showingWorkout = false
    @State private var workoutName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 64))
                    .foregroundStyle(Color.accentColor)

                VStack(spacing: 8) {
                    Text("Ready to train?")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Start a new workout session.")
                        .foregroundStyle(.secondary)
                }

                TextField("Workout name (optional)", text: $workoutName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 32)
                    .focused($isTextFieldFocused)

                Button {
                    showingWorkout = true
                } label: {
                    Text("Start Workout")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .navigationTitle("Start")
            .contentShape(Rectangle())
            .onTapGesture {
                isTextFieldFocused = false
            }
            .fullScreenCover(isPresented: $showingWorkout, onDismiss: {
                workoutName = ""
            }) {
                ActiveWorkoutView(initialName: workoutName)
            }
        }
    }
}

// MARK: - Active Workout View

struct ActiveWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue

    var initialName: String = ""

    @State private var exercises: [ActiveExercise] = []
    @State private var showingExercisePicker = false
    @State private var showingFinishAlert = false
    @State private var showingDiscardAlert = false
    @State private var startDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                if exercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises Yet",
                        systemImage: "plus.circle",
                        description: Text("Tap Add Exercise to get started.")
                    )
                } else {
                    List {
                        ForEach($exercises) { $activeExercise in
                            ActiveExerciseSection(
                                activeExercise: $activeExercise,
                                onDelete: {
                                    exercises.removeAll { $0.id == activeExercise.id }
                                }
                            )
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle(workoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") {
                        showingDiscardAlert = true
                    }
                    .foregroundStyle(.red)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Finish") {
                        showingFinishAlert = true
                    }
                    .fontWeight(.semibold)
                }

                ToolbarItem(placement: .bottomBar) {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { exercise in
                    let activeExercise = ActiveExercise(
                        exercise: exercise,
                        order: exercises.count
                    )
                    exercises.append(activeExercise)
                }
            }
            .alert("Finish Workout?", isPresented: $showingFinishAlert) {
                Button("Finish") { finishWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will save your workout.")
            }
            .alert("Discard Workout?", isPresented: $showingDiscardAlert) {
                Button("Discard", role: .destructive) {
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your workout will not be saved.")
            }
            .onAppear {
                startDate = Date()
            }
        }
    }

    // MARK: - Computed

    var workoutTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: startDate)
    }

    // MARK: - Finish: write everything to SwiftData at once

    private func finishWorkout() {
        let preferredUnit = WeightUnit(rawValue: weightUnitRaw) ?? .lbs
        let workout = Workout(
            date: startDate,
            name: initialName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : initialName.trimmingCharacters(in: .whitespaces),
            duration: Date().timeIntervalSince(startDate)
        )
        modelContext.insert(workout)

        for (i, activeExercise) in exercises.enumerated() {
            let workoutExercise = WorkoutExercise(
                            order: i,
                            exerciseName: activeExercise.exercise.name,
                            workout: workout,
                            exercise: activeExercise.exercise
                        )
            modelContext.insert(workoutExercise)

            for activeSet in activeExercise.sets {
                let set = ExerciseSet(
                    setNumber: activeSet.setNumber,
                    reps: activeSet.reps,
                    weight: activeSet.weight,
                    isComplete: activeSet.isComplete,
                    workoutExercise: workoutExercise
                )
                modelContext.insert(set)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Active Exercise Section

struct ActiveExerciseSection: View {
    @Binding var activeExercise: ActiveExercise
    let onDelete: () -> Void

    @AppStorage("weightUnit") private var weightUnitRaw: String = WeightUnit.lbs.rawValue

    var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRaw) ?? .lbs
    }

    var body: some View {
        Section {
            ForEach($activeExercise.sets) { $set in
                ActiveSetRow(
                    set: $set,
                    weightUnit: weightUnit
                )
            }

            Button {
                let newSet = ActiveSet(
                    setNumber: activeExercise.nextSetNumber,
                    reps: activeExercise.sets.last?.reps ?? 0,
                    weight: activeExercise.sets.last?.weight ?? 0
                )
                activeExercise.sets.append(newSet)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }

        } header: {
            HStack {
                Text(activeExercise.exercise.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .textCase(nil)

                Spacer()

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Active Set Row

struct ActiveSetRow: View {
    @Binding var set: ActiveSet
    let weightUnit: WeightUnit

    @State private var showingEditSheet = false

    var body: some View {
        Button {
            showingEditSheet = true
        } label: {
            HStack {
                Text("Set \(set.setNumber)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                Spacer()

                if set.reps > 0 || set.weight > 0 {
                    Text("\(set.weight.formatted()) \(weightUnit.rawValue) x \(set.reps)")
                        .font(.subheadline)
                        .foregroundStyle(set.isComplete ? .primary : .secondary)
                } else {
                    Text("Tap to log")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: set.isComplete ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(set.isComplete ? .green : Color(.systemGray4))
                    .font(.title3)
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            EditSetView(set: $set, weightUnit: weightUnit)
        }
    }
}

// MARK: - Edit Set View

struct EditSetView: View {
    @Binding var set: ActiveSet
    let weightUnit: WeightUnit

    @Environment(\.dismiss) private var dismiss

    @State private var weight: Double
    @State private var reps: Int

    init(set: Binding<ActiveSet>, weightUnit: WeightUnit) {
        _set = set
        self.weightUnit = weightUnit
        _weight = State(initialValue: set.wrappedValue.weight)
        _reps = State(initialValue: set.wrappedValue.reps > 0 ? set.wrappedValue.reps : 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight (\(weightUnit.rawValue))") {
                    HStack {
                        Button {
                            if weight >= 2.5 { weight -= 2.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(weight.formatted())
                            .font(.title)
                            .fontWeight(.semibold)
                            .monospacedDigit()

                        Spacer()

                        Button {
                            weight += 2.5
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 8) {
                        ForEach([5.0, 10.0, 25.0, 45.0], id: \.self) { plate in
                            Button("+\(Int(plate))") {
                                weight += plate
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(Capsule())
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("Reps") {
                    HStack {
                        Button {
                            if reps > 1 { reps -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text("\(reps)")
                            .font(.title)
                            .fontWeight(.semibold)
                            .monospacedDigit()

                        Spacer()

                        Button {
                            reps += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Set \(set.setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button {
                        save()
                    } label: {
                        Label("Log Set", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        set.weight = weight
        set.reps = reps
        set.isComplete = true
        dismiss()
    }
}

// MARK: - Exercise Picker View

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    let onSelect: (Exercise) -> Void

        @State private var searchText = ""
        @State private var selectedMuscleGroup: MuscleGroup? = nil
        @State private var showingAddExercise = false

    var filteredExercises: [Exercise] {
        exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty ||
                exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesMuscleGroup = selectedMuscleGroup == nil ||
                exercise.muscleGroup == selectedMuscleGroup
            return matchesSearch && matchesMuscleGroup
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MuscleGroupFilterBar(selected: $selectedMuscleGroup)

                List(filteredExercises) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        ExerciseRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { dismiss() }
                            }
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    showingAddExercise = true
                                } label: {
                                    Image(systemName: "plus")
                                }
                            }
                        }
                        .sheet(isPresented: $showingAddExercise) {
                            AddExerciseView(onSave: { exercise in
                                onSelect(exercise)
                                dismiss()
                            })
                        }
        }
    }
}

