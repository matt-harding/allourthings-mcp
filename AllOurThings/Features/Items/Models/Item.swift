//
//  Item.swift
//  AllOurThings
//
//  Created by Matt on 28/12/2025.
//

import Foundation
import SwiftData

// MARK: - Item Model

@Model
final class Item {
    var id: UUID
    var name: String
    var manufacturer: String
    var modelNumber: String
    var serialNumber: String
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
    var photoFilePaths: [String]
    var leadPhotoPath: String?

    init(name: String, manufacturer: String = "", modelNumber: String = "", serialNumber: String = "", category: String = "", purchaseDate: Date? = nil, warrantyExpirationDate: Date? = nil, location: String = "", notes: String = "", manualText: String? = nil, manualFileName: String? = nil, manualFilePath: String? = nil, imageData: Data? = nil, imageFileName: String? = nil, imageFilePath: String? = nil, photoFilePaths: [String] = [], leadPhotoPath: String? = nil) {
        self.id = UUID()
        self.name = name
        self.manufacturer = manufacturer
        self.modelNumber = modelNumber
        self.serialNumber = serialNumber
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
        self.photoFilePaths = photoFilePaths
        self.leadPhotoPath = leadPhotoPath
        self.timestamp = Date()
    }
}
