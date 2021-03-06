//
//  Array+extensions.swift
//  speccyMac
//
//  Created by John Ward on 02/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

extension Array {
    
    subscript(_ ix: UInt8) -> Element {
        return self[Int(ix)]
    }
    
    subscript(_ ix: UInt16) -> Element {
        return self[Int(ix)]
    }
}

extension ContiguousArray {

    subscript(_ ix: UInt8) -> Element {
        return self[Int(ix)]
    }

    subscript(_ ix: UInt16) -> Element {
        return self[Int(ix)]
    }
}
