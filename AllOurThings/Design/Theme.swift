import SwiftUI

// MARK: - Theme System for Cosy Videogame Aesthetic

enum Theme {

    // MARK: - Colors

    enum Colors {
        // Backgrounds
        static let skyBlue = Color(red: 0.87, green: 0.93, blue: 0.98)
        static let cloudWhite = Color(red: 0.98, green: 0.97, blue: 0.95)
        static let warmCream = Color(red: 0.99, green: 0.96, blue: 0.92)

        // Accents
        static let blushPink = Color(red: 0.98, green: 0.75, blue: 0.78)
        static let softLavender = Color(red: 0.82, green: 0.76, blue: 0.89)
        static let butterYellow = Color(red: 0.99, green: 0.93, blue: 0.67)
        static let mintGreen = Color(red: 0.74, green: 0.92, blue: 0.84)
        static let peach = Color(red: 0.99, green: 0.85, blue: 0.74)

        // Text
        static let cocoaBrown = Color(red: 0.34, green: 0.26, blue: 0.24)
        static let softGray = Color(red: 0.52, green: 0.48, blue: 0.52)
        static let mutedPlum = Color(red: 0.46, green: 0.38, blue: 0.44)

        // Borders & Shadows
        static let gentleBorder = Color(red: 0.85, green: 0.82, blue: 0.82)
        static let shadowTint = Color(red: 0.78, green: 0.72, blue: 0.78).opacity(0.15)

        // Category-specific colors
        static func categoryColor(for category: String) -> Color {
            switch category.lowercased() {
            case "kitchen":
                return butterYellow
            case "laundry":
                return softLavender
            case "cleaning":
                return mintGreen
            default:
                return blushPink
            }
        }
    }

    // MARK: - Typography (Pixel Art / Arcade Style)

    enum Fonts {
        static func cosyExtraLargeTitle() -> Font {
            .system(size: 32, weight: .heavy, design: .monospaced)
        }

        static func cosyLargeTitle() -> Font {
            .system(size: 26, weight: .bold, design: .monospaced)
        }

        static func cosyTitle() -> Font {
            .system(size: 22, weight: .bold, design: .monospaced)
        }

        static func cosyHeadline() -> Font {
            .system(size: 18, weight: .bold, design: .monospaced)
        }

        static func cosyBody() -> Font {
            .system(size: 16, weight: .medium, design: .default)
        }

        static func cosySubheadline() -> Font {
            .system(size: 14, weight: .semibold, design: .default)
        }

        static func cosyCaption() -> Font {
            .system(size: 12, weight: .medium, design: .default)
        }

        static func cosyButton() -> Font {
            .system(size: 16, weight: .bold, design: .monospaced)
        }
    }

    // MARK: - Spacing

    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let large: CGFloat = 20
        static let xl: CGFloat = 24
    }

    // MARK: - Corner Radius (Pixel Art / Arcade Style)

    enum CornerRadius {
        static let small: CGFloat = 2
        static let medium: CGFloat = 3
        static let large: CGFloat = 4
        static let xl: CGFloat = 6
    }

    // MARK: - Shadows (Pixel Art / Arcade Style - More Defined)
    // Note: Shadow view modifiers are defined in the View extension below

    // MARK: - Border Widths (Pixel Art / Arcade Style - Thicker & Crisper)

    enum BorderWidth {
        static let thin: CGFloat = 2
        static let standard: CGFloat = 3
        static let thick: CGFloat = 4
    }
}

// MARK: - View Modifiers

extension View {
    // Cosy Card Modifier (Pixel Art Style)
    func cosyCard(padding: CGFloat = Theme.Spacing.small) -> some View {
        self
            .padding(padding)
            .background(Theme.Colors.cloudWhite)
            .cornerRadius(Theme.CornerRadius.large)
            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.large)
                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
            )
    }

    // Cosy Button Modifier (Pixel Art Style)
    func cosyButton(
        backgroundColor: Color = Theme.Colors.blushPink,
        foregroundColor: Color = .white,
        horizontalPadding: CGFloat = 12,
        verticalPadding: CGFloat = 8
    ) -> some View {
        self
            .font(Theme.Fonts.cosyButton())
            .foregroundColor(foregroundColor)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(backgroundColor)
            .cornerRadius(Theme.CornerRadius.xl)
            .shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.xl)
                    .stroke(Theme.Colors.cocoaBrown.opacity(0.3), lineWidth: Theme.BorderWidth.thin)
            )
    }

    // Category Badge Modifier (Pixel Art Style)
    func categoryBadge(category: String) -> some View {
        let categoryColor = Theme.Colors.categoryColor(for: category)
        return self
            .font(Theme.Fonts.cosyCaption())
            .foregroundColor(Theme.Colors.cocoaBrown)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(categoryColor.opacity(0.3))
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(categoryColor, lineWidth: Theme.BorderWidth.standard)
            )
    }

    // Gradient Background Helper
    func cosyGradientBackground(topColor: Color = Theme.Colors.skyBlue, bottomColor: Color = Theme.Colors.warmCream) -> some View {
        self.background(
            LinearGradient(
                colors: [topColor, bottomColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // Shadow Modifiers (Pixel Art Style)
    func standardShadow() -> some View {
        self.shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 2, y: 2)
    }

    func softShadow() -> some View {
        self.shadow(color: Theme.Colors.shadowTint.opacity(0.3), radius: 0, x: 3, y: 3)
    }
}

// MARK: - Cozy TextField Component (Pixel Art Style)

struct CozyTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(Theme.Fonts.cosyBody())
            .foregroundColor(Theme.Colors.cocoaBrown)
            .padding(Theme.Spacing.small)
            .background(Theme.Colors.warmCream)
            .cornerRadius(Theme.CornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.medium)
                    .stroke(Theme.Colors.gentleBorder, lineWidth: Theme.BorderWidth.standard)
            )
    }
}

// MARK: - Animated Button Wrapper

struct CosyButtonPress: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

extension View {
    func cosyButtonPress() -> some View {
        modifier(CosyButtonPress())
    }
}
