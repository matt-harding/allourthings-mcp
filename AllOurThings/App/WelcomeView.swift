//
//  WelcomeView.swift
//  AllOurThings
//
//  First-use wizard/onboarding screen
//

import SwiftUI

struct WelcomeView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    private let totalPages = 3

    var body: some View {
        VStack(spacing: 0) {
            // Page indicator
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(currentPage == index ? Theme.Colors.blushPink : Theme.Colors.gentleBorder)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 20)

            // Content pages
            TabView(selection: $currentPage) {
                WelcomePage1()
                    .tag(0)

                WelcomePage2()
                    .tag(1)

                WelcomePage3()
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentPage)

            // Bottom buttons
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button(action: {
                        withAnimation {
                            currentPage -= 1
                        }
                    }) {
                        Text("Back")
                            .font(Theme.Fonts.cosyBody())
                            .foregroundColor(Theme.Colors.cocoaBrown)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(Theme.Colors.cloudWhite)
                            .cornerRadius(Theme.CornerRadius.large)
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thick)
                            )
                    }
                    .cosyButtonPress()
                }

                Spacer()

                Button(action: {
                    if currentPage < totalPages - 1 {
                        withAnimation {
                            currentPage += 1
                        }
                    } else {
                        completeOnboarding()
                    }
                }) {
                    Text(currentPage < totalPages - 1 ? "Next" : "Get Started")
                        .font(Theme.Fonts.cosyBody())
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.blushPink)
                        .cornerRadius(Theme.CornerRadius.large)
                }
                .cosyButtonPress()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .cosyGradientBackground(topColor: Theme.Colors.skyBlue.opacity(0.3), bottomColor: Theme.Colors.skyBlue)
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}

// MARK: - Welcome Page 1: Introduction

struct WelcomePage1: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: "house.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.blushPink)
                .padding(.bottom, 20)

            // Title
            Text("Welcome to AllOurThings")
                .font(Theme.Fonts.cosyTitle())
                .foregroundColor(Theme.Colors.cocoaBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Description
            Text("Keep track of all your household items, manuals, and warranties in one cosy place")
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.softGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Welcome Page 2: Features

struct WelcomePage2: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.blushPink)
                .padding(.bottom, 20)

            // Title
            Text("Smart Manual Assistant")
                .font(Theme.Fonts.cosyTitle())
                .foregroundColor(Theme.Colors.cocoaBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Features list
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "doc.fill",
                    text: "Upload PDF manuals for your items"
                )

                FeatureRow(
                    icon: "message.fill",
                    text: "Ask questions using Apple Intelligence"
                )

                FeatureRow(
                    icon: "link",
                    text: "Get answers with direct page citations"
                )
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Welcome Page 3: Get Started

struct WelcomePage3: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // Icon
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(Theme.Colors.blushPink)
                .padding(.bottom, 20)

            // Title
            Text("Ready to Get Started?")
                .font(Theme.Fonts.cosyTitle())
                .foregroundColor(Theme.Colors.cocoaBrown)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // Description
            VStack(spacing: 16) {
                Text("Start by adding your first item to your collection")
                    .font(Theme.Fonts.cosyBody())
                    .foregroundColor(Theme.Colors.softGray)
                    .multilineTextAlignment(.center)

                Text("You can add photos, manuals, and details about each item to keep everything organized")
                    .font(Theme.Fonts.cosyCaption())
                    .foregroundColor(Theme.Colors.softGray)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Theme.Colors.blushPink)
                .frame(width: 40)

            Text(text)
                .font(Theme.Fonts.cosyBody())
                .foregroundColor(Theme.Colors.cocoaBrown)

            Spacer()
        }
        .padding(16)
        .background(Theme.Colors.cloudWhite)
        .cornerRadius(Theme.CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.thin)
        )
    }
}

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
