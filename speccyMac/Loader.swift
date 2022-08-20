//
//  Loader.swift
//  speccyMac
//
//  Created by John Ward on 21/07/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Foundation

enum SupportedGameTypes: String, CaseIterable {
    case SNA = "sna"
    case Z80 = "z80"
    
    var loader: GameLoaderProtocol.Type {
        switch self {
        case .SNA:
            return SNALoader.self
        case .Z80:
            return Z80Loader.self
        }
    }
}

class Loader {
    
    init?(_ game: String, z80: ZilogZ80) {
        let gameType = (game as NSString).pathExtension.lowercased()
        
        guard let gameType = SupportedGameTypes.allCases.first(where: { $0.rawValue == gameType }) else {
            return nil
        }
        
        guard let gameUrl = Bundle.main.url(forResource: game, withExtension: ""),
              let gameData = try? Data.init(contentsOf: gameUrl) else {
            return nil
        }
        
        let gameLoader = gameType.loader.init(z80: z80)
        
        if gameLoader.load(data: gameData) {
            z80.counter = 0
            z80.lateFrames = 0
            z80.halted = false
        } else {
            return nil
        }
    }
}
