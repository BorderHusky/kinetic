import Foundation

extension Array where Element == Exercise {
    func filtered(searchText: String, muscleGroup: MuscleGroup?) -> [Exercise] {
        filter { exercise in
            let matchesSearch = searchText.isEmpty || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesMuscleGroup = muscleGroup == nil || exercise.muscleGroup == muscleGroup
            return matchesSearch && matchesMuscleGroup
        }
    }
}
