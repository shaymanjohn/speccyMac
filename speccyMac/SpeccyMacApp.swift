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
    // The emulator machine lives for the lifetime of the view.
    @State private var machine: Machine = Spectrum()
    @State private var displayMode: MetalScreenView.DisplayMode = .crisp
    @State private var showingImporter = false
    // Tracks the built-in game chosen from the Games menu (nil when a game was
    // loaded via drag-drop or the file importer, i.e. not in the built-in list).
    @State private var selectedGameFile: String?

    // Built-in games, sorted by display name.
    private var games: [Game] {
        machine.games.sorted { $0.name < $1.name }
    }

    // Content types the file importer accepts (.sna / .z80).
    private var importableTypes: [UTType] {
        SupportedGameTypes.allCases.compactMap {
            UTType(filenameExtension: $0.rawValue)
        }
    }

    var body: some View {
        EmulatorView(machine: machine, displayMode: displayMode)
            .frame(minWidth: 320, minHeight: 288)
            .toolbar {
                ToolbarItemGroup {
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
    }

    // MARK: - Game loading

    private func loadBuiltIn(_ game: Game) {
        if let url = Bundle.main.url(forResource: game.file, withExtension: "") {
            machine.loadGame(url)
        }
    }

    private func loadCustom(_ url: URL) {
        // Harmless when not sandboxed; required if the sandbox is enabled later.
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        machine.loadGame(url)
        // Loaded game isn't in the built-in list, so clear the menu tick.
        selectedGameFile = nil
    }
}
