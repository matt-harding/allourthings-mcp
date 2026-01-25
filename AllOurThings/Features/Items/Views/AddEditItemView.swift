import SwiftUI
import SwiftData
import PhotosUI
import FoundationModels

struct AddEditItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var manufacturer = ""
    @State private var modelNumber = ""
    @State private var categorySelection = ""
    @State private var customCategory = ""
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
    @State private var pdfError: String?
    @State private var temporarySections: [SectionData] = []
    @State private var isExtractingFeatures = false
    @State private var pdfProcessingStage: String?
    @State private var temporaryFeatures: [ItemFeature] = []

    // Image fields
    @State private var imageData: Data?
    @State private var imageFileName: String?
    @State private var imageFilePath: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isSavingImage = false
    @State private var imageError: String?
    @State private var showingCamera = false

    let item: Item?

    var isEditing: Bool {
        item != nil
    }

    private let categoryOptions = [
        "Kitchen Appliance",
        "Laundry Appliance",
        "Cleaning Appliance",
        "Heating/Cooling",
        "Smart Home Device",
        "Home Entertainment",
        "Computer/Networking",
        "Mobile Device",
        "Wearable",
        "Camera/Imaging",
        "Audio",
        "Gaming",
        "Personal Care",
        "Power Tool",
        "Outdoor Equipment",
        "Vehicle Accessory",
        "Other"
    ]

    private var resolvedCategory: String {
        if categorySelection == "Other" {
            return customCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return categorySelection
    }

    private var capabilities: [ItemFeature] {
        temporaryFeatures.filter { $0.type == .capability }
    }

    private var specifications: [ItemFeature] {
        temporaryFeatures.filter { $0.type == .specification }
    }

    var isSaveDisabled: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        manufacturer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        resolvedCategory.isEmpty
    }

    init(item: Item? = nil) {
        self.item = item
        if let item = item {
            _name = State(initialValue: item.name)
            _manufacturer = State(initialValue: item.manufacturer)
            _modelNumber = State(initialValue: item.modelNumber)
            _location = State(initialValue: item.location)
            _notes = State(initialValue: item.notes)
            _purchaseDate = State(initialValue: item.purchaseDate)
            _warrantyExpirationDate = State(initialValue: item.warrantyExpirationDate)
            _manualText = State(initialValue: item.manualText)
            _manualFileName = State(initialValue: item.manualFileName)
            _manualFilePath = State(initialValue: item.manualFilePath)
            _imageData = State(initialValue: item.imageData)
            _imageFileName = State(initialValue: item.imageFileName)
            _imageFilePath = State(initialValue: item.imageFilePath)
            _temporaryFeatures = State(initialValue: item.features)
            if categoryOptions.contains(item.category) {
                _categorySelection = State(initialValue: item.category)
                _customCategory = State(initialValue: "")
            } else if item.category.isEmpty {
                _categorySelection = State(initialValue: "")
                _customCategory = State(initialValue: "")
            } else {
                _categorySelection = State(initialValue: "Other")
                _customCategory = State(initialValue: item.category)
            }
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
                            RequiredFieldView(label: "Name", placeholder: "Enter item name", text: $name)

                            // Category field (required)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Category")
                                    .font(Theme.Fonts.cosySubheadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)

                                Picker("Category", selection: $categorySelection) {
                                    Text("Select a category").tag("")
                                    ForEach(categoryOptions, id: \.self) { option in
                                        Text(option).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(Theme.Fonts.cosyBody())
                                .foregroundColor(Theme.Colors.cocoaBrown)
                                .padding(Theme.Spacing.small)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.Colors.warmCream)
                                .cornerRadius(Theme.CornerRadius.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                        .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                                )

                                if categorySelection == "Other" {
                                    CozyTextField(placeholder: "Enter category", text: $customCategory)
                                }
                            }

                            // Manufacturer field (required)
                            RequiredFieldView(label: "Manufacturer", placeholder: "Enter manufacturer name", text: $manufacturer)

                            // Serial Number field (optional)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Serial Number")
                                    .font(Theme.Fonts.cosySubheadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                CozyTextField(placeholder: "Enter serial number (optional)", text: $modelNumber)
                            }

                            // Location field (optional)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text("Location")
                                    .font(Theme.Fonts.cosySubheadline())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                CozyTextField(placeholder: "Where is this item stored?", text: $location)
                            }
                        }
                        .cosyCard(padding: Theme.Spacing.medium)
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
                        .cosyCard(padding: Theme.Spacing.medium)
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

                    // Features Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Key Features")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                            Text("Capabilities")
                                .font(Theme.Fonts.cosySubheadline())
                                .foregroundColor(Theme.Colors.cocoaBrown)

                            ForEach(Array(temporaryFeatures.enumerated()), id: \.element.id) { index, feature in
                                if feature.type == .capability {
                                    HStack(spacing: Theme.Spacing.small) {
                                        TextField("Capability", text: $temporaryFeatures[index].text)
                                            .font(Theme.Fonts.cosyBody())
                                            .foregroundColor(Theme.Colors.cocoaBrown)
                                            .padding(.horizontal, Theme.Spacing.small)
                                            .padding(.vertical, Theme.Spacing.xs)
                                            .background(Theme.Colors.warmCream)
                                            .cornerRadius(Theme.CornerRadius.medium)

                                        Button(action: { removeFeature(id: feature.id) }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(Theme.Colors.peach)
                                        }
                                    }
                                }
                            }

                            Button(action: addCapability) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Theme.Colors.mintGreen)
                                    Text("Add Capability")
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                }
                            }
                            .padding(.top, Theme.Spacing.xs)

                            Divider()
                                .background(Theme.Colors.gentleBorder)
                                .padding(.vertical, Theme.Spacing.xs)

                            Text("Specifications")
                                .font(Theme.Fonts.cosySubheadline())
                                .foregroundColor(Theme.Colors.cocoaBrown)

                            ForEach(Array(temporaryFeatures.enumerated()), id: \.element.id) { index, feature in
                                if feature.type == .specification {
                                    HStack(spacing: Theme.Spacing.small) {
                                        TextField("Specification", text: $temporaryFeatures[index].text)
                                            .font(Theme.Fonts.cosyBody())
                                            .foregroundColor(Theme.Colors.cocoaBrown)
                                            .padding(.horizontal, Theme.Spacing.small)
                                            .padding(.vertical, Theme.Spacing.xs)
                                            .background(Theme.Colors.warmCream)
                                            .cornerRadius(Theme.CornerRadius.medium)

                                        Button(action: { removeFeature(id: feature.id) }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(Theme.Colors.peach)
                                        }
                                    }
                                }
                            }

                            Button(action: addSpecification) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(Theme.Colors.mintGreen)
                                    Text("Add Specification")
                                        .font(Theme.Fonts.cosyBody())
                                        .foregroundColor(Theme.Colors.cocoaBrown)
                                }
                            }
                            .padding(.top, Theme.Spacing.xs)
                        }
                        .cosyCard(padding: Theme.Spacing.medium)
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

                                // Feature extraction status
                                if isExtractingFeatures {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        ProgressView()
                                            .tint(Theme.Colors.cocoaBrown)
                                            .scaleEffect(0.8)
                                        Text("Extracting features...")
                                            .font(Theme.Fonts.cosyCaption())
                                            .foregroundColor(Theme.Colors.cocoaBrown)
                                    }
                                    .padding(.horizontal, Theme.Spacing.small)
                                } else if !temporaryFeatures.isEmpty {
                                    Text("\(temporaryFeatures.count) features extracted")
                                        .font(Theme.Fonts.cosyCaption())
                                        .foregroundColor(Theme.Colors.mintGreen)
                                        .padding(.horizontal, Theme.Spacing.small)
                                }
                            }

                            // Show error if PDF processing failed
                            if let error = pdfError {
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

                            // Upload button
                            Button(action: { showingDocumentPicker = true }) {
                                HStack {
                                    if isProcessingPDF {
                                        ProgressView()
                                            .tint(Theme.Colors.cocoaBrown)
                                        Text("Processing: \(pdfProcessingStage ?? "Starting")")
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
                        .cosyCard(padding: Theme.Spacing.medium)
                    }

                    // Photo Section
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("Photo")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)
                            .padding(.horizontal, Theme.Spacing.medium)

                        VStack(spacing: Theme.Spacing.xs) {
                            // Show image preview if available
                            if let imageData = imageData,
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

                                    if let fileName = imageFileName {
                                        HStack {
                                            Image(systemName: "photo.fill")
                                                .foregroundColor(Theme.Colors.softLavender)
                                            Text(fileName)
                                                .font(Theme.Fonts.cosyCaption())
                                                .foregroundColor(Theme.Colors.softGray)
                                                .lineLimit(1)
                                            Spacer()
                                            Button(action: removeImage) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(Theme.Colors.peach)
                                            }
                                        }
                                        .padding(.horizontal, Theme.Spacing.small)
                                    }
                                }
                            }

                            // Show error if save failed
                            if let error = imageError {
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
                            if isSavingImage {
                                HStack {
                                    ProgressView()
                                        .tint(Theme.Colors.cocoaBrown)
                                    Text("Saving Image...")
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
                        .cosyCard(padding: Theme.Spacing.medium)
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
                        if isEditing {
                            Text("Save")
                                .font(Theme.Fonts.cosyButton())
                                .foregroundColor(isSaveDisabled ? Theme.Colors.softGray : Theme.Colors.cocoaBrown)
                                .padding(.horizontal, Theme.Spacing.small)
                                .padding(.vertical, Theme.Spacing.xs)
                                .background(isSaveDisabled ? Theme.Colors.softGray.opacity(0.3) : Theme.Colors.mintGreen)
                                .cornerRadius(Theme.CornerRadius.xl)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(isSaveDisabled ? Theme.Colors.softGray : Theme.Colors.mintGreen)
                        }
                    }
                    .disabled(isSaveDisabled)
                    .cosyButtonPress()
                }
            }
            .sheet(isPresented: $showingPurchaseDatePicker) {
                DatePickerSheet(title: "Purchase Date", date: $purchaseDate, isPresented: $showingPurchaseDatePicker)
            }
            .sheet(isPresented: $showingWarrantyDatePicker) {
                DatePickerSheet(title: "Warranty Expiration", date: $warrantyExpirationDate, isPresented: $showingWarrantyDatePicker)
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
        pdfError = nil
        pdfProcessingStage = "Saving PDF"

        Task {
            // First, save the PDF file
            guard let savedPath = PDFStorageHelper.shared.savePDF(from: url) else {
                await MainActor.run {
                    isProcessingPDF = false
                    pdfError = "Failed to save PDF file. Please try again."
                    pdfProcessingStage = nil
                }
                return
            }

            // Then extract text from the saved PDF
            await MainActor.run {
                pdfProcessingStage = "Extracting text"
            }
            guard let savedURL = PDFStorageHelper.shared.getPDFURL(for: savedPath),
                  let result = PDFTextExtractor.shared.extractEnglishText(from: savedURL) else {
                await MainActor.run {
                    isProcessingPDF = false
                    pdfError = "Failed to extract text from PDF. The file may be corrupted or password-protected."
                    pdfProcessingStage = nil
                }
                return
            }

            await MainActor.run {
                pdfProcessingStage = "Extracting sections"
            }
            let model = SystemLanguageModel()

            // Extract sections using Apple Intelligence (fallback to heuristic if unavailable)
            let extractedSections = await SectionExtractor.shared.extractSections(from: result.text, model: model)

            await MainActor.run {
                pdfProcessingStage = "Summarizing sections"
            }
            let sections = await SectionSummaryExtractor.shared.summarizeSections(extractedSections, model: model)

            // Extract features using Apple Intelligence
            await MainActor.run {
                isExtractingFeatures = true
                pdfProcessingStage = "Extracting features"
            }

            let features = await FeatureExtractor.shared.extractFeatures(
                from: result.text,
                model: model
            )

            await MainActor.run {
                // Delete old PDF and sections if replacing
                if let oldPath = manualFilePath {
                    PDFStorageHelper.shared.deletePDF(at: oldPath)
                    // Note: Section cleanup will happen on save when item.id is available
                }

                manualText = result.text
                manualFileName = PDFTextExtractor.shared.getFileName(from: url)
                manualFilePath = savedPath
                pdfStats = result.stats
                pdfError = nil
                isProcessingPDF = false
                pdfProcessingStage = nil

                // Store sections temporarily (will be saved to database on item save)
                temporarySections = sections

                // Store features temporarily (will be saved to database on item save)
                temporaryFeatures = features
                isExtractingFeatures = false
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
        pdfError = nil
        temporarySections = []
        temporaryFeatures = []
    }

    // MARK: - Photo Handling

    private func processImageData(_ imageData: Data, fileName: String) async {
        await MainActor.run {
            isSavingImage = true
            imageError = nil
        }

        // Save to disk
        guard let savedPath = ImageStorageHelper.shared.saveImage(imageData, originalFileName: fileName) else {
            await MainActor.run {
                imageError = "Failed to save image"
                isSavingImage = false
            }
            return
        }

        await MainActor.run {
            // Delete old image if replacing
            if let oldPath = imageFilePath {
                ImageStorageHelper.shared.deleteImage(at: oldPath)
            }

            // Update state
            self.imageData = imageData
            self.imageFileName = fileName
            self.imageFilePath = savedPath
            isSavingImage = false
        }
    }

    private func handlePhotoSelection(_ photoItem: PhotosPickerItem?) async {
        guard let photoItem = photoItem else { return }

        do {
            // Load image data from PhotosPickerItem
            guard let loadedImageData = try await photoItem.loadTransferable(type: Data.self) else {
                await MainActor.run {
                    imageError = "Failed to load image"
                    isSavingImage = false
                }
                return
            }

            await processImageData(loadedImageData, fileName: Constants.FileNames.photoFileName())

            await MainActor.run {
                selectedPhotoItem = nil
            }

        } catch {
            await MainActor.run {
                imageError = "An unexpected error occurred"
                isSavingImage = false
                selectedPhotoItem = nil
            }
        }
    }

    private func removeImage() {
        // Delete the image file
        if let filePath = imageFilePath {
            ImageStorageHelper.shared.deleteImage(at: filePath)
        }

        imageData = nil
        imageFileName = nil
        imageFilePath = nil
        imageError = nil
    }

    private func handleCameraCapture(_ image: UIImage) {
        Task {
            // Fix image orientation before converting to data
            let orientationFixedImage = image.fixedOrientation()

            // Convert UIImage to Data
            guard let imageData = orientationFixedImage.jpegData(compressionQuality: Constants.Image.jpegCompressionQuality) else {
                await MainActor.run {
                    imageError = "Failed to process camera image"
                    isSavingImage = false
                }
                return
            }

            await processImageData(imageData, fileName: Constants.FileNames.cameraFileName())
        }
    }

    private func saveItem() {
        let savedItem: Item

        if let item = item {
            // Edit existing item
            item.name = name
            item.manufacturer = manufacturer
            item.modelNumber = modelNumber
            item.category = resolvedCategory
            item.location = location
            item.notes = notes
            item.purchaseDate = purchaseDate
            item.warrantyExpirationDate = warrantyExpirationDate
            item.manualText = manualText
            item.manualFileName = manualFileName
            item.manualFilePath = manualFilePath
            item.imageData = imageData
            item.imageFileName = imageFileName
            item.imageFilePath = imageFilePath
            item.features = cleanedFeatures(from: temporaryFeatures)

            savedItem = item

            // Delete old sections if manual was replaced
            if !temporarySections.isEmpty {
                deleteExistingSections(for: item.id)
            }
        } else {
            // Create new item
            let newItem = Item(
                name: name,
                manufacturer: manufacturer,
                modelNumber: modelNumber,
                category: resolvedCategory,
                purchaseDate: purchaseDate,
                warrantyExpirationDate: warrantyExpirationDate,
                location: location,
                notes: notes,
                manualText: manualText,
                manualFileName: manualFileName,
                manualFilePath: manualFilePath,
                imageData: imageData,
                imageFileName: imageFileName,
                imageFilePath: imageFilePath
            )
            modelContext.insert(newItem)
            savedItem = newItem

            // Save features for new item
            newItem.features = cleanedFeatures(from: temporaryFeatures)
        }

        // Save sections to database if any
        if !temporarySections.isEmpty {
            for (index, sectionData) in temporarySections.enumerated() {
                let section = ManualSection(
                    itemId: savedItem.id,
                    heading: sectionData.heading,
                    content: sectionData.content,
                    summary: sectionData.summary,
                    pageNumbers: sectionData.pageNumbers,
                    sectionIndex: index,
                    fileName: nil
                )
                modelContext.insert(section)
            }
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving item: \(error)")
        }

        dismiss()
    }

    private func cleanedFeatures(from features: [ItemFeature]) -> [ItemFeature] {
        features.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func addCapability() {
        temporaryFeatures.append(ItemFeature(type: .capability, text: ""))
    }

    private func addSpecification() {
        temporaryFeatures.append(ItemFeature(type: .specification, text: ""))
    }

    private func removeFeature(id: UUID) {
        temporaryFeatures.removeAll { $0.id == id }
    }

    private func deleteExistingSections(for itemId: UUID) {
        let descriptor = FetchDescriptor<ManualSection>(
            predicate: #Predicate<ManualSection> { section in
                section.itemId == itemId
            }
        )

        if let existingSections = try? modelContext.fetch(descriptor) {
            for section in existingSections {
                modelContext.delete(section)
            }
        }
    }
}

// MARK: - Date Picker Sheet
struct DatePickerSheet: View {
    let title: String
    @Binding var date: Date?
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            VStack {
                DatePicker(title, selection: Binding(
                    get: { date ?? Date() },
                    set: { date = $0 }
                ), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .tint(Theme.Colors.blushPink)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.warmCream)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        date = nil
                        isPresented = false
                    }
                    .foregroundColor(Theme.Colors.mutedPlum)
                    .font(Theme.Fonts.cosyBody())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(Theme.Colors.blushPink)
                    .font(Theme.Fonts.cosyButton())
                }
            }
        }
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

// MARK: - Required Field View
struct RequiredFieldView: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack {
                Text(label)
                    .font(Theme.Fonts.cosySubheadline())
                    .foregroundColor(Theme.Colors.cocoaBrown)
                Text("*")
                    .font(Theme.Fonts.cosySubheadline())
                    .foregroundColor(Theme.Colors.peach)
            }
            CozyTextField(placeholder: placeholder, text: $text)
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

