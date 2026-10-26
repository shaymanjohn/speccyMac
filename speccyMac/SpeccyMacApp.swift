//
//  SpeccyMacApp.swift
//  speccyMac
//
//  SwiftUI entry point. Replaces the Main.storyboard launch. Owns the
//  emulator machine instance and the selected display mode, and hosts the
//  emulator via the EmulatorView representable.
//

import SwiftUI
import UniformTypeIdentifiers

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
    // Supported machine models. 48K is the default.
    enum Model: String, CaseIterable, Identifiable {
        case spectrum48 = "48K"
        case spectrum128 = "128K"
        var id: String { rawValue }
    }

    @State private var model: Model = .spectrum48
    // The emulator machine lives for the lifetime of the view.
    @State private var machine: Machine = Spectrum()
    @State private var displayMode: MetalScreenView.DisplayMode = .crisp
    @State private var showingImporter = false
    // Tracks the built-in game chosen from the Games menu (nil when a game was
    // loaded via drag-drop or the file importer, i.e. not in the built-in list).
    @State private var selectedGameFile: String?
    // Tape transport state, mirrored for the toolbar control.
    @State private var tapeLoaded = false
    @State private var tapePlaying = false
    // Fast tape loading (uncapped emulation while a tape plays).
    @State private var fastLoad = true

    // Built-in games, sorted by display name.
    private var games: [Game] {
        machine.games.sorted { $0.name < $1.name }
    }

    // Content types the file importer accepts (.sna / .z80 / .tap / .tzx / .zip).
    private var importableTypes: [UTType] {
        var types = SupportedGameTypes.allCases.compactMap {
            UTType(filenameExtension: $0.rawValue)
        }
        if let zip = UTType(filenameExtension: "zip") {
            types.append(zip)
        }
        return types
    }

    var body: some View {
        EmulatorView(machine: machine, displayMode: displayMode)
            .frame(minWidth: 320, minHeight: 288)
            .toolbar {
                ToolbarItemGroup {
                    Menu("Model") {
                        Picker("Model", selection: $model) {
                            ForEach(Model.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Menu("Games") {
                        Picker("Games", selection: $selectedGameFile) {
                            ForEach(games, id: \.file) { game in
                                Text(game.name).tag(game.file as String?)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }

                    Button("Load…") { showingImporter = true }

                    Button("Reset") {
                        machine.resetMachine()
                        selectedGameFile = nil
                        refreshTapeState()
                    }

                    Button(tapePlaying ? "Stop Tape" : "Play Tape") {
                        if tapePlaying {
                            machine.stopTape()
                        } else {
                            machine.playTape()
                        }
                        tapePlaying = machine.tapePlaying
                    }
                    .disabled(!tapeLoaded)

                    Toggle("Fast Load", isOn: $fastLoad)
                        .onChange(of: fastLoad) { _, newValue in
                            machine.fastLoad = newValue
                        }

                    Menu("Display") {
                        Picker("Display", selection: $displayMode) {
                            ForEach(MetalScreenView.DisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .fileImporter(isPresented: $showingImporter,
                          allowedContentTypes: importableTypes) { result in
                if case .success(let url) = result {
                    loadCustom(url)
                }
            }
            .onChange(of: selectedGameFile) { _, newValue in
                if let file = newValue,
                   let game = games.first(where: { $0.file == file }) {
                    loadBuiltIn(game)
                }
            }
            .onChange(of: model) { _, newModel in
                // Stop the outgoing machine's emulation thread, then swap in a
                // fresh machine for the new model. EmulatorView.updateNSView
                // detects the new machine instance and re-wires the existing
                // views to it (no view rebuild).
                machine.processor.stop()
                switch newModel {
                case .spectrum48:  machine = Spectrum()
                case .spectrum128: machine = Spectrum128()
                }
                selectedGameFile = nil
                tapeLoaded = false
                tapePlaying = false
            }
            .task {
                // Keep the toolbar's tape state in sync with the deck. This
                // covers paths that don't call refreshTapeState() directly -
                // notably drag-and-drop loading, which goes through the Metal
                // view's drag delegate - and the deck stopping on its own at
                // the end of a tape (on the emulation thread).
                while !Task.isCancelled {
                    let playing = machine.tapePlaying
                    if playing != tapePlaying {
                        tapePlaying = playing
                    }
                    let loaded = machine.tapeLoaded
                    if loaded != tapeLoaded {
                        tapeLoaded = loaded
                    }
                    try? await Task.sleep(nanoseconds: 300_000_000)  // 0.3s
                }
            }
    }

    // MARK: - Game loading

    private func loadBuiltIn(_ game: Game) {
        if let url = Bundle.main.url(forResource: game.file, withExtension: "") {
            machine.loadGame(url)
            refreshTapeState()
        }
    }

    private func loadCustom(_ url: URL) {
        // Harmless when not sandboxed; required if the sandbox is enabled later.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        machine.loadGame(url)
        // Loaded game isn't in the built-in list, so clear the menu tick.
        selectedGameFile = nil
        refreshTapeState()
    }

    private func refreshTapeState() {
        tapeLoaded = machine.tapeLoaded
        tapePlaying = machine.tapePlaying
    }
}
