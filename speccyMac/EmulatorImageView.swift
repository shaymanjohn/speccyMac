//
//  EmulatorImageView.swift
//  speccyMac
//
//  Created by John Ward on 26/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class EmulatorImageView: NSImageView {

    var modeIndex = 1
    let allImageModes: [NSImageInterpolation] = [.none, .low, .medium, .high]
    
    weak var dragDelegate: DragDelegate?

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = allImageModes[modeIndex]
        super.draw(dirtyRect)
    }

    func changeImageMode() {
        modeIndex += 1
        if modeIndex > allImageModes.count - 1 {
            modeIndex = 0
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)

        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
           let paths = board as? [String],
           let path = paths.first {
            
            let fileExtension = (path as NSString).pathExtension.lowercased()
            if SupportedGameTypes.allCases.first(where: { $0.rawValue == fileExtension }) != nil {
                return .copy
            }
        }
        
        return []
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray,
           let filePath = board.firstObject as? String {
            dragDelegate?.loadGame("file://" + filePath)
            return true
        }
        
        return false
    }
}
