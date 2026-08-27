import SwiftUI

struct PromptOptionPreviewContext: Identifiable, Hashable {
    let parameter: PromptParameter
    let option: PromptOption

    var id: String { "\(parameter.rawValue).\(option.id)" }
}

/// A compact, pointer-anchored photo preview for one prompt option.
struct PromptPhotoPreviewPopover: View {
    let context: PromptOptionPreviewContext

    private var recipe: PromptPhotoRecipe {
        context.option.preview.photoRecipe
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PromptPhotoCanvas(recipe: recipe)
                .frame(width: 290, height: 178)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.parameter.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(context.option.title)
                    .font(.headline)
                Text(context.option.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            Text(recipe.sourcePromptToken.isEmpty
                 ? "无，不写入最终英文提示词"
                 : recipe.sourcePromptToken)
                .font(.caption.monospaced())
                .foregroundStyle(recipe.sourcePromptToken.isEmpty ? .secondary : .primary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(width: 314, alignment: .leading)
        .accessibilityIdentifier("prompt-photo-preview.\(context.id)")
    }
}

/// Draws a photographic variation from the same recipe that belongs to the
/// selected prompt option. The source photo remains visible in every variant.
struct PromptPhotoCanvas: View {
    let recipe: PromptPhotoRecipe

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.08)
                layout(in: geometry.size)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                recipeOverlay
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
        }
        .aspectRatio(recipe.aspectWidth / recipe.aspectHeight, contentMode: .fit)
        .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func layout(in size: CGSize) -> some View {
        switch recipe.layout {
        case .single, .faceCloseUp, .fullBody:
            photo(in: size)
        case .triptych:
            HStack(spacing: 2) {
                photo(in: CGSize(width: size.width / 3, height: size.height), offset: -0.16)
                photo(in: CGSize(width: size.width / 3, height: size.height))
                photo(in: CGSize(width: size.width / 3, height: size.height), offset: 0.16)
            }
        case .splitFrame:
            HStack(spacing: 2) {
                photo(in: CGSize(width: size.width / 2, height: size.height), offset: -0.1)
                photo(in: CGSize(width: size.width / 2, height: size.height), offset: 0.1)
            }
        case .contactSheet(let count):
            let columns = count > 4 ? 3 : 2
            let rows = Int(ceil(Double(count) / Double(columns)))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns), spacing: 2) {
                ForEach(0..<count, id: \.self) { index in
                    photo(
                        in: CGSize(width: size.width / CGFloat(columns), height: size.height / CGFloat(rows)),
                        offset: (Double(index % columns) - Double(columns - 1) / 2) * 0.11
                    )
                }
            }
        }
    }

    private func photo(in size: CGSize, offset: Double = 0) -> some View {
        Image(recipe.assetName)
            .resizable()
            .scaledToFill()
            .frame(width: size.width, height: size.height)
            .scaleEffect(recipe.scale)
            .rotationEffect(.degrees(recipe.rotation))
            .rotation3DEffect(.degrees(recipe.perspectiveX), axis: (x: 1, y: 0, z: 0), perspective: 0.45)
            .rotation3DEffect(.degrees(recipe.perspectiveY), axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .offset(
                x: size.width * CGFloat(recipe.offsetX + offset),
                y: size.height * CGFloat(recipe.offsetY)
            )
            .saturation(recipe.saturation)
            .contrast(recipe.contrast)
            .brightness(recipe.brightness)
            .blur(radius: recipe.blur)
            .overlay(toneOverlay)
            .overlay(focusOverlay)
            .clipped()
    }

    @ViewBuilder
    private var toneOverlay: some View {
        toneColor
            .opacity(toneOpacity)
            .blendMode(.color)
    }

    @ViewBuilder
    private var focusOverlay: some View {
        switch recipe.focus {
        case .all:
            EmptyView()
        case .shallow(let radius):
            LinearGradient(colors: [.clear, .black.opacity(0.16)], startPoint: .center, endPoint: .bottom)
                .blur(radius: radius / 3)
        case .face, .eyes:
            RadialGradient(colors: [.clear, .black.opacity(0.34)], center: .top, startRadius: 12, endRadius: 110)
        case .foreground:
            LinearGradient(colors: [.clear, .black.opacity(0.36)], startPoint: .leading, endPoint: .trailing)
        case .background:
            LinearGradient(colors: [.black.opacity(0.28), .clear], startPoint: .leading, endPoint: .trailing)
        case .split:
            HStack(spacing: 0) { Color.clear; Color.black.opacity(0.22) }
        }
    }

    @ViewBuilder
    private var recipeOverlay: some View {
        switch recipe.overlay {
        case .none:
            EmptyView()
        case .softGlow, .halation, .lightLeak:
            LinearGradient(colors: [.white.opacity(recipe.overlayIntensity), .clear, .orange.opacity(recipe.overlayIntensity * 0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .hardShadow, .vignette, .silhouette:
            RadialGradient(colors: [.clear, .black.opacity(recipe.overlayIntensity)], center: .center, startRadius: 35, endRadius: 190)
        case .volumetric, .fog, .mist:
            LinearGradient(colors: [.white.opacity(recipe.overlayIntensity * 0.55), .clear], startPoint: .bottom, endPoint: .top)
        case .bokeh, .neon:
            HStack(spacing: 24) {
                Circle().fill(.pink.opacity(recipe.overlayIntensity)).frame(width: 42)
                Circle().fill(.cyan.opacity(recipe.overlayIntensity)).frame(width: 24)
                Circle().fill(.yellow.opacity(recipe.overlayIntensity * 0.8)).frame(width: 34)
            }
            .blur(radius: 8)
        case .motionTrails:
            Rectangle().fill(.white.opacity(recipe.overlayIntensity)).frame(height: 2).rotationEffect(.degrees(-14)).blur(radius: 2)
        case .rain, .storm:
            LinearGradient(colors: [.blue.opacity(recipe.overlayIntensity), .clear], startPoint: .top, endPoint: .bottom)
        case .snow:
            Image(systemName: "snowflake").font(.system(size: 70)).foregroundStyle(.white.opacity(recipe.overlayIntensity))
        case .dust, .wetReflection, .fineGrain, .coarseGrain, .microTexture, .glossy, .matte:
            Rectangle().fill(.white.opacity(recipe.overlayIntensity * 0.12)).blendMode(.overlay)
        case .cel, .painterly, .graphicInk, .inkWash, .gouache, .retroFuture, .miniature, .lowPoly, .comicDots, .frameWithinFrame:
            Rectangle().stroke(.white.opacity(recipe.overlayIntensity), lineWidth: 3).padding(8)
        }
    }

    private var toneColor: Color {
        switch recipe.tone {
        case .neutral: .clear
        case .warm, .sepia: .orange
        case .cool: .blue
        case .tealOrange: .teal
        case .muted: .gray
        case .vibrant: .pink
        case .monochrome: .gray
        case .pastel: .purple
        case .earth: .brown
        case .cyanMagenta: .cyan
        }
    }

    private var toneOpacity: Double {
        switch recipe.tone {
        case .neutral: 0
        case .monochrome: 0.52
        default: 0.18
        }
    }
}
