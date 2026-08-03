import SwiftUI

/// "Tatil Nightclub" tema paleti — gece kulübü enerjisiyle tatil/plaj partisi
/// hissini birleştiren koyu zemin + neon mor/magenta/turkuaz vurgular.
enum Theme {

    // MARK: - Ana renkler

    static let midnight = Color(red: 0.043, green: 0.024, blue: 0.114)      // #0B0620 - gece göğü
    static let deepViolet = Color(red: 0.102, green: 0.043, blue: 0.239)    // #1A0B3D
    static let plum = Color(red: 0.176, green: 0.067, blue: 0.333)          // #2D1155

    static let violet = Color(red: 0.545, green: 0.361, blue: 0.965)        // #8B5CF6
    static let magenta = Color(red: 0.925, green: 0.286, blue: 0.600)       // #EC4899
    static let coral = Color(red: 1.0, green: 0.451, blue: 0.396)           // #FF7365
    static let cyan = Color(red: 0.133, green: 0.827, blue: 0.933)          // #22D3EE

    static let mint = Color(red: 0.204, green: 0.827, blue: 0.600)          // #34D399 - başarı
    static let amber = Color(red: 0.984, green: 0.749, blue: 0.141)         // #FBBF24 - uyarı
    static let rose = Color(red: 0.957, green: 0.247, blue: 0.369)          // #F43F5E - hata

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.4)

    // MARK: - Gradyanlar

    /// Ana arkaplan — derin gece göğünden mora geçiş.
    static let backgroundGradient = LinearGradient(
        colors: [midnight, deepViolet, plum],
        startPoint: .top, endPoint: .bottom
    )

    /// CTA butonları, aktif rozetler, öne çıkan vurgular için — neon gün batımı.
    static let primaryGradient = LinearGradient(
        colors: [violet, magenta, coral],
        startPoint: .leading, endPoint: .trailing
    )

    /// İkincil vurgu — havuz/deniz turkuazı, mor zemin üstünde ferahlatıcı kontrast.
    static let accentGradient = LinearGradient(
        colors: [cyan, violet],
        startPoint: .leading, endPoint: .trailing
    )

    // MARK: - Yüzeyler (glassmorphism)

    static let glassFill = Color.white.opacity(0.08)
    static let glassStroke = Color.white.opacity(0.14)
}

// MARK: - Yardımcı view modifier'lar

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.glassFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Theme.glassStroke, lineWidth: 1)
            )
    }
}

struct GlowModifier: ViewModifier {
    var color: Color
    var radius: CGFloat = 16
    func body(content: Content) -> some View {
        content.shadow(color: color.opacity(0.55), radius: radius, x: 0, y: 4)
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius))
    }
    func neonGlow(_ color: Color = Theme.magenta, radius: CGFloat = 16) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

/// Uygulama genelinde kullanılan neon gradyan CTA buton stili.
struct NeonButtonStyle: ButtonStyle {
    var isFullWidth: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Theme.primaryGradient)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .neonGlow(Theme.magenta, radius: configuration.isPressed ? 6 : 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// İkincil (outline/ghost) buton stili — camsı zemin üstünde.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.bold())
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Theme.glassFill)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Theme.glassStroke, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
    }
}

extension ButtonStyle where Self == NeonButtonStyle {
    static var neon: NeonButtonStyle { NeonButtonStyle() }
}
extension ButtonStyle where Self == GhostButtonStyle {
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

/// Ekranın tamamını kaplayan, hafif hareketli "parti ışıkları" arkaplanı.
struct NightclubBackground: View {
    var body: some View {
        ZStack {
            Theme.backgroundGradient.ignoresSafeArea()

            Circle()
                .fill(Theme.magenta.opacity(0.35))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Theme.cyan.opacity(0.25))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: 140, y: -120)

            Circle()
                .fill(Theme.violet.opacity(0.35))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -80, y: 320)
        }
    }
}
