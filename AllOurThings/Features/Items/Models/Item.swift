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
    var manualFilePath: String?

    // Image fields
    var imageData: Data?
    var imageFileName: String?
    var imageFilePath: String?

    init(name: String, manufacturer: String = "", modelNumber: String = "", category: String = "", purchaseDate: Date? = nil, warrantyExpirationDate: Date? = nil, location: String = "", notes: String = "", manualText: String? = nil, manualFileName: String? = nil, manualFilePath: String? = nil, imageData: Data? = nil, imageFileName: String? = nil, imageFilePath: String? = nil) {
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
        self.manualFilePath = manualFilePath
        self.imageData = imageData
        self.imageFileName = imageFileName
        self.imageFilePath = imageFilePath
        self.timestamp = Date()
    }

    // MARK: - Computed Properties

    var contextDescription: String {
        var itemInfo = "- \(name)"

        if !category.isEmpty {
            itemInfo += " (Category: \(category))"
        }
        if !manufacturer.isEmpty {
            itemInfo += " by \(manufacturer)"
        }
        if !location.isEmpty {
            itemInfo += " located in \(location)"
        }
        if let warrantyDate = warrantyExpirationDate {
            itemInfo += " (Warranty expires: \(warrantyDate.formatted(date: .abbreviated, time: .omitted)))"
        }
        if !notes.isEmpty {
            itemInfo += " (Notes: \(notes))"
        }
        if let manualText = manualText, !manualText.isEmpty {
            itemInfo += "\n  Manual documentation:\n\(manualText)"
        }

        return itemInfo
    }
}
