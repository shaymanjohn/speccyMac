//
//  Z80Loader.swift
//  speccyMac
//
//  Created by hippietrail on 20/08/2022.
//

import Foundation

class Z80Loader: GameLoaderProtocol {
    
    let z80: ZilogZ80
    
    required init(z80: ZilogZ80) {
        self.z80 = z80
    }
    
    func load(data: Data) -> Bool {
        return false
    }
}
