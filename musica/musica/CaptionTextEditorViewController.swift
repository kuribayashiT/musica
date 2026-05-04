//
//  CaptionTextEditorViewController.swift
//  musica
//
//  YouTube 動画の字幕テキストを手動入力/編集するモーダル画面。
//  スクリーンショット OCR・カメラ OCR・YouTube アプリ連携をここに集約。

import UIKit
import PhotosUI
import Vision

final class CaptionTextEditorViewController: UIViewController {

    var videoID: String = ""
    var initialText: String = ""
    var onSave: ((String) -> Void)?

    private let scrollView        = UIScrollView()
    private let contentView       = UIView()
    private let textView          = UITextView()
    private let placeholderLabel  = UILabel()
    private let ocrButton         = UIButton(type: .system)   // スクショから取得
    private let loadingOverlay    = UIView()
    private let loadingLabel      = UILabel()
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = initialText.isEmpty ? "字幕を入力" : "字幕を編集"
        view.backgroundColor = AppColor.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存", style: .done, target: self, action: #selector(saveTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "キャンセル", style: .plain, target: self, action: #selector(cancelTapped))

        setupLayout()
        setupLoadingOverlay()
        textView.text = initialText
        updatePlaceholder()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(
            self, name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.removeObserver(
            self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if initialText.isEmpty { textView.becomeFirstResponder() }
    }

    // MARK: - Keyboard Handling

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let kbFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        let kbHeight = max(0, view.bounds.maxY - view.convert(kbFrame, from: nil).minY)
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.scrollView.contentInset.bottom          = kbHeight
            self.scrollView.verticalScrollIndicatorInsets.bottom = kbHeight
            // テキストビューが見えるようスクロール
            self.scrollView.scrollRectToVisible(self.textView.frame, animated: false)
        }
    }

    @objc private func keyboardWillHide() {
        UIView.animate(withDuration: 0.25) {
            self.scrollView.contentInset                      = .zero
            self.scrollView.verticalScrollIndicatorInsets     = .zero
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        // ─── ガイドカード ───────────────────────────────────────
        let guideCard = buildGuideCard()
        guideCard.translatesAutoresizingMaskIntoConstraints = false

        // ─── YouTube を開くボタン ────────────────────────────────
        let ytBtn = UIButton(type: .system)
        ytBtn.setTitle("YouTube で文字起こしを開く", for: .normal)
        ytBtn.setImage(UIImage(systemName: "arrow.up.right.square"), for: .normal)
        ytBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 15, weight: .semibold)
        ytBtn.setTitleColor(AppColor.textPrimary, for: .normal)
        ytBtn.tintColor         = AppColor.textPrimary
        ytBtn.backgroundColor   = AppColor.surface
        ytBtn.layer.cornerRadius = 14
        ytBtn.layer.borderWidth  = 1.5
        ytBtn.layer.borderColor  = AppColor.accent.withAlphaComponent(0.35).cgColor
        if #available(iOS 15, *) {
            var cfg = UIButton.Configuration.plain()
            cfg.image = UIImage(systemName: "arrow.up.right.square")
            cfg.imagePlacement = .leading
            cfg.imagePadding = 8
            cfg.title = "YouTube で文字起こしを開く"
            cfg.baseForegroundColor = AppColor.textPrimary
            cfg.background.backgroundColor = AppColor.surface
            cfg.background.cornerRadius = 14
            ytBtn.configuration = cfg
            ytBtn.layer.borderWidth = 1.5
            ytBtn.layer.borderColor = AppColor.accent.withAlphaComponent(0.35).cgColor
        }
        ytBtn.addTarget(self, action: #selector(openYoutubeTapped), for: .touchUpInside)
        ytBtn.translatesAutoresizingMaskIntoConstraints = false

        // ─── スクショから取得ボタン ──────────────────────────────
        styleOCRButton(ocrButton,
                       title: "スクショから取得",
                       icon: "camera.viewfinder",
                       primary: true)
        ocrButton.addTarget(self, action: #selector(ocrTapped), for: .touchUpInside)
        ocrButton.translatesAutoresizingMaskIntoConstraints = false

        // ─── テキストビュー ──────────────────────────────────────
        textView.font                 = UIFont.systemFont(ofSize: 15)
        textView.textColor            = AppColor.textPrimary
        textView.backgroundColor      = AppColor.surface
        textView.layer.cornerRadius   = 12
        textView.textContainerInset   = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.autocorrectionType   = .no
        textView.autocapitalizationType = .none
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.delegate = self

        placeholderLabel.text      = "ここに字幕テキストを貼り付けてください..."
        placeholderLabel.font      = UIFont.systemFont(ofSize: 15)
        placeholderLabel.textColor = AppColor.textSecondary.withAlphaComponent(0.5)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)

        // ─── 削除ボタン ──────────────────────────────────────────
        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("字幕を削除する", for: .normal)
        clearBtn.setTitleColor(UIColor.systemRed, for: .normal)
        clearBtn.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        clearBtn.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearBtn.isHidden = initialText.isEmpty
        clearBtn.translatesAutoresizingMaskIntoConstraints = false

        // ─── ScrollView ──────────────────────────────────────────
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(guideCard)
        contentView.addSubview(ytBtn)
        contentView.addSubview(ocrButton)
        contentView.addSubview(textView)
        contentView.addSubview(clearBtn)

        NSLayoutConstraint.activate([
            // scrollView はセーフエリア上端〜画面下端まで（キーボード下まで伸ばして contentInset で調整）
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // contentView は scrollView を満たし、幅は scrollView と同じ（縦スクロール専用）
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // ガイドカード
            guideCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            guideCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            guideCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // YouTube ボタン
            ytBtn.topAnchor.constraint(equalTo: guideCard.bottomAnchor, constant: 14),
            ytBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            ytBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            ytBtn.heightAnchor.constraint(equalToConstant: 50),

            // OCR ボタン
            ocrButton.topAnchor.constraint(equalTo: ytBtn.bottomAnchor, constant: 10),
            ocrButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            ocrButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            ocrButton.heightAnchor.constraint(equalToConstant: 50),

            // テキストビュー（最低高さを確保し、内容に応じて伸長）
            textView.topAnchor.constraint(equalTo: ocrButton.bottomAnchor, constant: 14),
            textView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 120),

            // 削除ボタン（contentView の下端を確定する）
            clearBtn.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
            clearBtn.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            clearBtn.heightAnchor.constraint(equalToConstant: 36),
            clearBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            // プレースホルダー
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -16),
        ])
    }

    private func styleOCRButton(_ btn: UIButton, title: String, icon: String, primary: Bool) {
        if #available(iOS 15, *) {
            var cfg = UIButton.Configuration.filled()
            cfg.image = UIImage(systemName: icon,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
            cfg.imagePlacement = .leading
            cfg.imagePadding   = 6
            cfg.title          = title
            cfg.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attr in
                var a = attr; a.font = UIFont.systemFont(ofSize: 14, weight: .semibold); return a
            }
            cfg.baseBackgroundColor = primary ? AppColor.accent : AppColor.surfaceSecondary
            cfg.baseForegroundColor = primary ? .white : AppColor.textPrimary
            cfg.background.cornerRadius = 14
            btn.configuration = cfg
        } else {
            btn.setTitle(title, for: .normal)
            btn.backgroundColor    = primary ? AppColor.accent : AppColor.surfaceSecondary
            btn.setTitleColor(primary ? .white : AppColor.textPrimary, for: .normal)
            btn.layer.cornerRadius = 14
        }
        btn.translatesAutoresizingMaskIntoConstraints = false
    }

    // MARK: - Loading Overlay

    private func setupLoadingOverlay() {
        loadingOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.55)
        loadingOverlay.layer.cornerRadius = 16
        loadingOverlay.isHidden = true
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false

        activityIndicator.color = .white
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        loadingLabel.text = "テキストを読み取り中..."
        loadingLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        loadingLabel.textColor = .white
        loadingLabel.translatesAutoresizingMaskIntoConstraints = false

        loadingOverlay.addSubview(activityIndicator)
        loadingOverlay.addSubview(loadingLabel)
        view.addSubview(loadingOverlay)

        NSLayoutConstraint.activate([
            loadingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            loadingOverlay.widthAnchor.constraint(equalToConstant: 200),
            loadingOverlay.heightAnchor.constraint(equalToConstant: 90),

            activityIndicator.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: loadingOverlay.topAnchor, constant: 16),

            loadingLabel.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            loadingLabel.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 8),
        ])
    }

    private func showLoading(_ show: Bool) {
        loadingOverlay.isHidden = !show
        if show { activityIndicator.startAnimating() }
        else    { activityIndicator.stopAnimating() }
        ocrButton.isEnabled = !show
    }

    // MARK: - Guide Card

    private func buildGuideCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 14

        let steps: [(String, String)] = [
            ("1", "下のボタンで YouTube アプリを開く"),
            ("2", "「…」→「文字起こし」を表示してスクショを撮る\n1画面に収まらない場合は複数枚撮影してください"),
            ("3", "このアプリに戻り「スクショから取得」をタップ\n複数枚まとめて選択できます"),
        ]

        let stepsStack = UIStackView()
        stepsStack.axis    = .vertical
        stepsStack.spacing = 10
        for (num, text) in steps {
            stepsStack.addArrangedSubview(buildStepRow(number: num, text: text))
        }

        // 複数枚ヒント
        let multiHintRow = UIStackView()
        multiHintRow.axis      = .horizontal
        multiHintRow.spacing   = 6
        multiHintRow.alignment = .center

        let stackIcon = UIImageView(image: UIImage(systemName: "photo.stack.fill"))
        stackIcon.tintColor   = AppColor.accent
        stackIcon.contentMode = .scaleAspectFit
        stackIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackIcon.widthAnchor.constraint(equalToConstant: 16),
            stackIcon.heightAnchor.constraint(equalToConstant: 16),
        ])

        let multiHintLabel = UILabel()
        multiHintLabel.text      = "複数枚選んだ場合、上から順に追記されます"
        multiHintLabel.font      = UIFont.systemFont(ofSize: 11, weight: .medium)
        multiHintLabel.textColor = AppColor.accent
        multiHintLabel.numberOfLines = 0

        multiHintRow.addArrangedSubview(stackIcon)
        multiHintRow.addArrangedSubview(multiHintLabel)

        let sep1 = makeSeparator()

        // 注意書き（YouTube 公式アプリ必須）
        let noteRow = UIStackView()
        noteRow.axis      = .horizontal
        noteRow.spacing   = 6
        noteRow.alignment = .top

        let noteIcon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        noteIcon.tintColor    = UIColor.systemOrange
        noteIcon.contentMode  = .scaleAspectFit
        noteIcon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            noteIcon.widthAnchor.constraint(equalToConstant: 14),
            noteIcon.heightAnchor.constraint(equalToConstant: 14),
        ])

        let noteLabel = UILabel()
        noteLabel.text          = "文字起こし機能は YouTube 公式アプリのみ対応しています。ブラウザでは表示されません。"
        noteLabel.font          = UIFont.systemFont(ofSize: 11)
        noteLabel.textColor     = UIColor.systemOrange
        noteLabel.numberOfLines = 0

        noteRow.addArrangedSubview(noteIcon)
        noteRow.addArrangedSubview(noteLabel)

        let sep2 = makeSeparator()

        let outerStack = UIStackView(arrangedSubviews: [stepsStack, sep1, multiHintRow, sep2, noteRow])
        outerStack.axis    = .vertical
        outerStack.spacing = 12
        outerStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(outerStack)
        NSLayoutConstraint.activate([
            outerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            outerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            outerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            outerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    private func buildStepRow(number: String, text: String) -> UIView {
        let badge = UILabel()
        badge.text                = number
        badge.font                = UIFont.systemFont(ofSize: 11, weight: .bold)
        badge.textColor           = .white
        badge.textAlignment       = .center
        badge.backgroundColor     = AppColor.accent
        badge.layer.cornerRadius  = 10
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 20),
            badge.heightAnchor.constraint(equalToConstant: 20),
        ])

        let label = UILabel()
        label.text          = text
        label.font          = UIFont.systemFont(ofSize: 13)
        label.textColor     = AppColor.textPrimary
        label.numberOfLines = 0

        let row = UIStackView(arrangedSubviews: [badge, label])
        row.axis      = .horizontal
        row.spacing   = 10
        row.alignment = .center
        return row
    }

    private func makeSeparator() -> UIView {
        let v = UIView()
        v.backgroundColor = AppColor.textSecondary.withAlphaComponent(0.15)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func updatePlaceholder() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            let alert = UIAlertController(title: "テキストが空です",
                                          message: "字幕テキストを入力してから保存してください。",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        onSave?(text)
        dismiss(animated: true)
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func openYoutubeTapped() {
        guard !videoID.isEmpty else { return }
        if let appURL = URL(string: "youtube://watch?v=\(videoID)"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL)
        } else if let webURL = URL(string: "https://www.youtube.com/watch?v=\(videoID)") {
            UIApplication.shared.open(webURL)
        }
    }

    @objc private func ocrTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 0   // 0 = 無制限（複数枚選択可）
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(title: "字幕を削除しますか？",
                                      message: "保存済みの字幕が削除されます。",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            YoutubeCaptionStore.delete(for: self.videoID)
            self.onSave?("")
            self.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - OCR

    private func runOCR(on image: UIImage, isLast: Bool = true, completion: (() -> Void)? = nil) {
        guard let cgImage = image.cgImage else {
            if isLast { showLoading(false) }
            completion?()
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, _ in
            guard let self else { return }
            let lines: [String] = (request.results as? [VNRecognizedTextObservation] ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            DispatchQueue.main.async {
                if isLast { self.showLoading(false) }
                if !lines.isEmpty {
                    let extracted = lines.joined(separator: "\n")
                    if self.textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.textView.text = extracted
                    } else {
                        self.textView.text += "\n" + extracted
                    }
                    self.updatePlaceholder()
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                completion?()
            }
        }
        request.recognitionLevel       = .accurate
        request.recognitionLanguages   = ["ja-JP", "en-US", "ko-KR"]
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }

    private func showOCRError(_ message: String) {
        let alert = UIAlertController(title: "読み取りできませんでした",
                                      message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate

extension CaptionTextEditorViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard !results.isEmpty else { return }
        showLoading(true)
        // 複数枚を順番にロードして OCR キューに積む
        loadImagesSequentially(results, index: 0)
    }

    private func loadImagesSequentially(_ results: [PHPickerResult], index: Int) {
        guard index < results.count else { return }  // 全枚処理完了は runOCR 内で管理
        results[index].itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self else { return }
            if let image = object as? UIImage {
                self.runOCR(on: image, isLast: index == results.count - 1) { [weak self] in
                    // 1枚終わったら次へ
                    self?.loadImagesSequentially(results, index: index + 1)
                }
            } else {
                // 読み込み失敗はスキップして次へ
                self.loadImagesSequentially(results, index: index + 1)
            }
        }
    }
}

// MARK: - UITextViewDelegate

extension CaptionTextEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
    }
}
