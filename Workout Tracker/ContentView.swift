//
//  ContentView.swift
//  Workout Tracker
//
//  Created by Wesley Imundo on 4/1/26.
//
 
import SwiftUI
 
struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
 
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }
 
            StartView()
                .tabItem {
                    Label("Start", systemImage: "play.circle.fill")
                }
 
            ExerciseLibraryView()
                .tabItem {
                    Label("Exercises", systemImage: "dumbbell")
                }
 
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
 
