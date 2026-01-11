import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey: String = ""
    @State private var showingSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isTestingKey = false
    @State private var hasExistingKey = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Theme.Spacing.large) {
                    // Header
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Theme.Colors.blushPink)

                        Text("Gemini API Key")
                            .font(Theme.Fonts.cosyLargeTitle())
                            .foregroundColor(Theme.Colors.cocoaBrown)

                        Text("Enter your Google Gemini API key to enable AI chat")
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.softGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Theme.Spacing.xl)
                    }
                    .padding(.top, Theme.Spacing.xl)

                    // API Key Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("API Key")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)

                        SecureField("Enter your Gemini API key", text: $apiKey)
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.cocoaBrown)
                            .padding(Theme.Spacing.small)
                            .background(Theme.Colors.warmCream)
                            .cornerRadius(Theme.CornerRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(Theme.Spacing.medium)
                    .background(Theme.Colors.cloudWhite)
                    .cornerRadius(Theme.CornerRadius.large)
                    .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                    )

                    // Save Button
                    Button(action: saveAPIKey) {
                        HStack {
                            if isTestingKey {
                                ProgressView()
                                    .tint(Theme.Colors.cocoaBrown)
                                Text("Testing Key...")
                            } else {
                                Image(systemName: hasExistingKey ? "checkmark.circle.fill" : "square.and.arrow.down.fill")
                                Text(hasExistingKey ? "Update Key" : "Save Key")
                            }
                        }
                        .font(Theme.Fonts.cosyButton())
                        .foregroundColor(Theme.Colors.cocoaBrown)
                        .frame(maxWidth: .infinity)
                        .padding(Theme.Spacing.small)
                        .background(Theme.Colors.mintGreen)
                        .cornerRadius(Theme.CornerRadius.xl)
                        .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                                .stroke(Theme.Colors.cocoaBrown.opacity(0.3), lineWidth: Theme.BorderWidth.thin)
                        )
                    }
                    .disabled(apiKey.isEmpty || isTestingKey)
                    .opacity(apiKey.isEmpty ? 0.5 : 1.0)
                    .cosyButtonPress()

                    // How to Get Key
                    VStack(alignment: .leading, spacing: Theme.Spacing.small) {
                        Text("How to Get Your API Key")
                            .font(Theme.Fonts.cosyHeadline())
                            .foregroundColor(Theme.Colors.mutedPlum)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                Text("1.")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                Text("Visit aistudio.google.com")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.softGray)
                            }

                            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                Text("2.")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                Text("Click 'Generate a free API key'")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.softGray)
                            }


                            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                Text("3.")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.cocoaBrown)
                                Text("Copy your API key here")
                                    .font(Theme.Fonts.cosyBody())
                                    .foregroundColor(Theme.Colors.softGray)
                            }
                        }

                        Text("Free tier: 60 requests/minute")
                            .font(Theme.Fonts.cosyCaption())
                            .foregroundColor(Theme.Colors.mintGreen)
                            .padding(.top, Theme.Spacing.xxs)
                    }
                    .padding(Theme.Spacing.medium)
                    .background(Theme.Colors.cloudWhite)
                    .cornerRadius(Theme.CornerRadius.large)
                    .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                            .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
                    )

                    // Delete Key (if exists)
                    if hasExistingKey {
                        Button(action: deleteAPIKey) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Remove API Key")
                            }
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.peach)
                        }
                        .padding(.top, Theme.Spacing.small)
                    }

                    Spacer()
                }
                .padding(Theme.Spacing.medium)
            }
            .cosyGradientBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Theme.Colors.blushPink)
                    .font(Theme.Fonts.cosyButton())
                }
            }
            .alert("Success!", isPresented: $showingSuccess) {
                Button("OK", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("API key saved and verified successfully!")
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                hasExistingKey = KeychainHelper.shared.hasGeminiKey()
            }
        }
    }

    private func saveAPIKey() {
        guard !apiKey.isEmpty else { return }

        isTestingKey = true

        Task {
            let isValid = await GeminiService.shared.testAPIKey(apiKey)

            await MainActor.run {
                isTestingKey = false

                if isValid {
                    showingSuccess = true
                    hasExistingKey = true
                } else {
                    errorMessage = "Invalid API key or network error. Please check your key and try again."
                    showingError = true
                }
            }
        }
    }

    private func deleteAPIKey() {
        KeychainHelper.shared.deleteGeminiKey()
        apiKey = ""
        hasExistingKey = false
    }
}
