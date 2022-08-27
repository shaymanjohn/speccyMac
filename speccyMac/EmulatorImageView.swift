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
        
        // is it possible to get the file contents directly in a drag? or a URL?
        registerForDraggedTypes([.fileURL, .fileContents, .URL])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        print("HIPP drag enter")
        // I can't get this to work with .fileContents or .URL for registered drag types
        // probably because NSFilenamesPboardType specifically means .fileURL
        // but then why is it a string and not an URL as its name implies?
        // I think maybe because the code I found is using converters from old Cocoa methods to new ones?
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray, let paths = board as? [String] {//}, let urls = board as? [URL] {

            //print("paths count, urls count:", paths.count, urls.count)
            // it doesn't make sense to load two snapshots, so take the first one
            // or we could take the first valid one?
            if paths.count != 1 {
                return []
            }
            
            let path = paths[0]
            
            let url = NSURL(fileURLWithPath: path)
            if let fileExtension = url.pathExtension?.lowercased() {
                // there are no trivial checks on these types
                if ["z80", "zip"].contains(fileExtension) {
                    return .copy
                }

                // 48k .sna can only be one size
                if (fileExtension == "sna") {
                    do {
                        // I can't get .fileSizeKey to work
                        let resVals = try url.resourceValues(forKeys: [.fileSizeKey])

                        if case let size as Int = resVals[.fileSizeKey], size == 49179 {
                            return .copy
                        }
                    } catch {
                        print("error:", error)
                    }
                }
            }
        }
        
        return []
    }
    
    // dragANDdrop exmple app uses draggingUpdated but not prepareForDragOperation

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("HIPP prepare drag")
        return true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        print("HIPP perform")
        if let board = sender.draggingPasteboard.propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")) as? NSArray, let filePath = board[0] as? String {
            // why can't I get URL to work above?
            
            print("dropped:", filePath)

            return true
        }
        return false
    }

}
