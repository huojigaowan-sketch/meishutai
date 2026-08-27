#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATION_DIR="$ROOT_DIR/build/validation"
EXECUTABLE="$VALIDATION_DIR/validate"

mkdir -p "$VALIDATION_DIR"

xcrun swiftc \
  "$ROOT_DIR/美术台/Models/LLMConfiguration.swift" \
  "$ROOT_DIR/美术台/Models/AssetModels.swift" \
  "$ROOT_DIR/美术台/Models/DesignProfiles.swift" \
  "$ROOT_DIR/美术台/Models/CharacterDesignOptions.swift" \
  "$ROOT_DIR/美术台/Models/CulturalContextOptions.swift" \
  "$ROOT_DIR/美术台/Models/PromptParameters.swift" \
  "$ROOT_DIR/美术台/Models/PromptPhotoRecipe.swift" \
  "$ROOT_DIR/美术台/Services/AssetSummaryConsolidator.swift" \
  "$ROOT_DIR/美术台/Services/PromptCompiler.swift" \
  "$ROOT_DIR/Tests/ValidationMain.swift" \
  -o "$EXECUTABLE"

"$EXECUTABLE" "$ROOT_DIR/美术台/Assets.xcassets"

xcodebuild test \
  -project "$ROOT_DIR/美术台.xcodeproj" \
  -scheme "美术台" \
  -destination "platform=macOS" \
  -derivedDataPath "$ROOT_DIR/build/DerivedData-validation" \
  CODE_SIGNING_ALLOWED=NO
