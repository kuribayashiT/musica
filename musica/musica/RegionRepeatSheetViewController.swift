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
//  ・現在再生位置を細い縦線で表示
//  ・「現在位置をスタートに」「現在位置をエンドに」ワンタップボタン
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
    private let trackBg       = UIView()
    private let fillView      = UIView()
    private let startHandle   = UIView()
    private let endHandle     = UIView()
    private let startTimeLbl  = UILabel()
    private let endTimeLbl    = UILabel()
    private let positionLine  = UIView()
    private let startDot      = UIView()
    private let endDot        = UIView()

    private let handleSize:  CGFloat = 28
    private let trackHeight: CGFloat = 6
    private let labelOffset: CGFloat = 36  // handle中心からラベル上端までの距離

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Track BG
        trackBg.backgroundColor    = AppColor.separator
        trackBg.layer.cornerRadius = trackHeight / 2

        // Fill
        fillView.backgroundColor    = AppColor.accent
        fillView.layer.cornerRadius = trackHeight / 2

        // Handles
        for handle in [startHandle, endHandle] {
            handle.backgroundColor    = .white
            handle.layer.cornerRadius = handleSize / 2
            handle.layer.shadowColor  = UIColor.black.cgColor
            handle.layer.shadowOpacity = 0.25
            handle.layer.shadowRadius  = 4
            handle.layer.shadowOffset  = CGSize(width: 0, height: 2)
        }
        startHandle.layer.borderWidth = 2.5
        startHandle.layer.borderColor = AppColor.accent.cgColor
        endHandle.layer.borderWidth   = 2.5
        endHandle.layer.borderColor   = AppColor.accent.cgColor

        // Dots inside handles
        for dot in [startDot, endDot] {
            dot.backgroundColor    = AppColor.accent
            dot.layer.cornerRadius = 4
        }

        // Time labels
        for lbl in [startTimeLbl, endTimeLbl] {
            lbl.font          = AppFont.caption
            lbl.textColor     = AppColor.accent
            lbl.textAlignment = .center
            lbl.backgroundColor = AppColor.surface
            lbl.layer.cornerRadius = 6
            lbl.layer.masksToBounds = true
        }

        // Position line
        positionLine.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        positionLine.layer.cornerRadius = 1

        [trackBg, fillView, positionLine, startHandle, endHandle,
         startDot, endDot, startTimeLbl, endTimeLbl].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        // Gesture
        let startPan = UIPanGestureRecognizer(target: self, action: #selector(handleStartPan(_:)))
        let endPan   = UIPanGestureRecognizer(target: self, action: #selector(handleEndPan(_:)))
        startHandle.addGestureRecognizer(startPan)
        endHandle.addGestureRecognizer(endPan)
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let w = bounds.width
        let centerY: CGFloat = labelOffset + handleSize / 2

        // Track bg
        trackBg.frame = CGRect(
            x: 0, y: centerY - trackHeight / 2,
            width: w, height: trackHeight
        )

        let startX = startRatio * w
        let endX   = endRatio   * w

        // Fill
        fillView.frame = CGRect(
            x: startX, y: centerY - trackHeight / 2,
            width: max(0, endX - startX), height: trackHeight
        )

        // Handles
        startHandle.frame = CGRect(
            x: startX - handleSize / 2,
            y: centerY - handleSize / 2,
            width: handleSize, height: handleSize
        )
        endHandle.frame = CGRect(
            x: endX - handleSize / 2,
            y: centerY - handleSize / 2,
            width: handleSize, height: handleSize
        )

        // Dots
        let dotSize: CGFloat = 8
        startDot.frame = CGRect(x: (handleSize - dotSize) / 2, y: (handleSize - dotSize) / 2,
                                width: dotSize, height: dotSize)
        endDot.frame   = startDot.frame

        // Position line
        let posX = positionRatio * w
        positionLine.frame = CGRect(
            x: posX - 1, y: centerY - handleSize / 2 - 4,
            width: 2, height: handleSize + 8
        )

        // Time labels
        let labelW: CGFloat = 56
        let labelH: CGFloat = 22
        let labelY: CGFloat = centerY - handleSize / 2 - labelH - 6

        let startLblX = min(max(startX - labelW / 2, 0), w - labelW)
        let endLblX   = min(max(endX   - labelW / 2, 0), w - labelW)
        startTimeLbl.frame = CGRect(x: startLblX, y: labelY, width: labelW, height: labelH)
        endTimeLbl.frame   = CGRect(x: endLblX,   y: labelY, width: labelW, height: labelH)

        updateLabels()
    }

    private func updateLabels() {
        startTimeLbl.text = formatTimeString(d: TimeInterval(startRatio) * duration)
        endTimeLbl.text   = formatTimeString(d: TimeInterval(endRatio)   * duration)
    }

    // MARK: Gestures

    @objc private func handleStartPan(_ pan: UIPanGestureRecognizer) {
        let tx = pan.translation(in: self).x
        pan.setTranslation(.zero, in: self)
        let newRatio = max(0, min(endRatio - 0.01, startRatio + tx / bounds.width))
        startRatio = newRatio
        onStartChanged?(newRatio)
    }

    @objc private func handleEndPan(_ pan: UIPanGestureRecognizer) {
        let tx = pan.translation(in: self).x
        pan.setTranslation(.zero, in: self)
        let newRatio = max(startRatio + 0.01, min(1, endRatio + tx / bounds.width))
        endRatio = newRatio
        onEndChanged?(newRatio)
    }

    // RangeTrackView の高さ（外側がheightConstraintで使う）
    static let preferredHeight: CGFloat = 36 + 28 + 16  // label + handle + bottom padding
}

// MARK: - RegionRepeatSheetViewController

final class RegionRepeatSheetViewController: UIViewController {

    // コールバック
    var onConfirm: ((_ isEnabled: Bool, _ start: CGFloat, _ end: CGFloat) -> Void)?

    // 初期値
    private var isEnabled: Bool
    private var startRatio: CGFloat
    private var endRatio:   CGFloat
    private let duration:   TimeInterval
    private let currentPositionRatio: CGFloat

    // MARK: UI
    private let containerView = UIView()
    private let handleBar     = UIView()
    private let titleLabel    = UILabel()
    private let enableSwitch  = UISwitch()
    private let enableLabel   = UILabel()
    private let trackView     = RangeTrackView()
    private let totalStartLbl = UILabel()  // "00:00"
    private let totalEndLbl   = UILabel()  // 曲の終端時刻
    private let setStartBtn   = UIButton(type: .system)
    private let setEndBtn     = UIButton(type: .system)
    private let doneButton    = UIButton(type: .system)

    // MARK: Init

    init(isEnabled: Bool, start: CGFloat, end: CGFloat,
         duration: TimeInterval, currentTime: TimeInterval) {
        self.isEnabled            = isEnabled
        self.startRatio           = start
        self.endRatio             = end
        self.duration             = duration
        self.currentPositionRatio = duration > 0 ? CGFloat(currentTime / duration) : 0
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
        syncEnableState()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateIn()
    }

    // MARK: Background

    private func setupBackground() {
        view.backgroundColor = .clear
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tap)
    }

    // MARK: Container

    private func setupContainer() {
        containerView.backgroundColor      = AppColor.surface
        containerView.layer.cornerRadius   = 24
        containerView.layer.maskedCorners  = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        containerView.clipsToBounds        = true
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalToConstant: 420),
        ])
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        containerView.addGestureRecognizer(pan)
    }

    // MARK: Content

    private func setupContent() {
        // ── ハンドルバー ──────────────────────────────────────────
        handleBar.backgroundColor    = AppColor.separator
        handleBar.layer.cornerRadius = 3
        handleBar.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(handleBar)

        // ── タイトル ──────────────────────────────────────────────
        titleLabel.text          = localText(key: "region_sheet_title")
        titleLabel.font          = AppFont.headline
        titleLabel.textColor     = AppColor.textPrimary
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(titleLabel)

        // ── 完了ボタン ────────────────────────────────────────────
        doneButton.setTitle(localText(key: "btn_done"), for: .normal)
        doneButton.titleLabel?.font = AppFont.button
        doneButton.setTitleColor(AppColor.accent, for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(doneButton)

        // ── ON/OFF 行 ─────────────────────────────────────────────
        enableLabel.text      = localText(key: "region_sheet_title")
        enableLabel.font      = AppFont.body
        enableLabel.textColor = AppColor.textPrimary
        enableLabel.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(enableLabel)

        enableSwitch.isOn        = isEnabled
        enableSwitch.onTintColor = AppColor.accent
        enableSwitch.addTarget(self, action: #selector(enableChanged(_:)), for: .valueChanged)
        enableSwitch.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(enableSwitch)

        // ── 区切り線 ──────────────────────────────────────────────
        let divider = UIView()
        divider.backgroundColor = AppColor.separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(divider)

        // ── RangeTrackView ────────────────────────────────────────
        trackView.duration      = duration
        trackView.startRatio    = startRatio
        trackView.endRatio      = endRatio
        trackView.positionRatio = currentPositionRatio
        trackView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(trackView)

        trackView.onStartChanged = { [weak self] v in self?.startRatio = v }
        trackView.onEndChanged   = { [weak self] v in self?.endRatio   = v }

        // ── 端時刻ラベル ──────────────────────────────────────────
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

        // ── 現在位置セットボタン行 ────────────────────────────────
        setupSetButton(setStartBtn, title: "◀ スタートをここに", action: #selector(setStartTapped))
        setupSetButton(setEndBtn,   title: "エンドをここに ▶",  action: #selector(setEndTapped))

        let btnStack = UIStackView(arrangedSubviews: [setStartBtn, setEndBtn])
        btnStack.axis         = .horizontal
        btnStack.distribution = .fillEqually
        btnStack.spacing      = 12
        btnStack.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(btnStack)

        // ── 制約 ──────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleBar.widthAnchor.constraint(equalToConstant: 40),
            handleBar.heightAnchor.constraint(equalToConstant: 5),

            titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),

            doneButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            doneButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            enableLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            enableLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),

            enableSwitch.centerYAnchor.constraint(equalTo: enableLabel.centerYAnchor),
            enableSwitch.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),

            divider.topAnchor.constraint(equalTo: enableLabel.bottomAnchor, constant: 16),
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

            btnStack.topAnchor.constraint(equalTo: totalStartLbl.bottomAnchor, constant: 20),
            btnStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            btnStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            btnStack.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupSetButton(_ btn: UIButton, title: String, action: Selector) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = AppFont.footnote
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth  = 1
        btn.layer.borderColor  = AppColor.border.cgColor
        btn.backgroundColor    = AppColor.surfaceSecondary
        btn.setTitleColor(AppColor.textPrimary, for: .normal)
        btn.addTarget(self, action: action, for: .touchUpInside)
    }

    // MARK: Sync

    private func syncEnableState() {
        let on = enableSwitch.isOn
        trackView.alpha       = on ? 1.0 : 0.4
        trackView.isUserInteractionEnabled = on
        setStartBtn.isEnabled = on
        setEndBtn.isEnabled   = on
        setStartBtn.alpha     = on ? 1.0 : 0.4
        setEndBtn.alpha       = on ? 1.0 : 0.4
    }

    // MARK: Actions

    @objc private func enableChanged(_ sender: UISwitch) {
        isEnabled = sender.isOn
        syncEnableState()
    }

    @objc private func setStartTapped() {
        let newRatio = min(currentPositionRatio, endRatio - 0.01)
        startRatio = max(0, newRatio)
        trackView.startRatio = startRatio
    }

    @objc private func setEndTapped() {
        let newRatio = max(currentPositionRatio, startRatio + 0.01)
        endRatio = min(1, newRatio)
        trackView.endRatio = endRatio
    }

    @objc private func doneTapped() {
        onConfirm?(isEnabled, startRatio, endRatio)
        dismissSheet()
    }

    @objc private func backgroundTapped() { dismissSheet() }

    @objc private func panGesture(_ pan: UIPanGestureRecognizer) {
        let t = pan.translation(in: view).y
        switch pan.state {
        case .changed:
            if t > 0 { containerView.transform = CGAffineTransform(translationX: 0, y: t) }
        case .ended, .cancelled:
            if t > 100 { dismissSheet() }
            else { UIView.animate(withDuration: 0.2) { self.containerView.transform = .identity } }
        default: break
        }
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
            self.view.backgroundColor = .clear
            self.containerView.transform = CGAffineTransform(
                translationX: 0, y: self.containerView.bounds.height)
        }, completion: { _ in
            self.dismiss(animated: false)
        })
    }
}
