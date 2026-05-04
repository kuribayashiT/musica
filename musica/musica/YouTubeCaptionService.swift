//
//  YouTubeCaptionService.swift
//  musica
//
//  YouTube 字幕取得フロー:
//  1. InnerTube 複数クライアント（TVHTML5 / IOS / ANDROID）で captionTracks を取得
//  2. 失敗時: WKWebView 2段階フォールバック
//     Phase 1: default() WV で watch ページ → captionURL を JS 取得
//     Phase 2: nonPersistent() WV で timedtext URL を直接ロード（Service Worker なし）
//

import Foundation
import UIKit
import WebKit

// MARK: - Error

enum YouTubeCaptionError: LocalizedError {
    case noTrackFound
    case parseFailed
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noTrackFound:
            return "この動画には字幕（CC）が見つかりませんでした。\n字幕が有効になっていない動画は対応していません。"
        case .parseFailed:
            return "字幕データの解析に失敗しました。"
        case .networkError(let e):
            return "通信エラー: \(e.localizedDescription)"
        }
    }
}

// MARK: - Internal

private struct CaptionTrack {
    let lang: String
    let kind: String
    let baseUrl: String
}

// MARK: - YouTubeCaptionFetcher

final class YouTubeCaptionFetcher: NSObject {

    private static let timeoutSeconds: TimeInterval = 60

    private static let androidUA      = "com.google.android.youtube/17.36.4 (Linux; U; Android 12; GB) gzip"
    private static let androidAPIKey  = "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"
    private static let androidClientVersion = "17.36.4"

    private static let desktopUA =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"

    private static let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieAcceptPolicy = .always
        cfg.httpShouldSetCookies = true
        cfg.timeoutIntervalForRequest = 15
        return URLSession(configuration: cfg)
    }()

    private var completion: ((Result<(text: String, language: String), Error>) -> Void)?
    private var timeoutTimer: Timer?
    private var videoID: String = ""
    private weak var viewController: UIViewController?
    private var wkPageFetcher: WKCaptionPageFetcher?

    // MARK: - Public

    func fetch(videoID: String,
               in viewController: UIViewController,
               completion: @escaping (Result<(text: String, language: String), Error>) -> Void) {
        self.completion = completion
        self.videoID = videoID
        self.viewController = viewController

        timeoutTimer = Timer.scheduledTimer(withTimeInterval: Self.timeoutSeconds,
                                            repeats: false) { [weak self] _ in
            self?.finish(.failure(YouTubeCaptionError.networkError(
                NSError(domain: "YouTubeCaption", code: -1,
                        userInfo: [NSLocalizedDescriptionKey:
                                    "タイムアウト（\(Int(Self.timeoutSeconds))秒）。字幕の取得に失敗しました。"]))))
        }

        fetchViaInnerTubeAndroid()
    }

    // MARK: - InnerTube（複数クライアント試行）

    private struct InnerTubeClient {
        let name: String; let version: String; let nameNum: String; let ua: String
        let apiKey: String
    }
    private static let innerTubeClients: [InnerTubeClient] = [
        InnerTubeClient(name: "TVHTML5", version: "7.20231121.08.01", nameNum: "7",
                        ua: "Mozilla/5.0 (SMART-TV; LINUX; Tizen 6.0) AppleWebKit/538.1 (KHTML, like Gecko) Version/6.0 TV Safari/538.1",
                        apiKey: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"),
        InnerTubeClient(name: "IOS", version: "19.29.1", nameNum: "5",
                        ua: "com.google.ios.youtube/19.29.1 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)",
                        apiKey: "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUA"),
        InnerTubeClient(name: "ANDROID", version: "19.29.37", nameNum: "3",
                        ua: "com.google.android.youtube/19.29.37 (Linux; U; Android 14; en_US) gzip",
                        apiKey: "AIzaSyA8eiZmM1FaDVjRy-df2KTyQ_vz_yYM39w"),
    ]

    private func fetchViaInnerTubeAndroid() {
        tryInnerTubeClient(index: 0)
    }

    private func tryInnerTubeClient(index: Int) {
        let clients = Self.innerTubeClients
        guard index < clients.count else {
            dlog("[Caption] 全 InnerTube クライアント失敗 → WKPage フォールバック")
            fetchViaWKPage(); return
        }
        let client = clients[index]
        let vid = videoID
        dlog("[Caption] InnerTube \(client.name): POST for v=\(vid)")

        guard let url = URL(string: "https://www.youtube.com/youtubei/v1/player?key=\(client.apiKey)&prettyPrint=false") else {
            tryInnerTubeClient(index: index + 1); return
        }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue(client.ua,      forHTTPHeaderField: "User-Agent")
        req.setValue(client.nameNum, forHTTPHeaderField: "X-Youtube-Client-Name")
        req.setValue(client.version, forHTTPHeaderField: "X-Youtube-Client-Version")
        req.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")

        var clientCtx: [String: Any] = [
            "clientName": client.name, "clientVersion": client.version,
            "hl": "ja", "gl": "JP", "utcOffsetMinutes": 540
        ]
        if client.name == "ANDROID" { clientCtx["androidSdkVersion"] = 34 }
        if client.name == "IOS" { clientCtx["deviceModel"] = "iPhone16,2" }

        let body: [String: Any] = [
            "videoId": vid,
            "context": ["client": clientCtx]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        Self.session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard let data else {
                dlog("[Caption] \(client.name): network error")
                self.tryInnerTubeClient(index: index + 1); return
            }
            if status != 200 {
                let errBody = String(data: data, encoding: .utf8) ?? ""
                dlog("[Caption] \(client.name): status=\(status) body=\(errBody.prefix(200))")
                self.tryInnerTubeClient(index: index + 1); return
            }
            guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                dlog("[Caption] \(client.name): JSON parse failed")
                self.tryInnerTubeClient(index: index + 1); return
            }
            let tracks = Self.extractTracksFromPlayerResponse(json)
            dlog("[Caption] \(client.name): tracks(\(tracks.count)) = \(tracks.map { "\($0.lang)/\($0.kind)" })")
            if tracks.isEmpty {
                self.tryInnerTubeClient(index: index + 1); return
            }
            self.fetchTimedtext(tracks: tracks, useAndroidUA: client.name != "TVHTML5")
        }.resume()
    }

    private static func extractTracksFromPlayerResponse(_ json: [String: Any]) -> [CaptionTrack] {
        guard let captions = json["captions"] as? [String: Any],
              let renderer = captions["playerCaptionsTracklistRenderer"] as? [String: Any],
              let arr = renderer["captionTracks"] as? [[String: Any]] else { return [] }

        let pref = ["ja", "en", "ko", "zh", "es", "fr", "de", "pt", "ru"]
        return arr.compactMap { d -> CaptionTrack? in
            guard let lang    = d["languageCode"] as? String,
                  let baseUrl = d["baseUrl"] as? String, !baseUrl.isEmpty else { return nil }
            return CaptionTrack(lang: lang, kind: d["kind"] as? String ?? "", baseUrl: baseUrl)
        }.sorted { a, b in
            let ai = pref.firstIndex(where: { a.lang.hasPrefix($0) }) ?? 999
            let bi = pref.firstIndex(where: { b.lang.hasPrefix($0) }) ?? 999
            return ai < bi
        }
    }

    // MARK: - timedtext 取得

    private func fetchTimedtext(tracks: [CaptionTrack], useAndroidUA: Bool) {
        let vid = videoID
        var candidates: [(url: String, lang: String)] = []

        for track in tracks {
            let lang = track.lang
            let kindParam = track.kind.isEmpty ? "" : "&kind=\(track.kind)"
            candidates.append((url: track.baseUrl + "&fmt=json3", lang: lang))
            candidates.append((url: track.baseUrl, lang: lang))
            let base = "https://www.youtube.com/api/timedtext?v=\(vid)&lang=\(lang)\(kindParam)"
            candidates.append((url: base + "&fmt=json3", lang: lang))
            candidates.append((url: base, lang: lang))
        }
        for lang in ["ja", "en"] {
            candidates.append((url: "https://www.youtube.com/api/timedtext?v=\(vid)&lang=\(lang)&kind=asr&fmt=json3", lang: lang))
            candidates.append((url: "https://www.youtube.com/api/timedtext?v=\(vid)&lang=\(lang)&fmt=json3", lang: lang))
        }

        tryNextTimedtext(candidates, useAndroidUA: useAndroidUA)
    }

    private func tryNextTimedtext(_ candidates: [(url: String, lang: String)], useAndroidUA: Bool) {
        guard let first = candidates.first else {
            dlog("[Caption] timedtext 全 URL 失敗")
            if useAndroidUA { fetchViaWKPage() }
            else { finish(.failure(YouTubeCaptionError.noTrackFound)) }
            return
        }
        let rest = Array(candidates.dropFirst())
        guard let url = URL(string: first.url) else {
            tryNextTimedtext(rest, useAndroidUA: useAndroidUA); return
        }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 12)
        if useAndroidUA {
            req.setValue(Self.androidUA,            forHTTPHeaderField: "User-Agent")
            req.setValue("3",                       forHTTPHeaderField: "X-Youtube-Client-Name")
            req.setValue(Self.androidClientVersion, forHTTPHeaderField: "X-Youtube-Client-Version")
        } else {
            req.setValue(Self.desktopUA, forHTTPHeaderField: "User-Agent")
        }
        req.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
        req.setValue("ja,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
        req.setValue("*/*", forHTTPHeaderField: "Accept")

        Self.session.dataTask(with: req) { [weak self] data, resp, error in
            guard let self else { return }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let body   = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
            dlog("[Caption] timedtext[\(useAndroidUA ? "android" : "desktop")]: status=\(status), len=\(body.count) | \(first.url.suffix(60))")

            guard body.count >= 20 else {
                self.tryNextTimedtext(rest, useAndroidUA: useAndroidUA); return
            }
            if !self.parseAndFinish(body, lang: first.lang) {
                self.tryNextTimedtext(rest, useAndroidUA: useAndroidUA)
            }
        }.resume()
    }

    // MARK: - WKWebView フォールバック

    private func fetchViaWKPage() {
        guard let vc = viewController else {
            finish(.failure(YouTubeCaptionError.noTrackFound)); return
        }
        let vid = videoID
        dlog("[Caption] WKPage fallback: v=\(vid)")

        let fetcher = WKCaptionPageFetcher()
        self.wkPageFetcher = fetcher

        fetcher.fetch(videoID: vid, ua: Self.desktopUA, in: vc) { [weak self] text, lang in
            guard let self else { return }
            self.wkPageFetcher = nil
            if let text, text.count >= 20, let lang, self.parseAndFinish(text, lang: lang) { return }
            dlog("[Caption] WKPage fallback も失敗")
            self.finish(.failure(YouTubeCaptionError.noTrackFound))
        }
    }

    // MARK: - パース

    @discardableResult
    private func parseAndFinish(_ text: String, lang: String) -> Bool {
        if let data = text.data(using: .utf8),
           let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
           let events = json["events"] as? [[String: Any]] {
            var lines: [String] = []
            for ev in events {
                guard let segs = ev["segs"] as? [[String: Any]] else { continue }
                let t = segs.compactMap { $0["utf8"] as? String }.joined()
                    .replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
                if !t.isEmpty { lines.append(t) }
            }
            if !lines.isEmpty {
                dlog("[Caption] SUCCESS JSON3 lang=\(lang), lines=\(lines.count)")
                finish(.success((text: lines.joined(separator: "\n"), language: lang)))
                return true
            }
        }
        let xmlLines = Self.parseXML(text)
        if !xmlLines.isEmpty {
            dlog("[Caption] SUCCESS XML lang=\(lang), lines=\(xmlLines.count)")
            finish(.success((text: xmlLines.joined(separator: "\n"), language: lang)))
            return true
        }
        return false
    }

    private static func parseXML(_ text: String) -> [String] {
        var lines: [String] = []; var search = text.startIndex..<text.endIndex
        while let o = text.range(of: "<text", range: search),
              let c = text.range(of: "</text>", range: o.upperBound..<text.endIndex),
              let g = text.range(of: ">", range: o.upperBound..<c.lowerBound) {
            let raw = String(text[g.upperBound..<c.lowerBound])
                .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<")
                .replacingOccurrences(of: "&gt;", with: ">").replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'").replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            if !raw.isEmpty { lines.append(raw) }
            search = c.upperBound..<text.endIndex
        }
        return lines
    }

    private func finish(_ result: Result<(text: String, language: String), Error>) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.timeoutTimer?.invalidate(); self.timeoutTimer = nil
            self.completion?(result); self.completion = nil
        }
    }
}

// MARK: - WKCaptionPageFetcher（ytInitialPlayerResponse 直読み方式）
//
// 戦略: WKWebView で youtube.com/watch を読み込み、
//       ytInitialPlayerResponse から captionTracks の baseUrl を取得して
//       youtube.com ドメインの JS コンテキスト内で fetch() する。
//       ユーザーの IP とクッキーを使うため bot 判定されない。

private final class WKCaptionPageFetcher: NSObject, WKNavigationDelegate, WKScriptMessageHandler {

    private static let handlerName = "captionReady"

    private var watchWebView: WKWebView?
    private var completion: ((String?, String?) -> Void)?
    private var isDone = false

    func fetch(videoID: String, ua: String, in vc: UIViewController,
               completion: @escaping (String?, String?) -> Void) {
        self.completion = completion

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let config = WKWebViewConfiguration()
            config.websiteDataStore = .default()
            // 注意: メッセージハンドラはページロード後に登録する
            // （ページロード中に window.webkit.messageHandlers が存在すると
            //   YouTube が WKWebView を検出する可能性があるため）

            let wv = WKWebView(frame: CGRect(x: -400, y: 0, width: 390, height: 844),
                               configuration: config)
            wv.customUserAgent = ua
            wv.navigationDelegate = self
            vc.view.addSubview(wv)
            self.watchWebView = wv

            var req = URLRequest(url: URL(string: "https://www.youtube.com/watch?v=\(videoID)")!,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                 timeoutInterval: 25)
            req.setValue("ja,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
            wv.load(req)
        }
    }

    // MARK: - Navigation Delegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView === watchWebView else { return }

        // ページロード完了後にハンドラを登録（検出回避）
        webView.configuration.userContentController.add(self, name: Self.handlerName)

        // プレイヤーが PO Token を生成するまで少し待つ
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extractCaptions(from: webView)
        }
    }

    private func extractCaptions(from webView: WKWebView) {
        let h = Self.handlerName
        let js = """
        (function() {
            function post(obj) {
                try { webkit.messageHandlers['\(h)'].postMessage(obj); } catch(e) {}
            }
            try {
                var ipr = window.ytInitialPlayerResponse;
                if (!ipr) { post({error: 'no ytInitialPlayerResponse'}); return; }

                var playStatus = (ipr.playabilityStatus && ipr.playabilityStatus.status) || 'unknown';
                var tracks = (ipr.captions
                    && ipr.captions.playerCaptionsTracklistRenderer
                    && ipr.captions.playerCaptionsTracklistRenderer.captionTracks) || [];

                post({debug: 'playStatus=' + playStatus + ' tracks=' + tracks.length});

                if (!tracks.length) {
                    post({error: 'no captionTracks playStatus=' + playStatus});
                    return;
                }

                var track = tracks[0];
                for (var i = 0; i < tracks.length; i++) {
                    if (tracks[i].languageCode === 'ja') { track = tracks[i]; break; }
                }
                if (track.languageCode !== 'ja') {
                    for (var i = 0; i < tracks.length; i++) {
                        if (tracks[i].languageCode && tracks[i].languageCode.indexOf('en') === 0) {
                            track = tracks[i]; break;
                        }
                    }
                }

                // 完全な URL をログ出力（切り捨てなし）
                post({debug: 'FULL_URL: ' + (track.baseUrl || '')});

                // まず JS fetch で試す
                var urls = [track.baseUrl + '&fmt=json3', track.baseUrl];
                var idx = 0;
                function tryNext() {
                    if (idx >= urls.length) {
                        // JS fetch が全滅 → Swift URLSession で試すために URL を渡す
                        post({captionUrl: track.baseUrl, lang: track.languageCode});
                        return;
                    }
                    var u = urls[idx++];
                    fetch(u, {credentials: 'include'})
                        .then(function(r) {
                            post({debug: 'JS fetch status=' + r.status + ' url#' + (idx-1)});
                            return r.arrayBuffer();
                        })
                        .then(function(buf) {
                            post({debug: 'JS fetch bytes=' + buf.byteLength});
                            if (buf.byteLength > 20) {
                                var text = new TextDecoder('utf-8').decode(buf);
                                post({intercept: text, lang: track.languageCode});
                            } else {
                                tryNext();
                            }
                        })
                        .catch(function(e) {
                            post({debug: 'JS fetch error: ' + e});
                            tryNext();
                        });
                }
                tryNext();

            } catch(e) { post({error: 'exception: ' + e}); }
        })();
        """
        webView.evaluateJavaScript(js) { _, err in
            if let err { dlog("[Caption] WKPage JS error: \(err)") }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        dlog("[Caption] WKPage fail: \(error)"); done(nil, nil)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        dlog("[Caption] WKPage provisional fail: \(error)"); done(nil, nil)
    }

    // MARK: - Script Message Handler

    func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.handlerName else { return }
        let body = message.body as? [String: Any]

        if let dbg = body?["debug"] as? String {
            dlog("[Caption] WKPage: \(dbg)"); return
        }
        if let err = body?["error"] as? String {
            dlog("[Caption] WKPage error: \(err)"); done(nil, nil); return
        }
        // JS fetch 成功
        if let text = body?["intercept"] as? String,
           let lang = body?["lang"] as? String {
            dlog("[Caption] WKPage JS success: len=\(text.count), lang=\(lang)")
            done(text, lang); return
        }
        // JS fetch が全滅 → Swift URLSession で試す
        if let captionUrl = body?["captionUrl"] as? String,
           let lang = body?["lang"] as? String {
            dlog("[Caption] WKPage JS failed, trying URLSession: \(captionUrl.prefix(80))")
            fetchWithURLSession(baseUrl: captionUrl, lang: lang)
        }
    }

    // MARK: - URLSession フォールバック（WKWebView のクッキー付き）

    private func fetchWithURLSession(baseUrl: String, lang: String) {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }

            let ytCookies = cookies.filter { $0.domain.contains("youtube.com") || $0.domain.contains("google.com") }
            let cookieNames = ytCookies.map { $0.name }
            dlog("[Caption] URLSession cookies: \(cookieNames)")

            let formats = ["&fmt=json3", ""]
            var tried = 0

            for fmt in formats {
                guard let url = URL(string: baseUrl + fmt) else { continue }
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 15)
                req.setValue("https://www.youtube.com", forHTTPHeaderField: "Referer")
                req.setValue("https://www.youtube.com", forHTTPHeaderField: "Origin")
                req.setValue("ja,en-US;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")
                req.setValue("*/*", forHTTPHeaderField: "Accept")
                req.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

                let cookieHeader = ytCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                if !cookieHeader.isEmpty { req.setValue(cookieHeader, forHTTPHeaderField: "Cookie") }

                URLSession.shared.dataTask(with: req) { [weak self] data, resp, _ in
                    guard let self, !self.isDone else { return }
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    dlog("[Caption] URLSession fmt=\(fmt.isEmpty ? "none" : "json3"): status=\(status) len=\(text.count)")
                    if text.count > 20 {
                        self.done(text, lang)
                    } else {
                        tried += 1
                        if tried == formats.count { self.done(nil, nil) }
                    }
                }.resume()
            }
        }
    }

    // MARK: - Cleanup

    private func done(_ text: String?, _ lang: String?) {
        guard !isDone else { return }
        isDone = true
        DispatchQueue.main.async { [weak self] in
            self?.watchWebView?.removeFromSuperview()
            self?.watchWebView = nil
        }
        completion?(text, lang); completion = nil
    }
}
