//
//  Item.swift
//  AllOurThings
//
//  Created by Matt on 28/12/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var name: String
    var manufacturer: String
    var modelNumber: String
    var category: String
    var purchaseDate: Date?
    var warrantyExpirationDate: Date?
    var location: String
    var notes: String
    var timestamp: Date

    // Manual/Documentation fields
    var manualText: String?
    var manualFileName: String?

    init(name: String, manufacturer: String = "", modelNumber: String = "", category: String = "", purchaseDate: Date? = nil, warrantyExpirationDate: Date? = nil, location: String = "", notes: String = "", manualText: String? = nil, manualFileName: String? = nil) {
        self.name = name
        self.manufacturer = manufacturer
        self.modelNumber = modelNumber
        self.category = category
        self.purchaseDate = purchaseDate
        self.warrantyExpirationDate = warrantyExpirationDate
        self.location = location
        self.notes = notes
        self.manualText = manualText
        self.manualFileName = manualFileName
        self.timestamp = Date()
    }
}
