//
//  PracticeHistoryViewController.swift
//  musica
//
//  練習記録の詳細閲覧。
//  ユーザーが見たい5視点を「曲別」「期間別」2タブで提供。
//    曲別 : スコア推移・最高スコア・改善幅 → 成長確認 / 達成感
//    期間別: 月別棒グラフ・年間比較       → 継続確認 / 年間振り返り
//

import UIKit

final class PracticeHistoryViewController: UIViewController {

    // MARK: Views

    private let segment    = UISegmentedControl(items: [localText(key: "history_tab_track"), localText(key: "history_tab_period")])
    private let scrollView = UIScrollView()
    private let stack      = UIStackView()

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = AppColor.background
        title = localText(key: "history_title")
        navigationItem.largeTitleDisplayMode = .never
        setupLayout()
        buildContent()
    }

    // MARK: Layout

    private func setupLayout() {
        segment.selectedSegmentIndex = 0
        segment.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segment)

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis    = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            segment.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            segment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            segment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: segment.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
        ])
    }

    @objc private func segmentChanged() {
        buildContent()
    }

    private func buildContent() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if segment.selectedSegmentIndex == 0 {
            buildTrackView()
        } else {
            buildPeriodView()
        }
    }

    // MARK: 曲別ビュー（成長確認・達成感）

    private func buildTrackView() {
        let service   = PracticeHistoryService.shared
        let summaries = service.allTrackSummaries()

        if summaries.isEmpty {
            stack.addArrangedSubview(buildEmptyCard(message: localText(key: "history_empty_start")))
            return
        }

        let headerLbl = UILabel()
        let masteredCount = summaries.filter { ($0.bestScore ?? 0) >= 80 }.count
        headerLbl.text = masteredCount > 0
            ? "\(summaries.count)曲を練習・うち\(masteredCount)曲をマスター🏆"
            : "\(summaries.count)曲を練習しました"
        headerLbl.font      = UIFont.systemFont(ofSize: 13)
        headerLbl.textColor = AppColor.textSecondary
        stack.addArrangedSubview(headerLbl)

        for summary in summaries.prefix(50) {
            stack.addArrangedSubview(buildTrackCard(summary))
        }
    }

    private func buildTrackCard(_ s: PracticeHistoryService.TrackSummary) -> UIView {
        let card = makeCard()

        // ── 左アイコン ──────────────────────────────────────
        let iconCfg  = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        let iconView = UIImageView(
            image: UIImage(systemName: s.dominantType.symbolName, withConfiguration: iconCfg))
        iconView.tintColor   = AppColor.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)

        // ── タイトル ─────────────────────────────────────────
        let titleLbl = UILabel()
        titleLbl.text          = s.title.isEmpty ? localText(key: "history_unknown_track") : s.title
        titleLbl.font          = UIFont.systemFont(ofSize: 14, weight: .semibold)
        titleLbl.textColor     = AppColor.textPrimary
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        // ── サブ: 種別 + 回数 ─────────────────────────────────
        let typeNames = s.usedTypes.map { $0.displayName }.joined(separator: " · ")
        let subLbl = UILabel()
        subLbl.text      = "\(typeNames)  \(s.sessionCount)回"
        subLbl.font      = UIFont.systemFont(ofSize: 11)
        subLbl.textColor = AppColor.textSecondary
        subLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(subLbl)

        // ── スコア推移（グラフ or テキスト） ─────────────────
        let trend = s.scoreTrend
        let trendView: UIView
        if trend.count >= 2 {
            let sparkline = SparklineView()
            sparkline.dataPoints = trend
            sparkline.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(sparkline)
            sparkline.heightAnchor.constraint(equalToConstant: 32).isActive = true
            trendView = sparkline
        } else {
            let trendLbl = UILabel()
            trendLbl.text = trend.isEmpty ? localText(key: "history_no_score") : "\(trend[0])%"
            trendLbl.font      = UIFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            trendLbl.textColor = AppColor.textSecondary
            trendLbl.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(trendLbl)
            trendView = trendLbl
        }

        // ── 右: 最高スコア + 改善幅 ──────────────────────────
        let rightStack = UIStackView()
        rightStack.axis      = .vertical
        rightStack.alignment = .trailing
        rightStack.spacing   = 3
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(rightStack)

        if let best = s.bestScore {
            let bestLbl = UILabel()
            bestLbl.text      = "\(best)%"
            bestLbl.font      = UIFont.monospacedDigitSystemFont(ofSize: 22, weight: .bold)
            bestLbl.textColor = best >= 80 ? AppColor.accent
                              : best >= 60 ? AppColor.textPrimary
                              :              AppColor.textSecondary
            rightStack.addArrangedSubview(bestLbl)

            if best >= 80 {
                let badge = UILabel()
                badge.text          = localText(key: "history_best_badge")
                badge.font          = UIFont.systemFont(ofSize: 10, weight: .medium)
                badge.textColor     = AppColor.accent
                rightStack.addArrangedSubview(badge)
            } else if let delta = s.trendDelta, delta != 0 {
                let deltaLbl = UILabel()
                deltaLbl.text      = delta > 0 ? "↑ +\(delta)pt" : "↓ \(delta)pt"
                deltaLbl.font      = UIFont.systemFont(ofSize: 11, weight: .medium)
                deltaLbl.textColor = delta > 0 ? UIColor.systemGreen : UIColor.systemRed
                rightStack.addArrangedSubview(deltaLbl)
            }
        }

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            rightStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            rightStack.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            titleLbl.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLbl.trailingAnchor.constraint(equalTo: rightStack.leadingAnchor, constant: -8),
            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),

            subLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            subLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 3),
            subLbl.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),

            trendView.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            trendView.topAnchor.constraint(equalTo: subLbl.bottomAnchor, constant: 6),
            trendView.trailingAnchor.constraint(equalTo: titleLbl.trailingAnchor),
            trendView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    // MARK: 期間別ビュー（継続確認・年間振り返り）

    private func buildPeriodView() {
        let service = PracticeHistoryService.shared
        let years   = service.allActiveYears()

        if years.isEmpty {
            stack.addArrangedSubview(buildEmptyCard(message: localText(key: "history_empty")))
            return
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        stack.addArrangedSubview(buildYearComparisonCard(service: service, currentYear: currentYear))

        for year in years.reversed() {
            stack.addArrangedSubview(buildYearMonthlyCard(service: service, year: year))
        }
    }

    private func buildYearComparisonCard(service: PracticeHistoryService, currentYear: Int) -> UIView {
        let card = makeCard()
        let (thisYear, lastYear) = service.yearComparison()

        let titleLbl = UILabel()
        titleLbl.text      = localText(key: "history_year_comparison")
        titleLbl.font      = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLbl.textColor = AppColor.textSecondary
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        let thisCol = makeStatColumn(value: "\(thisYear)回", label: "\(currentYear)年")
        let lastCol = makeStatColumn(value: "\(lastYear)回", label: "\(currentYear - 1)年")

        let deltaLbl = UILabel()
        if lastYear > 0 {
            let pct  = Int(Double(thisYear - lastYear) / Double(lastYear) * 100)
            let sign = pct >= 0 ? "+" : ""
            deltaLbl.text      = "\(sign)\(pct)%"
            deltaLbl.textColor = pct >= 0 ? UIColor.systemGreen : UIColor.systemRed
        } else if thisYear > 0 {
            deltaLbl.text      = "🆕"
            deltaLbl.textColor = AppColor.accent
        } else {
            deltaLbl.text      = "—"
            deltaLbl.textColor = AppColor.textSecondary
        }
        deltaLbl.font          = UIFont.systemFont(ofSize: 26, weight: .bold)
        deltaLbl.textAlignment = .center
        deltaLbl.translatesAutoresizingMaskIntoConstraints = false

        let colStack = UIStackView(arrangedSubviews: [thisCol, deltaLbl, lastCol])
        colStack.axis         = .horizontal
        colStack.distribution = .fillEqually
        colStack.alignment    = .center
        colStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(colStack)

        NSLayoutConstraint.activate([
            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            titleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            colStack.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 12),
            colStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            colStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            colStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            colStack.heightAnchor.constraint(equalToConstant: 64),
        ])
        return card
    }

    private func buildYearMonthlyCard(service: PracticeHistoryService, year: Int) -> UIView {
        let card         = makeCard()
        let currentYear  = Calendar.current.component(.year, from: Date())
        let currentMonth = Calendar.current.component(.month, from: Date())
        let monthly      = service.monthlyBreakdown(year: year)
        let maxCount     = monthly.map { $0.count }.max() ?? 0
        let total        = monthly.reduce(0) { $0 + $1.count }

        let yearLbl = UILabel()
        yearLbl.text      = "\(year)年"
        yearLbl.font      = UIFont.systemFont(ofSize: 14, weight: .semibold)
        yearLbl.textColor = year == currentYear ? AppColor.textPrimary : AppColor.textSecondary
        yearLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(yearLbl)

        let totalLbl = UILabel()
        totalLbl.text      = "計 \(total)回"
        totalLbl.font      = UIFont.systemFont(ofSize: 12)
        totalLbl.textColor = AppColor.textSecondary
        totalLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(totalLbl)

        let chartStack = UIStackView()
        chartStack.axis         = .horizontal
        chartStack.distribution = .fillEqually
        chartStack.alignment    = .fill
        chartStack.spacing      = 2
        chartStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(chartStack)

        let barAreaH: CGFloat = 48
        let labelH:   CGFloat = 14

        for item in monthly {
            let colView = UIView()
            colView.translatesAutoresizingMaskIntoConstraints = false

            let bar = UIView()
            let isCurrent = year == currentYear && item.month == currentMonth
            bar.backgroundColor = isCurrent
                ? AppColor.accent
                : AppColor.accent.withAlphaComponent(item.count > 0 ? 0.45 : 0.12)
            bar.layer.cornerRadius = 3
            bar.translatesAutoresizingMaskIntoConstraints = false
            colView.addSubview(bar)

            let barH: CGFloat = maxCount > 0 ? max(4, barAreaH * CGFloat(item.count) / CGFloat(maxCount)) : 4

            let lbl = UILabel()
            lbl.text          = "\(item.month)"
            lbl.font          = UIFont.systemFont(ofSize: 9)
            lbl.textColor     = isCurrent ? AppColor.accent : AppColor.textSecondary
            lbl.textAlignment = .center
            lbl.translatesAutoresizingMaskIntoConstraints = false
            colView.addSubview(lbl)

            NSLayoutConstraint.activate([
                lbl.bottomAnchor.constraint(equalTo: colView.bottomAnchor),
                lbl.leadingAnchor.constraint(equalTo: colView.leadingAnchor),
                lbl.trailingAnchor.constraint(equalTo: colView.trailingAnchor),
                lbl.heightAnchor.constraint(equalToConstant: labelH),

                bar.bottomAnchor.constraint(equalTo: lbl.topAnchor, constant: -4),
                bar.centerXAnchor.constraint(equalTo: colView.centerXAnchor),
                bar.widthAnchor.constraint(equalToConstant: 14),
                bar.heightAnchor.constraint(equalToConstant: barH),
            ])
            chartStack.addArrangedSubview(colView)
        }

        NSLayoutConstraint.activate([
            yearLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            yearLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),

            totalLbl.centerYAnchor.constraint(equalTo: yearLbl.centerYAnchor),
            totalLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            chartStack.topAnchor.constraint(equalTo: yearLbl.bottomAnchor, constant: 12),
            chartStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            chartStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chartStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            chartStack.heightAnchor.constraint(equalToConstant: barAreaH + 4 + labelH),
        ])
        return card
    }

    // MARK: Helpers

    private func buildEmptyCard(message: String) -> UIView {
        let card = makeCard()
        let lbl  = UILabel()
        lbl.text          = message
        lbl.font          = UIFont.systemFont(ofSize: 14)
        lbl.textColor     = AppColor.textSecondary
        lbl.textAlignment = .center
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 32),
            lbl.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            lbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 24),
            lbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -24),
            lbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -32),
        ])
        return card
    }

    private func makeStatColumn(value: String, label: String) -> UIView {
        let valueLbl = UILabel()
        valueLbl.text          = value
        valueLbl.font          = UIFont.monospacedDigitSystemFont(ofSize: 24, weight: .bold)
        valueLbl.textColor     = AppColor.textPrimary
        valueLbl.textAlignment = .center

        let labelLbl = UILabel()
        labelLbl.text          = label
        labelLbl.font          = UIFont.systemFont(ofSize: 11)
        labelLbl.textColor     = AppColor.textSecondary
        labelLbl.textAlignment = .center

        let col = UIStackView(arrangedSubviews: [valueLbl, labelLbl])
        col.axis      = .vertical
        col.spacing   = 2
        col.alignment = .center
        return col
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor    = AppColor.surface
        card.layer.cornerRadius = 16
        card.layer.shadowColor   = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)
        card.layer.shadowRadius  = 8
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
}

// MARK: - SparklineView

private final class SparklineView: UIView {

    var dataPoints: [Int] = [] {
        didSet { setNeedsDisplay() }
    }

    private let lineColor: UIColor
    private let dotRadius: CGFloat = 3

    init(color: UIColor = AppColor.accent) {
        self.lineColor = color
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        if dataPoints.count < 2 {
            guard let v = dataPoints.first else { return }
            let dot = UIBezierPath(arcCenter: CGPoint(x: rect.midX, y: yPos(value: v, in: rect)),
                                   radius: dotRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            lineColor.setFill(); dot.fill()
            return
        }

        let points = dataPoints.enumerated().map { i, v -> CGPoint in
            let x = rect.minX + CGFloat(i) / CGFloat(dataPoints.count - 1) * rect.width
            return CGPoint(x: x, y: yPos(value: v, in: rect))
        }

        let fillPath = UIBezierPath()
        fillPath.move(to: CGPoint(x: points[0].x, y: rect.maxY))
        fillPath.addLine(to: points[0])
        for p in points.dropFirst() { fillPath.addLine(to: p) }
        fillPath.addLine(to: CGPoint(x: points.last!.x, y: rect.maxY))
        fillPath.close()
        lineColor.withAlphaComponent(0.12).setFill()
        fillPath.fill()

        let linePath = UIBezierPath()
        linePath.move(to: points[0])
        for p in points.dropFirst() { linePath.addLine(to: p) }
        linePath.lineWidth = 2; linePath.lineCapStyle = .round; linePath.lineJoinStyle = .round
        lineColor.setStroke(); linePath.stroke()

        for p in points {
            let dot = UIBezierPath(arcCenter: p, radius: dotRadius,
                                   startAngle: 0, endAngle: .pi * 2, clockwise: true)
            lineColor.setFill(); dot.fill()
        }
    }

    private func yPos(value: Int, in rect: CGRect) -> CGFloat {
        let pad: CGFloat = dotRadius + 1
        let ratio = CGFloat(value) / 100
        return rect.maxY - pad - ratio * (rect.height - pad * 2)
    }
}
