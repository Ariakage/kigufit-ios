//
//  Item.swift
//  KiguFit
//
//  Created by Ariakage on 2026/9/23.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
