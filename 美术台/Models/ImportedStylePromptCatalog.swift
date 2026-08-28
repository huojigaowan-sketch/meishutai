import Foundation

/// Vendored, immutable prompt cards from a pinned MIT-licensed upstream revision.
/// Do not refresh this catalog without reviewing the new revision and updating
/// THIRD_PARTY_NOTICES.md plus docs/STYLE_LIBRARY_SOURCES.md.
nonisolated enum ImportedStylePromptCatalog {
    static let repository = "YouMind-OpenLab/ai-image-prompts-skill"
    static let revision = "7c065c2b429bc75334239965768849cb00c8987d"
    static let license = "MIT"
    static let sourceFileCount = 8
    static let importedCardCount = 56

    static let cards: [StylePromptCard] = [
        StylePromptCard(
            id: UUID(uuidString: "72C8588B-EEAD-598C-A121-43CB1B7B32D1")!,
            title: "Luxurious Retrofuturistic Train Exterior",
            prompt: "{\n  \"image_generation_prompt\": {\n    \"shot_type\": \"exterior shot, photo\",\n    \"subject\": \"{argument name=\"subject\" default=\"A luxurious retrofuturistic train\"}\",\n    \"color_palette\": [\n      \"{argument name=\"primary color\" default=\"pastel pink\"}\",\n      \"{argument name=\"secondary color\" default=\"mint green\"}\"\n    ],\n    \"interior_design\": {\n      \"style\": \"Zaha Hadid\",\n      \"elements\": \"filled with flowers\",\n      \"features\": \"large windows\"\n    },\n    \"setting\": \"{argument name=\"environment\" default=\"overlooking Paris during cherry blossom season\"}\",\n    \"focus\": \"train exterior\",\n    \"parameters\": {\n      \"aspect_ratio\": \"9:16\",\n      \"version\": 7\n    }\n  }\n}",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32503",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "8411C091-7B02-5F51-BD2A-1C421E88638B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787639837859_idlxzp_HQf9rFua4AEdqW1.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32503"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "D9E9F853-0EEA-59C6-ABC8-9E358A7EE524")!,
            title: "Hybrid 3D Vector Illustration Style",
            prompt: "A sophisticated {argument name=\"subject\" default=\"hybrid human portrait style\"} that seamlessly combines the whimsical, glossy dimensional rendering of a premium 3D fantasy illustration with the clean, elegant simplicity of contemporary flat vector portraiture. Depict the human subject with recognizable anatomy, natural facial proportions, authentic expression, and clearly identifiable features, while transforming the overall appearance into a refined stylized illustration. The face should combine smooth dimensional modeling with simplified graphic planes: softly sculpted skin, subtle volumetric shading, delicate highlights, clean angular shapes, and carefully controlled flat-color regions. Use the visual language of premium digital character illustration: luminous expressive eyes, softly rendered skin, smooth flowing hair with layered strands, polished highlights, gentle depth, tactile surfaces, and subtle painterly transitions. At the same time, simplify the rendering with elegant vector-like shapes, clean silhouettes, controlled linework, minimal visual noise, and clearly defined color planes inspired by modern editorial portrait illustration. Integrate {argument name=\"artistic elements\" default=\"flowing artistic elements around the human figure, such as fluid paint splashes, soft liquid ribbons, abstract organic shapes\"}. These elements should feel energetic and three-dimensional, organically emerging from the portrait rather than appearing as a separate background decoration. Hair should combine clean graphic masses with silky dimensional strands and sweeping flowing shapes. Facial features should remain refined and human, enhanced with subtle geometric simplification rather than exaggerated cartoon distortion. Clothing should use bold simplified silhouettes with restrained geometric detailing, maintaining an elegant contemporary fashion-illustration appearance. Color treatment should merge the warm, restrained palette of modern vector portraiture with the {argument name=\"color scheme\" default=\"vibrant tropical energy of whimsical fantasy illustration\"}: warm coral, orange, cream, peach, turquoise, cyan, sky blue, deep navy, emerald, red, golden yellow, and subtle lavender accents. Use mostly clean saturated color fields, enhanced selectively with soft gradients, glossy highlights, translucent edges, and gentle volumetric illumination. Background should remain clean and uncluttered, preferably a simple warm solid or softly textured backdrop, allowing the human subject and surrounding artistic splashes to remain the primary focus. The final aesthetic should feel like an original fusion of elegant editorial vector portrait, contemporary digital painting, whimsical 3D character illustration, premium fashion artwork, and colorful fluid fantasy art — clean yet richly dimensional, sophisticated yet playful, expressive, polished, tactile, modern, artistic, and visually distinctive.",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32411",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "F1270A9B-86C0-53AD-BBA7-101F2F472921")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552793135_75pudi_HQZ5lDnbMAAjjNN.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "B977025A-9CB7-55E0-B65D-4593C1683F78")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552793140_0ibsb7_HQZ5lD9bAAApjg8.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "70A98392-31E5-5350-B037-7B2962B3D26A")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552793095_nx9jpa_HQZ5lDlaIAAKtp0.jpg",
                    sourceLabel: "上游完整样板 3"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32411"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "CA53D78C-8FA6-5B47-B365-130D260DF74F")!,
            title: "Serene Landscape and Surreal Figure at Sunset",
            prompt: "A tranquil digital landscape featuring a vibrant, glowing sunset over distant mountains, with the sun casting {argument name=\"reflections\" default=\"pastel reflections of pink, purple, and turquoise\"} across a calm lake. Two small, forested islands with tall pine trees frame the foreground, and the overall mood is serene and dreamlike, with soft gradients and minimalistic composition set against a muted, hazy background.\n\nA surreal landscape featuring a lone figure standing beneath a large tree with {argument name=\"tree details\" default=\"glowing purple leaves\"} on a cliff edge, overlooking a distant mountain at sunset. A stream of luminous turquoise water flows down the cliff, emitting magical sparkles. The scene is bathed in soft pastel colors, creating a tranquil and mystical atmosphere.",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32186",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "5F012506-7283-54DE-A6E9-E38DC18CAA92")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787379851536_v99f1l_HQQ44bQXoAAEdYz.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "891C1AC4-C2A6-5EE0-87DD-24774884C4A6")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787379851506_zj81ft_HQQ46uPW0AAavV9.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32186"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "8F1F8D75-F8A3-5EBA-B0A5-BE93FFBD81AB")!,
            title: "Edge Aware ASCII Art Conversion",
            prompt: "Apply an ASCII-art rendering effect to the reference image, where the ASCII character density and placement is driven by the underlying tonal contrast and edges of the photo, like a true edge-aware ASCII-art conversion. Dense character clusters follow the natural contours, silhouette lines, and high-detail areas (such as hair strands, fabric folds, and background structure), while flatter, low-contrast areas (such as smooth skin) stay comparatively clean with minimal or no texture. The effect should look like the ASCII characters are tracing the actual shapes and edges present in the photo, not a uniform overlay pasted on top of everything equally. Use a classic {argument name=\"color scheme\" default=\"green-on-black or grayscale\"} terminal character set ({argument name=\"character set\" default=\"@ # % & * + . :\"}), {argument name=\"density\" default=\"medium\"} overall density, with the original photo still legible underneath.",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31570",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "DC714A51-8CE9-57B8-8816-EE80A2E9B2F3")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786947851995_vupmgp_HPzCszWbkAAcggR.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "B8939C51-FF4E-5E17-B80F-7D5373F7EF7F")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786947851956_8bzhi2_HPzCwxTasAARNuf.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "7396983D-FE12-5FA0-8E7B-7A7490120522")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786947853667_fc61wc_HPzC1VOboAAvKbB.jpg",
                    sourceLabel: "上游完整样板 3"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31570"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "A40B778C-8B69-5F15-AC0E-BD365CAD9AE2")!,
            title: "Vacuum Sealed Logo Installation",
            prompt: "A DETAILED 3D INSTALLATION OF THE UPLOADED LOGO MOUNTED ON A SOLID CONCRETE WALL. ONLY THE LOGO ITSELF IS VACUUM-SEALED AND WRAPPED TIGHTLY IN A LAYER OF GLOSSY {argument name=\"color\" default=\"COLOR\"} PLASTIC SHRINK-WRAP, FOLLOWING THE EXACT CONTOUR OF EVERY LETTER AND SHAPE. THE PLASTIC FILM TIGHTLY HUGS THE EDGES OF THE LOGO, CREATING REALISTIC CRINKLES AND SHARP SPECULAR HIGHLIGHTS ON THE LOGO'S SURFACE. THE BACKGROUND WALL IS CLEAN CONCRETE, FREE OF ANY PLASTIC WRAPPING OR FRAMES. STUDIO SPOTLIGHTS CAST SOFT, REALISTIC DROP SHADOWS: FROM THE WRAPPED LOGO ONTO THE WALL. RATIO 1080X1350 VERTICAL.",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31468",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "C25EA7A8-568A-5570-A324-1CA4388E35B5")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774865701_c02f05_HPsDnRIbkAAlDge.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "C85417B5-5147-5889-AAD8-6A5A6777EA2B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774865865_w6ta19_HPsDnREbAAA14PB.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "987B588A-0D36-5E43-8952-9A886C71EF15")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774865686_nwd4t2_HPsDnRDaEAA__S8.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "EA47637C-5AA4-5D5D-9EBD-8925B0F2EDE9")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774866499_8h6ujx_HPsDnRFboAAcm7T.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31468"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "816325EB-689D-513A-8BDF-55FB5978B311")!,
            title: "Stylized Editorial Hybrid Composition",
            prompt: "{argument name=\"subject\" default=\"<subject>\"} in this style={argument name=\"transformation\" default=\"<transformation>\"} - Preserve the subject’s recognizable structure, but reinterpret it as a stylized editorial composition where drawing and miniature object-world logic coexist. - Convert some forms into sparse grainy line illustration while converting other forms into soft pastel miniatures or still-life objects. - Reinterpret texture-rich or detailed areas as small clusters of plants, props, vessels, terrain fragments, or decorative micro-world motifs. - Convert smooth surfaces into matte pastel color fields, while using graphic linework to describe edges, volume, and texture selectively. - Reduce complexity into a limited color system with one dominant graphic ink tone and a few quiet pastel support colors. - Replace deep realism with poster-like clarity, paper-print tactility, and curated tabletop arrangement. - Allow the subject to feel partially drawn and partially physically staged, creating a deliberate ambiguity between illustration and object. - Use negative space and sparse composition to keep the image clean, modern, and highly readable. </transformation> <shape_language> - Favor simple containers, rounded objects, leaves, stems, pebbles, tabletop silhouettes, miniature clusters, and clean abstract forms. - Use a mix of flat contour areas and soft low-relief sculptural accents. - Keep repetition rhythmic and decorative. - Let small details feel intentional and editorial rather than busy. </shape_language> <rendering_rules> - Use visibly grainy printed or crayon-like marks for lines and texture accents. - Keep volumetric forms soft, simplified, and pastel. - Limit the palette aggressively for a designed, print-friendly look. - Use {argument name=\"depth\" default=\"shallow spatial depth\"} with subtle diorama hints. - Make the final result feel like an art print, a magazine illustration, and a miniature set all at once. </rendering_rules> <finish> - Graphic limited-palette editorial hybrid. - Printmaking texture fused with soft pastel mini-world staging. - Smart, modern, collectible, and quietly distinctive. </finish> <avoid> - Avoid photoreal rendering. - Avoid deep cinematic perspective or strong realism. - Avoid overstuffing with too many tiny details. - Avoid using too many colors; keep it controlled and designed. </avoid>",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31339",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "14EE1EDF-9B54-5091-B8EA-76B1A67F9BF4")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774883701_7370ff_HPcPNsEXYAA95EP.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31339"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "4E27069A-98ED-5057-8C5B-8397BFAEE486")!,
            title: "Topographic Contour Line Portrait",
            prompt: "A highly refined contemporary mixed-media portrait style combining an ethereal high-key fashion aesthetic with intricate concentric contour-line artwork inspired by natural growth rings and fingerprint-like topographic patterns. The human subject should retain an elegant, soft, luminous, almost dreamlike presence while the entire visual structure is organically constructed through hundreds of delicate continuous concentric and flowing contour lines. Replace conventional flat shading and ordinary outlines with dense nested curved lines that follow the anatomy and three-dimensional structure of the human form. The lines should naturally conform to the contours of the face, forehead, cheeks, nose, lips, jaw, neck, shoulders, clothing, and hair, creating the illusion that the entire subject is sculpted from flowing rings and fine engraved contours. The line patterns should behave like organic topographic growth rings rather than geometric circles. Lines continuously expand, contract, bend, merge, separate, and change direction according to the underlying form. Around the eyes, nose, lips, and facial planes, the contours become tightly concentrated and delicately curved; across larger surfaces they gradually spread into wider flowing rings. Hair should be constructed from extremely fine flowing contour strands, with hundreds of elongated curved lines sweeping outward and merging into larger concentric patterns. The hair should feel weightless and fluid, almost dissolving into the surrounding background while maintaining an intricate line-based structure. Preserve the reference's soft luminous skin, delicate facial modeling, subtle blush, translucent highlights, pale neutral tones, and graceful editorial beauty. The human form should remain recognizable and aesthetically refined beneath the contour-line construction rather than becoming an abstract pattern. Introduce selective high-density black and charcoal contour areas to create depth and visual emphasis. Lines become progressively darker and closer together in recessed areas and shadow regions, while highlights contain sparse, extremely fine pale-gray lines and larger areas of negative space. This creates tonal values entirely through line density and spacing, rather than conventional painted shading. Allow portions of the contour lines to extend beyond the silhouette, forming expansive organic rings and flowing arcs around the subject. These external lines should gradually fade, break apart, become thinner, and dissolve into the background, creating an atmospheric transition between the human figure and the surrounding space. Use a predominantly luminous ivory, white, soft gray, pale beige, and subtle natural skin-tone palette, with deep charcoal-black lines providing controlled contrast. Maintain a clean, airy, almost monochromatic elegance while preserving subtle full-color skin undertones. The surface should have a fine tactile paper or archival-art texture",
            category: .general,
            tags: ["开源风格", "MIT", "应用与网页设计"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/app-web-design.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：30941",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "13689C1A-E215-5B33-81C6-89201D30D962")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786344502610_xvq442_HPU_tBzbEAApHG0.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "FE844872-1FA4-5BDC-98B2-23CECB903D1C")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786344503219_as3r0u_HPU_t_2bcAAsxVq.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/app-web-design.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "30941"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "7C757310-3BA5-5EFC-BB90-C4441EC41E0B")!,
            title: "Claymation Style Aliens in Desert",
            prompt: "Three claymation style {argument name=\"alien color\" default=\"green\"} aliens in {argument name=\"outfit style\" default=\"silver suits\"} stand in a {argument name=\"environment\" default=\"desert landscape\"} at night. The aliens are positioned in the center of the frame, with the middle alien slightly taller than the other two. They are all wearing silver jumpsuits with black belts and boots. The background features a large, full moon in a starry sky, with dark clouds obscuring parts of it. Cacti and desert plants surround the aliens, and rocky terrain is visible in the foreground. The lighting suggests a nighttime scene, with the moon casting a soft glow.",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32661",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "21BD0122-3F36-5D5D-A346-0C34D6DD51A9")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824273892_luubwm_HQo1H1DWAAEE31Y.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32661"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "5B9CA05A-EA64-5551-828D-41EB3634346D")!,
            title: "Grand Library Reader Portrait",
            prompt: "{\n  \"title\": \"{argument name=\"title\" default=\"THE READER OF THE GRAND LIBRARY\"}\",\n\n  \"scene\": \"{argument name=\"scene description\" default=\"Inside an enormous historic library with towering wooden bookshelves reaching toward an ornate vaulted ceiling. A tall arched window overlooks the quiet world outside as golden afternoon sunlight streams through, illuminating countless floating dust particles.\"}\",\n\n  \"subject\": \"{argument name=\"subject\" default=\"A beautiful young woman sits gracefully beside the arched window, reading an old leather-bound book. She wears an elegant dark green classic dress with a refined posture and a gentle, thoughtful smile, completely immersed in the timeless atmosphere of the library.\"}\",\n\n  \"detail\": \"Rich mahogany bookshelves are lined with thousands of antique books. Intricate carved woodwork, vintage brass lamps, worn leather bindings, polished wooden floors, and elegant architectural details enhance the luxurious interior. Soft rays of sunlight highlight the pages of the book while delicate dust motes shimmer in the warm light. Every fabric fold, hair strand, and skin texture is rendered with exceptional realism.\",\n\n  \"atmosphere\": \"Luxurious, peaceful, intellectual, nostalgic, elegant, timeless, cinematic, and inviting.\",\n\n  \"lighting\": \"Golden afternoon sunlight pouring through the tall arched window, Renaissance-inspired lighting, warm cinematic glow, soft natural shadows, volumetric light rays, realistic global illumination, and subtle ambient lighting.\",\n\n  \"composition\": \"Intimate cinematic portrait with the subject positioned beside the arched window, towering bookshelves framing the scene, eye-level perspective, shallow depth of field, creamy bokeh, and balanced editorial composition.\",\n\n  \"style\": \"Photorealistic, cinematic editorial photography, Renaissance-inspired lighting, Kodak Portra film colors, ultra realistic textures, realistic skin details, masterpiece, HDR, highly detailed, film grain, shallow depth of field, volumetric lighting, 8K.\"\n}",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32675",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "4960307D-95B5-5574-B676-1C1212920A70")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824282769_f1nlqo_HQqQn1va0AA7Pr5.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32675"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "01EBE2AB-E1AA-5E16-8C81-EFD22AF408BD")!,
            title: "3D Stylized Cartoon Girl on Stone Stool",
            prompt: "A full-body stylized 3D cartoon girl with {argument name=\"eye color\" default=\"large sparkling emerald-green\"} eyes, soft rosy cheeks, a gentle smile, and an innocent expression. She has {argument name=\"hair style\" default=\"messy platinum-blonde hair tied in a voluminous bun\"} with loose strands framing her face. She is sitting on a small stone stool with both hands supporting her cheeks in a cute, dreamy pose. She wears an {argument name=\"outfit\" default=\"off-shoulder light gray top, loose white harem pants with a rustic fabric belt\"}, and is barefoot with delicate ankle wraps. A small blue butterfly rests near her feet, with a white flower on the ground. Soft studio background, cinematic lighting, highly detailed stylized 3D rendering, painterly textures, smooth skin shading, whimsical fantasy atmosphere, premium animated feature film quality.",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32318",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "EDEFF101-78BA-54DD-A0E8-1A29A8D26798")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787466532881_16qv2a_HQV3iYCbUAA0jWx.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32318"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "0BB26646-0E6A-5787-9855-18BADA0ACA08")!,
            title: "70s Iran Political Group Portrait",
            prompt: "{argument name=\"group\" default=\"a left party\"} from {argument name=\"country\" default=\"iran\"} {argument name=\"decade\" default=\"70s\"} in tehran , like a communism man",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32194",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "5C0E6D24-4C71-5AE3-9A94-E3A26342688B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787379856020_x8scoe_HQRp55lXMAE50GZ.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32194"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "690D96AA-84A0-5178-BBE4-E75B0D47BCE0")!,
            title: "Whimsical Animal at Night",
            prompt: "A cute white bear sits alone on the edge of a waterfront at night, gazing across the shimmering water toward a brightly lit modern city skyline with a prominent tower. The sky is filled with stars and wispy clouds, creating a dreamy, serene atmosphere in a soft, anime-inspired art style. A cute white cartoon cat with big blue eyes sits on a wooden dock by a calm lake at twilight, holding a glowing lantern that reflects on the water. The background features lush green trees, lily pads, and a serene sky filled with stars and wispy clouds, creating a peaceful and enchanting mood in a soft, whimsical art style.",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31992",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "0F3D67D0-5826-58F2-A536-B168062EA439")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293543889_1p4qb1_HQHRazNXYAAu3r1.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "A61CC46E-FFE0-5278-8C90-C2FFBCF3CCCE")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293543883_e4porw_HQHRbUNXkAA5XPm.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31992"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "D51F9533-BA25-5F5F-B927-820B70A1DBF8")!,
            title: "Premium Organic Honey Commercial Storyboard",
            prompt: "TITLE: Premium Organic Honey Product Commercial Storyboard\n\nFORMAT:\n• Single-page premium storyboard\n• 3:4 Portrait ratio\n• Luxury food product campaign\n• 8 cinematic storyboard scenes\n• Product remains the visual hero\n• Premium advertising agency presentation\n\nHEADER:\n• Elegant serif typography\n• Information cards:\n  - Duration: {argument name=\"duration\" default=\"20 Seconds\"}\n  - Style: Natural Luxury Food Commercial\n  - Product: {argument name=\"product\" default=\"Organic Honey\"}\n  - Audio: Soft Nature ASMR\n• Why This Style Works section\n• {argument name=\"color theme\" default=\"Cream, amber and gold\"} aesthetic\n• Minimal honeycomb decorative details\n\nSTORYBOARD:\n1. Premium honey jar standing on a warm wooden surface\n2. Jar lid slowly opening in macro close-up\n3. Golden honey being lifted with a wooden honey dipper\n4. Honey flowing in an extremely slow silky stream\n5. Macro shot of honey texture and natural highlights\n6. Honey dripping over warm toast\n7. Honey jar surrounded by honeycomb and fresh ingredients\n8. Final luxury hero packshot with golden honey splash\n\nEVERY PANEL:\n• Scene number\n• Duration badge\n• Camera direction\n• Visual\n• Action\n• Product detail\n\nCAMERA:\nExtreme macro, slow-motion liquid photography, controlled push-in, top-down composition, shallow depth of field, cinematic hero shot.\n\nSTYLE:\nUltra-realistic honey texture, realistic liquid physics, warm natural lighting, premium food photography, glossy glass jar, elegant reflections, luxury organic branding, 8K.",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31995",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "9E2B8330-2CF5-5439-8573-F892A8960D05")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787208876029_xmncg0_HQF19kdacAATv1I.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31995"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "7CF77551-5F85-5A44-800E-5AF1254EE038")!,
            title: "Premium Instant Noodles Ad Storyboard",
            prompt: "TITLE: Premium Instant Noodles Product Commercial Storyboard\n\nFORMAT:\n• Single-page premium storyboard\n• 3:4 Portrait ratio\n• High-energy food advertisement\n• 8 cinematic product scenes\n• Product-focused commercial presentation\n\nHEADER:\n• Modern bold typography\n• Information cards:\n  - Duration: {argument name=\"duration\" default=\"20 Seconds\"}\n  - Style: Cinematic Food Advertisement\n  - Product: {argument name=\"product\" default=\"Instant Noodles\"}\n  - Audio: Cooking ASMR + Energetic Beat\n• Why This Style Works section\n• {argument name=\"accent colors\" default=\"Warm yellow and red\"} accents\n\nSTORYBOARD:\n1. Instant noodle packet standing upright with dramatic lighting\n2. Packet opening and noodles sliding into a bowl\n3. Boiling water pouring over noodles\n4. Noodles cooking with realistic steam rising\n5. Seasoning powder being added\n6. Chopsticks lifting perfectly cooked noodles\n7. Extreme macro shot of glossy noodles with toppings\n8. Final hero bowl beside the original product packet\n\nEVERY PANEL:\n• Scene number\n• Duration badge\n• Visual\n• Action\n• Camera direction\n• Product detail\n\nCAMERA:\nMacro food photography, overhead composition, steam close-up, noodle pull shot, dramatic product push-in, cinematic hero framing.\n\nSTYLE:\nUltra-realistic food commercial, realistic steam, detailed noodle texture, glossy broth, vibrant ingredients, professional studio lighting, premium packaging, 8K.",
            category: .camera,
            tags: ["开源风格", "MIT", "漫画分镜"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/comic-storyboard.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31997",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "25F32B8F-DC51-535F-AAAF-BC7F92FE99ED")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787208877458_0x85ko_HQE90xdaYAA8DRm.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/comic-storyboard.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31997"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "61F36B40-DAD2-53A9-91DA-617AC9108825")!,
            title: "Premium Beverage Advertising Photography",
            prompt: "Create one single photorealistic premium advertising photograph for the fictional beverage {argument name=\"beverage name\" default=\"ENFLAMMER\"}. Use all attached references",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32582",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "2AB8EE7A-4A11-51A9-9FB5-CA30B4E48CCC")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787725587170_ybmfk7_HQkQQPWXQAEWzlh.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "087D5593-E62E-5A36-BBA9-C8718B2F41BB")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787725586482_xe4ag2_HQkQR8NWoAAhzRJ.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32582"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "EFEFF3D2-0534-5EA3-93AB-AA70A0B50BB3")!,
            title: "Elegant Black Organza Ribbon",
            prompt: "Elegant {argument name=\"color\" default=\"Black\"} {argument name=\"material\" default=\"Organza\"} Ribbon",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32200",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "21E7A466-D9BD-5BA0-9B80-49AFB2892EBF")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787379863537_o4kkad_HQSrCbNbUAAFin6.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "DD3C473A-E5DE-591B-A658-DA87749FC370")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787379862312_ngg148_HQSrHiAbEAAuvwV.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32200"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "21DAB997-3C92-56AF-A8DD-2378BE068F1A")!,
            title: "Luxury Chocolate Ad Still Life",
            prompt: "A bright, stylized still life and a conceptual photograph from an advertisement for {argument name=\"product\" default=\"premium chocolate\"} on a {argument name=\"background color\" default=\"delicate, pastel pink background\"}. In the center is a luxurious dark chocolate bar wrapped in gold foil, slightly unwrapped to reveal glossy chocolate lying on a small pink velvet cushion. It is surrounded by a custom-made multi-tiered glass tray system descending from the top left. On the topmost tier there are whole cocoa beans, on the middle - pieces of roasted almonds, and on the bottom - small pieces of chocolate that fall into an elegant pink porcelain bowl. Various chocolate ingredients are laid out on the pink surface around the bar: right in front of the bar, on a delicate pink napkin, there is a large round plate filled with chocolate truffles. There is a small gold spoon and fork next to it. On the right is a tall cylindrical pink container with a golden label of the chocolate brand. There is an inscription on the lid: \"{argument name=\"main text\" default=\"LUXURY CHOCOLATE IS A PREMIUM CHOICE\"}.\" On the side: \"HANDMADE CHOCOLATE, 150 g\" with large letters \"LUX\". Around the main plate are three separate pink plates with ingredients: a plate with whole cocoa beans (far left), a small central plate with pieces of caramel and a long plate with roasted almonds (far right). There are several pieces of chocolate and truffles scattered on the surface of the table, and five small truffles are neatly arranged on the rightmost plate. There are many text elements on and around the image: Top right: \"LUXURY TASTE\", typed in a clean white font. On the left (vertically): \"Contact- 1 (800) 555 2020\", On the handset (vertically): \"Focus on creativity in photography and video.\" At the bottom of the center: \"LUXE VISION\". Logos in the form of three intertwining circles are located at the top left and bottom left. The soft but clear lighting highlights the texture of the chocolate and ingredients, and the overall composition is carefully chosen to show the transformation of raw cocoa into refined, ready-to-eat chocolate",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31658",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "609FB75F-B762-5EC1-973C-CCC180C50E1B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787034148215_konuoa_HP5xPIWaQAAXOUa.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "EB7CE9DF-D6BE-52AA-AD97-72871179D4CB")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787034148165_o7j5ax_HP5xPoVaAAAkJH8.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "F160E1F4-E54C-5E5E-AE5C-69A7AC08DFA2")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787034148171_kdnoti_HP5xQIdbYAAqA5j.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "95719AEA-1B65-5A61-BF9B-1D2AA31D059D")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787034148977_3gqt63_HP5xQqVbMAEVdnz.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31658"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "C60FF7BA-E576-5BF3-AB6B-00A77627D3C5")!,
            title: "Surreal Beauty Product Hair Roller",
            prompt: "Studio product photo shot from behind of a person with {argument name=\"hair color\" default=\"light brown\"} wavy/curled hair styled into large voluminous curls, viewed from the back of the head down to the shoulders. Multiple identical product tubes — {argument name=\"product\" default=\"product from uploaded photo\"} — are inserted into the hair like oversized velcro rollers/curlers, tucked between the curls at various angles all across the head, roughly 3-4 tubes visible, creating a playful surreal \"product as hair roller\" concept. The person wears a solid {argument name=\"shirt color\" default=\"green\"} collared top/shirt with a popped collar. Background is a flat, solid muted olive-green studio backdrop matching the tonal palette of the outfit. Even, soft studio lighting with minimal shadows, clean commercial beauty-photography look, slightly desaturated warm color grading. Composition is centered and vertical, tight crop from mid-shoulders up, no face visible — only the back of the head and hair. Photorealistic, high-end beauty/cosmetics advertising style, aspect ratio 3:4.",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31569",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "709F16F9-0CD8-5639-B21F-96A31E0038F0")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786947850240_ttctun_HP0JcjGa0AASb60.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31569"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "74B10007-769F-54C7-BBB2-9327286DB1CE")!,
            title: "Raspberry Shell Product Photography",
            prompt: "Studio product photo of {argument name=\"product\" default=\"product from uploaded photo\"} encased inside a hyper-realistic, oversized cross-section of a raspberry, split into two halves that wrap around and cradle the product like a protective shell, with the product sitting centered, floating slightly with a soft contact shadow; the raspberry surface shows glossy, dew-covered individual drupelets with visible juice dripping down realistically over the product, fine details like tiny hairs and moisture droplets, hyper-realistic CGI product photography style, high-end commercial advertising look, soft diffused studio lighting with subtle rim light, seamless light grey studio backdrop with subtle gradient, vertical composition, clean and minimal, no text overlays unless part of the product's own packaging.",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31465",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "44B40BAE-5F7D-5BC8-9FBF-9C577F23C6E6")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786861118125_5etqo8_HPuiXwBawAAatce.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "105038C5-9C52-52A3-9C7B-27E10F85ECF9")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786861118109_96hh3y_HPuiYSwbEAAwv4Z.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "6B13C9B3-2F2C-510B-BAE6-D2C8B2B22A18")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786861118389_a1sfeo_HPuiYw1bQAApiNE.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "64754493-27C7-5242-B157-A94877CDE20F")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786861119491_eytjfp_HPuiZP5a8AAPcB1.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31465"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "E7F4CEA7-5213-59A3-8E15-D02E4E0937A1")!,
            title: "Cinematic Product Advertisement with Spider Web",
            prompt: "Using the uploaded product as the exact reference, preserve its original shape, branding, packaging, label, logo, colors, proportions and details. Do not redesign, replace or modify the product in any way. Create a premium minimalist advertising composition in a {argument name=\"aspect ratio\" default=\"panoramic 21:9\"} format. Use a seamless studio background matching the {argument name=\"background color\" default=\"dominant color of the product\"} with a soft radial gradient and subtle vignette. On the far left, place a {argument name=\"hand gesture\" default=\"generic red web-pattern glove performing a web-shooting hand gesture\"}. A realistic white spider web shoots horizontally across the frame, maintaining identical thickness across approximately 80% of its length. Only near the product should the web naturally wrap around, attach to, interact with, or visually blend into the product in a clean and satisfying way while preserving the product's original appearance. The web should remain the same width throughout the composition and create a smooth, seamless transition from left to right. Keep the composition clean with plenty of negative space. Luxury commercial product photography, ultra-realistic, premium advertising aesthetic, soft studio lighting, realistic shadows, ultra-sharp focus, glossy details, 8K, highly detailed, photorealistic.",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31061",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "5E9B69B7-DD82-5A5C-8FE3-77FE99F1AEE7")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786518697805_jwa3cd_HPZ-iD6bMAAwf-F.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "390B6365-5701-55CF-95C3-27D336018B92")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786518698084_80d9zk_HPZ-ikwacAArGuQ.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31061"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "4CE8F3EB-AB38-5293-A601-3694A58DFCA4")!,
            title: "Product in Ice Cube Minimalist",
            prompt: "{argument name=\"product\" default=\"iPhone 18 Pro\"} inside ice cube, white background",
            category: .prop,
            tags: ["开源风格", "MIT", "电商主图"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/ecommerce-main-image.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：30800",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "926ACC03-EFFC-553D-A928-4CFCC3957A63")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786257225958_njgnpk_HPLRmraa8AAW99W.png",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/ecommerce-main-image.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "30800"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "48D5F7F2-4EF2-57E9-9B99-86F6521C8222")!,
            title: "Manga Character Nendoroid Style Diorama",
            prompt: "<instruction> 1. Semantic Inference Engine Input A is a {argument name=\"character\" default=\"Manga/Anime Character or Comic Book Hero\"} (e.g., Goku, Spider-Man, All Might). Deconstruct the character to generate 3 Action Assets: The Power (The Effect): Identify the {argument name=\"attack\" default=\"signature attack\"}. (e.g., Fireball, Web-Slinging, Psychic Blast, Lightning). The Sound (The Onomatopoeia): Identify the {argument name=\"sound effect\" default=\"comic book sound effect text\"}. (e.g., \"BOOM!\", \"SMASH!\", \"THWIP!\", \"KABOOM!\"). The Color (The Aura): Identify the primary energy color. (e.g., Orange, Red, Purple, Green). 2. Container (The Display Stand): Goal: \"Nendoroid\" Style Diorama Photography. The Stage: A simple L-Shaped Display Base (Vertical Back wall + Horizontal Floor). The Backdrop: The vertical wall is covered in a collage of Black & White Manga Panels or Comic Strips, creating a chaotic, ink-heavy background. 3. The Figure (The Chibi Hero): The Style: Chibi / Super-Deformed (SD). Large head, small body, big expressive eyes. The Pose: Dynamic, mid-air action pose (punching towards the camera or casting a spell). The Material: Smooth, matte PVC or Vinyl Plastic (collectible toy aesthetic). 4. The Visual FX (The 2.5D Impact): The Text: The \"Sound\" (Step 1) is rendered as large, jagged, colorful 3D Text Plates (Orange/Red with black outlines) floating in the air around the character. The Debris: 3D shards of rock, glass, or torn paper fly outward from the center, simulating an explosion. The Energy: Translucent, colored plastic parts (representing the \"Power\") swirl around the figure's hands or feet. 5. Lighting & Atmosphere: Lighting: Bright Studio Key Light. Even, shadowless illumination typical of toy photography. Vibe: Energetic, playful, and explosive. Output: ONE image, 1:1 Aspect Ratio, 3D Render, \"Anime Figure\" aesthetic, High Saturation. </instruction>",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32662",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "74D27CE6-326F-5236-9662-CC7675CE110F")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275323_zvc7vd_HQiIeVbW8AE7rHc.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "47A5F2C2-23F7-5960-8EBC-D8F3EEC67DE4")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275344_7uyl1o_HQiIecjWsAAJw7C.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "495F86C1-D6D2-5989-80E3-B6995FBC1634")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275287_4gvrkn_HQiIeVYXMAA40pK.jpg",
                    sourceLabel: "上游完整样板 3"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32662"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "3D325170-9719-5455-AA2F-20C3A72EFCAD")!,
            title: "Cinematic Liquid Splash Portrait",
            prompt: "Ultra-realistic IMAX-level Netflix-style cinematic fantasy portrait, 4:5 vertical frame, use the uploaded image as the primary facial reference with maximum face consistency, create a young woman leaning dynamically toward the camera while reaching one hand directly forward into the foreground, her extended hand appearing dramatically larger due to strong perspective and shallow depth of field, fingers naturally spread as if playfully reaching toward the viewer, her other arm positioned naturally closer to her body, upper body leaning forward with an energetic spontaneous posture, wearing a {argument name=\"clothing\" default=\"soft beige flowing draped outfit\"} wrapped naturally around her upper body, {argument name=\"hair style\" default=\"messy high bun\"} with abundant textured strands escaping around the crown, temples and sides of her face, several fine flyaway strands lifted naturally around her head, surrounded by dramatic frozen splashes of {argument name=\"liquid colors\" default=\"vivid turquoise, red, pink, golden-yellow and orange paint-like fluid\"} forms sweeping upward and outward around her body, individual droplets suspended sharply in the air, colorful fluid arcs creating a dynamic circular frame around her, bright neutral background visible between the splashes, highly detailed translucent liquid surfaces with realistic reflections and refractions, strong foreground-background depth separation, cinematic perspective, crisp facial detail with the reaching hand gradually becoming softer toward the closest foreground due to lens depth, realistic motion energy frozen at the exact moment of the splash, sophisticated studio lighting with soft frontal illumination on her face and subtle highlights along the wet fluid droplets and hair strands, vibrant but naturally balanced colors, realistic fabric texture, natural photographic detail, cinematic depth of field, high dynamic range. Facial Expression: her eyes are wide open and looking directly into the camera with a bright playful gaze, eyebrows naturally raised with excitement, mouth opened into a broad genuine smile showing her upper teeth, lips naturally stretched by the smile, cheeks noticeably lifted and rounded with natural smile lines forming around the eyes and mouth, creating a joyful spontaneous energetic expression.",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32399",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "089D4E72-7D3F-5C77-9C9A-FE2CD55D9B57")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787639844605_3cbv9r_HQdbMO1aMAAy6DN.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "73A08710-8AD3-5E86-A600-B5838976E8E2")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787639844557_555q4h_HQdbMO9aMAAOtlc.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "BE5B901E-710B-5C66-A8F2-21028247A96C")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787639844623_o6zh82_HQdbMO8bUAE4BwP.jpg",
                    sourceLabel: "上游完整样板 3"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32399"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "09EE4068-7CE5-55F2-8890-9897CEEBF0F1")!,
            title: "Sydney Sweeney Gaming Setup Portrait",
            prompt: "{\n  \"subject\": {\n    \"identity\": {\n      \"biometric_reference\": \"{argument name=\"celebrity\" default=\"Sydney Sweeney\"}\",\n      \"facial_structure\": \"Recognizable soft facial proportions, bright blue eyes, clear transparent-framed glasses, subtle natural makeup, soft pink lips, diamond stud earrings\",\n      \"skin\": \"Fair complexion, smooth natural skin texture, clear anatomical definition, zero smoothing\"\n    },\n    \"hair\": {\n      \"color\": \"Blonde\",\n      \"style\": \"Sleek shoulder-length bob cut with a clean middle part\",\n      \"finish\": \"Soft, natural texture and hair movement\"\n    },\n    \"body\": {\n      \"somatotype\": \"Fit, athletic, well-defined waist and torso alignment\",\n      \"precision\": \"Seated forward in an ergonomic gaming chair, leaning slightly back with head tilted gently to the side\"\n    },\n    \"wardrobe\": {\n      \"apparel\": \"{argument name=\"clothing\" default=\"White ribbed sleeveless crop tank top, paired with dark blue drawstring lounge shorts\"}\",\n      \"textiles\": \"Ribbed cotton knit for top, soft fleece cotton for shorts\",\n      \"branding_override\": \"No text or logos on apparel\",\n      \"accessories\": \"Layered diamond tennis necklaces and a gold chain, gold chain bracelet on wrist\"\n    },\n    \"pose_action\": {\n      \"posture\": \"Seated comfortably on a grey textured gaming chair, arms resting casually near the armrests, head tilted slightly to her right\",\n      \"expression\": \"Relaxed, subtle engaging look directly toward the camera lens\"\n    }\n  },\n  \"scene\": {\n    \"environment\": \"{argument name=\"room style\" default=\"Modern gaming setup and streaming room, featuring a grey fabric ergonomic gaming chair\"}\",\n    \"lighting\": \"Vibrant purple LED ambient background illumination combined with soft, clean white key lighting directly illuminating the subject's face and upper torso\"\n  },\n  \"camera\": {\n    \"framing\": \"9:16 vertical aspect ratio, eye-level portrait shot, medium close-up framing centered on the subject and gaming chair setup\",\n    \"lens_settings\": \"35mm lens, sharp focus on subject's face, glasses reflection, and chair details, smooth background falloff\",\n    \"aesthetic\": \"High-end streamer portrait photography, vibrant color contrast, sharp details, realistic skin texture\"\n  },\n  \"negative_constraints\": {\n    \"anatomy\": \"No extra limbs, no deformed fingers, no extra fingers, no fused digits, no asymmetrical eyes, no bad anatomy\",\n    \"rendering\": \"No beautify smoothing, no plastic skin, no low quality, no blur on face, no noise, no compression artifacts\",\n    \"elements\": \"No unwanted text on clothing, no extra watermarks, no logos other than 'Pinodi'\"\n  }\n}",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31876",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "666DA8F5-D0F1-5651-8098-8526E4FE895B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787120731463_cj0t5w_HQBN45eXcAAtoxR.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "B423F705-D924-58D5-8AFF-FED9A8C866B7")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787120731466_ws5vlb_HQBN6XfWgAA5RQu.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31876"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "7F7B0E9E-36C8-5D65-AE0B-D32F76FB5196")!,
            title: "Cinematic Android in Nature",
            prompt: "Cinematic {argument name=\"character\" default=\"Android\"} in {argument name=\"setting\" default=\"Meadow\"}",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31885",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "9A422287-28D6-5CE0-98FA-1C4082284C21")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787120741335_arstps_HQAhYD6WAAAGizs.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31885"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "3E658348-C07D-568B-BAB8-1CF736496468")!,
            title: "Futuristic Arachnid Gamer Persona",
            prompt: "Transform the uploaded person into a premium original {argument name=\"color scheme\" default=\"black-and-crimson\"} futuristic {argument name=\"theme\" default=\"arachnid-inspired\"} character in a cinematic gaming-room environment while preserving the person’s natural appearance and recognizable identity.\nFORMAT LOCK\nVertical 3:4 composition. Full-body portrait. Subject completely visible from head to shoes. High-angle cinematic camera looking downward. Centered framing. Premium editorial gaming-room photography.\nIDENTITY LOCK\nUse the uploaded image as the only identity reference. Preserve the exact facial structure, hairstyle, skin tone, age, body proportions, expression, and overall recognizable appearance. Do not redesign, exaggerate, beautify, or alter the person’s natural features.\nCHARACTER DESIGN\nCreate a completely original futuristic tactical outfit using matte black technical fabric, deep crimson accents, subtle geometric patterns inspired by arachnid structures, realistic stitching, layered materials, and understated protective panels. Add a small original geometric chest insignia with no recognizable superhero symbol. The design should feel like premium futuristic fashion-tech, completely distinct from existing movie, comic, or game costumes.\nENVIRONMENT\nPremium modern gaming bedroom with charcoal interiors, crimson LED lighting, gaming desk, RGB keyboard and mouse, large monitor displaying abstract red geometric artwork, gaming chair, minimalist bed, collectible shelves, warm practical lighting, and dark wooden flooring. Keep the environment sophisticated, clean, cinematic, and uncluttered.\nPOSE\nSubject stands naturally in the center. One hand rests naturally inside the outfit pocket while the other holds a gaming controller. Direct eye contact with the camera. Calm, confident expression. Natural posture, relaxed shoulders, believable anatomy, and realistic hand positioning.\nCAMERA\nHigh-angle cinematic perspective looking downward. Full-body framing with enough surrounding environment to establish the gaming room. Natural lens perspective. Realistic depth of field. Subject remains the primary focal point.\nLIGHTING & STYLE\nSoft cinematic key lighting. Deep controlled shadows. Subtle crimson ambient illumination. Natural skin tones. Gentle rim lighting. Realistic fabric reflections. Soft volumetric atmosphere. Premium editorial color grading. Photorealistic fashion photography. Extremely detailed textures. Sharp facial detail. Realistic materials. High-end cinematic gaming campaign aesthetic. Ultra-detailed 8K quality.",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31469",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "CA6CC021-98E9-50A6-926A-1128FD73750E")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774867558_66snrz_HPskDdrW0AA1KBB.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "5B9F3C40-A4EA-572C-9B5D-840F2BE92D6A")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774867607_5l7ubd_HPskDdUWgAAbE8D.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31469"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "53F27C02-6759-5472-B100-F36AC56B247C")!,
            title: "Clockpunk Miniature Botanical Greenhouse",
            prompt: "Whimsical miniature world depiction of a {argument name=\"subject\" default=\"grand botanical greenhouse conservatory\"} imagined and rendered in an {argument name=\"art style\" default=\"artistic clockpunk\"} style.",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31482",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "06424C4E-0B5E-5E24-B96F-D6E897D6B079")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774884248_2ixnrt_HPsVAUpbMAEn8oh.png",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31482"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "850947B7-0EA1-5A4B-B1AF-C2FCB7D6AAF6")!,
            title: "Futuristic Glass Turbine Engine",
            prompt: "A sleek high-performance frosted glass turbine workhorse engine with anodized aluminum housing and layered refractive glass prisms, firing an ultra-fast {argument name=\"light beam\" default=\"vivid mint light beam\"} with elongated holographic circuit light trails at extreme velocity, asymmetrical composition on rule of thirds grid :: Editorial 3D glassmorphism, refractive glass panels, smooth ceramic, brushed steel, anodized metallic elements, subsurface scattering, light dispersion, chromatic aberration, caustics :: {argument name=\"background\" default=\"Deep charcoal slate and midnight navy background\"}, soft glowing mint highlights with vivid emerald internal glow, subtle deep oceanic blue environmental reflections, clean color separation :: Cinematic studio lighting, volumetric lighting, f/1.8 aperture, extreme bokeh macro photography, deep-focus perspective, {argument name=\"composition\" default=\"minimalist, extreme negative space\"} --ar 16:9 --no text, font, letters, typography, words, watermarks, UI elements, borders, people, faces, humans, hands, laptops, desks, offices, cartoon, vector, clip art, fleshy, biological, organic, busy background, warm colors, red, yellow, purple, noise, clutter",
            category: .prop,
            tags: ["开源风格", "MIT", "游戏资产"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/game-asset.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31475",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "54BF010C-DC1C-567B-907F-F39A95932B11")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774873705_nwlq8t_HPrlVpcaoAADayY.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "70231A3E-E016-5261-BFDD-A7B90B502FBA")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786774873489_vytibt_HPrlVpebsAAoZDd.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/game-asset.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31475"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "C14E6FD8-1976-5CCA-8F8A-F6BC53D3C453")!,
            title: "Premium liquid glass Bento grid product infographic with 8 modules",
            prompt: "Input Variable: [insert product name]\nLanguage: [insert language]\n\nSystem Instruction:\nCreate an image of premium liquid glass Bento grid product infographic with 8 modules (card 2 to 8 show text titles only).\n1) Product Analysis:\n→ Identify product's dominant natural color → \"hero color\"\n→ Identify category: FOOD / MEDICINE / TECH\n2) Color Palette (derived from hero):\n→ Product + accents: full saturation hero color\n→ Icons, borders: muted hero (30-40% saturation, never black)\n3) Visual Style:\n→ Hero product: real photography (authentic, premium), 3D Glass version [choose one]\n→ Cards: Apple liquid glass (85-90% transparent) with Whisper-thin borders and Subtle drop shadow for floating depth and reflecting the background color\n→ Background stays behind cards and high blur where cards are [choose one]:\n  - Ethereal: product essence, light caustics, abstract glow\n  - Macro: product texture close-up, heavily blurred\n  - Pattern: product repeated softly at 10-15% opacity\n  - Context: relevant environment, blurred + desaturated\n→ Add subtle motion effect\n→ Asymmetric Bento grid, 16:9 landscape\n→ Hero card: 28-30% | Info modules: 70-72%\n4) Module Content (8 Cards):\nM1 — Hero: Product displayed as real photo / 3D glass / stylized interpretation (choose one)in beautiful form + product name label\nM2 — Core Benefits: 4 unique benefits + hero-color icons\nM3 — How to Use: 4 usage methods + icons\nM4 — Key Metrics: 5 EXACT data points\nFormat: [icon] [Label] [Bold Value] [Unit]\nFOOD: Calories: [X] kcal/100g, Carbs: [X]g (fiber [X]g, sugar [X]g), Protein: [X]g, [Key Vitamin]: [X]mg ([X]% DV), [Key Mineral]: [X]mg ([X]% DV)\nMEDICINE:Active: [name], Strength: [X] mg, Onset: [X] min, Duration: [X] hrs, Half-life: [X] hrs \nTECH:Chip: [model], Battery: [X] hrs, Weight: [X]g,[Key spec]: [value], Connectivity: [protocols]\nM5 — Who It's For: 4 recommended groups with green checkmark icons | 3 caution groups with amber warning icons\nM6 — Important Notes: 4 precautions + warning icons\nM7 — Quick Reference:\n→ FOOD: Glycemic Index + dietary tags with icons\n→ MEDICINE: Side effects + severity with icons\n→ TECH: Compatibility + certifications with icons\nM8 — Did You Know: 3 facts (origin, science, global stat) + icons\nOutput: 1 image, 16:9 landscape, ultra-premium liquid glass infographic.",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：6847",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "31AE3232-0156-5DF0-92DD-AA74C9FD26EF")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1768962051381_l9uih4_537980579-6f29d32a-c786-40c4-bd5a-79c640737496.png",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "4ED64D38-FAE6-5CCF-A6FD-B4B05D0F066E")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1768962076321_nu4c5q_537981099-d18d0e38-f7ac-4781-a5da-6d68e2380885.png",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "6847"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "EDB2876A-5B98-5859-89BD-17FBF34DAEA3")!,
            title: "Hand-drawn style header image prompt from photo",
            prompt: "Completely recreate the uploaded person.\nMake it a header image for a note article where that person introduces “Nano Banana Pro”.\nAspect ratio: horizontal 16:9.\nStyle and colors: simple, hand-drawn style, italic, with a blue and green gradient.\nTitle text: “In-depth explanation of Google’s new AI ‘Nano Banana Pro’”.",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：498",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "C40687E4-43A6-5FD9-9E56-A2D3AF37E8E4")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763885651870_4szbai_G6VZiROagAAqsIh.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "0DE4D38F-358A-5B40-92C4-B3A437A09DD3")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763885654537_qf6h9o_G6VZiRWaIAA_9x5.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "498"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "C35284E5-3262-5B65-BC8B-45B27B75DEF4")!,
            title: "Watercolor map of Germany with labeled states",
            prompt: "Generate a map of Germany in watercolor style, on which all federal states are labeled in ballpoint pen.",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：380",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "723ECD7C-6717-555D-A128-C3BD0A4656E9")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763886061720_fzgqaq_G6RIeSZXgAA7cOf.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "380"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "EA20F754-B59D-5486-BC46-F8260C1FA3A6")!,
            title: "Vintage Patent Document for an Invention",
            prompt: "A vintage patent document for {argument name=\"invention\" default=\"INVENTION\"}, styled after late 1800s United States Patent Office filings. The page features precise technical drawings with numbered callouts (Fig. 1, Fig. 2, Fig. 3) showing front, side, and exploded views. Handwritten annotations in fountain-pen ink describe mechanisms. The paper is aged ivory with foxing stains and soft fold creases. An official embossed seal and red wax stamp appear in the corner. A hand-signed inventor's name and date appear at the bottom. The entire image feels like a recovered archival document—authoritative, historic, and slightly mysterious.",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：3438",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "F7621A76-63E7-542C-9023-DE8C7C37B645")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1766940094520_1mg5pd_G8_m2ZVWEAAMG7y.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "C426C25D-2DA4-5DE9-9EA0-CBE9EB0B34BE")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1766940095035_8t8iil_G8_mW4FWwAEwERE.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "EA33BC2A-55B5-5053-9551-FDF69824E050")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1766940095188_kt8ksq_G8_m_7hWoAAw19u.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "A93FDF54-3FC8-535C-B8FB-EF50F5A2894A")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1766940096864_fhv4oo_G8_nePrXUAAHvgn.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "3438"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "045F76DB-733C-56D4-A342-30047527DB43")!,
            title: "Chalkboard-style AI news summary",
            prompt: "Using the following content, summarize the news in a chalkboard-style, hand‑written look, and break it down with diagrams and easy‑to‑understand expressions as if a teacher had written it.\n—-\nSearch results from Grok",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：509",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "5783AA03-C09B-578B-87DA-298981F35D21")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763885620059_vzaj75_G6WfVvIbAAEgvYg.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "31A7576B-E7CB-5633-9EBE-A93394400978")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763885622901_pk1vka_G6P2CkracAINIfP.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "509"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "5275F225-C2B4-545A-B182-B2DB42191D4E")!,
            title: "Whimsical Coloring Page Illustration",
            prompt: "A black and white line drawing features the text \"{argument name=\"quote\" default=\"DOING MY BEST RESULTS MAY VARY\"}\" in large, bold, bubble-style lettering. The text is surrounded by various cute and whimsical elements, including smiling stars, a cat face, clouds, daisies, hearts, cupcakes, a boba tea, and sparkly starbursts. The overall composition is dense and playful, designed as a coloring page.",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32501",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "CC9AFBE1-CE1D-5CE2-9181-DC7C3FE5A030")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787639835929_41tdel_HPMiazuWYAA5e7F.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32501"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "5940C767-A11B-5F78-8263-C948A352F7AC")!,
            title: "Professional Beef Taco Product Photography",
            prompt: "A high-quality professional product photograph of three premium loaded beef tacos arranged neatly on a dark ceramic plate, centered against a warm terracotta-orange seamless studio background. Each taco features a crisp golden corn shell filled with juicy seasoned grilled beef, melted cheddar cheese, fresh shredded lettuce, diced tomatoes, purple onions, jalapeño slices, and creamy lime sauce. The beef has realistic grilled texture and subtle char marks, while the vegetables appear fresh and vibrant with natural moisture. Soft cinematic studio lighting creates rich highlights and subtle shadows beneath the plate. Ultra-sharp focus, DSLR macro food photography, premium Mexican fast-food advertisement style, hyper realistic, clean commercial composition, 8K. Aspect Ratio: 1:1 Create a hyper-realistic exploded vertical infographic composition of a premium loaded beef taco. Top → Bottom structure: Fresh Cilantro Garnish → Lime Crema → Jalapeño Slices → Diced Tomato & Onion → Shredded Lettuce → Melted Cheddar Cheese → Seasoned Grilled Beef → Crispy Corn Shell Every element must be perfectly centered, evenly spaced, and aligned vertically. Show realistic grilled beef texture, melted cheese, crisp vegetables, fresh herbs, creamy sauce, and a detailed crunchy corn shell. Use a warm terracotta-orange seamless studio background, soft commercial lighting, subtle realistic shadows beneath every floating element, ultra-sharp DSLR macro food photography, premium fast-food infographic aesthetic, clean professional composition, hyper realistic, 8K. Add clean minimalist infographic text labels with thin pointer lines using these exact labels: \"Cilantro\" \"Lime Crema\" \"Jalapeños\" \"Tomato & Onion\" \"Lettuce\" \"Cheddar Cheese\" \"Grilled Beef\" \"Corn Shell\" Aspect Ratio: 1:1 The tacos start to slowly spin while the ingredients separate gently and precisely, maintaining alignment and scale. The motion is smooth, appetizing, and controlled with no extra effects.",
            category: .general,
            tags: ["开源风格", "MIT", "信息图与教育视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/infographic-edu-visual.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32322",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "8B196338-3284-5DDE-9275-378345C5FEC5")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787466537773_lhlib8_HQVoTC-a0AAbNyI.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/infographic-edu-visual.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32322"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "944E78B1-CD4A-5E53-B53A-8C760EECE8A2")!,
            title: "Wide quote card with portrait and Chinese/English customization",
            prompt: "A wide quote card featuring a famous person, with a brown background and a light-gold serif font for the quote: “{argument name=\"famous_quote\" default=\"Stay Hungry, Stay Foolish\"}” and smaller text: “—{argument name=\"author\" default=\"Steve Jobs\"}.” There is a large, subtle quotation mark before the text. The portrait of the person is on the left, the text on the right. The text occupies two-thirds of the image and the portrait one-third, with a slight gradient transition effect on the portrait.",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：151",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "BD673BC9-77D5-5592-9B3A-66F3AB36D3C1")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763886933714_5zqn1e_G6QBjQHbgAE3Yt_.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "AD9CA93A-7DE5-5EAE-9FE6-8F0FC6C12C02")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763886938314_wbcfc7_G6QBiiracAInQ8z.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "38B5418C-B288-54FD-8084-F69C8E2E67E6")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763886941069_1d9ace_G6QBii_acAIRxKd.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "117A0EBE-DC21-5721-8A87-321CA90AF444")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763886946388_nwahev_G6QBikOaEAAmYkO.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "151"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "25B2C032-E61A-578A-83D5-B7859917DEA1")!,
            title: "Object Replacement Inpainting Prompt",
            prompt: "Replace the magenta region with an object matching the size/shape/lighting of nearby {argument name=\"subject\" default=\"subject\"}, but in {argument name=\"color\" default=\"color\"}. Keep everything else unchanged.",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32413",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "E5BCBDAF-BF21-506C-9DE4-C79BE6F9FAAF")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552793635_cmwx69_HQbC89_WsAAXS3h.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32413"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "DD57E454-7EF3-5548-B839-E89196F12AF8")!,
            title: "Classical Fat Cat Painting",
            prompt: "{argument name=\"animal\" default=\"A very fat cat\"} is lounging on a {argument name=\"furniture\" default=\"plush, ornate armchair\"}. The cat is predominantly white with patches of brown and black tabby markings on its head, back, and tail. Its belly is exceptionally large and hangs down. The cat is positioned with its front paws resting on the armrest and its hind legs stretched out. The armchair has a patterned fabric in shades of brown and gold. In the background, a framed painting with a landscape scene is visible. The overall style of the image is reminiscent of a {argument name=\"style\" default=\"classical painting\"}.",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32198",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "38415B3B-7672-57AA-BF8E-7E1F41096456")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787379859767_tmhbwg_HPCB5X-WkAEMmbf.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32198"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "63488A01-0BB5-55E2-BD23-1F588E2CF71C")!,
            title: "Blackglass Ascendant System Prompt",
            prompt: "SYSTEM PROMPT: BLACKGLASS ASCENDANT\n\nRewrite the user's text, image, or both as one prompt for GPT Image Gen V2 or Nano Banana Pro. Use GPT unless Nano is named. Preserve language, text, references, and requested or source ratio.\n\nUse three systems. Ascendant Frame gives one subject, object, building, creature, or terrain mass dominance through silhouette, viewpoint, scale, framing, and an open field. Blackglass Lattice builds the dark mass from plates, feathers, folds, joints, cables, ridges, metal, leather, stone, glass, or another owned material. Silverfall Halo uses a pale counterform and one hard source to reveal edges, reflective planes, atmosphere, and depth.\n\nDetermine subject, state, silhouette, viewpoint, dark-material owner, construction, pale counterform, source, edge route, focal transition, scale marker, and quiet region.\n\nDark surfaces need separation. Glossy plates carry narrow reflections; matte fabric absorbs light; leather shows seams; metal shows thickness and joints; feathers and hair use grouped masses before fine edges. Patterns and engravings appear only when requested and follow curvature, ownership, and function. Preserve anatomy, object use, support, access, and perspective.\n\nLight appears only on source-facing contours. No complete glowing outline, random chrome highlights, global bloom, flat black collapse, or blank white surfaces. Atmosphere, snow, ash, rain, or dust needs a source and direction. Keep one source, a weak return surface, two to four caused transitions, a focal region, and one low-detail field.\n\nUse five values from deep black to white edge. Preserve explicit colors; otherwise use near-monochrome with one restrained accent. Remove praise, mood labels, prestige terms, fake detail, repetition, and unresolved choices. Use concrete nouns and active verbs. No em dash or en dash.\n\nGPT: return 500 to 800 words in five paragraphs covering scene, subjects, frame, lattice, halo, transitions, composition, references, text, and failures.\n\nNANO: return JSON only, 1000 to 1800 tokens, using \"aspect_ratio\", \"references\", \"scene\", \"subjects\", \"ascendant_frame\", \"blackglass_lattice\", \"silverfall_halo\", \"transitions\", \"composition\", \"surface_and_palette\", \"text\", \"avoid\". Omit unused fields. No metadata, IDs, weights, or comments.\n\nReturn only the finished prompt.",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32101",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "6E5170D7-42CE-5711-A4C8-56DCDD33B881")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293544474_wnrzdy_HQKbHMUWcAEvEG6.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "2B052F6E-09DB-52DC-A756-2CBC54261625")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293544259_qklyok_HQKbHMOWwAAANx4.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "70DCD0EE-8DBE-5627-A736-D0FC3B72EE0D")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293544539_fjpf1u_HQKbHMeXYAAsjDS.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "988096D3-5301-55BE-B18A-D590CC883FEA")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293545226_jwjbkl_HQKbHMLW8AANU-_.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32101"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "18EADBFA-651F-515F-963D-93C0797A7E61")!,
            title: "Water-level Bridge Modification",
            prompt: "flatten the bridge completely so it's running just above the surface of the water.",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31654",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "3318CE1D-457B-51B3-A0B6-B9A52BD2A01C")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786947843973_bf0jlx_HP2zVJWbEAAKpZk.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "0750F004-90C9-56F7-B7F3-744F5C49D941")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786947843685_ypbnu6_HP2zW_raoAA1Rv0.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31654"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "C75EA0C5-D218-589F-9C47-E28B0DAAFFDF")!,
            title: "Woman Riding Black Horse on Beach",
            prompt: "Create an ultra-photorealistic cinematic fashion photograph of an elegant woman riding a powerful {argument name=\"horse color\" default=\"jet-black\"} horse along a {argument name=\"setting\" default=\"pristine tropical beach\"} during a bright, windy afternoon.\\n\\nSUBJECT:\\nA striking adult woman with long, naturally wavy dark hair flowing dramatically in the ocean breeze. She has refined natural facial features, realistic skin texture, subtle pores, delicate facial asymmetry, and a calm, confident expression. She looks slightly toward the camera while maintaining a believable riding posture.\\n\\nShe is wearing a luxurious flowing {argument name=\"dress color\" default=\"crimson-red\"} off-shoulder dress made from lightweight semi-transparent chiffon and silk. The dress has realistic folds, layered fabric, natural stitching, subtle fabric texture, and a long flowing train extending dramatically behind her. The wind catches different sections of the dress independently, creating complex natural movement rather than a perfectly uniform wave.\\n\\nHer posture must look like that of a real experienced rider: balanced torso, naturally positioned legs, relaxed but controlled hands holding the reins, realistic contact between her body and the horse.\\n\\nHORSE:\\nA magnificent muscular black horse with a glossy but completely natural coat. Highly detailed facial anatomy, realistic eyes, nostrils, ears, mane, muscles, veins, and individual strands of hair.\\n\\nThe horse is moving at a fast but believable gallop along the shoreline. Its front legs and rear legs must have anatomically correct positioning and realistic joint movement. Hooves interact naturally with the wet sand, producing small splashes and scattered grains of sand.\\n\\nThe horse wears an elegant but practical dark leather bridle and saddle with realistic stitching, buckles, leather texture, subtle wear, and believable physical attachment.\\n\\nENVIRONMENT:\\nA breathtaking tropical beach stretching into the distance.\\n\\nOn the left side, crystal-clear turquoise-blue ocean water approaches the shoreline with small white waves and realistic foam.\\n\\nBehind the rider are tall tropical palm trees bending slightly in the ocean breeze, dense green vegetation, white sand, and a distant coastline.\\n\\nThe sky is enormous and dramatic, filled with large naturally shaped cumulus clouds against a rich blue tropical sky.\\n\\nThe beach should not look artificial or perfectly clean. Include tiny footprints, hoof marks, irregular wet patches, small shells, scattered natural debris, subtle sand texture, and realistic variations in color.\\n\\nMOVEMENT:\\nCapture the exact moment when the horse is galloping beside the water.\\n\\nThe woman's hair should be blown backward and sideways by the wind, with hundreds of individual strands behaving naturally.\\n\\nThe red dress should trail behind her in multiple layers, with different sections of fabric",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31576",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "24AD7BD1-5F93-5100-8BE4-F16F6E126261")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786861132845_lqtxor_HP0PIaCacAA8zdI.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31576"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "770D237F-CE2F-57B2-944A-E74F17FE42C8")!,
            title: "Golden Gate Bridge LED Screen",
            prompt: "{argument name=\"subject\" default=\"Golden Gate Bridge\"} as if it were a {argument name=\"dimensions\" default=\"64 x 32\"} LED screen and have only one color per pixel",
            category: .general,
            tags: ["开源风格", "MIT", "综合视觉"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/others.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31257",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "E87DF50C-2A6B-5847-BFF8-FBB15DF5FBEC")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1786603824925_c9lra3_HPe5zaIa0AAI0z_.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/others.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31257"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "FEAC3032-0687-590F-85AD-18DE01005AB0")!,
            title: "New Year's Day Special: Four-Panel Puzzle for 2026 Blessing",
            prompt: "[Key: Maintain precise facial features, retain original face structure, the character in the image must be completely consistent with the uploaded reference image] High-end photo studio 2x2 grid photo. Top-left panel (Navy Blue background): The character wears a navy blue uniform-style dress, decorated with gold buttons, vintage curls with a blue beret and pearl earrings. She holds up a huge puzzle piece (top-left piece, with the number \"20\" on it) with both hands, moving it towards the center of the frame. Her eyes are focused on the central puzzle area, her expression is serious, with a slight smile. The background features navy stripes, an anchor, and the text \"Set Sail for the New Year\". Top-right panel (Cherry Blossom Pink background): The same woman wears a pink lace dress, a pearl necklace, a princess hairstyle with a pink rose hairpin and crystal earrings. She holds up the top-right puzzle piece (with the number \"26\" on it) with both hands, moving it towards the center to connect with the top-left piece. Her eyes look at the puzzle seam, her expression is focused and expectant, and her body leans forward. The background features pink cherry blossoms, the text \"Beautiful Encounter\", butterflies, and petals. Bottom-left panel (Mint Green background): The same woman wears a mint green cotton and linen dress, in an artistic style, with natural long hair, a green hairband, and wooden earrings. She holds up the bottom-left puzzle piece (with the text \"New Year's Day\" on it) with both hands, moving it upwards to connect with the top-left piece. Her eyes look at the puzzle, her expression is serious, and her mouth is slightly pursed. The background features green plants, the text \"Hope Grows\", new sprouts, and leaves. Bottom-right panel (Lemon Yellow background): The same woman wears a yellow dress with a sunflower pattern, pigtails with yellow bows. She pushes in the last bottom-right puzzle piece (with the text \"Happy\" on it) to complete the puzzle. The four pieces perfectly form the complete pattern \"2026 New Year's Day Happy\" in the center of the frame. She tilts her head back, looking at the completed puzzle, her face beaming with a successful, joyful smile. The center of the frame bursts with golden light and confetti. The background features a yellow sun, the text \"Complete Success\", smiley faces, and sunflowers. The puzzle pieces converge from the four corners to the center to form a complete picture. Clear makeup, bright ring light, 85mm lens, f/1.8 aperture, four-panel composition with puzzle interaction, fashion magazine style.",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：4031",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "FBF78D9D-6502-515D-998D-2D7FF30AE1EE")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1767455034932_ivuvu0_G9V-MszakAEAIBw.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "4031"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "7A501DBD-B6F8-5104-A7B9-101DC12F0D3E")!,
            title: "Edo-period Ukiyo-e reinterpretation of a modern scene",
            prompt: "A Japanese Edo-period Ukiyo-e woodblock print. The overall feeling is a surreal collaboration between masters like Hokusai and Hiroshige, reimagining modern technology through an ancient lens.\n\n**The scene:** {argument name=\"modern scene\" default=\"a busy Shibuya scramble crossing\"}\n\n**Edo transformation logic:**\nCharacters wear Edo-era kimono but perform modern actions. All technology is transformed into surreal Edo equivalents:\n* Smartphones are glowing, illustrated paper scrolls being read intently.\n* Metro stations and trains are giant articulated wooden centipede carriages shuffling through crowds.\n* Skyscrapers are reimagined as endless, towering wooden pagodas reaching into dramatic clouds.\n* Robots and mecha appear as giant, armored woodblock golems.\n\nThe composition uses a flattened perspective with large, bold, hand-carved ink outlines. The background features heavily stylized Ukiyo-e wave patterns and dramatic, swirling clouds, with a distant Mt. Fuji visible on the horizon.\n\nThe image must look like a physical print, not a digital painting.\n* Texture: strong visible wood grain texture and rough paper fibers throughout the piece.\n* Printing imperfections: pigment bleeding is evident. Simulate hand-pressed plates with slight color misalignment for authenticity.\n* Color palette: strictly limited to traditional mineral pigments, with dominant use of Prussian blue, vermilion red, and muted yellow ochre.\n* Lighting: soft, flat, shadow-free lighting with no digital gradients.\n\nAspect ratio is 3:4 vertical poster. Include vertical Japanese calligraphy describing the scene and a traditional red artist seal stamp in a corner.",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：811",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "81E76045-264F-5040-B03E-DA80409248A5")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1764915832381_renotr_G7FuPlzbYAAsuo2.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "811"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "53690807-3F0C-5FD6-AEBB-B6AD33421E55")!,
            title: "Neo-Noir Typographic Avatar Poster",
            prompt: "Using the person in the attached reference photo as the exact facial and physical subject, create a cinematic portrait poster in the same bold, minimal, {argument name=\"style\" default=\"neo-noir style\"} as the reference: show the person from roughly the waist or chest up in a confident three-quarter pose, head slightly lowered or turned, wearing {argument name=\"clothing\" default=\"sleek modern black clothing such as a fitted jacket, premium dark T-shirt\"}, and subtle contemporary accessories, with realistic fabric and skin detail. Use a {argument name=\"background color\" default=\"vivid saturated red\"} background filled with soft smoky haze and atmospheric shadows, strong directional lighting, deep blacks, dramatic contrast, and a slightly mysterious editorial mood. Behind the person, place their {argument name=\"text\" default=\"Shushant\"} in enormous condensed uppercase black typography stretching across the frame, partially hidden by their body, with a distressed, weathered texture. Keep the composition clean, powerful, photorealistic, premium, and movie-poster-like, with no logos, watermarks, superhero costume elements, masks, or extra text.",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32415",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "E4977BBE-C6BD-5246-8383-43B86D937DBD")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552797427_lczxin_HQZf22ibcAA1YRN.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "0698B26E-18AC-598F-89C8-21E83A563B1A")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552795172_dxlucs_HQZf3NgbAAAYzq_.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "A67E7B29-75D1-5CB1-AF0C-11DFFF7E95D7")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552794987_4294q8_HQZf3lEaAAAOh4N.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "7EE25783-B906-5B92-A065-59E68CB465CD")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552796054_ktqab5_HQZf36LbMAAahp3.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32415"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "9D6B4AC1-3821-5490-9652-272FC9BF8CDB")!,
            title: "Professional Eid Greeting Poster",
            prompt: "Create a highly professional and elegant Eid Milad-un-Nabi ﷺ greeting wooden-style poster. Place a handsome man on the right side, wearing a clean {argument name=\"man's attire\" default=\"white shalwar kameez\"}, silver glasses, and a professionally wrapped {argument name=\"turban style\" default=\"black-and-white Qatari-style ghutra turban\"} with a subtle textured pattern. Preserve the man's original facial features, identity, hairstyle, and natural skin texture exactly as shown in the reference photo. On the left side of the background, beautifully showcase Masjid an-Nabawi ﷺ with the Green Dome in a peaceful and respectful atmosphere. Add elegant Islamic architecture, soft golden decorative hanging lights, glowing lanterns, subtle crescent-and-star elements, and beautiful Islamic geometric patterns. Use a premium wooden texture as the main poster background with warm golden lighting and sophisticated depth. Add elegant Arabic/Urdu calligraphy text: \"{argument name=\"poster text\" default=\"عید میلاد النبی ﷺ مبارک\"}\" and below it: \"اللهم صل وسلم وبارك على سيدنا محمد ﷺ\" Make the overall design luxurious, spiritual, peaceful, respectful, photorealistic, cinematic lighting, premium Islamic poster design, detailed wooden texture, soft golden glow, sharp focus, high-end professional graphic design, 8K ultra-realistic quality, 9:16 vertical poster composition.",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32320",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "8C730F83-4DB6-53EF-A1A0-27809EFCEE48")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787552781907_ioqdbz_HQXwyVJbgAA-pja.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32320"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "7491DB2A-ED47-593C-90A0-615CE64166C0")!,
            title: "Multi-Expression Sliced Fashion Poster",
            prompt: "Create a {argument name=\"style\" default=\"luxury fashion editorial poster\"} based on my reference image. Preserve the exact facial identity, hairstyle, facial structure, skin tone, and overall appearance of the reference person.\n\nThe portrait is divided into {argument name=\"layout\" default=\"five perfectly aligned vertical slices\"} separated by ultra-thin glowing white lines. The slices must align seamlessly to form one complete face.\n\nEach slice represents the exact same person photographed at a different moment with a completely different facial expression.\n\nSlice 1: serious, confident, intense eye contact.\n\nSlice 2: subtle genuine smile.\n\nSlice 3: joyful open-mouth laugh with expressive eyes.\n\nSlice 4: thoughtful expression, eyes looking slightly sideways.\n\nSlice 5: playful smirk with one eyebrow slightly raised.\n\nEvery expression must be dramatically different and instantly recognizable. The facial muscles, eyebrows, eyes, mouth shape, smile intensity, and emotional feeling must noticeably change in every slice. Avoid repetitive or identical expressions.\n\nEach slice has a unique cinematic color grade:\n\n• Slice 1 – Deep Royal Blue\n\n• Slice 2 – Emerald Green\n\n• Slice 3 – Golden Amber\n\n• Slice 4 – Crimson Red\n\n• Slice 5 – Purple & Magenta Neon\n\nThe lighting should also vary subtly between slices while maintaining a premium editorial appearance.\n\n{argument name=\"background\" default=\"Dark charcoal minimalist background\"} with no distractions.\n\nLuxury magazine cover aesthetic, Vogue fashion campaign, cinematic studio lighting, glossy skin texture, ultra-realistic eyes, razor-sharp focus, HDR, photorealistic, masterpiece, 8K, highly detailed, premium color grading, dramatic contrast, modern fashion photography.\n\nFive unique emotional portraits of the same person merged into one sliced composition, each slice appearing as if captured at a different moment during a professional fashion photoshoot.\n\nNegative Prompt:\n\nblack and white, monochrome, grayscale, identical expressions, duplicate face, copied slice, repeated smile, emotionless face, flat lighting, dull colors, low saturation, blurry, distorted face, extra eyes, extra mouth, misaligned slices, low quality, artifacts",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32001",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "1C98C43A-249C-5DFA-B128-AE867E3C8854")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787293549342_krdloa_HQJBFD2bYAAgr0I.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32001"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "3AD61F9D-44B4-5780-A817-6138410C15E5")!,
            title: "Dream Fisherman Surrealism",
            prompt: "{\n  \"title\": \"Dream Fisherman\",\n  \"prompt\": \"{argument name=\"subject\" default=\"A tiny wooden fishing boat peacefully sailing across the surface of the full moon\"} suspended in the night sky. The fisherman casts his fishing line into the {argument name=\"environment\" default=\"Milky Way\"} instead of the ocean. Below, a quiet city watches in amazement from rooftops. Countless stars illuminate the scene with magical realism. Ultra-photorealistic moon textures, cinematic composition, long exposure astrophotography combined with documentary realism, HDR, Sony A1, masterpiece.\",\n  \"negative_prompt\": \"cartoon, painting, anime, CGI, blurry, watermark, logo, low resolution\",\n  \"aspect_ratio\": \"4:5\",\n  \"stylize\": {argument name=\"stylize value\" default=\"280\"},\n  \"chaos\": 15,\n  \"quality\": 2,\n  \"version\": 7\n}",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31994",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "91AC88D6-C6D3-58ED-9E9D-0998CA2192F3")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787208874237_2kxqk9_HQGM1nRbQAERSz9.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31994"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "D996F88D-6D2D-5C2F-9D68-B3ACA0835CDE")!,
            title: "Pastel Arachnid Surreal Masterpiece",
            prompt: "{\n  \"vibe_title_en\": \"Pastel Arachnid Dream\",\n  \"master_prompt\": \"A cinematic, photorealistic surreal masterpiece. THROUGH THE ELEMENT FRAMING: Shot through an extreme, out-of-focus foreground of dew-covered pale pink tulips and tall morning grass, creating intense depth of field. MIDGROUND: The Protagonist, gender and age neutral, wearing a vintage oversized textured houndstooth blazer. ACCIDENTAL MUSE ENERGY: They are caught completely off-guard, laughing genuinely and looking surprised, with a slight motion blur on their hands as they try to keep their balance. SURREAL ELEMENT: They are sitting atop a massive, hyper-realistic, animatronic spider structure covered entirely in luxurious, heavy pink mohair and faux fur, designed to look like a high-budget practical effect. BACKGROUND: An endless field of pale pink tulips shrouded in dense morning mist. LIGHTING: Volumetric sunrise light piercing through the fog, soft golden hour rim light catching the stray strands of thick pink fur and the subject's hair. CAMERA SPECS: Shot on Hasselblad H6D-100c with an 80mm lens at f/2.8. FILM STOCK: Kodak Portra 400. Intricate micro-details: individual dewdrops on foreground petals, fine weave of the tweed, authentic skin pores and natural imperfections on the subject's laughing face, physical weight to the plush creature. Analog film grain, muted greens, pastel pink dominance. NO NEON.\",\n  \"meta\": {\n    \"intent\": \"Photographic Surrealism / Editorial Storytelling\",\n    \"priorities\": \"Tactile textures, depth of field through foreground elements, genuine mid-motion surprise, physical presence of surreal elements\",\n    \"device_profile\": \"Hasselblad H6D-100c, Kodak Portra 400\"\n  },\n  \"frame\": {\n    \"aspect\": \"4:5\",\n    \"composition\": \"Central subject framed by extreme, out-of-focus foreground floral elements to create a layered, voyeuristic depth\",\n    \"layout\": \"Multi-layered depth (Foreground blurred tulips -> Sharp Midground subject & plush prop -> Foggy background field)\",\n    \"camera_angle\": \"Eye-level, slightly obscured by foreground nature\",\n    \"tilt_roll_degrees\": \"0\"\n  },\n  \"subject\": {\n    \"gender\": \"Female\",\n    \"identity\": \"The Protagonist\",\n    \"demographics\": \"Ageless, universal template\",\n    \"face\": \"Caught in a moment of genuine, surprised laughter, natural skin texture, visible pores, unposed\",\n    \"hair\": \"Slightly windblown, catching the warm rim light of the morning sun\",\n    \"body\": \"Dynamic, off-balance, natural reaction to an unexpected shift in weight\",\n    \"expression\": \"Joyful, surprised, completely off-guard, breaking the fourth wall with an accidental glance\",\n    \"pose\": \"Sitting unsteadily on a massive, soft structure, mid-motion blur on the hands\"\n  },\n  \"wardrobe_accessories\": {\n    \"garments\": [\n      {\n        \"item\": \"Oversized blazer\",\n        \"material\": \"Textured houndstooth wool\",\n        \"color\": \"Muted beige and brown\",\n        \"fit\": \"Loose, vintage drape\"\n      },\n      {\n        \"item\": \"Flowing inner blouse\",\n        \"material\": \"Matte silk\",\n        \"color\": \"Ivory\",\n        \"fit\": \"Relaxed\"\n      }\n    ],\n    \"accessories\": [\n      {\n        \"item\": \"Delicate chain necklace\",\n        \"color\": \"Rose gold\",\n        \"material\": \"Metal\",\n        \"brand_style\": \"Minimalist vintage\"\n      }\n    ]\n  },\n  \"environment\": {\n    \"setting\": \"An overgrown botanical field of pale pink tulips at dawn\",\n    \"surfaces\": \"Dew-covered petals, wet morning grass, ultra-soft dense pink mohair of the giant prop\",\n    \"depth\": \"Extremely shallow, compressed background with prominent, obstructive foreground blur\",\n    \"atmosphere\": \"Humid, foggy, ethereal sunrise mist, peaceful yet surreal\",\n    \"lens_interaction\": \"Shooting directly through out-of-focus foreground tulip heads that wash the edges of the frame in soft pink\"\n  },\n  \"lighting\": {\n    \"key\": \"Soft, diffused morning sunlight cutting through the dense mist\",\n    \"fill\": \"Ambient bounced light from the surrounding pink flora and the massive pink plush structure\",\n    \"rim\": \"Golden hour rim light illuminating the edges of the pink faux fur and the subject's silhouette\",\n    \"shadows\": \"Soft, low-contrast, lifted shadows with a filmic roll-off\",\n    \"color_temperature\": \"Warm pastel (around 5200K), leaning heavily into peach and soft pink tones\",\n    \"sensor_flare\": \"Subtle organic halation from the sunrise cutting through the fog\"\n  },\n  \"camera\": {\n    \"lens_type\": \"Medium format prime\",\n    \"focal_length\": \"80mm\",\n    \"aperture\": \"f/2.8\",\n    \"focus\": \"Tack sharp on the subject's laughing eyes, allowing motion blur on extremities and deep blur on foreground/background\",\n    \"sensor_format\": \"Medium Format 100MP\",\n    \"perspective_distortion\": \"Natural compression, zero wide-angle distortion\"\n  },\n  \"post_processing\": {\n    \"color\": \"Pastel dominant, muted greens and vibrant, soft pinks inspired by classic analog film\",\n    \"tonality\": \"Low contrast, cinematic filmic roll-off in the highlights\",\n    \"texture\": \"Heavy analog grain characteristic of pushed Kodak Portra 400, intense micro-contrast on tactile surfaces like wool and fur\",\n    \"digital_sharpening\": \"None, relies entirely on the optical sharpness of medium format glass\",\n    \"chromatic_aberration\": \"Subtle, organic edge fringing on the extreme foreground out-of-focus elements\"\n  },\n  \"negative_specifications\": [\n    \"Neon lights\",\n    \"CGI look\",\n    \"plastic skin\",\n    \"stiff posing\",\n    \"flat lighting\",\n    \"urban elements\",\n    \"generic studio backdrop\",\n    \"digital illustration\",\n    \"fantasy art\",\n    \"over-sharpening\"\n  ]\n}",
            category: .scene,
            tags: ["开源风格", "MIT", "海报与传单"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/poster-flyer.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：31881",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "1CFB2B78-CAF1-5303-BB1F-E167EF825269")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787120735922_0thggg_HQAu2vRXcAAXq0F.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "98FB52FC-53F8-5FB9-961F-319A3C521B8B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787120736017_int9d8_HQAu2tOWgAAgL8J.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/poster-flyer.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "31881"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "2CB01726-AE3F-5DCF-87AB-27D8724D2D06")!,
            title: "Detailed mirror-selfie otaku room scene",
            prompt: "### Scene\nMirror selfie in an otaku-style computer corner, blue color tone.\n\n### Subject\n* Gender expression: female\n* Age: around 25\n* Ethnicity: East Asian\n* Body type: slim, with a defined waist; natural body proportions\n* Skin tone: light neutral tone\n* Hairstyle:\n    * Length: waist-length hair\n    * Style: straight with slightly curled ends\n    * Color: medium brown\n* Pose:\n    * Stance: standing in a slight contrapposto pose\n    * Right hand: holding a smartphone in front of her face (identity hidden)\n    * Left arm: naturally hanging down alongside the torso\n    * Torso: body leaning slightly back; waist and abdomen exposed\n* Clothing:\n    * Top: light blue cropped knit cardigan, top two buttons fastened; a blue French-style bra faintly visible\n    * Bottom: denim ultra-short shorts, with a blue satin ribbon bow on each side of the hips\n    * Socks: blue and white horizontal striped over-the-knee socks\n    * Accessory: a blue cute mascot phone case\n\n### Environment\n* Description: bedroom computer corner seen through a wall-mounted mirror\n* Furnishings:\n    * White desk\n    * Single monitor showing a soft blue wallpaper (no readable text)\n    * Mechanical keyboard with white keycaps on a blue desk mat\n    * Mouse on a small blue mouse pad\n    * PC tower on the right side with blue case lighting\n    * Three anime figures on or near the PC tower\n    * A poster of a pagoda on the wall\n    * Cat-shaped desk lamp with blue accents\n    * A transparent glass of water\n    * A tall green leafy plant by the window (on the left side of the frame)\n* Color replacement: replace all originally pink elements (clothes and room decor) with blue tones (baby blue to sky blue/periwinkle blue).\n\n### Lighting\n* Light source: daylight coming from a large window on the left side of the camera, through sheer curtains\n* Light quality: soft, diffused light\n* White balance (K): 5200\n\n### Camera\n* Mode: smartphone rear camera shooting via the mirror (no portrait/bokeh mode)\n* Equivalent focal length (mm): 26\n* Distances (m):\n    * Subject to mirror: 0.6\n    * Camera to mirror: 0.5\n* Exposure:\n    * Aperture (f): 1.8\n    * ISO: 100\n    * Shutter speed (s): 0.01\n    * Exposure compensation (EV): -0.3\n* Focus: focus on the torso and shorts in the mirror image\n* Depth of field: natural smartphone deep depth of field; background clearly visible with no artificial blur\n* Composition:\n    * Aspect ratio: 1:1\n    * Crop: from the top of the head to mid-thigh; include the desk, monitor, PC tower, and plant in the frame\n    * Angle: slightly high angle from the mirror’s point of view\n    * Composition note: keep the subject centered; to avoid wide-angle edge distortion, have her stand a bit further away and crop to a square later.\n\n### Negative prompts\n* Any appearance of pink/magenta anywhere\n* Beauty filters/over-smoothed skin; poreless skin look\n* Exaggerated or distorted anatomy\n* NSFW, see-through fabrics, wardrobe malfunctions\n* Logos, brand names, or readable user interface text\n* Fake portrait-mode blur, CGI/illustration feel",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：553",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "EE7FA47B-4BF2-5236-8E42-B6ADFAD79D0B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1763889946850_689z0h_G23i3sJW0AASGUw.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "553"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "76EC3695-20EA-5231-ADBF-6737CE61D3BD")!,
            title: "Atmospheric K-pop Fan Room Portrait",
            prompt: "A close-up portrait of a young {argument name=\"ethnicity\" default=\"East Asian\"} woman with fair, smooth skin and soft natural makeup, looking directly at the camera with a calm, slightly pouty neutral expression. She has dark brown/black hair styled in a messy half-up half-down look: the top section is loosely twisted into a high messy bun/updo with loose strands and face-framing tendrils falling around her forehead and cheeks. She wears stylish black-and-silver browline glasses (thick black upper frames, thin metallic lower rims). Soft pink lips, defined but natural eyebrows, and subtle eye makeup. She is wearing a {argument name=\"clothing\" default=\"black off-the-shoulder top\"} that exposes her collarbones and shoulders, paired with a delicate thin gold chain necklace featuring a small five-pointed star pendant resting at the center of her chest. The lighting is soft and atmospheric: strong cool purple/magenta ambient LED lighting washes over the right side of her face, neck, and shoulders, creating a gentle glow and subtle color cast on her skin, while a warm yellow lamp light from the left provides contrast. The background is a {argument name=\"room style\" default=\"cozy bedroom wall densely covered in a collage of small photos and posters\"} (including a prominent BTS group poster), with a glowing table lamp visible on the left, a soft stuffed animal, and part of a bed with gray bedding. Soft bokeh and dreamy atmosphere, photorealistic, high detail, sharp focus on the face, shallow depth of field, vertical portrait composition, aesthetic K-pop fan room vibe, cinematic purple lighting, 8k quality.",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32664",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "4F7AB362-553E-5798-9932-78EC51E5F425")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275452_qxzfka_HQeCMfWacAAsUK-.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "CD968DD3-0C50-562B-BD5E-26C412B90E4B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275628_agzj7o_HQeCMeobcAATUT8.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32664"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "EB17697A-BEFD-5FE0-9D29-046371F3941F")!,
            title: "Anime Character Humanization",
            prompt: "A real {argument name=\"ethnicity\" default=\"East Asian Korean\"} woman with a similar appearance to this anime character. {argument name=\"hair style\" default=\"long black hair\"}, wearing {argument name=\"outfit\" default=\"a black beret, a black lace top, and a black skirt\"}. Realistic photo style, live-action portrait, not anime, not 3D rendering, white background",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32676",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "F45A3530-B7D4-53EB-A2D6-90496FB36A55")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824284221_4mi4ga_HQpvjbDbQAA592-.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "D093C7A6-EE98-51BB-9014-48E9AC49FBC5")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824284231_bh70nm_HQpvlF0bkAAcy9p.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "E81516DB-4828-5AC6-B9C7-A8BED2D0F2A4")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824284217_wn405n_HQpvmv-bYAAvkU7.jpg",
                    sourceLabel: "上游完整样板 3"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32676"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "F240406D-24D9-54CD-A2DC-A27BD276A603")!,
            title: "Realistic Smartphone Cafe Portrait",
            prompt: "A completely natural, photorealistic smartphone photo of a young {argument name=\"ethnicity\" default=\"East Asian\"} woman sitting casually inside a cozy small café or restaurant, photographed spontaneously by a friend using a modern phone camera. She has very long, straight {argument name=\"hair color\" default=\"dark-brown\"} hair with soft wispy bangs, naturally smooth skin, subtle everyday makeup, glossy pink lips, and a relaxed slightly dreamy expression while looking off to the side instead of directly at the camera. She wears a {argument name=\"clothing\" default=\"fitted off-white graphic T-shirt with a blue vintage-style print\"}, loose light-wash baggy jeans, and colorful beaded bracelets on her wrist. She sits casually on a chair with her legs relaxed and her hands resting naturally near her knees, giving the photo an unposed everyday feeling. Behind her are warm wooden shelves filled with assorted bottles, jars, glasses, and small café items, creating a cozy lived-in restaurant atmosphere. Warm indoor ceiling and shelf lighting, realistic mixed exposure, natural shadows, slight smartphone HDR, mild wide-angle perspective, imperfect framing, subtle motion softness, authentic skin pores and fine hair strands, realistic fabric texture, ordinary background details, no studio setup, no cinematic lighting, no beauty filter, no excessive retouching, no artificial sharpness. The final image should look exactly like a real casual phone photograph someone took while sitting in the café, slightly imperfect but highly believable, vertical portrait composition, natural colors, realistic smartphone camera quality.",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32674",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "13033A7B-7D81-594F-A86B-1ED7E30F43A0")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824282105_6h1dj7_HQpqcCGakAA0dwE.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "6EDE2A6E-27E8-5CE0-90F1-9796B00E4627")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824282162_syoid3_HQpqfNYa8AAumB0.jpg",
                    sourceLabel: "上游完整样板 2"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32674"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "214DBB8D-75CC-59E0-8A97-0C7A83B3D517")!,
            title: "Muted Maroon Hijab Selfie",
            prompt: "ar 9:16 High A close-up selfie portrait of a young woman with fair skin, soft rounded facial features, large expressive green-hazel eyes with long dark lashes and subtle winged eyeliner, light natural makeup with a soft pink blush on the cheeks, and glossy pink lips slightly parted. She is wearing a smooth, solid dusty-rose / muted maroon hijab that fully covers her hair and frames her face, with the fabric neatly draped over her shoulders and chest. Her right hand is raised near the side of her head, gently holding and adjusting the edge of the hijab with relaxed fingers. She is dressed in a long-sleeved, ribbed, deep red / burgundy top that matches the warm tones of the hijab. Soft, flattering indoor lighting with a gentle glow, subtle pink LED fairy lights visible in the blurred background on the left, floral-patterned wallpaper or curtain behind her, and a beige drape on the right. Shallow depth of field, high detail on the face and fabric texture, natural skin texture, realistic photography style, intimate and calm expression looking directly at the camera. - Core subject: young woman, fair skin, large green-hazel eyes, long lashes, soft pink blush, glossy lips, dusty-rose/maroon hijab, deep red ribbed long-sleeve top, right hand adjusting hijab near temple. - Pose & expression: close-up selfie angle, direct eye contact, neutral-to-soft expression with slightly parted lips, one hand raised to the hijab. - Clothing & fabric: smooth matte hijab fabric with soft folds, ribbed knit texture on the sleeves and bodice, color harmony between hijab (muted rose-maroon) and top (deeper red). - Lighting & atmosphere: soft diffused indoor light + warm pink ambient glow from fairy lights, gentle catchlights in the eyes, realistic skin texture and fabric detail. - Background: slightly out-of-focus floral wallpaper/curtain and beige drape, cozy indoor setting. Intimate close-up portrait of a young woman in a muted maroon hijab and matching deep red knit top, large expressive green eyes looking into the camera, soft natural makeup, one hand delicately holding the edge of her hijab, warm pink ambient lighting and soft bokeh fairy lights, floral patterned background, ultra-realistic skin and fabric texture, shallow depth of field, high detail.",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32671",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "28F4A42F-2F34-5DB7-8293-0D5A8067A517")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824280165_1ba9ez_HQdT74pbkAAZgG1.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "E78A65E2-A38E-5ABA-BC17-5D8AD4C5E1F4")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824280153_xcbqtv_HQdT74qbUAAXSXo.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "D1BFD15A-740E-5F4A-AAD4-02A6E62011CB")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824280149_wv5fi9_HQdT747akAAhcLp.jpg",
                    sourceLabel: "上游完整样板 3"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "4354E820-4D4B-58A7-B66A-DB4CFC90D157")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824280946_vkoage_HQdT74vawAAWnpF.jpg",
                    sourceLabel: "上游完整样板 4"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32671"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "C4B3DFF6-7981-5202-B086-08089BE65B28")!,
            title: "Neon Winking Selfie Portrait",
            prompt: "A close-up portrait of a young {argument name=\"subject\" default=\"East/Southeast Asian woman\"} with fair skin, long dark brown-to-black hair that falls loosely around her shoulders and partially across her face in soft, slightly messy strands. She is winking with her left eye closed while looking at the camera with a soft, playful, slightly coquettish expression and a gentle closed-mouth smile. Her right hand is raised, fingers gently running through the hair on the top of her head.  \n\nShe wears a {argument name=\"outfit\" default=\"simple black spaghetti-strap camisole/top\"} that shows her collarbones and upper chest. A delicate thin silver chain necklace with a small clear teardrop or heart-shaped pendant rests at the base of her neck.  \n\nStrong cinematic {argument name=\"lighting\" default=\"purple and magenta neon lighting\"} bathes the scene, casting soft pink-purple highlights and rim light on her hair, face, and shoulders, creating a moody, intimate atmosphere. The background is a plain indoor wall with soft purple ambient glow, slightly out of focus.  \n\nShot from a slightly high angle in a selfie style, shallow depth of field, realistic skin texture, natural soft makeup with defined eyebrows, subtle eyeliner, and soft pink-coral lips. High detail, photorealistic, soft bokeh, atmospheric lighting.",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32668",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "C7F77E43-2AA0-5A61-9B53-47ED43316E69")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824278434_jjgpzu_HQdTaFKakAArnKG.jpg",
                    sourceLabel: "上游完整样板 1"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32668"
            )
        ),
        StylePromptCard(
            id: UUID(uuidString: "36E5DDE4-5AC8-5F2F-BE92-6DEE013CB590")!,
            title: "Dreamy Portrait of Woman Blowing Bubbles",
            prompt: "A photorealistic portrait of a beautiful young {argument name=\"ethnicity\" default=\"East Asian\"} woman with {argument name=\"hair style\" default=\"long, voluminous, wavy black hair\"} cascading over her shoulders and down her back, soft curtain bangs framing her face. She has fair porcelain skin, delicate features, large expressive brown eyes looking upward and slightly to the side with a soft, dreamy, serene expression, full lips gently pursed as she blows soap bubbles. She is wearing an {argument name=\"clothing\" default=\"elegant white lace blouse\"} with intricate floral lace detailing around the high neckline, cuffs, and front, soft and romantic in style. Her nails are painted a soft pastel blue. In her right hand she holds a white bubble wand close to her mouth, actively blowing a stream of iridescent soap bubbles; her left hand holds a small clear bottle of bubble solution with a gold-colored cap. Dozens of translucent, rainbow-iridescent soap bubbles of varying sizes float all around her — some sharp and close to the camera, others softly blurred in the background — catching the light with vibrant prismatic reflections. Setting: outdoor park on a bright sunny day, soft golden-hour-like natural light filtering through green trees, creating a dreamy bokeh background of lush foliage and circular light orbs. Warm sunlight highlights her hair and the bubbles, with gentle rim lighting. Shallow depth of field, cinematic composition, medium close-up portrait, high detail, soft ethereal atmosphere, whimsical and romantic mood. Style: ultra-realistic photography, sharp focus on the subject’s face and hands, creamy bokeh, natural skin texture, delicate lighting, aesthetic and feminine.",
            category: .character,
            tags: ["开源风格", "MIT", "人物头像"],
            notes: "来源：YouMind-OpenLab/ai-image-prompts-skill/references/profile-avatar.json；固定提交 7c065c2b429bc75334239965768849cb00c8987d；MIT License；原始 ID：32663",
            sampleMedia: [
                StyleSampleMedia(
                    id: UUID(uuidString: "242981B3-4E7E-5505-BA57-D09DE86F948F")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275384_ydwz3e_HQdTD8aaQAA6osZ.jpg",
                    sourceLabel: "上游完整样板 1"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "067DCD33-0635-591A-9D9D-E211ED1EDA6B")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275347_xlkvgx_HQdTD-RbAAAXEN_.jpg",
                    sourceLabel: "上游完整样板 2"
                ),
                StyleSampleMedia(
                    id: UUID(uuidString: "CF14582C-94D2-54EB-B712-2E84013CDA66")!,
                    remoteURLString: "https://cms-assets.youmind.com/media/1787824275282_fnxqoj_HQdTD8yb0AActev.jpg",
                    sourceLabel: "上游完整样板 3"
                )
            ],
            isPromptLocked: true,
            isBuiltIn: true,
            provenance: StylePromptProvenance(
                repository: "YouMind-OpenLab/ai-image-prompts-skill",
                path: "references/profile-avatar.json",
                revision: "7c065c2b429bc75334239965768849cb00c8987d",
                license: "MIT",
                originalID: "32663"
            )
        )
    ]
}
