import Foundation
import SwiftData

// MARK: - Manual Topic Bullet Model

@Model
final class ManualTopicBullet {
    var id: UUID
    var itemId: UUID
    var topicRaw: String
    var text: String
    var pageNumber: Int
    var bulletIndex: Int
    var timestamp: Date

    init(
        itemId: UUID,
        topicRaw: String,
        text: String,
        pageNumber: Int,
        bulletIndex: Int
    ) {
        self.id = UUID()
        self.itemId = itemId
        self.topicRaw = topicRaw
        self.text = text
        self.pageNumber = pageNumber
        self.bulletIndex = bulletIndex
        self.timestamp = Date()
    }

    var topic: ManualTopic? {
        ManualTopic(rawValue: topicRaw)
    }
}
