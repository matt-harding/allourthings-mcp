# AllOurThings

A household item management app with AI-powered assistance using Apple Intelligence.

## Overview

AllOurThings helps you organize and manage your household items with a cosy, pixel-art inspired interface. Upload item manuals, ask questions about your items, and get intelligent responses with citations directly from your documentation.

## Key Features

### 📦 Item Management
- **Item Catalog**: Store comprehensive details about household items including:
  - Name, manufacturer, model number
  - Category and location
  - Purchase date and warranty expiration
  - Custom notes
  - Pixel-art style images
  - PDF manuals with text extraction

### 💬 Apple Intelligence Chat
- **On-Device AI**: Powered by Apple's FoundationModels framework (iOS 26.0+)
- **Context-Aware**: AI has access to all your items and their documentation
- **Citation System**: Automatically links page references to PDF manuals
  - AI responses include citations like "(page 5)" or "(pages 12-15)"
  - Tap citations to instantly view the referenced manual page
- **Privacy-First**: All processing happens on-device, no data leaves your iPhone

### 📄 PDF Manual Integration
- **Upload & Extract**: Attach PDF manuals to items with automatic text extraction
- **Page-Level Navigation**: Jump directly to specific pages via citations
- **Smart Search**: Manual text is indexed and searchable by Apple Intelligence

### 🎨 Cosy Design
- Warm, videogame-inspired pixel-art aesthetic
- Retro color palette (sky blue, warm cream, blush pink, peach)
- Monospaced fonts and thick borders
- Soft shadows and consistent rounded corners

## Architecture

### Tech Stack
- **Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **AI**: Apple FoundationModels (SystemLanguageModel)
- **PDF Handling**: PDFKit
- **Storage**: iOS Keychain (future secure storage)

### Project Structure

```
AllOurThings/
├── App/
│   ├── AllOurThingsApp.swift          # App entry point
│   ├── ContentView.swift               # Tab navigation (Items, Chat)
│   └── Constants.swift                 # Configuration & constants
├── Features/
│   ├── Chat/
│   │   └── Views/
│   │       └── AppleIntelligenceChatView.swift  # AI chat interface
│   ├── Items/
│   │   ├── Models/
│   │   │   └── Item.swift              # Item data model
│   │   └── Views/
│   │       ├── ItemListView.swift      # Item list & grid
│   │       └── AddEditItemView.swift   # Item creation/editing
│   └── PDF/
│       ├── Views/
│       │   └── PDFViewerView.swift     # Manual viewer with page nav
│       └── Services/
│           ├── PDFStorageHelper.swift  # PDF file management
│           └── PDFTextExtractor.swift  # Text extraction from PDFs
├── Design/
│   └── Theme.swift                     # Colors, fonts, spacing
└── Utilities/
    ├── KeychainHelper.swift            # Secure storage helper
    ├── DocumentPicker.swift            # File picker utilities
    └── ImageStorageHelper.swift        # Image file management
```

## How It Works

### Item Context Building

When you ask a question, the chat system builds context from your items:

1. **Basic Information**: Name, category, manufacturer, location, warranty
2. **Notes**: Any custom notes you've added
3. **Manual Text**: Extracted text from PDF manuals (truncated to 2000 chars per item)

This context is sent with each message to help Apple Intelligence provide accurate, personalized answers.

### Citation System

The citation system works in three steps:

1. **AI Response**: Apple Intelligence is instructed to cite page numbers using the format `(page X)` or `(pages X-Y)`
2. **Parsing**: A regex pattern `\(pages? (\d+)(?:-(\d+))?\)` detects citations in responses
3. **Linking**: Citations become clickable links styled in blush pink with underline
4. **Navigation**: Tapping opens the PDF viewer at the specified page

**Example Flow:**
```
User: "What temperature should I set my oven to for roasting?"
AI: "For roasting vegetables, set to 425°F (page 12)."
[User taps "(page 12)"]
→ PDF viewer opens to page 12 of the oven manual
```

### Context Window Management

To prevent exceeding Apple Intelligence's context limits:

- **System Instructions**: Minimal, focused on citation formatting
- **Per-Message Context**: Item info is built fresh for each question
- **Manual Truncation**: Long manuals are limited to 2000 characters per item
- **Dynamic Loading**: Only relevant context is included per conversation

### Data Model

**Item** (SwiftData)
```swift
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

    // Documentation
    var manualText: String?        // Extracted PDF text
    var manualFileName: String?
    var manualFilePath: String?

    // Images
    var pixelArtImageData: Data?
    var pixelArtFileName: String?
    var pixelArtFilePath: String?
}
```

**ChatMessage**
```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let itemsWithManuals: [ItemManualReference]
}
```

## Requirements

- **iOS**: 26.0 or later
- **Device**: Compatible device with Apple silicon
- **Apple Intelligence**: Must be enabled in System Settings

## Apple Intelligence Availability States

The app gracefully handles various availability scenarios:

| State | Description | UI Response |
|-------|-------------|-------------|
| ✅ Available | AI ready and working | Full chat functionality |
| ⚠️ Model Not Ready | Model downloading/preparing | "Preparing..." status with yellow indicator |
| ❌ Not Enabled | AI disabled in Settings | Prompt to enable with Settings link |
| ❌ Device Not Eligible | Incompatible hardware | Clear explanation message |

## Privacy & Security

- **On-Device Processing**: All AI inference happens locally
- **No API Keys**: No external AI services or API calls
- **Secure Storage**: Keychain helper ready for future secure data
- **No Telemetry**: No usage data collected or transmitted

## Design Philosophy

**Cosy Pixel-Art Aesthetic**
- Inspired by retro videogames and 16-bit era UI
- Warm, welcoming color scheme avoids harsh corporate blues
- Monospaced fonts (SF Mono Rounded) for headers add character
- Thick borders (2-4px) and soft shadows create tactile feel
- Consistent rounded corners (2-6px) for organic shapes

**Color Palette**
```swift
Sky Blue:     #B8D8E8  // Soft backgrounds
Warm Cream:   #FCF7F0  // Primary backgrounds
Cloud White:  #FFFFFF  // Cards and containers
Blush Pink:   #FFB6C1  // Accents and CTAs
Peach:        #FFD4B0  // Secondary accents
Cocoa Brown:  #6B4423  // Primary text
Soft Gray:    #8C8C8C  // Secondary text
Soft Lavender:#E6D5F5  // Decorative elements
Butter Yellow:#F9E79F  // Highlights
Gentle Border:#E8D5C4  // Subtle dividers
Shadow Tint:  #C4A57B  // Depth and elevation
```

## Future Enhancements

Potential features for future development:

- **Maintenance Tracking**: Schedule and log maintenance tasks
- **Smart Reminders**: Warranty expiration notifications
- **Export/Backup**: Cloud sync or local backup options
- **Advanced Search**: Filter items by multiple criteria
- **Family Sharing**: Multi-user support
- **Receipt Scanning**: OCR for purchase receipts
- **Barcode Support**: Quick item lookup via UPC/EAN

## Development Notes

### Migration from Gemini

This app originally used Google's Gemini API but was migrated to Apple Intelligence for:
- Better privacy (on-device processing)
- No API keys required
- Tighter iOS ecosystem integration
- Consistent user experience

The citation parsing and PDF integration system was preserved during migration.

### Testing

When testing the chat functionality:
1. Ensure Apple Intelligence is enabled in Settings
2. Add items with PDF manuals for best results
3. Test citation links by asking manual-related questions
4. Verify context window limits with items containing large manuals

## License

[Your License Here]

## Contact

[Your Contact Information]

---

**Built with ❤️ using SwiftUI and Apple Intelligence**
