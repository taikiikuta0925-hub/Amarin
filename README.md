# DueBite

賞味期限のアプリです（デモ版）

## 実装済み

- カメラ撮影／アルバム選択
- AI画像解析による商品名・賞味期限・カテゴリーの入力補助
- AIとの会話による商品・賞味期限の特定と登録
- 登録済み食材・調味料から期限の近い食品を優先するAIレシピ生成
- 登録内容を踏まえたAIシェフとの料理・代用品チャット
- 手入力とカレンダー入力
- 期限順の一覧、緊急度表示、食べきり済み管理
- 期限内の食べきりで10〜20ポイント付与
- 0ポイント開始、ポイント履歴、5段階のレベル表示
- ポイント達成でアンロックされるデモ報酬（実交換は準備中）
- iOS・Androidの期限通知（3日前と当日、通知時刻を選択可能）
- SharedPreferencesによる端末内保存
- Android、iOS、Web対応のレスポンシブUIと端末追従ダークモード

iOS・Androidの期限通知は、端末に設定されている現地時刻を使います。Androidでは、端末を再起動した後も通知予約を復元します。

## 起動

通常の起動では、公開済みのDueBite AI Workerを通してGeminiへ接続します。

```powershell
flutter pub get
flutter run
```

別のWorkerへ接続する場合は、そのURLをビルド時に指定できます。

```powershell
flutter run --dart-define=AI_API_BASE_URL=https://YOUR-WORKER.workers.dev
```

APIキーはFlutterアプリへ記載しないでください。WorkerのSecretとして保持します。

## テスト

```powershell
flutter analyze
flutter test
```
