//
//  WeakWordListViewController.swift
//  musica
//
//  苦手単語一覧画面。
//  - 単語カードでもう一度を選んだ単語を表示・管理
//  - スワイプで個別削除、ゴミ箱ボタンで全削除
//  - 「練習する」ボタンで FlashCardViewController を苦手単語モードで起動
//

import UIKit

final class WeakWordListViewController: UIViewController {

    // MARK: Views
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let practiceBtn = UIButton(type: .system)
    private let emptyView = UIView()

    // MARK: State
    private var words: [WeakWord] = []

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = localText(key: "weak_word_title")
        view.backgroundColor = AppColor.background
        navigationItem.largeTitleDisplayMode = .never

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "trash"),
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .systemRed

        setupTableView()
        setupPracticeButton()
        setupEmptyView()
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    // MARK: Setup

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.delegate   = self
        tableView.dataSource = self
        tableView.register(WeakWordCell.self, forCellReuseIdentifier: WeakWordCell.reuseID)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
    }

    private func setupPracticeButton() {
        practiceBtn.backgroundColor   = AppColor.accent
        practiceBtn.setTitleColor(.white, for: .normal)
        practiceBtn.titleLabel?.font  = UIFont.systemFont(ofSize: 16, weight: .semibold)
        practiceBtn.layer.cornerRadius = 16
        practiceBtn.addTarget(self, action: #selector(practiceTapped), for: .touchUpInside)
        practiceBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(practiceBtn)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            practiceBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16),
            practiceBtn.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            practiceBtn.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            practiceBtn.heightAnchor.constraint(equalToConstant: 52),

            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: practiceBtn.topAnchor, constant: -8),
        ])
    }

    private func setupEmptyView() {
        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 48, weight: .thin)
        let iconView = UIImageView(image: UIImage(systemName: "bookmark.slash", withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.textSecondary.withAlphaComponent(0.5)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text          = localText(key: "weak_word_empty_title")
        titleLabel.font          = UIFont.systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subLabel = UILabel()
        subLabel.text          = localText(key: "weak_word_empty_sub")
        subLabel.font          = UIFont.systemFont(ofSize: 14)
        subLabel.textColor     = AppColor.textSecondary
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2
        subLabel.translatesAutoresizingMaskIntoConstraints = false

        emptyView.addSubview(iconView)
        emptyView.addSubview(titleLabel)
        emptyView.addSubview(subLabel)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyView.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            emptyView.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -32),

            iconView.topAnchor.constraint(equalTo: emptyView.topAnchor),
            iconView.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subLabel.centerXAnchor.constraint(equalTo: emptyView.centerXAnchor),
            subLabel.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor),
        ])
    }

    // MARK: Data

    private func reload() {
        words = WeakWordService.shared.all()
        tableView.reloadData()
        updateUI()
    }

    private func updateUI() {
        let isEmpty = words.isEmpty
        emptyView.isHidden  = !isEmpty
        tableView.isHidden  = isEmpty
        practiceBtn.isHidden = isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !isEmpty

        if !isEmpty {
            practiceBtn.setTitle(String(format: localText(key: "weak_word_practice_btn_fmt"), words.count), for: .normal)
        }
    }

    // MARK: Actions

    @objc private func practiceTapped() {
        let vc = FlashCardViewController()
        vc.preloadedWeakWords = words
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .pageSheet
        if #available(iOS 15.0, *),
           let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(nav, animated: true)
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: localText(key: "weak_word_clear_all_title"),
            message: localText(key: "weak_word_clear_all_msg"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: localText(key: "weak_word_delete"), style: .destructive) { [weak self] _ in
            WeakWordService.shared.clear()
            self?.reload()
        })
        alert.addAction(UIAlertAction(title: localText(key: "btn_cancel"), style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension WeakWordListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        words.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: WeakWordCell.reuseID, for: indexPath) as! WeakWordCell
        cell.configure(word: words[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView,
                   commit editingStyle: UITableViewCell.EditingStyle,
                   forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        let key = words[indexPath.row].word
        WeakWordService.shared.remove(wordKey: key)
        words.remove(at: indexPath.row)
        tableView.deleteRows(at: [indexPath], with: .automatic)
        updateUI()
    }

    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        localText(key: "weak_word_delete")
    }
}

// MARK: - UITableViewDelegate

extension WeakWordListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
}

// MARK: - WeakWordCell

private final class WeakWordCell: UITableViewCell {
    static let reuseID = "WeakWordCell"

    private let wordLabel       = UILabel()
    private let translLabel     = UILabel()
    private let sourceLabel     = UILabel()
    private let bookmarkIcon    = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle  = .none

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        bookmarkIcon.image     = UIImage(systemName: "bookmark.fill", withConfiguration: iconCfg)
        bookmarkIcon.tintColor = .systemOrange
        bookmarkIcon.contentMode = .scaleAspectFit
        bookmarkIcon.translatesAutoresizingMaskIntoConstraints = false
        bookmarkIcon.widthAnchor.constraint(equalToConstant: 16).isActive = true

        wordLabel.font      = UIFont.systemFont(ofSize: 17, weight: .semibold)
        wordLabel.textColor = AppColor.textPrimary
        wordLabel.numberOfLines = 1

        translLabel.font      = UIFont.systemFont(ofSize: 14)
        translLabel.textColor = AppColor.accent
        translLabel.numberOfLines = 1

        sourceLabel.font      = UIFont.systemFont(ofSize: 11)
        sourceLabel.textColor = AppColor.textSecondary
        sourceLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [wordLabel, translLabel, sourceLabel])
        textStack.axis    = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [bookmarkIcon, textStack])
        row.axis      = .horizontal
        row.spacing   = 10
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)

        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    func configure(word: WeakWord) {
        wordLabel.text   = word.displayWord
        translLabel.text = word.translation ?? word.contextLine
        translLabel.textColor = word.translation != nil ? AppColor.accent : AppColor.textSecondary

        let source = [word.trackTitle, word.trackArtist].filter { !$0.isEmpty }.joined(separator: " · ")
        sourceLabel.text    = source.isEmpty ? nil : source
        sourceLabel.isHidden = source.isEmpty
    }
}
