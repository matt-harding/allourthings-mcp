# AllOurThings

A household item management app with AI-powered assistance using Apple Intelligence and a ReAct agent architecture.

## Overview

AllOurThings helps you organize and manage your household items with a cosy, pixel-art inspired interface. Upload item manuals, ask questions about your items, and get intelligent responses with citations directly from your documentation.

The app uses a **ReAct (Reasoning and Acting) agent** powered by Apple Intelligence with specialized tools for searching items and retrieving manual information.

## Key Features

### 📦 Item Management
- **Item Catalog**: Store comprehensive details about household items including:
  - Name, manufacturer, model number
  - Category and location
  - Purchase date and warranty expiration
  - Custom notes
  - Pixel-art style images
  - PDF manuals with automatic section extraction

### 💬 Apple Intelligence Chat (ReAct Agent)
- **On-Device AI**: Powered by Apple's FoundationModels framework (iOS 18.2+)
- **Tool-Based Architecture**: AI uses specialized tools to access information:
  - `search_items` - Semantic search across your item collection
  - `list_manual_sections` - Lists available sections in an item's manual
  - `get_manual_section` - Retrieves full content of a specific section
  - `search_manual_sections` - Semantic search across all manual sections
- **Citation System**: Automatically links page references to PDF manuals
  - AI responses include citations like "(page 5)" or "(pages 12-15)"
  - Tap citations to instantly view the referenced manual page
- **Privacy-First**: All processing happens on-device, no data leaves your iPhone

### 📄 PDF Manual Integration
- **Upload & Extract**: Attach PDF manuals to items with automatic section detection
- **ManualSection Model**: PDFs are split into searchable sections with:
  - Section headings
  - Content text
  - Page numbers
  - Section ordering
- **Semantic Search**: Uses NLEmbedding for intelligent section retrieval
- **Page-Level Navigation**: Jump directly to specific pages via citations

### 🎨 Cosy Design
- Warm, videogame-inspired pixel-art aesthetic
- Retro color palette (sky blue, warm cream, blush pink, peach)
- Monospaced fonts and thick borders
- Soft shadows and consistent rounded corners

## Architecture

### Tech Stack
- **Framework**: SwiftUI
- **Data Persistence**: SwiftData (Item, ManualSection models)
- **AI**: Apple FoundationModels (SystemLanguageModel with Tool support)
- **Semantic Search**: NaturalLanguage framework (NLEmbedding)
- **PDF Handling**: PDFKit
- **Logging**: OSLog for debugging

### Project Structure

```
AllOurThings/
├── App/
│   ├── AllOurThingsApp.swift          # App entry point with ModelContainer
│   ├── ContentView.swift               # Tab navigation (Items, Chat)
│   └── Constants.swift                 # Configuration & constants
├── Features/
│   ├── Chat/
│   │   ├── Tools/
│   │   │   └── ReActTools.swift        # 4 tool implementations for AI
│   │   └── Views/
│   │       └── AppleIntelligenceChatView.swift  # AI chat interface
│   ├── Items/
│   │   ├── Models/
│   │   │   └── Item.swift              # Item data model
│   │   └── Views/
│   │       ├── ItemListView.swift      # Item list & grid
│   │       └── AddEditItemView.swift   # Item creation/editing
│   └── PDF/
│       ├── Models/
│       │   └── ManualSection.swift     # Manual section data model
│       ├── Views/
│       │   └── PDFViewerView.swift     # Manual viewer with page nav
│       └── Services/
│           ├── PDFStorageHelper.swift  # PDF file management
│           ├── PDFTextExtractor.swift  # Text extraction from PDFs
│           └── ManualSectionStorage.swift  # Section creation/storage
├── Design/
│   └── Theme.swift                     # Colors, fonts, spacing
└── Utilities/
    ├── SemanticSearchHelper.swift      # NLEmbedding-based search
    ├── KeychainHelper.swift            # Secure storage helper
    ├── DocumentPicker.swift            # File picker utilities
    └── ImageStorageHelper.swift        # Image file management
```

## How It Works: ReAct Agent with Tools

### ReAct Agent Architecture

The app implements a **ReAct (Reasoning and Acting)** pattern where Apple Intelligence:
1. **Reasons** about what information it needs to answer the user's question
2. **Acts** by calling specialized tools to retrieve that information
3. **Responds** to the user with synthesized information and citations

This is superior to the old "context dumping" approach because:
- ✅ No token limit issues - AI only fetches what it needs
- ✅ Semantic search finds relevant information intelligently
- ✅ Scalable to hundreds of items and manuals
- ✅ More accurate citations with structured section data

### The Four Tools

#### 1. **SearchItemsTool** (`search_items`)
**Purpose**: Find relevant items based on semantic similarity

**How it works**:
1. Takes a query string (e.g., "refrigerator" or "kitchen appliances")
2. Uses `NLEmbedding` to convert query and item metadata to vectors
3. Calculates cosine similarity scores
4. Returns top N matching items with relevance scores

**Returns**:
```
Found 2 relevant item(s):

1. Samsung Refrigerator
   Category: Kitchen
   Manufacturer: Samsung
   Location: Kitchen
   Has Manual: Yes
   Relevance: 95.2%

2. LG Dishwasher
   Category: Kitchen
   Manufacturer: LG
   Location: Kitchen
   Has Manual: No
   Relevance: 68.5%
```

#### 2. **ListManualSectionsTool** (`list_manual_sections`)
**Purpose**: Show what documentation sections are available for a specific item

**How it works**:
1. Takes an item name
2. Finds matching item in database
3. Fetches all ManualSection entries for that item
4. Returns section headings and page ranges

**Returns**:
```
Manual sections for 'Samsung Refrigerator' (8 sections):
1. Installation Instructions (Pages 3-8)
2. Temperature Settings (Page 9)
3. Food Storage Guidelines (Pages 10-12)
4. Cleaning & Maintenance (Pages 13-15)
...
```

#### 3. **GetManualSectionTool** (`get_manual_section`)
**Purpose**: Retrieve the full content of a specific manual section

**How it works**:
1. Takes item name and section heading
2. Finds the matching item and section
3. Returns complete section content with page information

**Returns**:
```
Section: Temperature Settings
Pages 9

The refrigerator has two independent temperature controls...
[Full section content with proper page formatting]
```

#### 4. **SearchManualSectionsTool** (`search_manual_sections`)
**Purpose**: Search across ALL manual sections using semantic similarity

**How it works**:
1. Takes a query string (e.g., "how to clean ice maker")
2. Fetches all ManualSection entries across all items
3. Uses `NLEmbedding` for semantic search
4. Returns most relevant sections with item names and page numbers

**Returns**:
```
Found 2 relevant section(s):

1. Ice Maker Maintenance (from Samsung Refrigerator)
   Pages 14-15
   Relevance: 92.3%
   Preview: To clean the ice maker, first turn off the ice...

2. Water Filter Replacement (from Samsung Refrigerator)
   Pages 16-17
   Relevance: 65.8%
   Preview: Replace the water filter every 6 months...
```

### Example Agent Flow

**User Question**: "How do I clean my refrigerator's ice maker?"

**Agent Process**:

1. **Reasoning**: "I need to find information about cleaning an ice maker in a refrigerator"

2. **Action 1**: Calls `search_items` with query "refrigerator ice maker"
   ```
   Result: Found "Samsung Refrigerator" (95.2% match)
   ```

3. **Action 2**: Calls `search_manual_sections` with query "clean ice maker"
   ```
   Result: Found "Ice Maker Maintenance" section from Samsung Refrigerator (Pages 14-15)
   ```

4. **Action 3**: Calls `get_manual_section` with itemName="Samsung Refrigerator", sectionHeading="Ice Maker Maintenance"
   ```
   Result: Full content retrieved with page numbers
   ```

5. **Response**: Synthesizes information with proper citations
   ```
   "To clean your Samsung Refrigerator's ice maker, first turn off
   the ice production (page 14). Remove the ice bin and wash it with
   warm soapy water (page 14). Wipe down the ice maker mechanism with
   a soft cloth (page 15)."
   ```

### Semantic Search with NLEmbedding

The app uses Apple's `NaturalLanguage` framework for semantic search:

```swift
// Example: Searching items
let embedding = NLEmbedding.sentenceEmbedding(for: .english)
let queryVector = embedding.vector(for: "kitchen refrigerator")
let itemVector = embedding.vector(for: "Samsung Fridge Category:Kitchen")

// Calculate similarity using cosine similarity
let similarity = cosineSimilarity(queryVector, itemVector)
// Result: 0.85 (85% match)
```

This allows the AI to find relevant information even when:
- User uses different words (e.g., "fridge" vs "refrigerator")
- Query is vague (e.g., "that thing in the kitchen")
- Information is across multiple items

### Citation System

Citations work in three steps:

1. **AI Generation**: Tools return content with page information, AI is instructed to cite using format `(page X)` or `(pages X-Y)`

2. **Parsing**: Regex pattern `\(pages? (\d+)(?:-(\d+))?\)` detects citations in responses

3. **Linking**: Citations become tappable links styled in blush pink with underline

4. **Navigation**: Tapping opens PDFViewerView at the specified page

**Example**:
```
User: "What temperature should I set for the crisper drawer?"
AI: "Set the crisper drawer to 'High Humidity' for leafy greens (page 11)"
[User taps "(page 11)"]
→ PDF viewer opens Samsung Refrigerator manual to page 11
```

## Data Models

### Item (SwiftData)
```swift
@Model
final class Item {
    var id: UUID
    var name: String
    var manufacturer: String
    var modelNumber: String
    var category: String
    var purchaseDate: Date?
    var warrantyExpirationDate: Date?
    var location: String
    var notes: String
    var timestamp: Date

    // Manual/Documentation
    var manualText: String?        // Legacy: full manual text
    var manualFileName: String?
    var manualFilePath: String?

    // Images
    var imageData: Data?
    var imageFileName: String?
    var imageFilePath: String?
}
```

### ManualSection (SwiftData)
```swift
@Model
final class ManualSection {
    var id: UUID
    var itemId: UUID               // Reference to parent Item
    var heading: String             // Section title
    var content: String             // Section text content
    var pageNumbers: [Int]          // Pages this section spans
    var sectionIndex: Int           // Order in the manual
    var fileName: String?           // Optional file reference
    var timestamp: Date

    // Computed properties
    var displayHeading: String      // "Section 1" if heading is empty
    var pageRange: String           // "Page 5" or "Pages 5-7"
}
```

### ChatMessage
```swift
struct ChatMessage: Identifiable {
    let id: UUID
    let text: String
    let isUser: Bool
    let timestamp: Date
    let itemsWithManuals: [ItemManualReference]
}

struct ItemManualReference {
    let itemName: String
    let manualFilePath: String
}
```

## Debugging

The app includes comprehensive logging using OSLog (Logger). All logs use the subsystem `com.allourhings.chat`.

### Viewing Debug Logs

**In Xcode Console**:
1. Run the app from Xcode (Cmd+R)
2. Open Debug Area (Cmd+Shift+Y)
3. Look for messages with emojis and tags

**In Console.app**:
1. Open Console app on Mac
2. Select your device/simulator
3. Filter by subsystem: `subsystem:com.allourhings.chat`

### Log Categories

- **Startup** (`com.allourhings.app`): App initialization
- **ChatView** (`com.allourhings.chat`): Session setup, message sending
- **Tools** (`com.allourhings.chat`): Tool invocations and results

### Example Log Output

```
🚀 APP STARTING - LOGGER TEST
🤖 [AppleIntelligenceChatView] Setting up session...
🤖 [AppleIntelligenceChatView] Created 4 tools for session
🤖 [AppleIntelligenceChatView] Current items count: 7
✅ [AppleIntelligenceChatView] Session setup complete

💬 [AppleIntelligenceChatView] Sending message: 'how do I clean my fridge?'
💬 [AppleIntelligenceChatView] Found 1 items with manual references
🤖 [AppleIntelligenceChatView] Waiting for response from model...

🔍 [SearchItemsTool] Called with query: 'refrigerator', maxResults: 5
🔍 [SearchItemsTool] Total items available: 7
🔍 [SearchItemsTool] Found 1 results
  ✓ Result 1: Samsung Refrigerator (relevance: 95.2%, hasManual: false)
✅ [SearchItemsTool] Returning response

🔎 [SearchManualSectionsTool] Called with query: 'clean refrigerator', maxResults: 3
🔎 [SearchManualSectionsTool] Total sections in database: 45
🔎 [SearchManualSectionsTool] Found 2 matching sections
  ✓ Result 1: Cleaning & Maintenance from 'Samsung Refrigerator' (relevance: 94.1%)
✅ [SearchManualSectionsTool] Returning response

📖 [GetManualSectionTool] Called with itemName: 'Samsung Refrigerator', sectionHeading: 'Cleaning'
📖 [GetManualSectionTool] Found item: 'Samsung Refrigerator'
📖 [GetManualSectionTool] Found 8 sections for item
📖 [GetManualSectionTool] Found section: 'Cleaning & Maintenance' with 1,245 characters
📖 [GetManualSectionTool] Page numbers: [13, 14, 15]
✅ [GetManualSectionTool] Returning section content

✅ [AppleIntelligenceChatView] Received response (length: 412)
📝 [AppleIntelligenceChatView] Response: To clean your Samsung Refrigerator...
```

### Troubleshooting

**No manual sections found?**
- Check that PDFs are properly uploaded to items
- Verify ManualSection entries exist in database
- Look for errors during PDF processing

**Tools not being called?**
- Check Apple Intelligence availability status
- Verify session initialized successfully
- Look for tool invocation logs in console

**Citations not appearing?**
- Check that ManualSection entries have page numbers
- Verify AI response contains `(page X)` format
- Look for citation parsing logs

## Requirements

- **iOS**: 18.2 or later
- **Device**: Compatible device with Apple silicon (A17 Pro or M1+)
- **Apple Intelligence**: Must be enabled in System Settings

## Apple Intelligence Availability States

The app gracefully handles various availability scenarios:

| State | Description | UI Response |
|-------|-------------|-------------|
| ✅ Available | AI ready and working | Full chat functionality with tools |
| ⚠️ Model Not Ready | Model downloading/preparing | "Preparing..." status with yellow indicator |
| ❌ Not Enabled | AI disabled in Settings | Prompt to enable with Settings link |
| ❌ Device Not Eligible | Incompatible hardware | Clear explanation message |

## Privacy & Security

- **On-Device Processing**: All AI inference happens locally using Apple Intelligence
- **No API Keys**: No external AI services or API calls required
- **Secure Storage**: Keychain helper ready for future secure data
- **No Telemetry**: No usage data collected or transmitted
- **No Cloud Sync**: All data stays on device

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

## Development Notes

### Migration from Context-Based to Tool-Based Architecture

The app was originally built with a context-dumping approach where all item information was sent with each message. This was replaced with a ReAct agent architecture for:

**Old Approach (Context Dumping)**:
- ❌ Hit token limits with many items
- ❌ Sent irrelevant information
- ❌ Poor scalability

**New Approach (ReAct with Tools)**:
- ✅ AI only fetches what it needs
- ✅ Semantic search finds relevant info
- ✅ Scales to hundreds of items
- ✅ Better citation accuracy with ManualSection model

### Testing

When testing the chat functionality:

1. **Setup**:
   - Ensure Apple Intelligence is enabled in Settings
   - Add items with PDF manuals
   - Verify ManualSection entries are created

2. **Test Tools**:
   - Ask about specific items to test `search_items`
   - Ask for section listings to test `list_manual_sections`
   - Ask detailed questions to test `search_manual_sections`
   - Verify citations appear and link correctly

3. **Monitor Logs**:
   - Check Xcode console for tool invocations
   - Verify semantic search is finding relevant content
   - Look for any errors in tool execution

4. **Test Edge Cases**:
   - Items without manuals
   - Queries with no matching sections
   - Multiple items with similar names
   - Vague queries requiring semantic understanding

## Future Enhancements

Potential features for future development:

- **Multi-PDF Support**: Multiple manuals per item (installation, user guide, repair)
- **Maintenance Tracking**: Schedule and log maintenance tasks with AI reminders
- **Smart Reminders**: Warranty expiration notifications
- **Export/Backup**: iCloud sync or local backup options
- **Advanced Search**: Filter items by multiple criteria
- **Family Sharing**: Multi-user support with shared item database
- **Receipt Scanning**: OCR for purchase receipts
- **Barcode Support**: Quick item lookup via UPC/EAN
- **Voice Input**: Ask questions using Siri
- **Image Recognition**: Auto-detect items from photos

---

**Built with ❤️ using SwiftUI, Apple Intelligence, and the ReAct agent pattern**
