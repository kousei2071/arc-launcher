# Cyber Launcher

macOS 向けの円形デスクトップランチャー。カーソル位置に Liquid Glass / ビブランシー UI のラジアルメニューを表示し、よく使うアプリを素早く起動できます。

## 特徴

- **円形ラジアルメニュー** — カーソル周辺に 8 スロットのアプリを配置
- **macOS ネイティブガラス** — `NSVisualEffectView` / `NSGlassEffectView`（macOS 26+）による壁紙ぼかし
- **グローバルショートカット** — デフォルト `⌘ + Shift + L` で表示 / 非表示
- **メニューバー常駐** — トレイアイコンからも操作可能
- **ログイン時自動起動** — LaunchAgent 対応

## 必要条件

- macOS（主要ターゲット）
- Xcode / Command Line Tools（SwiftPM）

## セットアップ

```bash
git clone <repository-url>
cd arc-launcher

swift build
```

## 起動

```bash
./start.sh
```

または:

```bash
swift run CyberLauncher
```

## 操作

| 操作 | 説明 |
|------|------|
| `⌘ + Shift + L` | ランチャーの表示 / 非表示 |
| マウス移動 + クリック | ホバーしたアプリを起動 |
| `Esc` | 非表示 |
| メニューバーアイコン | クリックで表示 / 非表示 |
| `Ctrl + C`（ターミナル） | 終了 |

## ショートカットの設定

`⌘ + Shift + L` が効かない場合、macOS の「サービス」経由でトグルできます（アクセシビリティ権限不要）。

```bash
./scripts/install-macos-shortcut.sh
```

その後:

1. **システム設定 → キーボード → キーボードショートカット → サービス**
2. **Toggle Cyber Launcher** にチェック
3. `⌘ + Shift + L` を割り当て

HTTP やファイル経由でもトグルできます:

```bash
curl http://127.0.0.1:39281/toggle
# または
touch ~/Library/Application\ Support/CyberLauncher/toggle
```

## ログイン時に自動起動

```bash
./scripts/install-launch-agent.sh
```

解除:

```bash
./scripts/uninstall-launch-agent.sh
```

LaunchAgent インストール時に release ビルドを作成し、その実行ファイルをログイン時に起動します。

## 環境変数

| 変数 | デフォルト | 説明 |
|------|-----------|------|
| `CYBER_LAUNCHER_START_VISIBLE` | `1` | 起動時にランチャーを表示する |
| `CYBER_LAUNCHER_NATIVE_GLASS` | `1` | macOS ネイティブガラス（`NSVisualEffectView`）を使う |
| `CYBER_LAUNCHER_LIQUID` | `0` | macOS 26+ で Liquid Glass 表示を優先 |

例:

```bash
CYBER_LAUNCHER_START_VISIBLE=0 CYBER_LAUNCHER_LIQUID=1 ./start.sh
```

## アプリのカスタマイズ

デフォルトのアプリ一覧は `Sources/CyberLauncher/LauncherItem.swift` の `defaultItems()` で定義されています。配列を編集すると、ラジアルメニューに表示するアプリを変更できます。

```swift
[
    "Finder",
    "Dia",
    "Terminal",
    // ...
]
```

名前は macOS のアプリケーション名（`/Applications` 内の `.app` 名）と一致させてください。

## プロジェクト構成

```
Package.swift                      SwiftPM パッケージ定義
Sources/CyberLauncher/main.swift   エントリポイント
Sources/CyberLauncher/             AppKit ラジアル UI・ホットキー・トグル実装
Tests/CyberLauncherTests/          ラジアル選択ロジックのテスト
start.sh             起動スクリプト
scripts/             LaunchAgent・ショートカット登録用
```

## トラブルシューティング

**ショートカットが反応しない**

- 他アプリやシステムショートカットとの競合を確認
- `./scripts/install-macos-shortcut.sh` でサービス経由のトグルを設定

**ガラス効果が表示されない**

- `CYBER_LAUNCHER_NATIVE_GLASS=1` を設定
- Liquid Glass は macOS 26+ かつ `CYBER_LAUNCHER_LIQUID=1` が必要

**LaunchAgent のログ**

```bash
tail -f /tmp/cyber-launcher.log
tail -f /tmp/cyber-launcher.err
```

## ライセンス

リポジトリに LICENSE がない場合は、利用・再配布前に所有者に確認してください。
