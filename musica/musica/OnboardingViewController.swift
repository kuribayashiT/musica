//
//  OnboardingViewController.swift
//  musica
//
//  初回起動時のみ表示する3ステップオンボーディング。
//  Step 1: Welcome
//  Step 2: 目的選択（3択カード）
//  Step 3: 使い方ガイド（目的に応じた内容）→「始める」

import UIKit

// MARK: - User Goal

enum UserGoal: String {
    case music    = "music"     // 好きな曲で練習
    case youtube  = "youtube"   // YouTube で語学学習
    case earCopy  = "earCopy"   // 耳コピ・楽器練習
}

// MARK: - OnboardingViewController

final class OnboardingViewController: UIViewController {

    var onFinish: (() -> Void)?

    // MARK: State

    private var selectedGoal: UserGoal = .music
    private var currentStep = 0   // 0: welcome, 1: goal, 2: how

    // MARK: Views

    private let containerView = UIView()

    // 各ステップのビュー
    private lazy var stepWelcome  = makeWelcomeView()
    private lazy var stepGoal     = makeGoalView()
    private lazy var stepHow      = makeHowView()

    private var stepViews: [UIView] { [stepWelcome, stepGoal, stepHow] }

    private let actionButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(localText(key: "onboarding_next"), for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        btn.backgroundColor = AppColor.accent
        btn.layer.cornerRadius = 16
        btn.layer.shadowColor = AppColor.accent.cgColor
        btn.layer.shadowOpacity = 0.35
        btn.layer.shadowRadius  = 8
        btn.layer.shadowOffset  = CGSize(width: 0, height: 4)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let skipButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(localText(key: "onboarding_skip"), for: .normal)
        btn.setTitleColor(AppColor.textSecondary, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let stepDots: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 8
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private var dotViews: [UIView] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        setupLayout()
        showStep(0, animated: false)
    }

    // MARK: - Layout

    private func setupLayout() {
        // コンテナ（各ステップが切り替わる領域）
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        // ドットインジケーター
        for i in 0..<3 {
            let dot = UIView()
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: i == 0 ? 20 : 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
            ])
            dot.layer.cornerRadius = 4
            dot.backgroundColor = i == 0 ? AppColor.accent : AppColor.accent.withAlphaComponent(0.25)
            stepDots.addArrangedSubview(dot)
            dotViews.append(dot)
        }

        view.addSubview(stepDots)
        view.addSubview(actionButton)
        view.addSubview(skipButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: stepDots.topAnchor, constant: -20),

            stepDots.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stepDots.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -24),

            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            actionButton.heightAnchor.constraint(equalToConstant: 56),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -52),

            skipButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            skipButton.topAnchor.constraint(equalTo: actionButton.bottomAnchor, constant: 12),
        ])

        actionButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        let swipeLeft  = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
    }

    // MARK: - Step Navigation

    private func showStep(_ step: Int, animated: Bool, reversed: Bool = false) {
        currentStep = step

        // 古いビューを除去
        containerView.subviews.forEach { $0.removeFromSuperview() }

        let view = stepViews[step]
        view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: containerView.topAnchor),
            view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
        ])

        if animated {
            view.alpha = 0
            view.transform = CGAffineTransform(translationX: reversed ? -40 : 40, y: 0)
            UIView.animate(withDuration: 0.38, delay: 0,
                           usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
                view.alpha = 1
                view.transform = .identity
            }
        }

        // ドット更新
        updateDots(step)

        // ボタン更新
        let isLast = step == stepViews.count - 1
        actionButton.setTitle(isLast ? localText(key: "onboarding_start") : localText(key: "onboarding_next"), for: .normal)
        skipButton.isHidden = isLast

        // Step 2（How）は目的に合わせて再構築
        if step == 2 { rebuildHowView() }
    }

    private func updateDots(_ active: Int) {
        for (i, dot) in dotViews.enumerated() {
            UIView.animate(withDuration: 0.28) {
                if i == active {
                    dot.backgroundColor = AppColor.accent
                    // アクティブは幅20
                    dot.constraints.first(where: { $0.firstAttribute == .width })?.constant = 20
                } else {
                    dot.backgroundColor = AppColor.accent.withAlphaComponent(0.25)
                    dot.constraints.first(where: { $0.firstAttribute == .width })?.constant = 8
                }
                dot.superview?.layoutIfNeeded()
            }
        }
    }

    @objc private func handleSwipe(_ gr: UISwipeGestureRecognizer) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if gr.direction == .left, currentStep < stepViews.count - 1 {
            showStep(currentStep + 1, animated: true, reversed: false)
        } else if gr.direction == .right, currentStep > 0 {
            showStep(currentStep - 1, animated: true, reversed: true)
        }
    }

    @objc private func nextTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.1, animations: {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }) { _ in
            UIView.animate(withDuration: 0.1) { self.actionButton.transform = .identity }
        }
        if currentStep < stepViews.count - 1 {
            showStep(currentStep + 1, animated: true)
        } else {
            finish()
        }
    }

    @objc private func skipTapped() { finish() }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        UserDefaults.standard.set(selectedGoal.rawValue, forKey: "userGoal")
        onFinish?()
    }

    // MARK: - Step 0: Welcome

    private func makeWelcomeView() -> UIView {
        let v = UIView()

        // 大きなアイコン
        let iconBg = UIView()
        iconBg.backgroundColor    = AppColor.accent.withAlphaComponent(0.12)
        iconBg.layer.cornerRadius = 80
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "music.note.list",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 72, weight: .thin)))
        icon.tintColor    = AppColor.accent
        icon.contentMode  = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        // パルスアニメーション
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue    = 1.0; pulse.toValue = 1.06
        pulse.duration     = 1.4; pulse.autoreverses = true
        pulse.repeatCount  = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        iconBg.layer.add(pulse, forKey: "pulse")

        let titleLabel = UILabel()
        titleLabel.text          = localText(key: "onboarding_welcome_title")
        titleLabel.font          = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        bodyLabel.text          = localText(key: "onboarding_welcome_body")
        bodyLabel.font          = UIFont.systemFont(ofSize: 16)
        bodyLabel.textColor     = AppColor.textSecondary
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        v.addSubview(iconBg)
        v.addSubview(icon)
        v.addSubview(titleLabel)
        v.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            iconBg.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            iconBg.centerYAnchor.constraint(equalTo: v.centerYAnchor, constant: -80),
            iconBg.widthAnchor.constraint(equalToConstant: 160),
            iconBg.heightAnchor.constraint(equalToConstant: 160),

            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 80),
            icon.heightAnchor.constraint(equalToConstant: 80),

            titleLabel.topAnchor.constraint(equalTo: iconBg.bottomAnchor, constant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -32),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 32),
            bodyLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -32),
        ])
        return v
    }

    // MARK: - Step 1: Goal Selection

    private var goalCardViews: [UIView] = []

    private func makeGoalView() -> UIView {
        let v = UIView()

        let titleLabel = UILabel()
        titleLabel.text          = localText(key: "onboarding_goal_title")
        titleLabel.font          = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subLabel = UILabel()
        subLabel.text          = localText(key: "onboarding_goal_sub")
        subLabel.font          = UIFont.systemFont(ofSize: 13)
        subLabel.textColor     = AppColor.textSecondary
        subLabel.textAlignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false

        let goals: [(UserGoal, String, String, String)] = [
            (.music,   "music.note.list",      localText(key: "onboarding_goal_music_title"),   localText(key: "onboarding_goal_music_sub")),
            (.youtube, "play.rectangle.fill",  localText(key: "onboarding_goal_youtube_title"), localText(key: "onboarding_goal_youtube_sub")),
            (.earCopy, "waveform",             localText(key: "onboarding_goal_earcopy_title"), localText(key: "onboarding_goal_earcopy_sub")),
        ]

        let cardsStack = UIStackView()
        cardsStack.axis      = .vertical
        cardsStack.spacing   = 12
        cardsStack.translatesAutoresizingMaskIntoConstraints = false

        goalCardViews = []
        for (goal, icon, title, sub) in goals {
            let card = makeGoalCard(goal: goal, icon: icon, title: title, sub: sub)
            cardsStack.addArrangedSubview(card)
            goalCardViews.append(card)
        }

        v.addSubview(titleLabel)
        v.addSubview(subLabel)
        v.addSubview(cardsStack)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: v.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -28),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subLabel.centerXAnchor.constraint(equalTo: v.centerXAnchor),

            cardsStack.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 28),
            cardsStack.leadingAnchor.constraint(equalTo: v.leadingAnchor, constant: 24),
            cardsStack.trailingAnchor.constraint(equalTo: v.trailingAnchor, constant: -24),
        ])

        // 初期選択
        updateGoalCards()
        return v
    }

    private func makeGoalCard(goal: UserGoal, icon: String, title: String, sub: String) -> UIView {
        let card = UIControl()
        card.tag = goal.hashValue
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16
        card.layer.borderWidth  = 2
        card.layer.borderColor  = UIColor.clear.cgColor
        card.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .medium)))
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text      = title
        titleLbl.font      = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLbl.textColor = AppColor.textPrimary

        let subLbl = UILabel()
        subLbl.text      = sub
        subLbl.font      = UIFont.systemFont(ofSize: 12)
        subLbl.textColor = AppColor.textSecondary

        let textStack = UIStackView(arrangedSubviews: [titleLbl, subLbl])
        textStack.axis    = .vertical
        textStack.spacing = 3
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let checkmark = UIImageView(image: UIImage(systemName: "checkmark.circle.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)))
        checkmark.tintColor = AppColor.accent
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.contentMode = .scaleAspectFit
        checkmark.tag = 999  // チェックマーク識別用

        card.addSubview(iconView)
        card.addSubview(textStack)
        card.addSubview(checkmark)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            textStack.trailingAnchor.constraint(equalTo: checkmark.leadingAnchor, constant: -8),

            checkmark.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            checkmark.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            checkmark.widthAnchor.constraint(equalToConstant: 24),
            checkmark.heightAnchor.constraint(equalToConstant: 24),
        ])

        // タップで goal 変更
        let goalCopy = goal
        card.addTarget(self, action: #selector(goalCardTapped(_:)), for: .touchUpInside)
        card.accessibilityIdentifier = goalCopy.rawValue
        return card
    }

    @objc private func goalCardTapped(_ sender: UIControl) {
        guard let raw = sender.accessibilityIdentifier,
              let goal = UserGoal(rawValue: raw) else { return }
        selectedGoal = goal
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        updateGoalCards()
    }

    private func updateGoalCards() {
        let goals: [UserGoal] = [.music, .youtube, .earCopy]
        for (i, view) in goalCardViews.enumerated() {
            guard let card = view as? UIControl else { continue }
            let isSelected = goals[i] == selectedGoal
            UIView.animate(withDuration: 0.22) {
                card.backgroundColor    = isSelected ? AppColor.accent.withAlphaComponent(0.1) : AppColor.surface
                card.layer.borderColor  = isSelected ? AppColor.accent.cgColor : UIColor.clear.cgColor
                let checkmark = card.viewWithTag(999)
                checkmark?.alpha = isSelected ? 1 : 0
                // アイコン・テキストの色
                if let icon = card.subviews.compactMap({ $0 as? UIImageView }).first(where: { $0.tag != 999 }) {
                    icon.tintColor = isSelected ? AppColor.accent : AppColor.textSecondary
                }
            }
        }
    }

    // MARK: - Step 2: How It Works

    private var howContentView = UIView()

    private func makeHowView() -> UIView {
        howContentView = UIView()
        rebuildHowView()
        return howContentView
    }

    private func rebuildHowView() {
        howContentView.subviews.forEach { $0.removeFromSuperview() }

        let content = howContentForGoal(selectedGoal)

        let titleLabel = UILabel()
        titleLabel.text          = content.title
        titleLabel.font          = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stepsStack = UIStackView()
        stepsStack.axis      = .vertical
        stepsStack.spacing   = 14
        stepsStack.translatesAutoresizingMaskIntoConstraints = false

        for (i, step) in content.steps.enumerated() {
            stepsStack.addArrangedSubview(makeHowStepCard(number: i + 1, icon: step.0, text: step.1))
        }

        let readyLabel = UILabel()
        readyLabel.text          = localText(key: "onboarding_ready_title")
        readyLabel.font          = UIFont.systemFont(ofSize: 15, weight: .semibold)
        readyLabel.textColor     = AppColor.accent
        readyLabel.textAlignment = .center
        readyLabel.translatesAutoresizingMaskIntoConstraints = false

        howContentView.addSubview(titleLabel)
        howContentView.addSubview(stepsStack)
        howContentView.addSubview(readyLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: howContentView.topAnchor, constant: 36),
            titleLabel.leadingAnchor.constraint(equalTo: howContentView.leadingAnchor, constant: 28),
            titleLabel.trailingAnchor.constraint(equalTo: howContentView.trailingAnchor, constant: -28),

            stepsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 28),
            stepsStack.leadingAnchor.constraint(equalTo: howContentView.leadingAnchor, constant: 24),
            stepsStack.trailingAnchor.constraint(equalTo: howContentView.trailingAnchor, constant: -24),

            readyLabel.topAnchor.constraint(equalTo: stepsStack.bottomAnchor, constant: 28),
            readyLabel.centerXAnchor.constraint(equalTo: howContentView.centerXAnchor),
        ])
    }

    private struct HowContent {
        let title: String
        let steps: [(String, String)]  // (icon, text)
    }

    private func howContentForGoal(_ goal: UserGoal) -> HowContent {
        switch goal {
        case .music:
            return HowContent(
                title: localText(key: "onboarding_howto_music_title"),
                steps: [
                    ("music.note",              localText(key: "onboarding_howto_music_step1")),
                    ("doc.text.magnifyingglass", localText(key: "onboarding_howto_music_step2")),
                    ("pencil.and.list.clipboard",localText(key: "onboarding_howto_music_step3")),
                ]
            )
        case .youtube:
            return HowContent(
                title: localText(key: "onboarding_howto_youtube_title"),
                steps: [
                    ("heart.fill",              localText(key: "onboarding_howto_youtube_step1")),
                    ("text.bubble",             localText(key: "onboarding_howto_youtube_step2")),
                    ("pencil.and.list.clipboard",localText(key: "onboarding_howto_youtube_step3")),
                ]
            )
        case .earCopy:
            return HowContent(
                title: localText(key: "onboarding_howto_earcopy_title"),
                steps: [
                    ("music.note.list", localText(key: "onboarding_howto_earcopy_step1")),
                    ("tortoise.fill",   localText(key: "onboarding_howto_earcopy_step2")),
                    ("repeat",          localText(key: "onboarding_howto_earcopy_step3")),
                ]
            )
        }
    }

    private func makeHowStepCard(number: Int, icon: String, text: String) -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 14

        let numLabel = UILabel()
        numLabel.text                = "\(number)"
        numLabel.font                = UIFont.systemFont(ofSize: 13, weight: .bold)
        numLabel.textColor           = .white
        numLabel.textAlignment       = .center
        numLabel.backgroundColor     = AppColor.accent
        numLabel.layer.cornerRadius  = 14
        numLabel.layer.masksToBounds = true
        numLabel.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)))
        iconView.tintColor   = AppColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let textLabel = UILabel()
        textLabel.text      = text
        textLabel.font      = UIFont.systemFont(ofSize: 15, weight: .medium)
        textLabel.textColor = AppColor.textPrimary
        textLabel.numberOfLines = 2
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(numLabel)
        card.addSubview(iconView)
        card.addSubview(textLabel)

        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 64),

            numLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            numLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            numLabel.widthAnchor.constraint(equalToConstant: 28),
            numLabel.heightAnchor.constraint(equalToConstant: 28),

            iconView.leadingAnchor.constraint(equalTo: numLabel.trailingAnchor, constant: 12),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            textLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            textLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            textLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }
}

// MARK: - Entry Point

extension OnboardingViewController {
    static func presentIfNeeded(from vc: UIViewController) {
        guard !UserDefaults.standard.bool(forKey: "onboardingCompleted") else { return }
        let onboarding = OnboardingViewController()
        onboarding.modalPresentationStyle = .fullScreen
        onboarding.modalTransitionStyle = .crossDissolve
        onboarding.onFinish = { [weak vc] in
            vc?.dismiss(animated: true)
        }
        vc.present(onboarding, animated: true)
    }
}
