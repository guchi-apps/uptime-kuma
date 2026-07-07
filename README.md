# uptime-kuma

[Uptime Kuma](https://github.com/louislam/uptime-kuma) を [render.com](https://render.com/) 上で動かすためのリポジトリ。`Dockerfile` は公式イメージ `louislam/uptime-kuma:1` をそのまま利用しており、本体の機能は公式版と同じ。

## デプロイ環境

- **ホスティング**: render.com（無料プラン）
- **公開URL**: https://uptime-kuma-jqud.onrender.com/
- **稼働バージョン**: v1.23.17（`louislam/uptime-kuma:1` タグが指す1.x系最終版。フロントエンドのバンドルファイルから確認）
- 無料プランは15分間アクセスがないとスリープするため、[UptimeRobot](https://uptimerobot.com/) で5分間隔の keep-alive 監視を設定済み
- 無料プランは永続ディスクが使えず、再起動・再デプロイでデータが消える可能性がある（未対応。[issue #1](https://github.com/m-guchi/uptime-kuma/issues/1) 参照）

## 使い方

### 監視対象(Monitor)の追加

1. ダッシュボード左上の **「+ Add New Monitor」**
2. **Monitor Type** を選択（代表例）
   - `HTTP(s)` — Webサイト・APIの死活監視
   - `TCP Port` — 特定ポートの疎通確認
   - `Ping` — ICMP ping
3. **Friendly Name**（表示名）と **URL / ホスト** を入力
4. **Heartbeat Interval**（監視間隔）、**Retries**（ダウン判定までの失敗回数）を設定
5. 必要なら下部の **Notifications** で通知先にチェックを入れる
6. 「Save」で保存すると即座に監視が始まる

### Webhook通知の設定

1. 右上のユーザーアイコン → **Settings** → **Notifications**
2. **「Setup Notification」**をクリック
3. **Notification Type**: `Webhook` を選択
4. 設定項目
   - **Post URL**: 通知を受け取るエンドポイントのURL
   - **Content Type**: `application/json`
   - 必要に応じて **Additional Headers**（認証トークンなど）
5. 「Test」ボタンでテスト送信し、受信側で確認する
6. 保存後、各Monitorの編集画面で「Notifications」にこのWebhookのチェックを入れる

送信されるJSONペイロードには `heartbeat`（up/downの状態）、`monitor`（監視対象の情報）、`msg`（メッセージ文）が含まれる。Slack/Discord等の専用フォーマットが必要な場合は、`Webhook` ではなくそれぞれ専用の通知タイプを選ぶ方が簡単。

#### Custom Body（送信内容のカスタマイズ）

Webhook通知の **Request Body** で `Custom Body` を選ぶと、[Liquid](https://liquidjs.com/) テンプレート構文でJSONペイロードを自由に組み立てられる。

**重要（v1.23.17固有の注意点）**: このバージョンではテンプレートに渡される変数は `msg` / `heartbeatJSON` / `monitorJSON` の3つのみ。後継バージョンで追加された `status` / `name` / `hostnameOrURL` といった簡易変数は**存在しない**。これらを直接 `| json` フィルタに渡すと、値が未定義のため出力が空になりJSONが壊れる（構文エラーになる）。値は必ず `monitorJSON['name']` のように直接取り出し、`{% capture %}` で一度文字列化してから `| json` に通すこと。

##### Signaly（自前の通知ハブ）向けテンプレート例

[Signaly](https://github.com/m-guchi/signaly) はDiscord Execute Webhookと同じJSON形式（`embeds`）を受け付ける。以下のテンプレートは `msg` / `heartbeatJSON` / `monitorJSON` のみを使い、Test送信・実際のUP/DOWNイベントいずれでも正しいJSONを生成することを確認済み。

```liquid
{%- assign hbStatus = heartbeatJSON['status'] -%}
{%- if hbStatus == 1 -%}
  {%- assign statusText = "✅ Up" -%}
  {%- assign colorCode = 5763719 -%}
{%- elsif hbStatus == 0 -%}
  {%- assign statusText = "🔴 Down" -%}
  {%- assign colorCode = 15548997 -%}
{%- else -%}
  {%- assign statusText = "⚠️ Test" -%}
  {%- assign colorCode = 16512804 -%}
{%- endif -%}
{%- capture monitorName -%}{% if monitorJSON %}{{ monitorJSON['name'] }}{% endif %}{%- endcapture -%}
{%- capture hostText -%}{% if monitorJSON %}{{ monitorJSON['url'] | default: monitorJSON['hostname'] }}{% endif %}{%- endcapture -%}
{%- capture pingText -%}{% if heartbeatJSON and heartbeatJSON['ping'] %}{{ heartbeatJSON['ping'] }} ms{% endif %}{%- endcapture -%}
{%- capture dateText -%}{% if heartbeatJSON %}{{ heartbeatJSON['localDateTime'] | default: heartbeatJSON['time'] }}{% endif %}{%- endcapture -%}
{%- capture title -%}{{ statusText }} {{ monitorName }}{%- endcapture -%}
{
  "embeds": [
    {
      "title": {{ title | json }},
      "description": {{ msg | json }},
      "color": {{ colorCode }},
      "fields": [
        { "name": "監視対象", "value": {{ hostText | json }}, "inline": true },
        { "name": "応答時間", "value": {{ pingText | json }}, "inline": true },
        { "name": "日時", "value": {{ dateText | json }}, "inline": false }
      ]
    }
  ]
}
```

Post URLはSignalyの「Webhook URL」画面に表示される `https://<signalyのホスト>/webhook/<channel_id>` を指定する。

### 外部サイトへのステータス表示（Status Page）

1. 左サイドバーの **「Status Pages」** → **「+ New Status Page」**
2. スラッグ（URLの一部）とタイトルを設定
3. 表示したい Monitor をグループにドラッグ＆ドロップで追加
4. 保存すると公開URLが発行される（例: `https://uptime-kuma-jqud.onrender.com/status/<スラッグ>`）
5. このURLをそのまま外部に共有するか、他サイトに **iframe埋め込み** も可能
6. 個別の稼働率バッジ（SVG画像）は `/api/badge/<monitorID>/status` のようなURLで取得できる（Status Page編集画面の各Monitor横に埋め込みコードあり）
