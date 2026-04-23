//
//  ExerciseLibraryView.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//

import SwiftUI
import SwiftData

// MARK: - Exercise Library View

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup? = nil
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: Exercise? = nil

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

                if filteredExercises.isEmpty {
                    ContentUnavailableView(
                        "No Exercises Found",
                        systemImage: "dumbbell",
                        description: Text("Try a different search or filter.")
                    )
                } else {
                    List {
                        ForEach(filteredExercises) { exercise in
                            ExerciseRow(exercise: exercise)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    exerciseToEdit = exercise
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        deleteExercise(exercise)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        exerciseToEdit = exercise
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
            .sheet(item: $exerciseToEdit) { exercise in
                EditExerciseView(exercise: exercise)
            }
        }
    }

    private func deleteExercise(_ exercise: Exercise) {
        modelContext.delete(exercise)
        try? modelContext.save()
    }
}

// MARK: - Muscle Group Filter Bar

struct MuscleGroupFilterBar: View {
    @Binding var selected: MuscleGroup?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    isSelected: selected == nil
                ) {
                    selected = nil
                }

                ForEach(MuscleGroup.allCases, id: \.self) { group in
                    FilterChip(
                        title: group.rawValue,
                        isSelected: selected == group
                    ) {
                        selected = selected == group ? nil : group
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(exercise.name)
                .font(.body)

            HStack(spacing: 6) {
                Text(exercise.muscleGroup.rawValue)
                Text("·")
                Text(exercise.equipment.rawValue)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Exercise View

struct AddExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var onSave: ((Exercise) -> Void)? = nil

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var notes = ""
    @State private var showingNameError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Cable Fly", text: $name)
                        .autocorrectionDisabled()
                }

                Section("Details") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }

                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Any notes about this exercise", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Name Required", isPresented: $showingNameError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a name for the exercise.")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showingNameError = true
            return
        }

        let exercise = Exercise(
            name: trimmed,
            muscleGroup: muscleGroup,
            equipment: equipment,
            notes: notes.isEmpty ? nil : notes,
            isCustom: true
        )
        modelContext.insert(exercise)
        try? modelContext.save()
        onSave?(exercise)
        dismiss()
    }
}

// MARK: - Edit Exercise View

struct EditExerciseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let exercise: Exercise

    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var equipment: Equipment
    @State private var notes: String
    @State private var showingNameError = false

    init(exercise: Exercise) {
        self.exercise = exercise
        _name = State(initialValue: exercise.name)
        _muscleGroup = State(initialValue: exercise.muscleGroup)
        _equipment = State(initialValue: exercise.equipment)
        _notes = State(initialValue: exercise.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Exercise name", text: $name)
                        .autocorrectionDisabled()
                }

                Section("Details") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }

                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases, id: \.self) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                }

                Section("Notes (optional)") {
                    TextField("Any notes about this exercise", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Name Required", isPresented: $showingNameError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Please enter a name for the exercise.")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            showingNameError = true
            return
        }

        exercise.name = trimmed
        exercise.muscleGroup = muscleGroup
        exercise.equipment = equipment
        exercise.notes = notes.isEmpty ? nil : notes
        try? modelContext.save()
        dismiss()
    }
}
