//
//  LyricsTextEditorViewController.swift
//  musica
//
//  OCR・音声認識後の歌詞テキストを確認・編集するシート。
//  保存すると onSave が呼ばれ、呼び出し元が confirmAndSaveTranscription へ渡す。

import UIKit

final class LyricsTextEditorViewController: UIViewController {

    // MARK: - Input

    enum SourceMode { case ocr, audio }

    var initialText: String = ""
    var sourceMode: SourceMode = .ocr
    var onSave: ((String) -> Void)?

    // MARK: - Views

    private let textView        = UITextView()
    private let placeholderLabel = UILabel()
    private let charCountLabel  = UILabel()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "テキストを確認・編集"
        view.backgroundColor = AppColor.background

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "保存", style: .done,
            target: self, action: #selector(saveTapped))
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "キャンセル", style: .plain,
            target: self, action: #selector(cancelTapped))

        setupLayout()
        textView.text = initialText
        updateUI()
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
        textView.becomeFirstResponder()
        // 長い文字起こし結果を先頭から確認できるよう先頭へ
        if !textView.text.isEmpty {
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
    }

    // MARK: - Keyboard Handling

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let kbFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
              let curveRaw = notification.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt
        else { return }
        let kbHeightInView = max(0, view.bounds.maxY - view.convert(kbFrame, from: nil).minY)
        let options = UIView.AnimationOptions(rawValue: curveRaw << 16)
        UIView.animate(withDuration: duration, delay: 0, options: options) {
            self.textView.contentInset.bottom          = kbHeightInView
            self.textView.verticalScrollIndicatorInsets.bottom = kbHeightInView
        }
    }

    @objc private func keyboardWillHide() {
        UIView.animate(withDuration: 0.25) {
            self.textView.contentInset                      = .zero
            self.textView.verticalScrollIndicatorInsets     = .zero
        }
    }

    // MARK: - Layout

    private func setupLayout() {
        // ─── ヒントバナー ─────────────────────────────────────────
        let hintCard = UIView()
        hintCard.backgroundColor  = AppColor.accent.withAlphaComponent(0.1)
        hintCard.layer.cornerRadius = 12
        hintCard.translatesAutoresizingMaskIntoConstraints = false

        let hintIconName = sourceMode == .audio ? "waveform" : "doc.viewfinder"
        let hintIcon = UIImageView(image: UIImage(systemName: hintIconName))
        hintIcon.tintColor = AppColor.accent
        hintIcon.contentMode = .scaleAspectFit
        hintIcon.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = UILabel()
        hintLabel.text = sourceMode == .audio
            ? "音声認識の結果を確認し、必要な箇所を編集してから「保存」してください。"
            : "読み取り結果を確認し、必要な箇所を編集してから「保存」してください。"
        hintLabel.font = UIFont.systemFont(ofSize: 13)
        hintLabel.textColor = AppColor.textSecondary
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        hintCard.addSubview(hintIcon)
        hintCard.addSubview(hintLabel)
        NSLayoutConstraint.activate([
            hintIcon.leadingAnchor.constraint(equalTo: hintCard.leadingAnchor, constant: 14),
            hintIcon.centerYAnchor.constraint(equalTo: hintCard.centerYAnchor),
            hintIcon.widthAnchor.constraint(equalToConstant: 22),
            hintIcon.heightAnchor.constraint(equalToConstant: 22),
            hintLabel.leadingAnchor.constraint(equalTo: hintIcon.trailingAnchor, constant: 10),
            hintLabel.trailingAnchor.constraint(equalTo: hintCard.trailingAnchor, constant: -14),
            hintLabel.topAnchor.constraint(equalTo: hintCard.topAnchor, constant: 12),
            hintLabel.bottomAnchor.constraint(equalTo: hintCard.bottomAnchor, constant: -12),
        ])

        // ─── テキストビュー ───────────────────────────────────────
        textView.font                 = UIFont.systemFont(ofSize: 15)
        textView.textColor            = AppColor.textPrimary
        textView.backgroundColor      = AppColor.surface
        textView.layer.cornerRadius   = 12
        textView.textContainerInset   = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.autocorrectionType   = .no
        textView.autocapitalizationType = .none
        textView.delegate             = self
        textView.translatesAutoresizingMaskIntoConstraints = false

        placeholderLabel.text      = "テキストを入力してください..."
        placeholderLabel.font      = UIFont.systemFont(ofSize: 15)
        placeholderLabel.textColor = AppColor.textSecondary.withAlphaComponent(0.5)
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)

        // ─── 文字数・クリアバー ────────────────────────────────────
        charCountLabel.font      = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        charCountLabel.textColor = AppColor.textSecondary
        charCountLabel.textAlignment = .right
        charCountLabel.translatesAutoresizingMaskIntoConstraints = false

        // ─── キーボード上に浮かぶアクセサリバー ─────────────────────────
        // inputAccessoryView にすることで、キーボード表示中は自動的に
        // キーボードの真上に表示され、フレームがキーボードに隠れない。
        let clearBtn = UIButton(type: .system)
        clearBtn.setTitle("全て削除", for: .normal)
        clearBtn.setTitleColor(UIColor.systemRed, for: .normal)
        clearBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        clearBtn.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearBtn.translatesAutoresizingMaskIntoConstraints = false

        charCountLabel.translatesAutoresizingMaskIntoConstraints = false

        let accessory = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        accessory.backgroundColor = UIColor.secondarySystemBackground
        let sep = UIView()
        sep.backgroundColor = UIColor.separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        accessory.addSubview(sep)
        accessory.addSubview(clearBtn)
        accessory.addSubview(charCountLabel)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: accessory.topAnchor),
            sep.leadingAnchor.constraint(equalTo: accessory.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: accessory.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5),
            clearBtn.leadingAnchor.constraint(equalTo: accessory.leadingAnchor, constant: 20),
            clearBtn.centerYAnchor.constraint(equalTo: accessory.centerYAnchor),
            charCountLabel.trailingAnchor.constraint(equalTo: accessory.trailingAnchor, constant: -20),
            charCountLabel.centerYAnchor.constraint(equalTo: accessory.centerYAnchor),
        ])
        textView.inputAccessoryView = accessory

        view.addSubview(hintCard)
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            hintCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            hintCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            hintCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            textView.topAnchor.constraint(equalTo: hintCard.bottomAnchor, constant: 14),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 14),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -16),
        ])
    }

    private func updateUI() {
        let text = textView.text ?? ""
        placeholderLabel.isHidden = !text.isEmpty
        charCountLabel.text       = "\(text.count) 文字"
        navigationItem.rightBarButtonItem?.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        // dismiss を完了させてから onSave を呼ぶ（先に onSave を呼ぶと
        // 呼び出し元が present(alert) を試みてもこの VC が前面にいてブロックされる）
        dismiss(animated: true) { [weak self] in
            self?.onSave?(text)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func clearTapped() {
        let alert = UIAlertController(title: "テキストを全て削除しますか？",
                                      message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "削除", style: .destructive) { [weak self] _ in
            self?.textView.text = ""
            self?.updateUI()
        })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate

extension LyricsTextEditorViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateUI()
    }
}
