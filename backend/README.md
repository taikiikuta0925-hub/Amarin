# あまりん AI API

FlutterアプリにAPIキーを含めず、Cloudflare Worker経由でGeminiを利用します。

- `POST /analyze-expiry`: 写真から商品名・賞味期限・カテゴリーを抽出
- `POST /identify-product`: 会話しながら商品と期限を特定
- `POST /suggest-recipes`: 登録済みの食材・調味料からレシピを3件生成
- `POST /recipe-chat`: 登録済み食品を踏まえてAIシェフが料理相談へ回答
- `POST /daily-quote`: 日付と利用状況から、ホーム用の毎日のひとことを生成

既定モデルは`gemini-3.8-flash`です。混雑による一時エラー時は`gemini-3.5-flash`、`gemini-3.5-flash-lite`の順に自動で切り替えます。`GEMINI_MODEL`と`GEMINI_FALLBACK_MODELS`で変更できます。thinkingトークンも出力料金の対象になるため、公開前に[Gemini APIの料金](https://ai.google.dev/gemini-api/docs/pricing)を確認してください。

## セットアップ

1. [Google AI Studio](https://aistudio.google.com/app/apikey) でGemini APIキーを作成します。
2. 初回だけ設定ファイルを作成します。

   ```powershell
   Copy-Item backend\wrangler.toml.example backend\wrangler.toml
   ```

3. WorkerへAPIキーをSecretとして登録します。

   ```powershell
   Set-Location backend
   npx wrangler secret put GEMINI_API_KEY
   ```

4. デプロイします。

   ```powershell
   npx wrangler deploy
   ```

5. Worker URLを指定してFlutterアプリを起動します。

   ```powershell
   Set-Location ..
   flutter run --dart-define=AI_API_BASE_URL=https://YOUR-WORKER.workers.dev
   ```

APIキーはFlutterアプリや`wrangler.toml`へ記載しないでください。このリポジトリのアプリは公開済みあまりん Workerを既定値として使い、`AI_API_BASE_URL`で接続先を上書きできます。

## API形式

画像解析リクエスト:

```json
{
  "imageBase64": "...",
  "mimeType": "image/jpeg",
  "today": "2026-09-04",
  "locale": "ja-JP"
}
```

会話リクエスト:

```json
{
  "messages": [
    {"role": "user", "text": "冷蔵庫にある青いパックの牛乳です"},
    {"role": "assistant", "text": "印字された期限はいつですか？"},
    {"role": "user", "text": "2026年9月10日です"}
  ],
  "today": "2026-09-04",
  "locale": "ja-JP"
}
```

商品が特定できた場合のレスポンス:

```json
{
  "reply": "牛乳、賞味期限2026年9月10日として登録できます。",
  "ready": true,
  "name": "牛乳",
  "expiryDate": "2026-09-10",
  "category": "飲み物",
  "confidence": 0.96
}
```

レシピ生成リクエスト:

```json
{
  "items": [
    {"name": "絹ごし豆腐", "category": "冷蔵品", "expiryDate": "2026-09-18", "daysRemaining": 1},
    {"name": "みそ", "category": "調味料", "expiryDate": "2027-01-10", "daysRemaining": 115}
  ],
  "preference": "15分以内で辛くないもの",
  "today": "2026-09-17",
  "locale": "ja-JP"
}
```

料理チャットは同じ`items`と、`identify-product`と同形式の`messages`を`POST /recipe-chat`へ送ります。期限切れ（`daysRemaining`が負）の食品は、Worker側でもレシピ候補から除外します。

本番公開時は、利用回数制限・アプリ認証・監視をWorkerへ追加してください。
