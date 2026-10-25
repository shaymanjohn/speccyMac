//
//  SpeccyMacApp.swift
//  speccyMac
//
//  SwiftUI entry point. Replaces the Main.storyboard launch. Owns the
//  emulator machine instance and the selected display mode, and hosts the
//  emulator via the EmulatorView representable.
//

import SwiftUI

@main
struct SpeccyMacApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    // The emulator machine lives for the lifetime of the view.
    @State private var machine: Machine = Spectrum()
    @State private var displayMode: MetalScreenView.DisplayMode = .crisp

    var body: some View {
        VStack(spacing: 0) {
            EmulatorView(machine: machine, displayMode: displayMode)
                .frame(minWidth: 320, minHeight: 288)

            HStack {
                Picker("Display", selection: $displayMode) {
                    Text("Crisp").tag(MetalScreenView.DisplayMode.crisp)
                    Text("Smooth").tag(MetalScreenView.DisplayMode.smooth)
                    Text("Scanlines").tag(MetalScreenView.DisplayMode.scanlines)
                    Text("CRT").tag(MetalScreenView.DisplayMode.crt)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Spacer()
            }
            .padding(8)
        }
    }
}
