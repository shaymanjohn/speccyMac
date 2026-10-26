//
//  EmulatorView.swift
//  speccyMac
//
//  SwiftUI host for the emulator. Wraps the AppKit input view (keyboard) and
//  the Metal rendering view so the emulator can live inside a SwiftUI scene.
//  The emulation core and Metal renderer are unchanged; this just bridges them
//  into SwiftUI via NSViewRepresentable.
//

import SwiftUI

struct EmulatorView: NSViewRepresentable {

    let machine: Machine
    var displayMode: MetalScreenView.DisplayMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> EmulatorInputView {
        // The input view is the first responder and owns keyboard handling.
        let inputView = EmulatorInputView(frame: .zero)
        inputView.wantsLayer = true
        inputView.layer?.backgroundColor = NSColor.black.cgColor

        // Metal rendering view pinned to fill the input view.
        let metal = MetalScreenView(frame: inputView.bounds, device: nil)
        metal.translatesAutoresizingMaskIntoConstraints = false
        metal.dragDelegate = context.coordinator
        inputView.addSubview(metal)
        NSLayoutConstraint.activate([
            metal.leadingAnchor.constraint(equalTo: inputView.leadingAnchor),
            metal.trailingAnchor.constraint(equalTo: inputView.trailingAnchor),
            metal.topAnchor.constraint(equalTo: inputView.topAnchor),
            metal.bottomAnchor.constraint(equalTo: inputView.bottomAnchor)
        ])

        // Wire the emulator to the input and rendering views, then start it.
        machine.emulatorView = inputView
        machine.metalView = metal
        machine.start()

        context.coordinator.machine = machine
        context.coordinator.metalView = metal

        metal.setDisplayMode(displayMode)
        return inputView
    }

    func updateNSView(_ nsView: EmulatorInputView, context: Context) {
        // If the machine instance changed (e.g. a 48K/128K model switch), re-wire
        // the existing input and Metal views to the new machine and start it,
        // reusing the same views rather than rebuilding them. Recreating the
        // MTKView via a SwiftUI `.id` rebuild left the new view not presenting.
        if context.coordinator.machine !== machine {
            machine.emulatorView = nsView
            if let metal = context.coordinator.metalView {
                machine.metalView = metal
            }
            machine.start()
            context.coordinator.machine = machine
        }

        // Reflect SwiftUI state changes (e.g. display-mode picker) into the view.
        context.coordinator.metalView?.setDisplayMode(displayMode)
    }

    // Coordinator bridges drag-and-drop game loading back to the machine.
    final class Coordinator: DragDelegate {
        weak var machine: (any Machine)?
        weak var metalView: MetalScreenView?

        func loadGame(_ fileUrl: URL) {
            machine?.loadGame(fileUrl)
        }
    }
}
