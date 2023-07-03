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
                .environmentObject(CompletedWorkoutsViewModel())
                .environmentObject(PlanViewModel())
                .environmentObject(ExerciseViewModel())
                .environmentObject(StopwatchViewModel())
                .environment(\.colorScheme, .dark)
        }
    }
}
