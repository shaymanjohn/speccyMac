//
//  GameSelectViewController.swift
//  speccyMac
//
//  Created by John Ward on 18/08/2017.
//  Copyright © 2017 John Ward. All rights reserved.
//

import Cocoa

class GameSelectViewController: NSViewController {
    
    weak var machine: Machine!
    var sortedGames: [Game] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sortedGames = machine.games.sorted(by: { (game1 : Game, game2 : Game) -> Bool in
            return game1.name < game2.name
        })
    }
}

extension GameSelectViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        
        return sortedGames.count
    }
}

extension GameSelectViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let game = sortedGames[row]
        let tf = NSTextField(labelWithString: game.name)        
        return tf
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        if let tv = notification.object as? NSTableView {
            if tv.selectedRow >= 0 {
                let selectedGame = sortedGames[tv.selectedRow]
                machine.loadGame(selectedGame.file)
                
                self.dismissViewController(self)
            }
        }
    }
}

