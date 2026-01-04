import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var modelNumber = ""
    @State private var category = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var purchaseDate: Date?
    @State private var warrantyExpirationDate: Date?
    @State private var showingPurchaseDatePicker = false
    @State private var showingWarrantyDatePicker = false

    // Manual/PDF fields
    @State private var manualText: String?
    @State private var manualFileName: String?
    @State private var manualFilePath: String?
    @State private var showingDocumentPicker = false
    @State private var isProcessingPDF = false
    @State private var pdfStats: ExtractionStats?

    // Pixel Art Image fields
    @State private var pixelArtImageData: Data?
    @State private var pixelArtFileName: String?
    @State private var pixelArtFilePath: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isGeneratingPixelArt = false
    @State private var pixelArtError: String?
    @State private var showingCamera = false

    let item: Item?

    var isEditing: Bool {
        item != nil
    }

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(item: Item? = nil) {
        self.item = item
        if let item = item {
            _name = State(initialValue: item.name)
            _manufacturer = State(initialValue: item.manufacturer)
            _modelNumber = State(initialValue: item.modelNumber)
            _category = State(initialValue: item.category)
            _location = State(initialValue: item.location)
            _notes = State(initialValue: item.notes)
            _purchaseDate = State(initialValue: item.purchaseDate)
            _warrantyExpirationDate = State(initialValue: item.warrantyExpirationDate)
            _manualText = State(initialValue: item.manualText)
            _manualFileName = State(initialValue: item.manualFileName)
            _manualFilePath = State(initialValue: item.manualFilePath)
            _pixelArtImageData = State(initialValue: item.pixelArtImageData)
            _pixelArtFileName = State(initialValue: item.pixelArtFileName)
            _pixelArtFilePath = State(initialValue: item.pixelArtFilePath)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.medium) {
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Basic Information")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        VStack(spacing: Theme.Spacing.small) {
                            // Name field (required)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                HStack {
                                    Text("Name")
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                    Text("*")
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.peach)
                                }
                                CozyTextField(placeholder: "Enter item name", text: $name)
                            }

                            // Manufacturer field (required)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                HStack {
                                    Text("Manufacturer")
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                    Text("*")
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.peach)
                                }
                                CozyTextField(placeholder: "Enter manufacturer name", text: $manufacturer)
                            }

                            // Serial Number field (optional)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Serial Number")
                                    .font(Theme.Fonts.cosySubheadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                CozyTextField(placeholder: "Enter serial number (optional)", text: $modelNumber)
                            }

                            // Category field (optional)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Category")
                                    .font(Theme.Fonts.cosySubheadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                CozyTextField(placeholder: "e.g., Electronics, Appliance", text: $category)
                            }

                            // Location field (optional)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Location")
                                    .font(Theme.Fonts.cosySubheadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                CozyTextField(placeholder: "Where is this item stored?", text: $location)
                            }
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.cloudWhite)
                        .cornerRadius(Theme.CornerRadius.large)
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                        )
                    }

                    // Dates Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Dates")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        VStack(spacing: Theme.Spacing.xs) {
                            // Purchase Date Row
                            HStack {
                                Image(systemName: "calendar.circle.fill")
                                    .foregroundColor(Theme.Colors.blushPink)
                                Text("Purchase Date")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                Spacer()
                                if let purchaseDate = purchaseDate {
                                    Text(purchaseDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.softGray)
                                } else {
                                    Text("Not set")
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.softGray)
                                }
                            }
                            .padding(Theme.Spacing.small)
                            .background(Theme.Colors.warmCream)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingPurchaseDatePicker = true
                            }

                            // Warranty Date Row
                            HStack {
                                Image(systemName: "calendar.circle.fill")
                                    .foregroundColor(Theme.Colors.blushPink)
                                Text("Warranty Expires")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                Spacer()
                                if let warrantyDate = warrantyExpirationDate {
                                    Text(warrantyDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.softGray)
                                } else {
                                    Text("Not set")
                                        .font(Theme.Fonts.cosySubheadline())
                                        .foregroundColor(Theme.Colors.softGray)
                                }
                            }
                            .padding(Theme.Spacing.small)
                            .background(Theme.Colors.warmCream)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingWarrantyDatePicker = true
                            }
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.cloudWhite)
                        .cornerRadius(Theme.CornerRadius.large)
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                        )
                    }

                    // Notes Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Notes")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        TextField("Additional notes...", text: $notes, axis: .vertical)
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.cocoaBrown)
                            .padding(Theme.Spacing.small)
                            .background(Theme.Colors.butterYellow.opacity(0.1))
                            .cornerRadius(Theme.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Theme.Colors.butterYellow.opacity(0.3), lineWidth: Theme.BorderWidth.standard)
                            )
                            .lineLimit(4...8)
                            .frame(minHeight: 80)
                            .padding(Theme.Spacing.medium)
                            .background(Theme.Colors.cloudWhite)
                            .cornerRadius(Theme.CornerRadius.large)
                            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                            )
                    }

                    // Manual Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Manual")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        VStack(spacing: Theme.Spacing.xs) {
                            if let fileName = manualFileName {
                                // Show attached manual
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundColor(Theme.Colors.mintGreen)
                                    Text(fileName)
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                        .lineLimit(1)
                                    Spacer()
                                    Button(action: removeManual) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(Theme.Colors.peach)
                                    }
                                }
                                .padding(Theme.Spacing.small)
                                .background(Theme.Colors.mintGreen.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.medium)

                                if let stats = pdfStats {
                                    Text(stats.summary)
                                        .font(Theme.Fonts.cosyCaption())
                                        .foregroundColor(Theme.Colors.softGray)
                                        .padding(.horizontal, Theme.Spacing.small)
                                }
                            }

                            // Upload button
                            Button(action: { showingDocumentPicker = true }) {
                                HStack {
                                    if isProcessingPDF {
                                        ProgressView()
                                            .tint(Theme.Colors.cocoaBrown)
                                        Text("Processing PDF...")
                                    } else {
                                        Image(systemName: manualFileName == nil ? "doc.badge.plus" : "arrow.triangle.2.circlepath")
                                        Text(manualFileName == nil ? "Attach Manual (PDF)" : "Replace Manual")
                                    }
                                }
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.small)
                                .background(Theme.Colors.warmCream)
                                .cornerRadius(Theme.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                )
                            }
                            .disabled(isProcessingPDF)
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.cloudWhite)
                        .cornerRadius(Theme.CornerRadius.large)
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                        )
                    }

                    // Photo Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Photo")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        VStack(spacing: Theme.Spacing.xs) {
                            // Show pixel art preview if available
                            if let imageData = pixelArtImageData,
                               let uiImage = UIImage(data: imageData) {
                                VStack(spacing: Theme.Spacing.xs) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxHeight: 200)
                                        .cornerRadius(Theme.CornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                        )

                                    if let fileName = pixelArtFileName {
                                        HStack {
                                            Image(systemName: "photo.fill")
                                                .foregroundColor(Theme.Colors.softLavender)
                                            Text(fileName)
                                                .font(Theme.Fonts.cosyCaption())
                                                .foregroundColor(Theme.Colors.softGray)
                                                .lineLimit(1)
                                            Spacer()
                                            Button(action: removePixelArt) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(Theme.Colors.peach)
                                            }
                                        }
                                        .padding(.horizontal, Theme.Spacing.small)
                                    }
                                }
                            }

                            // Show error if generation failed
                            if let error = pixelArtError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Theme.Colors.peach)
                                    Text(error)
                                        .font(Theme.Fonts.cosyCaption())
                                        .foregroundColor(Theme.Colors.peach)
                                }
                                .padding(Theme.Spacing.small)
                                .background(Theme.Colors.peach.opacity(0.1))
                                .cornerRadius(Theme.CornerRadius.medium)
                            }

                            // Photo action buttons
                            if isGeneratingPixelArt {
                                HStack {
                                    ProgressView()
                                        .tint(Theme.Colors.cocoaBrown)
                                    Text("Generating Pixel Art...")
                                }
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                                .frame(maxWidth: .infinity)
                                .padding(Theme.Spacing.small)
                                .background(Theme.Colors.warmCream)
                                .cornerRadius(Theme.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                )
                            } else {
                                HStack(spacing: Theme.Spacing.small) {
                                    // Camera button
                                    Button(action: { showingCamera = true }) {
                                        HStack {
                                            Image(systemName: "camera.fill")
                                            Text("Take Photo")
                                        }
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                        .frame(maxWidth: .infinity)
                                        .padding(Theme.Spacing.small)
                                        .background(Theme.Colors.warmCream)
                                        .cornerRadius(Theme.CornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                        )
                                    }

                                    // PhotosPicker button
                                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                        HStack {
                                            Image(systemName: "photo.on.rectangle")
                                            Text("Choose Photo")
                                        }
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                        .frame(maxWidth: .infinity)
                                        .padding(Theme.Spacing.small)
                                        .background(Theme.Colors.warmCream)
                                        .cornerRadius(Theme.CornerRadius.medium)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                        )
                                    }
                                    .onChange(of: selectedPhotoItem) { _, newItem in
                                        Task {
                                            await handlePhotoSelection(newItem)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(Theme.Spacing.medium)
                        .background(Theme.Colors.cloudWhite)
                        .cornerRadius(Theme.CornerRadius.large)
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                        )
                    }
                }
                .padding(Theme.Spacing.medium)
            }
            .cosyGradientBackground()
            .navigationTitle(isEditing ? "Edit Item" : "Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.mutedPlum)
                    .font(Theme.Fonts.cosyBody())
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { saveItem() }) {
                        Text("Save")
                            .font(Theme.Fonts.cosyButton())
                            .foregroundColor(isSaveDisabled ? Theme.Colors.softGray : Theme.Colors.cocoaBrown)
                            .padding(.horizontal, Theme.Spacing.small)
                            .padding(.vertical, Theme.Spacing.xs)
                            .background(isSaveDisabled ? Theme.Colors.softGray.opacity(0.3) : Theme.Colors.mintGreen)
                            .cornerRadius(Theme.CornerRadius.xl)
                    }
                    .disabled(isSaveDisabled)
                    .cosyButtonPress()
                }
            }
            .sheet(isPresented: $showingPurchaseDatePicker) {
                NavigationView {
                    VStack {
                        DatePicker("Purchase Date", selection: Binding(
                            get: { purchaseDate ?? Date() },
                            set: { purchaseDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(Theme.Colors.blushPink)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.warmCream)
                    .navigationTitle("Purchase Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Clear") {
                                purchaseDate = nil
                                showingPurchaseDatePicker = false
                            }
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .font(Theme.Fonts.cosyBody())
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingPurchaseDatePicker = false
                            }
                            .foregroundColor(Theme.Colors.blushPink)
                            .font(Theme.Fonts.cosyButton())
                        }
                    }
                }
            }
            .sheet(isPresented: $showingWarrantyDatePicker) {
                NavigationView {
                    VStack {
                        DatePicker("Warranty Expiration", selection: Binding(
                            get: { warrantyExpirationDate ?? Date() },
                            set: { warrantyExpirationDate = $0 }
                        ), displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(Theme.Colors.blushPink)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.warmCream)
                    .navigationTitle("Warranty Expiration")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Clear") {
                                warrantyExpirationDate = nil
                                showingWarrantyDatePicker = false
                            }
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .font(Theme.Fonts.cosyBody())
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingWarrantyDatePicker = false
                            }
                            .foregroundColor(Theme.Colors.blushPink)
                            .font(Theme.Fonts.cosyButton())
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(onDocumentPicked: handleDocumentPicked)
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(onImageCaptured: handleCameraCapture)
            }
        }
    }

    private func handleDocumentPicked(_ url: URL) {
        isProcessingPDF = true

        Task {
            // First, save the PDF file
            guard let savedPath = PDFStorageHelper.shared.savePDF(from: url) else {
                await MainActor.run {
                    isProcessingPDF = false
                    // Could show error alert here
                }
                return
            }

            // Then extract text from the saved PDF
            guard let savedURL = PDFStorageHelper.shared.getPDFURL(for: savedPath),
                  let result = PDFTextExtractor.shared.extractEnglishText(from: savedURL) else {
                await MainActor.run {
                    isProcessingPDF = false
                    // Could show error alert here
                }
                return
            }

            await MainActor.run {
                // Delete old PDF if replacing
                if let oldPath = manualFilePath {
                    PDFStorageHelper.shared.deletePDF(at: oldPath)
                }

                manualText = result.text
                manualFileName = PDFTextExtractor.shared.getFileName(from: url)
                manualFilePath = savedPath
                pdfStats = result.stats
                isProcessingPDF = false
            }
        }
    }

    private func removeManual() {
        // Delete the PDF file
        if let filePath = manualFilePath {
            PDFStorageHelper.shared.deletePDF(at: filePath)
        }

        manualText = nil
        manualFileName = nil
        manualFilePath = nil
        pdfStats = nil
    }

    // MARK: - Photo Handling

    private func handlePhotoSelection(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem = photoItem else { return }

        await MainActor.run {
            isGeneratingPixelArt = true
            pixelArtError = nil
        }

        do {
            // Load image data from PhotosPickerItem
            guard let imageData = try await photoItem.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    pixelArtError = "Failed to load image"
                    isGeneratingPixelArt = false
                }
                return
            }

            // Convert to pixel art using local processor (runs on background thread)
            let pixelArtData = await Task.detached {
                PixelArtProcessor.shared.convertToPixelArt(imageData: imageData)
            }.value

            guard let pixelArtData = pixelArtData else {
                await MainActor.run {
                    pixelArtError = "Failed to convert to pixel art"
                    isGeneratingPixelArt = false
                }
                return
            }

            // Save to disk
            let originalFileName = "photo_\(Date().timeIntervalSince1970).png"
            guard let savedPath = ImageStorageHelper.shared.saveImage(pixelArtData, originalFileName: originalFileName) else {
                await MainActor.run {
                    pixelArtError = "Failed to save pixel art"
                    isGeneratingPixelArt = false
                }
                return
            }

            await MainActor.run {
                // Delete old image if replacing
                if let oldPath = pixelArtFilePath {
                    ImageStorageHelper.shared.deleteImage(at: oldPath)
                }

                // Update state
                pixelArtImageData = pixelArtData
                pixelArtFileName = originalFileName
                pixelArtFilePath = savedPath
                isGeneratingPixelArt = false
                selectedPhotoItem = nil
            }

        } catch {
            await MainActor.run {
                pixelArtError = "An unexpected error occurred"
                isGeneratingPixelArt = false
                selectedPhotoItem = nil
            }
        }
    }

    private func removePixelArt() {
        // Delete the image file
        if let filePath = pixelArtFilePath {
            ImageStorageHelper.shared.deleteImage(at: filePath)
        }

        pixelArtImageData = nil
        pixelArtFileName = nil
        pixelArtFilePath = nil
        pixelArtError = nil
    }

    private func handleCameraCapture(_ image: UIImage) {
        Task {
            await MainActor.run {
                isGeneratingPixelArt = true
                pixelArtError = nil
            }

            // Fix image orientation before converting to data
            let orientationFixedImage = image.fixedOrientation()

            // Convert UIImage to Data
            guard let imageData = orientationFixedImage.jpegData(compressionQuality: 0.8) else {
                await MainActor.run {
                    pixelArtError = "Failed to process camera image"
                    isGeneratingPixelArt = false
                }
                return
            }

            // Convert to pixel art using local processor
            let pixelArtData = await Task.detached {
                PixelArtProcessor.shared.convertToPixelArt(imageData: imageData)
            }.value

            guard let pixelArtData = pixelArtData else {
                await MainActor.run {
                    pixelArtError = "Failed to convert to pixel art"
                    isGeneratingPixelArt = false
                }
                return
            }

            // Save to disk
            let originalFileName = "camera_\(Date().timeIntervalSince1970).png"
            guard let savedPath = ImageStorageHelper.shared.saveImage(pixelArtData, originalFileName: originalFileName) else {
                await MainActor.run {
                    pixelArtError = "Failed to save pixel art"
                    isGeneratingPixelArt = false
                }
                return
            }

            await MainActor.run {
                // Delete old image if replacing
                if let oldPath = pixelArtFilePath {
                    ImageStorageHelper.shared.deleteImage(at: oldPath)
                }

                // Update state
                pixelArtImageData = pixelArtData
                pixelArtFileName = originalFileName
                pixelArtFilePath = savedPath
                isGeneratingPixelArt = false
            }
        }
    }

    private func saveItem() {
        if let item = item {
            // Edit existing item
            item.name = name
            item.manufacturer = manufacturer
            item.modelNumber = modelNumber
            item.category = category
            item.location = location
            item.notes = notes
            item.purchaseDate = purchaseDate
            item.warrantyExpirationDate = warrantyExpirationDate
            item.manualText = manualText
            item.manualFileName = manualFileName
            item.manualFilePath = manualFilePath
            item.pixelArtImageData = pixelArtImageData
            item.pixelArtFileName = pixelArtFileName
            item.pixelArtFilePath = pixelArtFilePath
        } else {
            // Create new item
            let newItem = Item(
                name: name,
                manufacturer: manufacturer,
                modelNumber: modelNumber,
                category: category,
                purchaseDate: purchaseDate,
                warrantyExpirationDate: warrantyExpirationDate,
                location: location,
                notes: notes,
                manualText: manualText,
                manualFileName: manualFileName,
                manualFilePath: manualFilePath,
                pixelArtImageData: pixelArtImageData,
                pixelArtFileName: pixelArtFileName,
                pixelArtFilePath: pixelArtFilePath
            )
            modelContext.insert(newItem)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }

        dismiss()
    }
}

// MARK: - Camera Picker
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func fixedOrientation() -> UIImage {
        // If image is already in correct orientation, return it
        if imageOrientation == .up {
            return self
        }

        // Redraw the image with correct orientation
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}