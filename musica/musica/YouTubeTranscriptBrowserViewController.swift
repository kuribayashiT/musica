//
//  YouTubeTranscriptBrowserViewController.swift
//  musica
//
//  アプリ内ブラウザで YouTube を開き、文字起こしパネルのテキストを DOM から抽出する。

import UIKit
import WebKit

final class YouTubeTranscriptBrowserViewController: UIViewController {

    var videoID: String = ""
    var onTranscriptFetched: ((String) -> Void)?

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15"
        wv.translatesAutoresizingMaskIntoConstraints = false
        return wv
    }()

    private let bottomBar = UIView()
    private let grabButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private var progressObservation: NSKeyValueObservation?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "文字起こしを開く"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "閉じる", style: .plain, target: self, action: #selector(closeTapped))

        setupLayout()
        setupProgressBar()
        loadVideo()
    }

    deinit {
        progressObservation?.invalidate()
    }

    // MARK: - Layout

    private func setupLayout() {
        // ─── WebView ───
        view.addSubview(webView)
        webView.navigationDelegate = self

        // ─── Bottom bar ───
        bottomBar.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomBar)

        // hint
        hintLabel.text = "①動画下「…」→「文字起こしを開く」\n②パネルが開いたら「テキストを取得」をタップ"
        hintLabel.font = UIFont.systemFont(ofSize: 12)
        hintLabel.textColor = UIColor(white: 0.75, alpha: 1)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        // grab button
        grabButton.setTitle("テキストを取得", for: .normal)
        grabButton.setImage(UIImage(systemName: "doc.on.clipboard.fill"), for: .normal)
        grabButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        grabButton.setTitleColor(.white, for: .normal)
        grabButton.tintColor = .white
        grabButton.backgroundColor = AppColor.accent
        grabButton.layer.cornerRadius = 14
        grabButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -6, bottom: 0, right: 6)
        grabButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: -6)
        grabButton.addTarget(self, action: #selector(grabTapped), for: .touchUpInside)
        grabButton.translatesAutoresizingMaskIntoConstraints = false

        bottomBar.addSubview(hintLabel)
        bottomBar.addSubview(grabButton)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 110),

            hintLabel.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -16),

            grabButton.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 10),
            grabButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 40),
            grabButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -40),
            grabButton.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func setupProgressBar() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.tintColor = AppColor.accent
        progressView.trackTintColor = UIColor.clear
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
        ])

        progressObservation = webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
            DispatchQueue.main.async {
                let p = Float(wv.estimatedProgress)
                self?.progressView.setProgress(p, animated: true)
                self?.progressView.isHidden = p >= 1.0
            }
        }
    }

    private func loadVideo() {
        guard !videoID.isEmpty,
              let url = URL(string: "https://www.youtube.com/watch?v=\(videoID)") else { return }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        req.setValue("ja,en-US;q=0.9", forHTTPHeaderField: "Accept-Language")
        webView.load(req)
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func grabTapped() {
        grabButton.isEnabled = false
        grabButton.setTitle("取得中...", for: .normal)

        // 文字起こしパネルのセグメントテキストをすべて抽出する
        let js = """
        (function() {
            var texts = [];

            // YouTube デスクトップの文字起こしセグメントセレクター（複数世代に対応）
            var selectors = [
                'ytd-transcript-segment-renderer .segment-text',
                'yt-formatted-string.segment-text',
                'ytd-transcript-segment-renderer yt-formatted-string',
                '[class*="transcript"] [class*="segment-text"]',
                '[class*="TranscriptSegment"] span',
            ];

            for (var i = 0; i < selectors.length; i++) {
                var els = document.querySelectorAll(selectors[i]);
                if (els.length > 0) {
                    els.forEach(function(el) {
                        var t = el.textContent.trim();
                        if (t) texts.push(t);
                    });
                    if (texts.length > 0) break;
                }
            }

            return JSON.stringify({text: texts.join('\\n'), count: texts.length});
        })();
        """

        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self else { return }

            DispatchQueue.main.async {
                self.grabButton.isEnabled = true
                self.grabButton.setTitle("テキストを取得", for: .normal)

                var extracted = ""
                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data),
                   let obj = json as? [String: Any],
                   let text = obj["text"] as? String,
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    extracted = text
                }

                if extracted.isEmpty {
                    let alert = UIAlertController(
                        title: "文字起こしが見つかりません",
                        message: "①動画の「…」→「文字起こしを開く」を先に押してパネルを開いてください。\n\n文字起こしが表示されない場合、その動画には字幕がありません。",
                        preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                } else {
                    self.onTranscriptFetched?(extracted)
                    self.dismiss(animated: true)
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension YouTubeTranscriptBrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.isHidden = true
    }
}
