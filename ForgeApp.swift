//
//  ForgeApp.swift
//  Forge
//
//  Created by Ryan Div on 2023-06-25.
//

import SwiftUI

@main
struct ForgeApp: App {
    var body: some Scene {
        WindowGroup {
            CompletedWorkoutsView()
                .environmentObject(CompletedWorkoutsViewModel(mockCompletedWorkouts: createMockCompletedWorkouts(workoutCount: 2, exercisesPerWorkout: 2)))
                .environmentObject(PlanViewModel(mockPlans: createMockWorkoutPlans(workoutCount: 2, exercisesPerWorkout: 2)))
                .environmentObject(ExerciseViewModel())
                .environment(\.colorScheme, .dark)
        }
    }
}
