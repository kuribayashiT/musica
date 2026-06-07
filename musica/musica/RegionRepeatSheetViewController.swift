//
//  RegionRepeatSheetViewController.swift
//  musica
//
//  区間リピート設定ボトムシート（ビジュアルタイムライン版）
//
//  ・トラック全体を1本の横バーで表示
//  ・選択区間をアクセントカラーで強調
//  ・2つのドラッグ可能なハンドルでスタート/エンドを設定
//  ・ハンドル上に時刻ラベルをリアルタイム表示
//  ・現在再生位置を細い縦線でリアルタイム表示
//  ・「再生位置をスタートに」「再生位置をエンドに」ボタンで即時セット
//  ・シートを閉じると自動確定（スイッチ・完了ボタン不要）
//

import UIKit

// MARK: - RangeTrackView

final class RangeTrackView: UIView {

    // 0.0〜1.0 の比率
    var startRatio: CGFloat = 0.0 { didSet { setNeedsLayout() } }
    var endRatio:   CGFloat = 1.0 { didSet { setNeedsLayout() } }
    var positionRatio: CGFloat = 0.0 { didSet { setNeedsLayout() } }
    var duration: TimeInterval = 0

    var onStartChanged: ((CGFloat) -> Void)?
    var onEndChanged:   ((CGFloat) -> Void)?

    // MARK: Subviews
    private let trackBg      = UIView()
    private let fillView     = UIView()
    private let startHandle  = UIView()
    private let endHandle    = UIView()
    private let startTimeLbl = UILabel()
    private let endTimeLbl   = UILabel()
    private let positionLine = UIView()
    private let startDot     = UIView()
    private let endDot       = UIView()

    private let handleSize:  CGFloat = 28
    private let trackHeight: CGFloat = 6
    private let labelOffset: CGFloat = 36

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        trackBg.backgroundColor    = AppColor.separator
        trackBg.layer.cornerRadius = trackHeight / 2

        fillView.backgroundColor    = AppColor.accent
        fillView.layer.cornerRadius = trackHeight / 2

        for handle in [startHandle, endHandle] {
            handle.backgroundColor     = .white
            handle.layer.cornerRadius  = handleSize / 2
            handle.layer.shadowColor   = UIColor.black.cgColor
            handle.layer.shadowOpacity = 0.25
            handle.layer.shadowRadius  = 4
            handle.layer.shadowOffset  = CGSize(width: 0, height: 2)
        }
        startHandle.layer.borderWidth = 2.5
        startHandle.layer.borderColor = AppColor.accent.cgColor
        endHandle.layer.borderWidth   = 2.5
        endHandle.layer.borderColor   = AppColor.accent.cgColor

        for dot in [startDot, endDot] {
            dot.backgroundColor    = AppColor.accent
            dot.layer.cornerRadius = 4
        }

        for lbl in [startTimeLbl, endTimeLbl] {
            lbl.font               = AppFont.caption
            lbl.textColor          = AppColor.accent
            lbl.textAlignment      = .center
            lbl.backgroundColor    = AppColor.surface
            lbl.layer.cornerRadius = 6
            lbl.layer.masksToBounds = true
        }

        positionLine.backgroundColor    = UIColor.white.withAlphaComponent(0.7)
        positionLine.layer.cornerRadius = 1

        [trackBg, fillView, positionLine, startHandle, endHandle,
         startDot, endDot, startTimeLbl, endTimeLbl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        let startPan = UIPanGestureRecognizer(target: self, action: #selector(handleStartPan(_:)))
        let endPan   = UIPanGestureRecognizer(target: self, action: #selector(handleEndPan(_:)))
        startHandle.addGestureRecognizer(startPan)
        endHandle.addGestureRecognizer(endPan)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let w       = bounds.width
        let centerY = labelOffset + handleSize / 2

        trackBg.frame = CGRect(x: 0, y: centerY - trackHeight / 2, width: w, height: trackHeight)

        let startX = startRatio * w
        let endX   = endRatio   * w

        fillView.frame = CGRect(x: startX, y: centerY - trackHeight / 2,
                                width: max(0, endX - startX), height: trackHeight)

        startHandle.frame = CGRect(x: startX - handleSize / 2, y: centerY - handleSize / 2,
                                   width: handleSize, height: handleSize)
        endHandle.frame   = CGRect(x: endX - handleSize / 2, y: centerY - handleSize / 2,
                                   width: handleSize, height: handleSize)

        let dotSize: CGFloat = 8
        startDot.frame = CGRect(x: (handleSize - dotSize) / 2, y: (handleSize - dotSize) / 2,
                                width: dotSize, height: dotSize)
        endDot.frame = startDot.frame

        let posX = positionRatio * w
        positionLine.frame = CGRect(x: posX - 1, y: centerY - handleSize / 2 - 4,
                                    width: 2, height: handleSize + 8)

        let labelW: CGFloat = 56
        let labelH: CGFloat = 22
        let labelY          = centerY - handleSize / 2 - labelH - 6
        startTimeLbl.frame = CGRect(x: min(max(startX - labelW / 2, 0), w - labelW),
                                    y: labelY, width: labelW, height: labelH)
        endTimeLbl.frame   = CGRect(x: min(max(endX - labelW / 2, 0), w - labelW),
                                    y: labelY, width: labelW, height: labelH)

        updateLabels()
    }

    private func updateLabels() {
        startTimeLbl.text = formatTimeString(d: TimeInterval(startRatio) * duration)
        endTimeLbl.text   = formatTimeString(d: TimeInterval(endRatio)   * duration)
    }

    // MARK: Gestures

    @objc private func handleStartPan(_ pan: UIPanGestureRecognizer) {
        let tx      = pan.translation(in: self).x
        pan.setTranslation(.zero, in: self)
        let newRatio = max(0, min(endRatio - 0.01, startRatio + tx / bounds.width))
        startRatio = newRatio
        onStartChanged?(newRatio)
    }

    @objc private func handleEndPan(_ pan: UIPanGestureRecognizer) {
        let tx      = pan.translation(in: self).x
        pan.setTranslation(.zero, in: self)
        let newRatio = max(startRatio + 0.01, min(1, endRatio + tx / bounds.width))
        endRatio = newRatio
        onEndChanged?(newRatio)
    }

    static let preferredHeight: CGFloat = 36 + 28 + 16
}

// MARK: - RegionRepeatSheetViewController

final class RegionRepeatSheetViewController: UIViewController {

    // 範囲を確定して閉じる（isEnabled は常に true）
    var onConfirm: ((_ isEnabled: Bool, _ start: CGFloat, _ end: CGFloat) -> Void)?

    // 区間リピートをOFFにして閉じる
    var onDisable: (() -> Void)?

    /// 呼び出し元が現在の再生位置を返すクロージャを渡す（未設定の場合は init 時の値を使用）
    var getPlaybackTime: (() -> TimeInterval)?

    // 初期値
    private var startRatio: CGFloat
    private var endRatio:   CGFloat
    private let duration:          TimeInterval
    private let initialPositionRatio: CGFloat

    // MARK: UI
    private let containerView    = UIView()
    private let handleBar        = UIView()
    private let titleLabel       = UILabel()
    private let closeButton      = UIButton(type: .system)
    private let trackView        = RangeTrackView()
    private let totalStartLbl    = UILabel()
    private let totalEndLbl      = UILabel()
    private let rangeSummaryLbl  = UILabel()   // "0:30  〜  1:15"
    private let startTimeBtnLbl  = UILabel()
    private let endTimeBtnLbl    = UILabel()

    private var positionTimer: Timer?
    private var confirmed = false   // 多重呼び出し防止

    // MARK: Init

    init(isEnabled: Bool, start: CGFloat, end: CGFloat,
         duration: TimeInterval, currentTime: TimeInterval) {
        self.startRatio           = start
        self.endRatio             = end
        self.duration             = duration
        self.initialPositionRatio = duration > 0 ? CGFloat(currentTime / duration) : 0
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle   = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupContainer()
        setupContent()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
        startPositionUpdate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        positionTimer?.invalidate()
        positionTimer = nil
    }

    // MARK: Background

    private func setupBackground() {
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tap)
    }

    // MARK: Container

    private func setupContainer() {
        containerView.backgroundColor     = AppColor.surface
        containerView.layer.cornerRadius  = 24
        containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds       = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 480),
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        containerView.addGestureRecognizer(pan)
    }

    // MARK: Content

    private func setupContent() {
        // ── ハンドルバー ──
        handleBar.backgroundColor    = AppColor.separator
        handleBar.layer.cornerRadius = 3
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(handleBar)

        // ── タイトル ──
        titleLabel.text          = localText(key: "region_sheet_title")
        titleLabel.font          = AppFont.headline
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // ── 完了ボタン（確定して閉じる） ──
        closeButton.setTitle(localText(key: "section_repeat_close"), for: .normal)
        closeButton.titleLabel?.font = AppFont.button
        closeButton.setTitleColor(AppColor.accent, for: .normal)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(closeButton)

        // ── 仕切り線 ──
        let divider = UIView()
        divider.backgroundColor = AppColor.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(divider)

        // ── RangeTrackView ──
        trackView.duration      = duration
        trackView.startRatio    = startRatio
        trackView.endRatio      = endRatio
        trackView.positionRatio = initialPositionRatio
        trackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(trackView)

        trackView.onStartChanged = { [weak self] v in
            guard let self else { return }
            self.startRatio = v
            self.updateRangeDisplay()
        }
        trackView.onEndChanged = { [weak self] v in
            guard let self else { return }
            self.endRatio = v
            self.updateRangeDisplay()
        }

        // ── 端時刻ラベル ──
        totalStartLbl.text      = "00:00"
        totalStartLbl.font      = AppFont.caption2
        totalStartLbl.textColor = AppColor.textSecondary
        totalStartLbl.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(totalStartLbl)

        totalEndLbl.text      = formatTimeString(d: duration)
        totalEndLbl.font      = AppFont.caption2
        totalEndLbl.textColor = AppColor.textSecondary
        totalEndLbl.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(totalEndLbl)

        // ── 区間サマリー ──
        rangeSummaryLbl.font                     = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
        rangeSummaryLbl.textColor                = AppColor.textPrimary
        rangeSummaryLbl.textAlignment            = .center
        rangeSummaryLbl.adjustsFontSizeToFitWidth = true
        rangeSummaryLbl.minimumScaleFactor        = 0.7
        rangeSummaryLbl.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(rangeSummaryLbl)
        updateRangeDisplay()

        // ── セットボタン ──
        let startBtnView = makeSetButtonView(
            timeLbl:    startTimeBtnLbl,
            actionText: localText(key: "section_repeat_set_start"),
            isStart:    true,
            action:     #selector(setStartTapped)
        )
        let endBtnView = makeSetButtonView(
            timeLbl:    endTimeBtnLbl,
            actionText: localText(key: "section_repeat_set_end"),
            isStart:    false,
            action:     #selector(setEndTapped)
        )

        let btnStack = UIStackView(arrangedSubviews: [startBtnView, endBtnView])
        btnStack.axis         = .horizontal
        btnStack.distribution = .fillEqually
        btnStack.spacing      = 12
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(btnStack)

        // ── 制約 ──
        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),

            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            divider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            divider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            divider.heightAnchor.constraint(equalToConstant: 1),

            trackView.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 16),
            trackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            trackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            trackView.heightAnchor.constraint(equalToConstant: RangeTrackView.preferredHeight),

            totalStartLbl.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            totalStartLbl.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),

            totalEndLbl.topAnchor.constraint(equalTo: trackView.bottomAnchor, constant: 4),
            totalEndLbl.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),

            rangeSummaryLbl.topAnchor.constraint(equalTo: totalStartLbl.bottomAnchor, constant: 16),
            rangeSummaryLbl.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            rangeSummaryLbl.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            btnStack.topAnchor.constraint(equalTo: rangeSummaryLbl.bottomAnchor, constant: 16),
            btnStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            btnStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            btnStack.heightAnchor.constraint(equalToConstant: 64),
        ])

        // ── ヒントカード ──
        let tipsView = buildTipsView()
        containerView.addSubview(tipsView)
        NSLayoutConstraint.activate([
            tipsView.topAnchor.constraint(equalTo: btnStack.bottomAnchor, constant: 16),
            tipsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            tipsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
        ])

        // ── OFFボタン（常に表示） ──
        let offBtn = UIButton(type: .system)
        offBtn.setTitle(localText(key: "section_repeat_turn_off"), for: .normal)
        offBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        offBtn.setTitleColor(AppColor.accent, for: .normal)
        offBtn.addTarget(self, action: #selector(disableTapped), for: .touchUpInside)
        offBtn.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(offBtn)
        NSLayoutConstraint.activate([
            offBtn.topAnchor.constraint(equalTo: tipsView.bottomAnchor, constant: 12),
            offBtn.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
        ])
    }

    private func buildTipsView() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.accent.withAlphaComponent(0.08)
        card.layer.cornerRadius = 12
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        let icon    = UIImageView(image: UIImage(systemName: "lightbulb.fill", withConfiguration: iconCfg))
        icon.tintColor = AppColor.accent
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text          = localText(key: "section_repeat_tips")
        label.font          = UIFont.systemFont(ofSize: 11)
        label.textColor     = AppColor.accent
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 11),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 7),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -11),
        ])
        return card
    }

    private func makeSetButtonView(timeLbl: UILabel,
                                   actionText: String,
                                   isStart: Bool,
                                   action: Selector) -> UIControl {
        let ctrl = UIControl()
        ctrl.backgroundColor    = AppColor.accent.withAlphaComponent(0.1)
        ctrl.layer.cornerRadius = 14
        ctrl.addTarget(self, action: action, for: .touchUpInside)

        let iconName = isStart ? "arrow.right.to.line" : "arrow.left.to.line"
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
        let iconView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        timeLbl.font          = UIFont.monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        timeLbl.textColor     = AppColor.accent
        timeLbl.textAlignment = .center
        timeLbl.translatesAutoresizingMaskIntoConstraints = false

        let actionLbl = UILabel()
        actionLbl.text          = actionText
        actionLbl.font          = UIFont.systemFont(ofSize: 10)
        actionLbl.textColor     = AppColor.textSecondary
        actionLbl.textAlignment = .center
        actionLbl.numberOfLines = 1
        actionLbl.adjustsFontSizeToFitWidth = true
        actionLbl.minimumScaleFactor = 0.8
        actionLbl.translatesAutoresizingMaskIntoConstraints = false

        ctrl.addSubview(iconView)
        ctrl.addSubview(timeLbl)
        ctrl.addSubview(actionLbl)

        NSLayoutConstraint.activate([
            timeLbl.centerXAnchor.constraint(equalTo: ctrl.centerXAnchor),
            timeLbl.centerYAnchor.constraint(equalTo: ctrl.centerYAnchor, constant: -9),

            iconView.centerYAnchor.constraint(equalTo: timeLbl.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            actionLbl.topAnchor.constraint(equalTo: timeLbl.bottomAnchor, constant: 4),
            actionLbl.leadingAnchor.constraint(equalTo: ctrl.leadingAnchor, constant: 6),
            actionLbl.trailingAnchor.constraint(equalTo: ctrl.trailingAnchor, constant: -6),
        ])

        if isStart {
            iconView.trailingAnchor.constraint(equalTo: timeLbl.leadingAnchor, constant: -4).isActive = true
        } else {
            iconView.leadingAnchor.constraint(equalTo: timeLbl.trailingAnchor, constant: 4).isActive = true
        }

        return ctrl
    }

    // MARK: Display Updates

    private func updateRangeDisplay() {
        let startT = TimeInterval(startRatio) * duration
        let endT   = TimeInterval(endRatio)   * duration
        rangeSummaryLbl.text  = "\(formatTimeString(d: startT))  〜  \(formatTimeString(d: endT))"
        startTimeBtnLbl.text  = formatTimeString(d: startT)
        endTimeBtnLbl.text    = formatTimeString(d: endT)
    }

    // MARK: Position Monitoring

    private func startPositionUpdate() {
        guard duration > 0 else { return }
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let time = self.getPlaybackTime?() else { return }
            self.trackView.positionRatio = CGFloat(time / self.duration)
        }
    }

    // MARK: Actions

    @objc private func setStartTapped() {
        let currentTime = getPlaybackTime?() ?? TimeInterval(initialPositionRatio) * duration
        let newRatio    = duration > 0 ? CGFloat(currentTime / duration) : initialPositionRatio
        startRatio           = max(0, min(newRatio, endRatio - 0.01))
        trackView.startRatio = startRatio
        updateRangeDisplay()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func setEndTapped() {
        let currentTime = getPlaybackTime?() ?? TimeInterval(initialPositionRatio) * duration
        let newRatio    = duration > 0 ? CGFloat(currentTime / duration) : initialPositionRatio
        endRatio           = max(startRatio + 0.01, min(newRatio, 1))
        trackView.endRatio = endRatio
        updateRangeDisplay()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @objc private func closeTapped() {
        confirmAndDismiss()
    }

    @objc private func disableTapped() {
        guard !confirmed else { return }
        confirmed = true
        onDisable?()
        dismissSheet()
    }

    @objc private func backgroundTapped() {
        confirmAndDismiss()
    }

    @objc private func panGesture(_ pan: UIPanGestureRecognizer) {
        let t = pan.translation(in: view).y
        switch pan.state {
        case .changed:
            if t > 0 { containerView.transform = CGAffineTransform(translationX: 0, y: t) }
        case .ended, .cancelled:
            if t > 100 { confirmAndDismiss() }
            else { UIView.animate(withDuration: 0.2) { self.containerView.transform = .identity } }
        default: break
        }
    }

    // MARK: Confirm & Dismiss

    private func confirmAndDismiss() {
        guard !confirmed else { return }
        confirmed = true
        onConfirm?(true, startRatio, endRatio)
        dismissSheet()
    }

    // MARK: Animation

    private func animateIn() {
        view.backgroundColor = AppColor.overlay.withAlphaComponent(0)
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.view.backgroundColor = AppColor.overlay
        }
    }

    private func dismissSheet() {
        UIView.animate(withDuration: 0.22, delay: 0, options: .curveEaseIn, animations: {
            self.view.backgroundColor    = .clear
            self.containerView.transform = CGAffineTransform(
                translationX: 0, y: self.containerView.bounds.height)
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }
}
