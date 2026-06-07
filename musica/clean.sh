#!/bin/bash
# =====================================================================
# musica 安全クリーンスクリプト
# CocoaPods + SPM 環境で "Clean Build Folder" の代わりに使用してください。
#
# 使い方:
#   chmod +x clean.sh  # 初回のみ
#   ./clean.sh
#
# クリーン後の注意:
#   Xcodeでビルドすると1回目は失敗することがあります（正常）。
#   Schemeのpre-actionが自動でnull-hash PIFを削除するので、
#   2回目のビルドは必ず通ります。
# =====================================================================

set -e

DERIVED_DATA_PATTERN="$HOME/Library/Developer/Xcode/DerivedData/musica-*"

echo "=== musica Clean ==="

# 1. Build フォルダを削除 (Clean Build Folder 相当)
echo "→ Build フォルダを削除中..."
for dir in $DERIVED_DATA_PATTERN; do
  if [ -d "$dir/Build" ]; then
    rm -rf "$dir/Build"
    echo "  削除: $dir/Build"
  fi
done

# 2. workspace-state.json を削除 (SPM再解決を強制)
echo "→ workspace-state.json を削除中..."
for dir in $DERIVED_DATA_PATTERN; do
  if [ -f "$dir/SourcePackages/workspace-state.json" ]; then
    rm -f "$dir/SourcePackages/workspace-state.json"
    echo "  削除: $dir/SourcePackages/workspace-state.json"
  fi
done

echo ""
echo "✓ クリーン完了"
echo ""
echo "【次のステップ】"
echo "  1. musica.xcworkspace を Xcode で開く"
echo "  2. ビルド → 1回目はGUID衝突エラーが出ることがある（正常）"
echo "  3. そのまま再度ビルド → Schemeのpre-actionが自動修正 → 成功"
echo ""
echo "  ※ musica.xcodeproj は直接開かないでください"
