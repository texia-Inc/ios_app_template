Claude Code 指示書 – iOSアプリ量産テンプレート

この指示書は、生成AI（例：Claude Code）に対してゼロベースでiOS/Flutterアプリ量産テンプレートを構築させるための詳細な手順書です。以下の手順に従って、モノレポ構成を作成し、コードやスクリプトを配置して、タグ付けだけでTestFlight配布やストア提出が可能な開発基盤を整えます。必ず順番通りに実行してください。

1. ディレクトリ構成の初期化

作業用ルートディレクトリ app-template/ を作成します。以下のサブディレクトリを用意してください：

apps/ – 実際のアプリが入る場所。

packages/ – 共通ライブラリ用。

tools/ – スクリプト類を置く場所。

fastlane/ – Fastlane関連の設定を置く場所。

ios_common/ – iOS固有の共通ファイルを置く場所。

.github/workflows/ – GitHub Actions 用設定ファイル。

melos.yaml – Monorepo管理用設定ファイル（後述）。

README.md を作成し、このテンプレートの概要と利用方法を簡潔に記載します。

2. sample_app の作成

apps/sample_app/ ディレクトリを作成し、Flutter CLI で仮アプリの雛形を生成します：

flutter create sample_app


生成された sample_app をモノレポで管理できるように、必要最小限の修正を行います。例えば、pubspec.yaml の name を sample_app に変更し、description を短文にします。

このアプリはテンプレートの動作確認用です。後で app.yaml から生成されるアプリへ差し替わる前提で進めます。

3. 共通パッケージの作成

packages/ ディレクトリ配下に、以下の2つのパッケージを用意します。Flutterのモノレポ管理ツールとして melos を使用すると便利ですが、この指示書では細かなセットアップには立ち入りません。

app_kit – 課金、広告、解析、レビュー誘導、Remote Config などの共通ロジックを集約するパッケージ。構造例：

packages/app_kit/lib/

app_review.dart – In-App Review API のラッパー。

app_purchases.dart – in_app_purchase パッケージを使った課金処理。

ads.dart – 広告（AdMob）ラッパー。後述の通り ATT/UMP を実装します。

analytics.dart – FirebaseやAmplitude等のラッパー。

remote_config.dart – サーバー上のJSONファイルから設定を取得する薄いラッパー。

pubspec.yaml – 依存には google_mobile_ads など必要なパッケージを追加します。

ui_kit – ボタン、ダイアログ、共通配色などのUIコンポーネントを提供します。ここでは最小限の共通ウィジェットを定義するだけで構いません。アプリ側の画面自体は各アプリに含めます。

共通ロジックはこの2パッケージに閉じ込め、各アプリでは公開されたAPIのみを呼び出すようにします。将来のSDK追加や差し替えが容易になります。

4. iOS 共通ファイルの用意

ios_common/ ディレクトリには、iOS固有の共通設定とファイルを置きます。

プライバシーマニフェスト – ios_common/PrivacyInfo.xcprivacy に以下の内容を記述します。

{
  "NSPrivacyTracking": false,
  "NSPrivacyTrackingDomains": [],
  "NSPrivacyCollectedDataTypes": [],
  "NSPrivacyAccessedAPITypes": []
}


Google AdMob などのSDKを追加する場合は、必要なデータタイプや目的をこのファイルに追記します。

UITest ランナー雛形 – ios_common/UITestRunner/ ディレクトリを作成し、最低限のUIテストファイルを置きます。例えば SnapshotTests.swift に以下のコードを用意しておきます：

import XCTest

class SnapshotTests: XCTestCase {
  let app = XCUIApplication()

  override func setUp() {
    continueAfterFailure = false
    setupSnapshot(app)
    app.launch()
  }

  func testShots() {
    snapshot("01-home")
    app.buttons["Play"].tap()
    snapshot("02-battle")
    app.buttons["Result"].tap()
    snapshot("03-result")
  }
}


UIテストはFastlane snapshot で自動スクリーンショットを撮るために使います。必要に応じて修正してください。

5. ツールスクリプトの用意

tools/ ディレクトリには、プロジェクトの自動生成や資産生成に関するスクリプトを置きます。

5.1 scaffold.sh

新規アプリを生成するためのスクリプトです。apps/sample_app/ をコピーし、指定したアプリ名・Bundle ID・テーマに置き換えます。以下のような内容にします：

#!/usr/bin/env bash
set -euo pipefail

APP_NAME="$1"
BUNDLE_ID="$2"
CFG="${3:-app.yaml}"

TARGET="apps/${APP_NAME}"
rsync -a apps/sample_app/ "${TARGET}/"

# 対象ファイルの名前とBundleIDを置換
find "${TARGET}" \( -name "*.dart" -o -name "Info.plist" -o -name "project.pbxproj" \) -print0 \
  | xargs -0 sed -i.bak -e "s/com.texia.sample/${BUNDLE_ID}/g" -e "s/Sample App/${APP_NAME}/g"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}" "${TARGET}/ios/Runner/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName ${APP_NAME}" "${TARGET}/ios/Runner/Info.plist"

# アイコン・スプラッシュ生成
if [ -f tools/gen_assets.dart ]; then
  dart run tools/gen_assets.dart "${CFG}" "${TARGET}"
fi

# メタデータ生成
if [ -f tools/gen_metadata.ts ]; then
  node tools/gen_metadata.ts "${CFG}" "fastlane/metadata"
fi

echo "Created ${TARGET}. Next:"
echo "  cd ${TARGET} && flutter pub get"


備考: sed -i.bak を用いて macOS と Linux の両方で動くようにしています。不要になった .bak ファイルは後で削除してください。

5.2 gen_assets.dart

アプリのアイコンやスプラッシュを自動生成する Dart スクリプトです。以下の内容に沿って実装します：

app.yaml を読み込み、アイコンの絵文字・背景色・テーマ色などを取得します。

これらの値をSVGテンプレートに差し込みます。

ImageMagick や Inkscape などの外部ツールを用いてPNGの各解像度を生成し、ios/Runner/Assets.xcassets/AppIcon.appiconset に配置します。

Contents.json を適切に生成し、iOS 用アイコンセットとして認識されるようにします。

このスクリプトの具体的な実装はプロジェクトに同梱してください。最初は絵文字1文字と背景色のシンプルなロゴで十分です。必要に応じて拡張できます。

5.3 gen_metadata.ts

ストア提出用メタデータを app.yaml から生成するNode.jsスクリプトです。実装の概要は以下の通りです：

app.yaml の store セクションを読み込みます。

fastlane/metadata/ja-JP/ や fastlane/metadata/en-US/ ディレクトリにある name.txt、subtitle.txt、keywords.txt、promotional_text.txt などのファイルを上書きします。

差し込み用テンプレートはシンプルに、例えば {{app_name}} や {{store.subtitle_ja}} といったプレースホルダーを、実際の値に置換します。

複数言語対応の場合はそれぞれのディレクトリを生成します。

Node.jsでファイル操作と文字列置換を行うだけなので、外部ライブラリは必要ありません。

6. Fastlane設定

fastlane/ ディレクトリには、TestFlight へのアップロードやApp Store Connectへの提出を自動化する設定を置きます。

Gemfile – Fastlane をインストールするためのファイルです。

source "https://rubygems.org"
gem "fastlane"


Fastfile – Fastlane のレーン定義を以下のように記述します：

default_platform(:ios)

platform :ios do
  desc "Bump build number"
  lane :bump do
    increment_build_number(xcodeproj: "ios/Runner.xcodeproj")
  end

  desc "Run UI tests & take screenshots"
  lane :screenshots do
    snapshot
  end

  desc "Upload to TestFlight"
  lane :beta do
    sh("flutter clean && flutter pub get && flutter build ipa --release")
    upload_to_testflight
  end

  desc "Submit to App Store (manual review)"
  lane :release do
    deliver(submit_for_review: false, force: true)
  end
end


Appfile – App Store Connect 用の設定を記述します。機密情報は環境変数から読み込むようにします。

app_identifier ENV["APP_BUNDLE_ID"]
apple_id ENV["APPLE_ID_EMAIL"]
itc_team_id ENV["ASC_TEAM_ID"]
team_id ENV["DEVPORTAL_TEAM_ID"]


metadata/ – 前述の gen_metadata.ts で更新されるストア文面を格納するディレクトリを用意します。言語ごとにフォルダを分け、各種 name.txt などを配置します。

Fastlane を実行する際には bundle exec fastlane ios beta を呼び出すだけで、TestFlight へのアップロードが完了するようになります。

7. GitHub Actions 設定

CI/CD を自動化するために、.github/workflows/ios.yml ファイルを作成します。内容は以下のようにします：

name: iOS CI
on:
  push:
    tags: ['v*']
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.22.0'
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
      - name: Bundler
        run: bundle install
      - name: Env
        run: |
          echo "APP_BUNDLE_ID=${{ vars.APP_BUNDLE_ID }}" >> $GITHUB_ENV
          echo "FL_OUTPUT_DIR=./build" >> $GITHUB_ENV
      - name: TestFlight
        run: bundle exec fastlane ios beta
        env:
          APPLE_ID_EMAIL: ${{ secrets.APPLE_ID_EMAIL }}
          ASC_TEAM_ID:    ${{ secrets.ASC_TEAM_ID }}
          DEVPORTAL_TEAM_ID: ${{ secrets.DEVPORTAL_TEAM_ID }}
          APP_BUNDLE_ID:  ${{ vars.APP_BUNDLE_ID }}
          APP_STORE_CONNECT_API_KEY_JSON_BASE64: ${{ secrets.ASC_API_KEY_B64 }}


このWorkflowは、Git タグ（例：v1.0.0）がプッシュされた際に起動し、FlutterビルドとTestFlightへのアップロードを自動で行います。必要な秘密情報（Apple ID や API Keyなど）は GitHub Secrets に登録しておきます。

8. app.yaml の定義

各アプリ固有の設定を記述する app.yaml は以下のような構造を持ちます。新しいアプリを作る際はこのファイルをコピーして編集します。

app_name: "Coin Blaster"
bundle_id: "com.texia.coinblaster"
display_name: "Coin Blaster"
primary_color: "#2D7CF6"
theme: "dark"
icons:
  emoji: "🪙"
  bg: "#101318"
store:
  subtitle_ja: "角度とパワーでコインを宇宙へ"
  keywords_ja: ["コイン", "物理", "対戦", "webrtc"]
  promo_ja: "ドラッグして離すだけ。オンライン対戦で腕試し！"
  subtitle_en: "Blast the coin to space"
  keywords_en: ["coin", "physics", "pvp", "webrtc"]
monetization:
  ads: true
  iap:
    - id: "com.texia.coinblaster.pro"
      type: "non_consumable"
      localized_title_ja: "広告解除"
analytics:
  provider: "firebase"
remote_config:
  difficulty: "normal"
  ad_interval_sec: 45
  offer_banner: true
screenshots:
  flows: ["home", "battle", "result"]
admob:
  app_id_ios: "ca-app-pub-XXXXXXXXXXXXXXX~YYYYYYYYYY"
  banner_ios: "ca-app-pub-XXXXXXXXXXXXXXX/BBBBBBBBBB"
  interstitial_ios: "ca-app-pub-XXXXXXXXXXXXXXX/IIIIIIIIII"
  rewarded_ios: "ca-app-pub-XXXXXXXXXXXXXXX/RRRRRRRRRR"
  frequency:
    interstitial_every_sec: 45
    show_after_actions: 3


必要に応じてこの YAML を拡張し、他の設定（FirebaseのプロジェクトID など）を追加しても構いません。scaffold.sh と gen_metadata.ts はこのファイルを参照し、適切に置き換え処理を行います。

9. AdMob ラッパーの実装 (app_kit/lib/ads.dart)

AdMob を取り込んだ状態で ads.dart を実装します。以下は基本形の例です。実際にはエラーハンドリングやプラットフォーム条件分岐を含めてください。

import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:user_messaging_platform/user_messaging_platform.dart' as ump;

class AppAds {
  static bool _initialized = false;
  static InterstitialAd? _interstitial;
  static RewardedAd? _rewarded;

  static Future<void> init({
    required String appIdIOS,
    required String bannerIdIOS,
    required String interstitialIdIOS,
    required String rewardedIdIOS,
  }) async {
    if (_initialized) return;

    // UMP: 同意情報の更新とフォーム表示
    try {
      await ump.ConsentInformation.instance.requestConsentInfoUpdate();
      if (await ump.ConsentInformation.instance.isConsentFormAvailable()) {
        final form = await ump.ConsentForm.load();
        await form.show();
      }
    } catch (_) {}

    // ATT: iOSのトラッキング許可リクエスト
    if (Platform.isIOS) {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    }

    // Mobile Ads 初期化
    await MobileAds.instance.initialize();
    _initialized = true;

    // 広告の事前ロード
    _loadInterstitial(interstitialIdIOS);
    _loadRewarded(rewardedIdIOS);
  }

  static BannerAd createBanner(String unitId) {
    return BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: const BannerAdListener(),
    );
  }

  static Future<void> showInterstitial({required String unitId}) async {
    if (_interstitial == null) {
      await _loadInterstitial(unitId);
    }
    _interstitial?.show();
    _interstitial = null;
    _loadInterstitial(unitId);
  }

  static Future<void> showRewarded({
    required String unitId,
    required void Function(RewardItem reward) onReward,
  }) async {
    if (_rewarded == null) {
      await _loadRewarded(unitId);
    }
    _rewarded?.show(onUserEarnedReward: onReward);
    _rewarded = null;
    _loadRewarded(unitId);
  }

  static Future<void> _loadInterstitial(String unitId) async {
    await InterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (e) => _interstitial = null,
      ),
    );
  }

  static Future<void> _loadRewarded(String unitId) async {
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (e) => _rewarded = null,
      ),
    );
  }
}


アプリ側では次のように初期化し、必要なタイミングで広告を表示します。

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppAds.init(
    appIdIOS: "ca-app-pub-...~...",
    bannerIdIOS: "ca-app-pub-.../......",
    interstitialIdIOS: "ca-app-pub-.../......",
    rewardedIdIOS: "ca-app-pub-.../......",
  );
  runApp(const MyApp());
}

// バナー表示例
class BannerArea extends StatefulWidget {
  const BannerArea({super.key});
}
class _BannerAreaState extends State<BannerArea> {
  BannerAd? _ad;
  @override
  void initState() {
    super.initState();
    final ad = AppAds.createBanner("ca-app-pub-.../......");
    ad.load();
    _ad = ad;
  }
  @override
  Widget build(BuildContext context) {
    if (_ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }
}


app.yaml に AdMob の各ユニットIDを登録しておき、AppAds.init() に渡せるようにします。IDFA取得とUMPによるプライバシー同意に留意してください。

10. Remote Config の扱い

remote_config.dart では、アプリの挙動をリモートから変更できるようにします。サーバー上に remote_config.json を配置し、次のように取得します：

class RemoteConf {
  static Map<String, dynamic> _c = {};
  static Future<void> load(Uri url) async {
    final resp = await HttpClient().getUrl(url);
    final response = await resp.close();
    final body = await response.transform(utf8.decoder).join();
    _c = jsonDecode(body) as Map<String, dynamic>;
  }
  static T get<T>(String key, T fallback) {
    return (_c[key] as T?) ?? fallback;
  }
}


アプリ起動時に RemoteConf.load(Uri.parse("https://your.domain/remote_config.json")) を呼び出し、設定に応じて広告表示頻度やゲーム難易度などを変更できるようにします。app.yaml でも初期値を定義し、リモート設定がなければそちらを参照するようにしてください。

11. 定義済み”完成条件”

このテンプレートが正常に機能するかを確認するために、以下の条件を満たしていることをチェックしてください：

tag を付けて push するだけで TestFlight にアップロードされる。

app.yaml の内容を変更して scaffold.sh を実行すると、アプリ名・Bundle ID・カラー・アイコンが反映された新プロジェクトが生成される。

fastlane snapshot 実行時にUIテストが起動し、少なくとも3枚のスクリーンショットが ./screenshots/ に保存される。

PrivacyInfo.xcprivacy がアプリに同梱されており、AdMob等のSDKに合わせて必要なデータタイプが追記されている。

app_kit の公開APIのみを使って、課金・広告・解析・レビュー要求が完結する。

gen_metadata.ts でストア文面が fastlane/metadata/* に自動生成され、fastlane deliver で提出できる。

これらを確認し、問題があれば該当部分のコードや設定を修正してください。

12. メンテナンスと拡張の指針

SDK追加時はapp_kitに閉じ込める – 新しい課金SDKや広告ネットワークを追加するときは、直接アプリから呼び出さずに app_kit でラップしてください。アプリ側のAPIが変わらないように保ちます。

プライバシー対応の更新 – iOSのプライバシーポリシーやデータ収集要件が変更された場合は、PrivacyInfo.xcprivacy と Info.plist の該当キーを更新し、FastlaneやCIでも適切に含まれるか確認します。

GitHub Actions のキャッシュ活用 – ビルド時間短縮のために ~/.pub-cache や build/ をキャッシュする設定を追加しても良いでしょう。

ASO運用の自動化 – gen_metadata.ts に週次更新処理を追加したり、レビュー内容からキーワード抽出するなど、ストア最適化を自動で行うバッチを今後追加できます。
