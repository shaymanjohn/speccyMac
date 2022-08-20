//
//  GameLoaderProtocol.swift
//  speccyMac
//
//  Created by John Ward on 20/08/2022.
//  Copyright © 2022 John Ward. All rights reserved.
//

import Foundation

protocol GameLoaderProtocol {    
    init(z80: ZilogZ80)
    func load(data: Data) -> Bool
}
