import SwiftUI

enum AppBackgroundVariant {
    case primary
    case elevated
}

struct AppBackgroundView: View {
    var variant: AppBackgroundVariant = .primary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppPalette.backgroundTop, AppPalette.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [AppPalette.neonPurpleGlow.opacity(variant == .elevated ? 0.28 : 0.10), .clear],
                center: .topLeading,
                startRadius: 30,
                endRadius: 360
            )
            .blur(radius: variant == .elevated ? 8 : 0)

            RadialGradient(
                colors: [AppPalette.neonBlueGlow.opacity(variant == .elevated ? 0.24 : 0.08), .clear],
                center: .bottomTrailing,
                startRadius: 60,
                endRadius: 320
            )
            .blur(radius: variant == .elevated ? 12 : 0)

            LinearGradient(
                colors: [AppPalette.glassHighlight.opacity(variant == .elevated ? 0.18 : 0.10), .clear, AppPalette.glassHighlight.opacity(variant == .elevated ? 0.08 : 0.03)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}

struct GlassCardModifier: ViewModifier {
    var accent: Color? = nil
    var cornerRadius: CGFloat = 28
    var strokeOpacity: Double = 0.18
    var fillOpacity: Double = 1
    var shadowOpacity: Double = 1
    var useMaterial: Bool = true
    var accentGlowOpacity: Double = 0.22

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if useMaterial {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(fillOpacity)
                    }

                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppPalette.glassSurfaceStrong, AppPalette.glassSurface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(fillOpacity)

                    if let accent {
                        RadialGradient(
                            colors: [accent.opacity(accentGlowOpacity), .clear],
                            center: .topLeading,
                            startRadius: 10,
                            endRadius: 220
                        )
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    }
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppPalette.glassBorder.opacity(strokeOpacity / 0.18), lineWidth: 1)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(AppPalette.glassHighlight.opacity(0.08), lineWidth: 0.5)
                            .blur(radius: 0.4)
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: AppPalette.shadowDeep.opacity(0.9 * shadowOpacity), radius: 26, y: 14)
            .shadow(color: (accent ?? AppPalette.accentPurple).opacity(0.10 * shadowOpacity), radius: 30, y: 12)
    }
}

extension View {
    func glassCard(
        accent: Color? = nil,
        cornerRadius: CGFloat = 28,
        strokeOpacity: Double = 0.18,
        fillOpacity: Double = 1,
        shadowOpacity: Double = 1,
        useMaterial: Bool = true,
        accentGlowOpacity: Double = 0.22
    ) -> some View {
        modifier(
            GlassCardModifier(
                accent: accent,
                cornerRadius: cornerRadius,
                strokeOpacity: strokeOpacity,
                fillOpacity: fillOpacity,
                shadowOpacity: shadowOpacity,
                useMaterial: useMaterial,
                accentGlowOpacity: accentGlowOpacity
            )
        )
    }
}

struct AccentBadge: View {
    let text: String
    var accent: Color = AppPalette.accentBlue
    var prominent: Bool = false
    var useMaterial: Bool = true

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(prominent ? 0.98 : 0.94))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                if useMaterial {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Capsule()
                                .fill(accent.opacity(prominent ? 0.22 : 0.14))
                        }
                } else {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    accent.opacity(prominent ? 0.24 : 0.18),
                                    AppPalette.glassSurface.opacity(0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay {
                Capsule()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
            }
    }
}

struct GlassIconButton: View {
    let systemImage: String
    var accent: Color = AppPalette.accentBlue
    var size: CGFloat = 48
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white.opacity(0.96))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay {
                            Circle()
                                .fill(accent.opacity(0.16))
                        }
                }
                .overlay {
                    Circle()
                        .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: accent.opacity(0.16), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }
}

struct GlassActionButton: View {
    let title: String
    let systemImage: String
    var accent: Color
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(accent.opacity(0.18))
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(accent.opacity(0.26), lineWidth: 1)
                    }

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.14), AppPalette.glassSurface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
            }
            .overlay {
                Capsule()
                    .strokeBorder(AppPalette.glassBorder.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: accent.opacity(0.14), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.48)
    }
}
