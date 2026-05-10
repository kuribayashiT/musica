//
//  DiscoverViewController.swift
//  musica
//
//  iTunes ランキング（国別）＋ YouTube 検索を統合した「発見」タブ
//

import UIKit
import WebKit
import SDWebImage

// MARK: - DiscoverViewController

class DiscoverViewController: UIViewController {

    // MARK: Countries

    private let countries: [(code: String, flag: String, label: String)] = [
        ("us", "🇺🇸", "US"),
        ("gb", "🇬🇧", "GB"),
        ("jp", "🇯🇵", "JP"),
        ("kr", "🇰🇷", "KR"),
        ("cn", "🇨🇳", "CN"),
        ("th", "🇹🇭", "TH"),
        ("es", "🇪🇸", "ES"),
        ("tr", "🇹🇷", "TR"),
    ]

    private var selectedCountryIndex: Int = 0
    private var viewMode: Int = 0   // 0: songs  1: music-videos
    private var rankingItems: [[String: Any]] = []
    private var isSearchActive = false
    private var isLoading = false

    // ランキングセグエで渡すデータ
    private var selectedMusicName  = ""
    private var selectedArtistName = ""
    private var selectedItunesUrl  = ""
    private var selectedArtworkUrl = ""

    // 検索 WebView から YoutubeVideoViewController へ渡すデータ
    private var searchVideoID = ""
    private var urlObserver: NSKeyValueObservation?
    private var isNavigatingToPlayer = false


    // MARK: UI

    private let countryScroll: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let countryStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let segment: UISegmentedControl = {
        let sc = UISegmentedControl(items: [
            localText(key: "discover_segment_songs"),
            localText(key: "discover_segment_mv"),
        ])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.register(DiscoverRankingCell.self,  forCellReuseIdentifier: DiscoverRankingCell.reuseID)
        tv.register(DiscoverSkeletonCell.self, forCellReuseIdentifier: DiscoverSkeletonCell.reuseID)
        tv.rowHeight = 72
        tv.separatorInset = UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 0)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = localText(key: "discover_search_placeholder")
        sb.translatesAutoresizingMaskIntoConstraints = false
        return sb
    }()

    private lazy var webView: WKWebView = {
        let wv = WKWebView(frame: .zero, configuration: makeYouTubeWebViewConfiguration())
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.isHidden = true
        return wv
    }()

    private let spinner: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let errorLabel: UILabel = {
        let l = UILabel()
        l.text = localText(key: "discover_load_error")
        l.textAlignment = .center
        l.font = UIFont.systemFont(ofSize: 15)
        l.isHidden = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.title = localText(key: "tab_discovery")

        buildLayout()
        buildCountryButtons()
        syncCountryToSetting()
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        searchBar.delegate = self
        tableView.delegate   = self
        tableView.dataSource = self
        tableView.backgroundColor = AppColor.background
        tableView.separatorColor  = AppColor.separator

        fetchRanking()

        // YouTube SPA は pushState でURLを変更するため decidePolicyFor が呼ばれない。
        // KVO でURLを監視し、動画URLに変わったら YoutubeVideoVC へ遷移する。
        urlObserver = webView.observe(\.url, options: .new) { [weak self] _, change in
            guard let self = self,
                  self.isSearchActive,
                  !self.isNavigatingToPlayer,
                  let optURL = change.newValue,
                  let url = optURL,
                  let videoID = self.youTubeVideoID(from: url.absoluteString) else { return }
            self.searchVideoID = videoID
            self.isNavigatingToPlayer = true
            DispatchQueue.main.async { [weak self] in
                self?.webView.goBack()
                self?.performSegue(withIdentifier: "toYoutubePlayerFromSearch", sender: nil)
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true

        let app = UINavigationBarAppearance()
        app.configureWithTransparentBackground()
        app.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        app.titleTextAttributes      = [.foregroundColor: AppColor.textPrimary]
        app.largeTitleTextAttributes = [.foregroundColor: AppColor.textPrimary]
        navigationController?.navigationBar.standardAppearance    = app
        navigationController?.navigationBar.scrollEdgeAppearance  = app
        navigationController?.navigationBar.compactAppearance     = app
        navigationController?.navigationBar.tintColor = AppColor.accent

        // 検索モード中に YoutubeVideoVC から戻った場合は検索モードのナビゲーションを維持
        if isSearchActive {
            navigationItem.title = localText(key: "discover_search_title")
            navigationItem.leftBarButtonItem = makeBackToRankingButton()
            navigationItem.rightBarButtonItem = nil
        } else {
            setSearchButton()
        }

        for btn in countryStack.arrangedSubviews {
            fadeInRanDomAnimesion(view: btn)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isNavigatingToPlayer = false  // ポップ完了後にリセット（インタラクティブポップ中の再プッシュを防ぐ）
        if isLoading {
            let skeletons = tableView.visibleCells.compactMap { $0 as? DiscoverSkeletonCell }
            if skeletons.isEmpty {
                // viewDidLoad時にboundsが0でcellが生成されていないケース
                tableView.reloadData()
            } else {
                // cellは存在するがboundsが0だったためshimmerが未構築のケース
                skeletons.forEach { $0.startShimmer() }
            }
        }
    }

    // MARK: Layout

    private func buildLayout() {
        // 検索バー（初期非表示）
        searchBar.isHidden = true
        [searchBar, countryScroll, segment, tableView, webView, spinner, errorLabel]
            .forEach { view.addSubview($0) }
        countryScroll.addSubview(countryStack)

        let safe = view.safeAreaLayoutGuide

        NSLayoutConstraint.activate([
            // 検索バー
            searchBar.topAnchor.constraint(equalTo: safe.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // 国セレクタ
            countryScroll.topAnchor.constraint(equalTo: safe.topAnchor, constant: 6),
            countryScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            countryScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            countryScroll.heightAnchor.constraint(equalToConstant: 52),

            countryStack.topAnchor.constraint(equalTo: countryScroll.contentLayoutGuide.topAnchor, constant: 4),
            countryStack.bottomAnchor.constraint(equalTo: countryScroll.contentLayoutGuide.bottomAnchor, constant: -4),
            countryStack.leadingAnchor.constraint(equalTo: countryScroll.contentLayoutGuide.leadingAnchor, constant: 16),
            countryStack.trailingAnchor.constraint(equalTo: countryScroll.contentLayoutGuide.trailingAnchor, constant: -16),
            countryStack.heightAnchor.constraint(equalTo: countryScroll.frameLayoutGuide.heightAnchor, constant: -8),

            // セグメント
            segment.topAnchor.constraint(equalTo: countryScroll.bottomAnchor, constant: 8),
            segment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            // ランキングテーブル
            tableView.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // YouTube WebView（検索時に全面表示）
            webView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // ローディング
            spinner.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),

            // エラー
            errorLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor),
        ])
    }

    // MARK: Country Buttons

    private func buildCountryButtons() {
        for (i, country) in countries.enumerated() {
            let btn = makeCountryButton(country.flag + " " + country.label, tag: i)
            countryStack.addArrangedSubview(btn)
        }
    }

    private func makeCountryButton(_ title: String, tag: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = tag
        btn.addTarget(self, action: #selector(countryTapped(_:)), for: .touchUpInside)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        btn.backgroundColor = AppColor.surfaceSecondary
        btn.setTitleColor(AppColor.textPrimary, for: .normal)
        btn.layer.cornerRadius = 16
        btn.clipsToBounds = true
        return btn
    }

    private func syncCountryToSetting() {
        // UserDefaultsに保存済みの国コードがあれば復元
        if let saved = UserDefaults.standard.string(forKey: "discover_selected_country") {
            SETTING_CONTRY_CODE = saved
        }
        let idx = countries.firstIndex { $0.code == SETTING_CONTRY_CODE } ?? 0
        selectedCountryIndex = idx
        refreshCountryHighlight()
    }

    private func refreshCountryHighlight() {
        for (i, v) in countryStack.arrangedSubviews.enumerated() {
            guard let btn = v as? UIButton else { continue }
            let selected = i == selectedCountryIndex
            btn.backgroundColor = selected ? AppColor.accent : AppColor.surfaceSecondary
            btn.setTitleColor(selected ? .white : AppColor.textPrimary, for: .normal)
        }
    }

    // MARK: Actions

    @objc private func countryTapped(_ sender: UIButton) {
        selectedCountryIndex = sender.tag
        SETTING_CONTRY_CODE = countries[sender.tag].code
        // タスクキル後も復元できるよう保存
        UserDefaults.standard.set(SETTING_CONTRY_CODE, forKey: "discover_selected_country")
        refreshCountryHighlight()
        fetchRanking()
    }

    @objc private func segmentChanged() {
        viewMode = segment.selectedSegmentIndex
        fetchRanking()
    }

    private func setSearchButton() {
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "magnifyingglass"),
            style: .plain,
            target: self,
            action: #selector(openSearch)
        )
    }

    @objc private func openSearch() {
        isSearchActive = true
        searchBar.isHidden = false
        countryScroll.isHidden = true
        segment.isHidden = true
        tableView.isHidden = true
        errorLabel.isHidden = true
        spinner.stopAnimating()
        webView.isHidden = false
        searchBar.becomeFirstResponder()
        // 左側にiOS標準ライクな「< ランキング」ボタンを配置
        navigationItem.title = localText(key: "discover_search_title")
        navigationItem.leftBarButtonItem = makeBackToRankingButton()
        navigationItem.rightBarButtonItem = nil
    }

    @objc private func closeSearch() {
        isSearchActive = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchBar.isHidden = true
        countryScroll.isHidden = false
        segment.isHidden = false
        tableView.isHidden = false
        errorLabel.isHidden = true
        webView.isHidden = true
        navigationItem.title = localText(key: "tab_discovery")
        navigationItem.leftBarButtonItem = nil
        setSearchButton()
    }

    private func makeBackToRankingButton() -> UIBarButtonItem {
        let btn = UIButton(type: .system)
        btn.setImage(
            UIImage(systemName: "chevron.left",
                    withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)),
            for: .normal
        )
        btn.setTitle("  " + localText(key: "discover_back_ranking"), for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17)
        btn.tintColor = AppColor.accent
        btn.sizeToFit()
        // 末尾の文字が詰まって見えないよう右側にマージンを追加
        btn.frame.size.width += 12
        btn.addTarget(self, action: #selector(closeSearch), for: .touchUpInside)
        return UIBarButtonItem(customView: btn)
    }

    // MARK: Data

    private func fetchRanking() {
        rankingItems = []
        isLoading = true
        tableView.reloadData()
        errorLabel.isHidden = true

        let code = countries[selectedCountryIndex].code
        let type = viewMode == 0 ? "songs" : "music-videos"
        let urlStr = "https://rss.applemarketingtools.com/api/v2/\(code)/music/most-played/50/\(type).json"
        guard let url = URL(string: urlStr) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isLoading = false
                guard
                    let data = data,
                    let rawJSON = try? JSONSerialization.jsonObject(with: data),
                    let json  = rawJSON as? [String: Any],
                    let feed  = json["feed"] as? [String: Any],
                    let items = feed["results"] as? [[String: Any]]
                else {
                    self.errorLabel.isHidden = false
                    self.tableView.reloadData()
                    return
                }
                self.rankingItems = items
                self.tableView.reloadData()
            }
        }.resume()
    }

    // MARK: Segue

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toContentsList",
           let dest = segue.destination as? iTuneRankingContentsListViewController {
            let keyword = "\(selectedMusicName) \(selectedArtistName)"
            dest.searchWord      = keyword
            dest.searchTitleWord = selectedMusicName
            dest.searchArtist    = selectedArtistName
            dest.searchMusic     = selectedMusicName
            dest.itunesUrl       = selectedItunesUrl
            dest.itunesArtwork   = selectedArtworkUrl
        }

        if segue.identifier == "toYoutubePlayerFromSearch",
           let dest = segue.destination as? YoutubeVideoViewController {
            dest.nowYoutubeVideoID = searchVideoID
            dest.fromView = COLOR_THEMA.SEARCH
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension DiscoverViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        isLoading ? 15 : rankingItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isLoading {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: DiscoverSkeletonCell.reuseID, for: indexPath) as! DiscoverSkeletonCell
            cell.startShimmer()
            return cell
        }
        let cell = tableView.dequeueReusableCell(
            withIdentifier: DiscoverRankingCell.reuseID, for: indexPath) as! DiscoverRankingCell
        let item = rankingItems[indexPath.row]
        cell.configure(
            rank:       indexPath.row + 1,
            title:      item["name"]       as? String ?? "",
            artist:     item["artistName"] as? String ?? "",
            artworkUrl: item["artworkUrl100"] as? String
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !isLoading else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        let item = rankingItems[indexPath.row]
        selectedMusicName   = item["name"]         as? String ?? ""
        selectedArtistName  = item["artistName"]   as? String ?? ""
        selectedItunesUrl   = item["url"]           as? String ?? ""
        selectedArtworkUrl  = item["artworkUrl100"] as? String ?? ""
        performSegue(withIdentifier: "toContentsList", sender: nil)
    }
}

// MARK: - WKNavigationDelegate / WKUIDelegate

extension DiscoverViewController: WKNavigationDelegate, WKUIDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url?.absoluteString,
           let videoID = youTubeVideoID(from: url),
           !isNavigatingToPlayer {
            searchVideoID = videoID
            isNavigatingToPlayer = true
            decisionHandler(.cancel)
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "toYoutubePlayerFromSearch", sender: nil)
            }
            return
        }
        decisionHandler(.allow)
    }

    // 新規ウィンドウ（全画面プレイヤー等）の生成を禁止
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url?.absoluteString,
           let videoID = youTubeVideoID(from: url),
           !isNavigatingToPlayer {
            searchVideoID = videoID
            isNavigatingToPlayer = true
            DispatchQueue.main.async {
                self.performSegue(withIdentifier: "toYoutubePlayerFromSearch", sender: nil)
            }
        } else if let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}

// MARK: - YouTube URL Helpers

private extension DiscoverViewController {

    /// watch?v= と /shorts/ の両形式から videoID を抽出する。
    func youTubeVideoID(from urlString: String) -> String? {
        if let range = urlString.range(of: "/shorts/") {
            let after = String(urlString[range.upperBound...])
            let id = String(after.split(separator: "?").first ?? Substring(after))
                .split(separator: "&").first.map(String.init) ?? after
            return id.isEmpty ? nil : id
        }
        for prefix in ["https://www.youtube.com/watch?v=", "https://m.youtube.com/watch?v="] {
            if urlString.hasPrefix(prefix) {
                let stripped = String(urlString.dropFirst(prefix.count))
                let id = String(stripped.split(separator: "&").first ?? Substring(stripped))
                return id.isEmpty ? nil : id
            }
        }
        return nil
    }
}

// MARK: - UISearchBarDelegate

extension DiscoverViewController: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let text = searchBar.text, !text.isEmpty else { return }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") {
            webView.load(URLRequest(url: url))
        }
        searchBar.resignFirstResponder()
    }
}

// MARK: - DiscoverSkeletonCell

final class DiscoverSkeletonCell: UITableViewCell {

    static let reuseID = "DiscoverSkeletonCell"

    private let rankPlaceholder    = UIView()
    private let artworkPlaceholder = UIView()
    private let titlePlaceholder   = UIView()
    private let artistPlaceholder  = UIView()

    private var shimmerWrapper:   CALayer?
    private var shimmerGradient:  CAGradientLayer?
    private var needsShimmer = false   // startShimmer後にboundsが0でも再トライするためのフラグ

    private var placeholders: [UIView] {
        [rankPlaceholder, artworkPlaceholder, titlePlaceholder, artistPlaceholder]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = AppColor.surface
        selectionStyle  = .none
        isUserInteractionEnabled = false

        for v in placeholders {
            v.backgroundColor = AppColor.surfaceSecondary
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }

        rankPlaceholder.layer.cornerRadius    = 4
        artworkPlaceholder.layer.cornerRadius = 8
        titlePlaceholder.layer.cornerRadius   = 4
        artistPlaceholder.layer.cornerRadius  = 4

        NSLayoutConstraint.activate([
            rankPlaceholder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            rankPlaceholder.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rankPlaceholder.widthAnchor.constraint(equalToConstant: 22),
            rankPlaceholder.heightAnchor.constraint(equalToConstant: 14),

            artworkPlaceholder.leadingAnchor.constraint(equalTo: rankPlaceholder.trailingAnchor, constant: 12),
            artworkPlaceholder.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artworkPlaceholder.widthAnchor.constraint(equalToConstant: 50),
            artworkPlaceholder.heightAnchor.constraint(equalToConstant: 50),

            titlePlaceholder.leadingAnchor.constraint(equalTo: artworkPlaceholder.trailingAnchor, constant: 12),
            titlePlaceholder.topAnchor.constraint(equalTo: artworkPlaceholder.topAnchor, constant: 5),
            titlePlaceholder.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.5),
            titlePlaceholder.heightAnchor.constraint(equalToConstant: 14),

            artistPlaceholder.leadingAnchor.constraint(equalTo: titlePlaceholder.leadingAnchor),
            artistPlaceholder.topAnchor.constraint(equalTo: titlePlaceholder.bottomAnchor, constant: 8),
            artistPlaceholder.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.33),
            artistPlaceholder.heightAnchor.constraint(equalToConstant: 12),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        // needsShimmer=true かつまだ構築されていない場合にだけ構築を試みる
        // （removeShimmerでwrapperがnilになってもフラグで再トライできる）
        if needsShimmer && shimmerWrapper == nil {
            buildShimmerIfNeeded()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        needsShimmer = false
        removeShimmer()
    }

    func startShimmer() {
        needsShimmer = true
        removeShimmer()           // 既存を消す
        buildShimmerIfNeeded()    // bounds有効なら即構築、無効なら layoutSubviews に委ねる
    }

    // ── Private ──────────────────────────────────────────────────────

    private func removeShimmer() {
        shimmerWrapper?.removeFromSuperlayer()
        shimmerWrapper  = nil
        shimmerGradient = nil
    }

    private func buildShimmerIfNeeded() {
        let w = contentView.bounds.width
        let h = contentView.bounds.height
        guard w > 0 else { return }

        // 既存を除去して作り直す（何度呼ばれても1本）
        shimmerWrapper?.removeFromSuperlayer()

        // ── ラッパー（プレースホルダー形状のマスク付き）────────────────
        let wrapper = CALayer()
        wrapper.frame = contentView.bounds
        wrapper.mask  = buildMask(width: w, height: h)
        contentView.layer.addSublayer(wrapper)
        shimmerWrapper = wrapper

        // ── グラデーション（cell幅の3倍、左から右へスライド）────────────
        // transform.translation.x アニメなので全幅でピクセル速度が一定になる
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.28).cgColor,
            UIColor.clear.cgColor,
        ]
        gradient.locations  = [0.4, 0.5, 0.6]   // 細い光の帯
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint   = CGPoint(x: 1, y: 0.5)
        // 3倍幅にして「帯が左端から来て右端へ抜ける」ようにする
        gradient.frame           = CGRect(x: -w, y: 0, width: w * 3, height: h)
        gradient.backgroundColor = AppColor.surfaceSecondary.cgColor
        wrapper.addSublayer(gradient)
        shimmerGradient = gradient

        let anim = CABasicAnimation(keyPath: "transform.translation.x")
        anim.fromValue   = 0
        anim.toValue     = w * 2   // 左端(-w)→右端(+w) の移動量
        anim.duration    = 1.5
        anim.repeatCount = .infinity
        gradient.add(anim, forKey: "shimmer")
    }

    // プレースホルダーの形だけグラデーションを通すマスクレイヤー
    private func buildMask(width: CGFloat, height: CGFloat) -> CALayer {
        let mask = CALayer()
        mask.frame = CGRect(x: 0, y: 0, width: width, height: height)
        for v in placeholders {
            let s = CALayer()
            s.frame           = v.frame
            s.backgroundColor = UIColor.white.cgColor
            s.cornerRadius    = v.layer.cornerRadius
            mask.addSublayer(s)
        }
        return mask
    }
}

// MARK: - DiscoverRankingCell

final class DiscoverRankingCell: UITableViewCell {

    static let reuseID = "DiscoverRankingCell"

    private let rankLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        l.textColor = AppColor.textSecondary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let artworkView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        iv.backgroundColor = AppColor.surfaceSecondary
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        l.textColor = AppColor.textPrimary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let artistLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13)
        l.textColor = AppColor.textSecondary
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = AppColor.surface
        let sel = UIView(); sel.backgroundColor = AppColor.accentMuted
        selectedBackgroundView = sel
        accessoryType = .disclosureIndicator

        [rankLabel, artworkView, titleLabel, artistLabel].forEach { contentView.addSubview($0) }

        NSLayoutConstraint.activate([
            rankLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            rankLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 30),

            artworkView.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 8),
            artworkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            artworkView.widthAnchor.constraint(equalToConstant: 50),
            artworkView.heightAnchor.constraint(equalToConstant: 50),

            titleLabel.leadingAnchor.constraint(equalTo: artworkView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: artworkView.topAnchor, constant: 5),

            artistLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            artistLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(rank: Int, title: String, artist: String, artworkUrl: String?) {
        rankLabel.text  = "\(rank)"
        titleLabel.text  = title
        artistLabel.text = artist
        artworkView.image = nil
        if let str = artworkUrl, let url = URL(string: str) {
            artworkView.sd_setImage(with: url)
        }
        fadeInRanDomAnimesion(view: artworkView)
    }
}
