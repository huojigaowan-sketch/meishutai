from pathlib import Path

ui = Path('美术台/Views/ArtDepartmentV2Views.swift')
text = ui.read_text()
text = text.replace('List(selection: $store.selectedSection) {', 'List {', 1)
text = text.replace(
    '''Label(section.rawValue, systemImage: section.systemImage)
                            .tag(section)''',
    '''Button {
                            store.selectedSection = section
                        } label: {
                            Label(section.rawValue, systemImage: section.systemImage)
                                .foregroundStyle(store.selectedSection == section ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)''',
    1,
)
ui.write_text(text)

client = Path('美术台/Services/ArtDepartmentV2Clients.swift')
text = client.read_text()
text = text.replace(
    '''        var body: [String: Any] = [
            "model": recipe.model.isEmpty ? configuration.model : recipe.model,
            "prompt": prompt,
            "size": recipe.size,
            "response_format": "b64_json",
            "watermark": recipe.watermark,
        ]
        if !negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            body["negative_prompt"] = negativePrompt
        }''',
    '''        let cleanNegative = negativePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedPrompt = cleanNegative.isEmpty
            ? prompt
            : prompt + "\\n\\n必须避免：" + cleanNegative
        var body: [String: Any] = [
            "model": recipe.model.isEmpty ? configuration.model : recipe.model,
            "prompt": resolvedPrompt,
            "size": recipe.size,
            "response_format": "b64_json",
            "watermark": recipe.watermark,
        ]''',
    1,
)
client.write_text(text)

store = Path('美术台/Stores/ArtDepartmentV2Store.swift')
text = store.read_text()
text = text.replace(
    '''    var selectedAsset: ProductionAsset? {
        guard let selectedAssetID else { return filteredAssets.first }
        return currentProject?.assets.first { $0.id == selectedAssetID }
    }''',
    '''    var selectedAsset: ProductionAsset? {
        guard let selectedAssetID,
              let selected = currentProject?.assets.first(where: {
                  $0.id == selectedAssetID
                    && $0.kind == selectedAssetKind
                    && $0.reviewDecision != .rejected
              }) else {
            return filteredAssets.first
        }
        return selected
    }''',
    1,
)
store.write_text(text)

persistence = Path('美术台/Services/ArtDepartmentV2Persistence.swift')
text = persistence.read_text()
if 'import FoundationXML' not in text:
    text = text.replace('import Foundation\n', 'import Foundation\nimport FoundationXML\n', 1)
persistence.write_text(text)
