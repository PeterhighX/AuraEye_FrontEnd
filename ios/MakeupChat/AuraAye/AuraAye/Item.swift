//
//  Item.swift
//  AuraAye
//
//  Created by xlzj on 2026/7/1.
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
