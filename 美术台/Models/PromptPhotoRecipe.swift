import Foundation

enum PromptPhotoLayout: Hashable, Sendable {
    case single
    case faceCloseUp
    case fullBody
    case contactSheet(Int)
    case triptych
    case splitFrame
}

enum PromptPhotoTone: String, Hashable, Sendable {
    case neutral
    case warm
    case cool
    case tealOrange
    case muted
    case vibrant
    case monochrome
    case pastel
    case earth
    case cyanMagenta
    case sepia
}

enum PromptPhotoOverlay: String, Hashable, Sendable {
    case none
    case softGlow
    case hardShadow
    case volumetric
    case bokeh
    case motionTrails
    case rain
    case storm
    case snow
    case fog
    case mist
    case dust
    case wetReflection
    case fineGrain
    case coarseGrain
    case halation
    case cel
    case painterly
    case graphicInk
    case inkWash
    case gouache
    case retroFuture
    case miniature
    case lowPoly
    case comicDots
    case neon
    case lightLeak
    case vignette
    case silhouette
    case frameWithinFrame
    case microTexture
    case glossy
    case matte
}

enum PromptPhotoFocus: Hashable, Sendable {
    case all
    case shallow(Double)
    case face
    case eyes
    case foreground
    case background
    case split
}

/// A photographic preview recipe derived from the exact option record that
/// also feeds PromptCompiler. Every option therefore has one stable photo key,
/// one visual treatment and one matching prompt token.
struct PromptPhotoRecipe: Hashable, Sendable {
    let assetName: String
    let sourceOptionID: String
    let sourcePromptToken: String
    let imageKey: String

    var layout: PromptPhotoLayout = .single
    var tone: PromptPhotoTone = .neutral
    var overlay: PromptPhotoOverlay = .none
    var focus: PromptPhotoFocus = .all
    var aspectWidth: Double = 16
    var aspectHeight: Double = 10
    var scale: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0
    var rotation: Double = 0
    var perspectiveX: Double = 0
    var perspectiveY: Double = 0
    var saturation: Double = 1
    var contrast: Double = 1
    var brightness: Double = 0
    var blur: Double = 0
    var overlayIntensity: Double = 0.45

    static func make(
        family: PromptPreviewFamily,
        variant: String,
        promptToken: String
    ) -> PromptPhotoRecipe {
        var recipe = PromptPhotoRecipe(
            assetName: assetName(for: family, variant: variant),
            sourceOptionID: variant,
            sourcePromptToken: promptToken,
            imageKey: "\(family.rawValue).\(variant)"
        )

        if variant == PromptParameter.noneOptionID {
            return recipe
        }

        switch family {
        case .aspectRatio:
            let parts = variant.split(separator: ":").compactMap { Double($0) }
            guard parts.count == 2, parts[0] > 0, parts[1] > 0 else {
                preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }
            recipe.aspectWidth = parts[0]
            recipe.aspectHeight = parts[1]

        case .outputPurpose:
            switch variant {
            case "establishing-keyframe": recipe.scale = 0.78
            case "environment-concept": recipe.scale = 0.86; recipe.tone = .tealOrange
            case "set-design": recipe.layout = .splitFrame; recipe.contrast = 1.08
            case "mood-keyframe": recipe.tone = .cyanMagenta; recipe.overlay = .lightLeak
            case "location-survey": recipe.layout = .triptych; recipe.scale = 0.84
            case "lighting-study": recipe.layout = .triptych; recipe.overlay = .softGlow
            case "color-script": recipe.layout = .contactSheet(6); recipe.tone = .vibrant
            case "face-bible": recipe.layout = .faceCloseUp
            case "character-sheet": recipe.layout = .contactSheet(4)
            case "orthographic-turnaround-sheet":
                recipe.layout = .single
                recipe.aspectWidth = 16
                recipe.aspectHeight = 9
            case "single-full-body-solid-background":
                recipe.layout = .single
                recipe.aspectWidth = 4
                recipe.aspectHeight = 5
            case "full-body": recipe.layout = .fullBody; recipe.scale = 0.82
            case "turnaround": recipe.layout = .contactSheet(4); recipe.scale = 0.86
            case "expression-sheet": recipe.layout = .contactSheet(6); recipe.scale = 2.05; recipe.offsetY = -0.2
            case "wardrobe-lineup": recipe.layout = .triptych; recipe.tone = .vibrant
            case "action-keyframe": recipe.scale = 1.08; recipe.rotation = -4; recipe.offsetX = 0.12
            case "hero-prop": recipe.layout = .splitFrame; recipe.scale = 1.35; recipe.offsetY = 0.22
            case "orthographic": recipe.layout = .triptych; recipe.scale = 0.88
            case "exploded": recipe.layout = .contactSheet(4); recipe.scale = 1.18
            case "material-callout": recipe.layout = .splitFrame; recipe.scale = 2.15; recipe.offsetY = 0.05; recipe.overlay = .microTexture
            case "scale-function": recipe.layout = .splitFrame; recipe.scale = 0.8
            case "in-context": recipe.scale = 0.9; recipe.tone = .tealOrange
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .detailLevel:
            switch variant {
            case "production": recipe.contrast = 1.06
            case "concept": recipe.overlay = .painterly; recipe.saturation = 0.82
            case "refined": recipe.scale = 1.18; recipe.contrast = 1.16
            case "micro": recipe.layout = .faceCloseUp; recipe.scale = 2.4; recipe.overlay = .microTexture
            case "model-sheet": recipe.layout = .fullBody; recipe.saturation = 0.8; recipe.contrast = 1.12
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .visualStyle:
            switch variant {
            case "cinematic-real": recipe.tone = .tealOrange; recipe.overlay = .vignette
            case "photographic": recipe.contrast = 1.04; recipe.saturation = 1.04
            case "film-still": recipe.tone = .warm; recipe.overlay = .fineGrain
            case "3d-anime": recipe.saturation = 1.28; recipe.contrast = 1.18; recipe.overlay = .cel
            case "stylized-3d": recipe.tone = .pastel; recipe.contrast = 1.24; recipe.overlay = .softGlow
            case "chibi-3d-card": recipe.layout = .fullBody; recipe.scale = 0.78; recipe.tone = .pastel; recipe.overlay = .softGlow
            case "love-deepspace-key-art": recipe.layout = .faceCloseUp; recipe.scale = 1.85; recipe.tone = .pastel; recipe.overlay = .softGlow
            case "ue5-oriental-fantasy": recipe.layout = .faceCloseUp; recipe.scale = 2.05; recipe.tone = .cyanMagenta; recipe.overlay = .softGlow
            case "realistic-3d-cultivator": recipe.layout = .faceCloseUp; recipe.scale = 1.75; recipe.saturation = 0.9; recipe.contrast = 0.92
            case "virtual-idol-pbr": recipe.layout = .faceCloseUp; recipe.scale = 1.8; recipe.tone = .cool; recipe.overlay = .softGlow
            case "next-gen-pbr-portrait": recipe.layout = .faceCloseUp; recipe.scale = 1.8; recipe.tone = .cool; recipe.contrast = 0.9
            case "ue5-guoman-male": recipe.layout = .faceCloseUp; recipe.scale = 2.0; recipe.tone = .earth; recipe.overlay = .painterly
            case "anime-cel": recipe.saturation = 1.32; recipe.contrast = 1.34; recipe.overlay = .cel
            case "concept-art": recipe.tone = .earth; recipe.overlay = .painterly
            case "graphic-novel": recipe.saturation = 0.55; recipe.contrast = 1.48; recipe.overlay = .graphicInk
            case "ink-wash": recipe.saturation = 0.08; recipe.contrast = 1.18; recipe.overlay = .inkWash
            case "gouache": recipe.tone = .pastel; recipe.contrast = 1.2; recipe.overlay = .gouache
            case "retro-futurism": recipe.tone = .cyanMagenta; recipe.overlay = .retroFuture
            case "stop-motion": recipe.tone = .warm; recipe.scale = 0.92; recipe.overlay = .miniature
            case "low-poly": recipe.saturation = 1.18; recipe.contrast = 1.35; recipe.overlay = .lowPoly
            case "comic-book": recipe.saturation = 1.35; recipe.contrast = 1.5; recipe.overlay = .comicDots
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .realism:
            switch variant {
            case "naturalistic": recipe.saturation = 0.96
            case "photoreal": recipe.contrast = 1.08; recipe.scale = 1.08
            case "heightened": recipe.saturation = 1.18; recipe.contrast = 1.22; recipe.tone = .tealOrange
            case "stylized": recipe.saturation = 1.25; recipe.overlay = .softGlow
            case "graphic": recipe.saturation = 0.72; recipe.contrast = 1.5; recipe.overlay = .graphicInk
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .composition:
            switch variant {
            case "thirds": recipe.offsetX = 0.23; recipe.scale = 0.92
            case "centered": recipe.scale = 1.04
            case "symmetry": recipe.layout = .splitFrame; recipe.scale = 0.9
            case "golden": recipe.offsetX = -0.18; recipe.offsetY = -0.08; recipe.scale = 0.94
            case "diagonal": recipe.rotation = -8; recipe.offsetX = 0.08
            case "leading-lines": recipe.scale = 0.82; recipe.offsetY = -0.1; recipe.perspectiveY = -5
            case "frame-within": recipe.scale = 0.9; recipe.overlay = .frameWithinFrame
            case "negative-space": recipe.scale = 0.68; recipe.offsetX = 0.34
            case "layered": recipe.layout = .triptych; recipe.scale = 0.94
            case "fill-frame": recipe.scale = 1.95; recipe.offsetY = -0.18
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .shotSize:
            switch variant {
            case "ews": recipe.scale = 0.62
            case "ws": recipe.scale = 0.72
            case "fs": recipe.scale = 0.86
            case "mls": recipe.scale = 1.08; recipe.offsetY = -0.05
            case "ms": recipe.scale = 1.42; recipe.offsetY = -0.12
            case "mcu": recipe.scale = 1.82; recipe.offsetY = -0.2
            case "cu": recipe.scale = 2.35; recipe.offsetY = -0.28
            case "ecu": recipe.scale = 3.25; recipe.offsetY = -0.34
            case "macro": recipe.scale = 4.15; recipe.offsetX = 0.1; recipe.offsetY = -0.32; recipe.overlay = .microTexture
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .cameraAngle:
            switch variant {
            case "eye": break
            case "low": recipe.perspectiveX = -12; recipe.offsetY = 0.1; recipe.scale = 1.05
            case "high": recipe.perspectiveX = 12; recipe.offsetY = -0.08; recipe.scale = 0.94
            case "overhead": recipe.perspectiveX = 28; recipe.scale = 0.82
            case "worm": recipe.perspectiveX = -28; recipe.scale = 1.15; recipe.offsetY = 0.14
            case "dutch": recipe.rotation = -13; recipe.scale = 1.1
            case "three-quarter": recipe.perspectiveY = -10; recipe.offsetX = 0.1
            case "profile": recipe.perspectiveY = 24; recipe.offsetX = -0.12
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .perspective:
            switch variant {
            case "natural": break
            case "one-point": recipe.scale = 0.86; recipe.perspectiveX = -4
            case "two-point": recipe.perspectiveY = 12; recipe.scale = 0.92
            case "three-point": recipe.perspectiveX = -15; recipe.perspectiveY = 10; recipe.scale = 1.02
            case "isometric": recipe.perspectiveX = 12; recipe.perspectiveY = -12; recipe.scale = 0.82
            case "orthographic": recipe.layout = .fullBody; recipe.scale = 0.78; recipe.contrast = 1.05
            case "wide-exaggerated": recipe.scale = 0.68; recipe.perspectiveX = -8; recipe.contrast = 1.1
            case "compressed": recipe.scale = 1.35; recipe.blur = 0.6
            case "fisheye": recipe.scale = 0.72; recipe.overlay = .bokeh; recipe.overlayIntensity = 0.22
            case "anamorphic": recipe.aspectWidth = 21; recipe.aspectHeight = 9; recipe.overlay = .lightLeak
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .focalLength:
            guard let millimeters = Double(variant.replacingOccurrences(of: "mm", with: "")) else {
                preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }
            recipe.scale = min(1.8, max(0.66, 0.58 + millimeters / 165))
            recipe.focus = millimeters >= 85 ? .shallow(min(10, millimeters / 20)) : .all
            recipe.contrast = millimeters <= 24 ? 1.12 : 1.04

        case .lensCharacter:
            switch variant {
            case "clean": recipe.contrast = 1.08
            case "vintage": recipe.tone = .sepia; recipe.contrast = 0.88; recipe.overlay = .fineGrain
            case "anamorphic-2x": recipe.aspectWidth = 21; recipe.aspectHeight = 9; recipe.overlay = .lightLeak; recipe.focus = .shallow(5)
            case "diffusion": recipe.overlay = .softGlow; recipe.contrast = 0.9
            case "macro": recipe.scale = 3.1; recipe.offsetY = -0.28; recipe.focus = .shallow(8)
            case "tilt-shift": recipe.focus = .split; recipe.rotation = -2
            case "vintage-swirl": recipe.tone = .warm; recipe.overlay = .bokeh; recipe.focus = .shallow(7)
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .depthOfField:
            switch variant {
            case "f1.4": recipe.focus = .shallow(12)
            case "f2": recipe.focus = .shallow(10)
            case "f2.8": recipe.focus = .shallow(8)
            case "f4": recipe.focus = .shallow(5)
            case "f5.6": recipe.focus = .shallow(3)
            case "f8": recipe.focus = .all; recipe.contrast = 1.06
            case "f11": recipe.focus = .all; recipe.contrast = 1.12
            case "focus-stack": recipe.focus = .all; recipe.contrast = 1.18; recipe.overlay = .microTexture
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .focusStrategy:
            switch variant {
            case "eyes": recipe.focus = .eyes; recipe.scale = 2.35; recipe.offsetY = -0.28
            case "face": recipe.focus = .face; recipe.scale = 2.05; recipe.offsetY = -0.24
            case "subject": recipe.focus = .shallow(7)
            case "deep": recipe.focus = .all; recipe.contrast = 1.1
            case "foreground": recipe.focus = .foreground
            case "background": recipe.focus = .background
            case "split-diopter": recipe.focus = .split; recipe.layout = .splitFrame
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .motionRendering:
            switch variant {
            case "natural": recipe.overlay = .motionTrails; recipe.overlayIntensity = 0.18
            case "freeze": recipe.contrast = 1.15
            case "crisp": recipe.contrast = 1.1; recipe.overlay = .motionTrails; recipe.overlayIntensity = 0.08
            case "panning": recipe.overlay = .motionTrails; recipe.overlayIntensity = 0.42; recipe.offsetX = 0.12
            case "long": recipe.overlay = .lightLeak; recipe.overlayIntensity = 0.72; recipe.blur = 1.2
            case "intentional": recipe.overlay = .motionTrails; recipe.overlayIntensity = 0.68; recipe.rotation = -5
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .lightQuality:
            switch variant {
            case "motivated": recipe.tone = .warm; recipe.overlay = .softGlow; recipe.overlayIntensity = 0.25
            case "soft": recipe.overlay = .softGlow; recipe.contrast = 0.88
            case "hard": recipe.overlay = .hardShadow; recipe.contrast = 1.4
            case "chiaroscuro": recipe.overlay = .hardShadow; recipe.contrast = 1.58; recipe.brightness = -0.08
            case "high-key": recipe.brightness = 0.16; recipe.contrast = 0.84; recipe.overlay = .softGlow
            case "low-key": recipe.brightness = -0.22; recipe.contrast = 1.28; recipe.overlay = .vignette
            case "silhouette": recipe.overlay = .silhouette; recipe.brightness = -0.18
            case "volumetric": recipe.overlay = .volumetric; recipe.contrast = 1.14
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .lightDirection:
            switch variant {
            case "three-quarter": recipe.overlay = .softGlow; recipe.offsetX = 0.04
            case "front": recipe.brightness = 0.08; recipe.contrast = 0.94
            case "side": recipe.overlay = .hardShadow; recipe.contrast = 1.28
            case "back": recipe.overlay = .lightLeak; recipe.brightness = -0.04
            case "rim": recipe.overlay = .halation; recipe.contrast = 1.2
            case "top": recipe.overlay = .hardShadow; recipe.offsetY = 0.05; recipe.brightness = -0.08
            case "under": recipe.tone = .cyanMagenta; recipe.overlay = .hardShadow; recipe.rotation = 1
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .lightingSetup:
            switch variant {
            case "available": recipe.saturation = 0.92; recipe.contrast = 0.94
            case "window": recipe.overlay = .softGlow; recipe.tone = .cool
            case "three-point": recipe.tone = .tealOrange; recipe.contrast = 1.1
            case "rembrandt": recipe.overlay = .hardShadow; recipe.tone = .warm; recipe.contrast = 1.32
            case "butterfly": recipe.layout = .faceCloseUp; recipe.overlay = .softGlow; recipe.brightness = 0.08
            case "split": recipe.overlay = .hardShadow; recipe.contrast = 1.5
            case "practical": recipe.tone = .warm; recipe.overlay = .bokeh
            case "neon": recipe.tone = .cyanMagenta; recipe.overlay = .neon
            case "fire": recipe.tone = .warm; recipe.overlay = .lightLeak; recipe.overlayIntensity = 0.62
            case "moon": recipe.tone = .cool; recipe.brightness = -0.16; recipe.overlay = .softGlow
            case "studio": recipe.layout = .fullBody; recipe.contrast = 1.08; recipe.brightness = 0.05
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .exposureKey:
            switch variant {
            case "balanced": break
            case "high": recipe.brightness = 0.2; recipe.contrast = 0.88
            case "low": recipe.brightness = -0.24; recipe.contrast = 1.25
            case "under": recipe.brightness = -0.14; recipe.saturation = 1.12
            case "highlight": recipe.brightness = -0.04; recipe.contrast = 0.88; recipe.overlay = .softGlow
            case "silhouette": recipe.brightness = -0.25; recipe.overlay = .silhouette
            case "hdr": recipe.contrast = 1.32; recipe.saturation = 1.08
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .colorTemperature:
            switch variant {
            case "neutral": break
            case "daylight": recipe.tone = .neutral; recipe.brightness = 0.04
            case "tungsten": recipe.tone = .warm; recipe.overlay = .lightLeak; recipe.overlayIntensity = 0.22
            case "warm": recipe.tone = .warm
            case "cool": recipe.tone = .cool
            case "mixed": recipe.tone = .tealOrange
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .colorPalette:
            switch variant {
            case "cinematic": recipe.tone = .tealOrange
            case "warm": recipe.tone = .warm
            case "cool": recipe.tone = .cool
            case "muted": recipe.tone = .muted; recipe.saturation = 0.55
            case "vibrant": recipe.tone = .vibrant; recipe.saturation = 1.45
            case "monochrome": recipe.tone = .monochrome; recipe.saturation = 0
            case "complementary": recipe.tone = .cyanMagenta; recipe.saturation = 1.18
            case "analogous": recipe.tone = .cool; recipe.saturation = 0.9
            case "earth": recipe.tone = .earth
            case "pastel": recipe.tone = .pastel; recipe.contrast = 0.86
            case "teal-orange": recipe.tone = .tealOrange; recipe.saturation = 1.2
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .colorContrast:
            switch variant {
            case "natural": break
            case "low": recipe.contrast = 0.72; recipe.saturation = 0.82
            case "high": recipe.contrast = 1.55; recipe.saturation = 1.12
            case "filmic": recipe.contrast = 0.9; recipe.tone = .warm; recipe.overlay = .fineGrain
            case "lifted": recipe.contrast = 0.78; recipe.brightness = 0.07
            case "crushed": recipe.contrast = 1.45; recipe.brightness = -0.09
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .timeOfDay:
            switch variant {
            case "script": recipe.tone = .neutral
            case "dawn": recipe.tone = .pastel; recipe.overlay = .lightLeak; recipe.brightness = -0.02
            case "day": recipe.brightness = 0.12; recipe.contrast = 0.92
            case "golden-hour": recipe.tone = .warm; recipe.overlay = .lightLeak; recipe.overlayIntensity = 0.55
            case "dusk": recipe.tone = .cyanMagenta; recipe.brightness = -0.08
            case "blue-hour": recipe.tone = .cool; recipe.brightness = -0.12
            case "night": recipe.tone = .cool; recipe.brightness = -0.24; recipe.overlay = .bokeh
            case "midnight": recipe.tone = .cool; recipe.brightness = -0.34; recipe.contrast = 1.35
            case "interior-unspecified": recipe.tone = .neutral; recipe.contrast = 0.96
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .nationality:
            recipe.layout = .faceCloseUp
            recipe.scale = 1.72
            recipe.offsetY = -0.22
            switch variant.utf8.reduce(0, { ($0 + Int($1)) % 4 }) {
            case 0: recipe.tone = .neutral
            case 1: recipe.tone = .warm
            case 2: recipe.tone = .cool
            default: recipe.tone = .earth
            }

        case .historicalEra:
            recipe.scale = 0.9
            recipe.overlay = .fineGrain
            switch variant.utf8.reduce(0, { ($0 + Int($1)) % 4 }) {
            case 0: recipe.tone = .earth
            case 1: recipe.tone = .sepia
            case 2: recipe.tone = .warm
            default: recipe.tone = .neutral
            }

        case .weatherAtmosphere:
            switch variant {
            case "script": break
            case "clear": recipe.brightness = 0.1; recipe.saturation = 1.12
            case "overcast": recipe.tone = .cool; recipe.contrast = 0.72; recipe.saturation = 0.7
            case "rain": recipe.tone = .cool; recipe.overlay = .rain; recipe.brightness = -0.1
            case "storm": recipe.tone = .cool; recipe.overlay = .storm; recipe.brightness = -0.24; recipe.contrast = 1.35
            case "snow": recipe.tone = .cool; recipe.overlay = .snow; recipe.brightness = 0.12
            case "fog": recipe.overlay = .fog; recipe.contrast = 0.55
            case "mist": recipe.overlay = .mist; recipe.contrast = 0.76
            case "dust": recipe.tone = .earth; recipe.overlay = .dust
            case "after-rain": recipe.tone = .tealOrange; recipe.overlay = .wetReflection; recipe.contrast = 1.15
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .subjectPresentation:
            switch variant {
            case "face": recipe.layout = .faceCloseUp; recipe.scale = 2.25; recipe.offsetY = -0.28
            case "beauty": recipe.layout = .faceCloseUp; recipe.scale = 2.45; recipe.offsetY = -0.3; recipe.overlay = .softGlow
            case "head-turnaround": recipe.layout = .triptych; recipe.scale = 2.1; recipe.offsetY = -0.28
            case "expression-sheet": recipe.layout = .contactSheet(6); recipe.scale = 2.15; recipe.offsetY = -0.28
            case "full-body": recipe.layout = .fullBody; recipe.scale = 0.82
            case "turnaround": recipe.layout = .contactSheet(4); recipe.scale = 0.84
            case "silhouette": recipe.layout = .triptych; recipe.overlay = .silhouette; recipe.scale = 0.82
            case "wardrobe": recipe.layout = .triptych; recipe.tone = .vibrant; recipe.scale = 0.88
            case "action": recipe.scale = 1.04; recipe.rotation = -6; recipe.offsetX = 0.16
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .poseDynamics:
            switch variant {
            case "neutral": recipe.layout = .fullBody; recipe.scale = 0.82
            case "a-pose": recipe.layout = .fullBody; recipe.scale = 0.76; recipe.perspectiveY = 1
            case "contrapposto": recipe.rotation = 3; recipe.offsetX = 0.08
            case "relaxed": recipe.rotation = -2; recipe.offsetX = -0.08; recipe.tone = .warm
            case "seated": recipe.scale = 1.18; recipe.offsetY = 0.22
            case "walking": recipe.rotation = -5; recipe.offsetX = 0.18; recipe.overlay = .motionTrails; recipe.overlayIntensity = 0.12
            case "dynamic": recipe.rotation = -10; recipe.scale = 1.16; recipe.offsetX = 0.2; recipe.overlay = .motionTrails
            case "profile": recipe.perspectiveY = 28; recipe.offsetX = -0.12
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .facialExpression:
            recipe.layout = variant == "grid" ? .contactSheet(6) : .faceCloseUp
            recipe.scale = 2.25
            recipe.offsetY = -0.28
            switch variant {
            case "neutral": break
            case "determined": recipe.contrast = 1.18; recipe.tone = .cool
            case "joy": recipe.brightness = 0.1; recipe.tone = .warm; recipe.rotation = 1.5
            case "sorrow": recipe.tone = .cool; recipe.saturation = 0.6; recipe.brightness = -0.08
            case "anger": recipe.contrast = 1.38; recipe.tone = .warm; recipe.rotation = -2
            case "fear": recipe.brightness = -0.08; recipe.contrast = 1.25; recipe.scale = 2.5
            case "enigmatic": recipe.tone = .cyanMagenta; recipe.overlay = .softGlow
            case "grid": recipe.tone = .vibrant
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .backgroundTreatment:
            switch variant {
            case "neutral-gray": recipe.saturation = 0.72
            case "white": recipe.brightness = 0.2; recipe.contrast = 0.82
            case "black": recipe.brightness = -0.28; recipe.contrast = 1.35; recipe.overlay = .vignette
            case "gradient": recipe.tone = .cyanMagenta; recipe.overlay = .softGlow
            case "isolated": recipe.layout = .fullBody; recipe.brightness = 0.12; recipe.contrast = 1.22
            case "context": recipe.scale = 0.78; recipe.tone = .tealOrange
            case "minimal-set": recipe.scale = 0.82; recipe.saturation = 0.82; recipe.contrast = 1.08
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .materialDetail:
            switch variant {
            case "balanced": recipe.contrast = 1.04
            case "microtexture": recipe.scale = 2.75; recipe.offsetY = -0.15; recipe.overlay = .microTexture
            case "tactile": recipe.scale = 1.8; recipe.contrast = 1.24; recipe.overlay = .microTexture
            case "worn": recipe.tone = .earth; recipe.overlay = .coarseGrain; recipe.contrast = 1.18
            case "pristine": recipe.brightness = 0.1; recipe.contrast = 1.08
            case "wet": recipe.overlay = .wetReflection; recipe.contrast = 1.24
            case "dusty": recipe.tone = .earth; recipe.overlay = .dust; recipe.saturation = 0.7
            case "glossy": recipe.overlay = .glossy; recipe.contrast = 1.32
            case "matte": recipe.overlay = .matte; recipe.contrast = 0.82; recipe.saturation = 0.76
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }

        case .finishing:
            switch variant {
            case "clean-digital": recipe.contrast = 1.08
            case "cinematic-grade": recipe.tone = .tealOrange; recipe.contrast = 1.16; recipe.overlay = .vignette
            case "35mm": recipe.tone = .warm; recipe.overlay = .fineGrain
            case "16mm": recipe.tone = .sepia; recipe.overlay = .coarseGrain; recipe.contrast = 1.12
            case "analog": recipe.tone = .warm; recipe.overlay = .lightLeak; recipe.contrast = 0.9
            case "halation": recipe.overlay = .halation; recipe.tone = .warm
            case "hdr": recipe.contrast = 1.4; recipe.saturation = 1.12
            case "monochrome": recipe.tone = .monochrome; recipe.saturation = 0; recipe.overlay = .fineGrain
            default: preconditionFailure("Missing photo recipe: \(family.rawValue).\(variant)")
            }
        }

        return recipe
    }

    private static func assetName(
        for family: PromptPreviewFamily,
        variant: String
    ) -> String {
        switch (family, variant) {
        case (.outputPurpose, "orthographic-turnaround-sheet"):
            "PromptPreviewTurnaroundSheet"
        case (.outputPurpose, "single-full-body-solid-background"):
            "PromptPreviewFullBodySolid"
        default:
            "PromptPreviewModel"
        }
    }
}
