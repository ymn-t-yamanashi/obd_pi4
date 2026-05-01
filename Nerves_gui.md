# Nerves GUI化メモ（RPI4 / HDMI0固定）

## 目的
NervesでGUIアニメーションするサンプルを作る。
対象はRPI4。表示はHDMI0のみを使う。

## 前提条件
- 実績がある構成を優先する（RC版は使わない）
- SSHコンソール前提ではなく、RPI4直結ディスプレイで動作させる
- Nerves起動時に自動実行する

## 調査結果（2026-04-30）

### 実現可否
実現可能。

根拠:
- 既存 `pi_cui_anim` が Nerves + RPI4 で構築・反映実績あり
- ローカル開発環境が `Elixir 1.19.3 / Erlang OTP 28`
- Scenic v0.11系で Nerves向けローカル描画ドライバは `scenic_driver_local` が現行推奨

### 採用バージョン（実績優先）
- `{:nerves, "~> 1.14"}`（既存実績: 1.14.1）
- `{:nerves_system_rpi4, "~> 2.0", runtime: false, targets: :rpi4}`（既存実績: 2.0.2）
- `{:scenic, "~> 0.11.2"}`（stable）
- `{:scenic_driver_local, "~> 0.11.0"}`（stable）

### 不採用
- `scenic 0.12.0-rc.0`
- `scenic_driver_local 0.12.0-rc.0`
理由: RC版のため、今回の「実績優先」方針に合わない。

### 注意点
`scenic_driver_local` の公式記載として、`rpi4` は描画が遅くなるケースがある。
初期実装は以下で始める:
- 描画要素を少数にする
- 更新レートは 15〜20fps 程度
- まず安定動作を優先

## 仕様（初期版）
1. 使用言語: Elixir
2. 描画方式: Scenic Scene（GUIベクター描画）
3. 表示内容: 文字を「線分の組み合わせ」で描画する
4. アニメーション: 線で構成した文字全体を左右移動
5. 起動方式: Nerves起動時に自動開始
6. 表示先: HDMI0のみ

## ASCIIアートからの置き換え
- 置き換え前: ターミナル文字列としてASCIIアートを出力
- 置き換え後: Scenicの `line` / `path` でストローク描画

実装イメージ:
- 文字ごとに線分定義を持つ（例: `A = [{x1,y1,x2,y2}, ...]`）
- `Graph` に線分を追加して1文字を描画
- 複数文字はオフセットをずらして連結
- SceneのtickでX座標を更新して移動

## 実装ステップ
1. `pi_gui_anim` 作成（`mix nerves.new pi_gui_anim --target rpi4`）
2. 依存追加（`scenic`, `scenic_driver_local`）
3. `Scenic.ViewPort` を `Application` で起動
4. `PiGuiAnim.Scene.Marquee` を作成
5. `PiGuiAnim.VectorFont` を作成（線分フォント定義）
6. `Process.send_after/3` で座標更新
7. `-noshell` 構成でIExプロンプトを出さない
8. `mix firmware` -> `mix upload <IP>` で反映

## 検証項目
- HDMI0に表示される
- 起動後に線分文字が自動で左右移動する
- 30分連続動作でクラッシュしない
- 解像度差異で文字が消えっぱなしにならない

## 参考
- Scenic Driver Local: https://hexdocs.pm/scenic_driver_local/overview.html
- Scenic Driver Overview: https://hexdocs.pm/scenic/overview_driver.html
- Elixir/OTP互換: https://hexdocs.pm/elixir/compatibility-and-deprecations.html

## ドライバ周りの調査（2026-04-30）

### 結論
- 採用ドライバは `Scenic.Driver.Local` 一択（Scenic v0.11系の現行推奨）。
- 旧 `scenic_driver_nerves_rpi` はRPI3中心の記述で、現行方針では優先しない。

### 根拠
- Scenic公式: v0.11ではローカル描画ドライバが `scenic_driver_local` に統合。
- `scenic_driver_local` 公式: Nerves + rpi4 では下位層に `drm` を使用。
- 公式記載に「rpi4で描画はするが遅いケースあり」と明記。

### HDMI0運用への示唆
- RPI4システム自体は HDMI 表示を標準サポート（nerves_system_rpi4 docs）。
- Scenic側のドライバは「利用可能な表示へ描画する」設計で、
  HDMI0固定の最終担保はブート時の表示系設定（EDID/解像度/接続先）も含めて確認が必要。

### 初期設定の推奨
- まずは追加設定を最小化して `Scenic.Driver.Local` のデフォルトで起動。
- 遅延が気になる場合に段階的に調整:
  - `limit_ms` を調整（描画更新間隔の上限制御）
  - `antialias: false` を検証
  - 描画オブジェクト数を削減（線分数、同時文字数）

### ViewPortドライバ設定の叩き台
```elixir
# config/target.exs 例（概念）
config :pi_gui_anim, :viewport, %{
  size: {1280, 720},
  default_scene: {PiGuiAnim.Scene.Marquee, nil},
  drivers: [
    [
      module: Scenic.Driver.Local,
      limit_ms: 33,
      cursor: false,
      antialias: false,
      position: [scaled: true, centered: true, orientation: :normal]
    ]
  ]
}
```

### 検証手順（ドライバ観点）
1. HDMI0のみ接続して起動し、表示が出ることを確認
2. HDMI1接続時の挙動差（誤表示先）を確認
3. `limit_ms` を `16 / 33 / 50` で比較して負荷と滑らかさを確認
4. `antialias true/false` のCPU使用率差を比較

### ドライバ選定の最終判断
- 今回の要件（実績優先、RPI4、シンプルGUI）では `scenic_driver_local` を採用。
- 速度課題が大きい場合は、
  - 表示内容の簡略化
  - フレーム更新頻度の低減
から先に対処する。

## GUIが映らない根本原因（詳細）

### 結論
- 根本原因は、`pi_gui_anim` と `hello_scenic` で **Scenicドライバ依存が一致していなかったこと**。
- 具体的には `scenic_driver_local` の実装差分により、RPI4でDRM初期化が失敗していた。

### 事象
- `pi_gui_anim` 起動時に以下が発生:
  - `drmModeGetResources failed: Operation not supported`
  - `failed to initialize DRM`
- 結果としてGUIは表示されず、再起動ループやエラースクロールが発生。

### 切り分け結果
- 同一RPI4・同一SD・同一接続条件で `hello_scenic` は表示可能だった。
- よってハード故障や配線不良ではなく、**アプリ依存（ドライバ実装）差分**が主因と判断。

### 差分の中身
- `hello_scenic`: `scenic_driver_local` を GitHub固定コミットで利用
  - `26cd49dee26bb5951e63e39b16840087c9b7d96f`
- `pi_gui_anim`: `scenic_driver_local` Hex版 `0.11.0` を利用

### 解決策
- `pi_gui_anim` の `scenic_driver_local` を `hello_scenic` と同じGitHub固定refに統一。
- その後、GUI表示は回復し再現性を確認。

### 注意（別問題）
- 電源再投入で戻る現象は `Nerves.Runtime.validate_firmware/0` 未実行によるロールバック要因であり、
  「GUIが映らない根本原因」とは別問題。
