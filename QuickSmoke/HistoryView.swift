import SwiftUI
import Charts

private struct DayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let smoked: Int
    let resisted: Int
}

private enum Aggregation {
    case daily
    case weekly
    case monthly
}

private enum ChartStyle {
    case line
    case bar
}

private struct HistoryChartConfig {
    let aggregation: Aggregation
    let style: ChartStyle
    let interval: DateInterval?
}

private enum ChartMetric {
    case smoked
    case resisted

    var title: String {
        switch self {
        case .smoked: return "Sigarette fumate"
        case .resisted: return "Sigarette evitate"
        }
    }

    var color: Color {
        switch self {
        case .smoked: return .orange
        case .resisted: return .green
        }
    }

    func value(from point: DayPoint) -> Int {
        switch self {
        case .smoked: return point.smoked
        case .resisted: return point.resisted
        }
    }
}

private enum HistoryRange: String, CaseIterable, Identifiable {
    case today = "Oggi"
    case days7 = "7 giorni"
    case days30 = "30 giorni"
    case months6 = "6 mesi"
    case year1 = "1 anno"
    case all = "Tutto"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .today: return 1
        case .days7: return 7
        case .days30: return 30
        case .months6: return 182
        case .year1: return 365
        case .all: return Int.max
        }
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: ChallengeViewModel
    @State private var selectedRange: HistoryRange = .days7
    @State private var drillStack: [HistoryChartConfig] = []
    @State private var showFullScreenChart = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let profile = viewModel.profile {
                        let config = currentConfig(startDate: profile.challengeStartDate)
                        chartCard(
                            points: points(from: profile, days: selectedRange.days, startDate: profile.challengeStartDate, config: config),
                            config: config,
                            availableRanges: availableRanges(startDate: profile.challengeStartDate)
                        )

                        NavigationLink {
                            BadgeRecordsView(viewModel: viewModel)
                        } label: {
                            Label("Record", systemImage: "rosette")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let profile = viewModel.profile {
                        VStack(spacing: 12) {
                            let keys = profile.dailyStats.keys.sorted().reversed()
                            ForEach(keys, id: \.self) { key in
                                if let s = profile.dailyStats[key] {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(key).font(.headline)
                                        Text("Fumate: \(s.smoked) • Evitate: \(s.resisted) • Anticipate: \(s.smokedEarly)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(Color(uiColor: .secondarySystemBackground))
                                    )
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showFullScreenChart) {
                let config = viewModel.profile.map { currentConfig(startDate: $0.challengeStartDate) } ?? HistoryChartConfig(aggregation: .daily, style: .line, interval: nil)
                FullScreenHistoryChartView(
                    points: viewModel.profile.map { points(from: $0, days: selectedRange.days, startDate: $0.challengeStartDate, config: config) } ?? [],
                    title: selectedRange.rawValue,
                    config: config,
                    selectedRange: selectedRange
                )
            }
            .onChange(of: selectedRange) { _, _ in
                drillStack = []
            }
            .onAppear {
                ensureValidSelectedRange()
            }
            .onChange(of: viewModel.profile?.challengeStartDate) { _, _ in
                ensureValidSelectedRange()
            }
        }
    }

    private func chartCard(points: [DayPoint], config: HistoryChartConfig, availableRanges: [HistoryRange]) -> some View {
        let widthPerPoint: CGFloat = config.style == .line ? 36 : 28
        let isAllShortWindow = selectedRange == .all && points.count <= 7
        let fitTodayOnScreen = selectedRange == .today

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Andamento")
                    .font(.headline)
                Spacer()
                Button {
                    showFullScreenChart = true
                } label: {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                }
                .buttonStyle(.bordered)
            }

            Picker("Periodo", selection: $selectedRange) {
                ForEach(availableRanges) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)

            GeometryReader { proxy in
                let availableWidth = max(220, proxy.size.width)
                let contentWidth = fitTodayOnScreen ? availableWidth : max(availableWidth, CGFloat(points.count) * widthPerPoint)
                let safeWidth = contentWidth.isFinite && contentWidth > 0 ? contentWidth : availableWidth

                VStack(alignment: .leading, spacing: 16) {
                    singleMetricChart(
                        points: points,
                        config: config,
                        safeWidth: safeWidth,
                        metric: .smoked,
                        isAllShortWindow: isAllShortWindow,
                        enableHorizontalScroll: !fitTodayOnScreen
                    )
                    singleMetricChart(
                        points: points,
                        config: config,
                        safeWidth: safeWidth,
                        metric: .resisted,
                        isAllShortWindow: isAllShortWindow,
                        enableHorizontalScroll: !fitTodayOnScreen
                    )
                }
            }
            .frame(height: 470)

            Text("Tap su barra per entrare nel dettaglio • doppio tap per tornare indietro")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
    }

    private func singleMetricChart(
        points: [DayPoint],
        config: HistoryChartConfig,
        safeWidth: CGFloat,
        metric: ChartMetric,
        isAllShortWindow: Bool,
        enableHorizontalScroll: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(metric.color)

            ScrollView(.horizontal, showsIndicators: enableHorizontalScroll) {
                Chart(points) { point in
                    if config.style == .line {
                        LineMark(
                            x: .value("Periodo", point.date),
                            y: .value(metric.title, metric.value(from: point))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.color)
                        .symbol(.circle)
                    } else {
                        BarMark(
                            x: .value("Periodo", point.date),
                            y: .value(metric.title, metric.value(from: point))
                        )
                        .foregroundStyle(metric.color)
                    }
                }
                .frame(width: safeWidth, height: 200)
                .chartXScale(domain: xDomain(for: points, selectedRange: selectedRange))
                .chartYScale(domain: yDomain(for: points, metric: metric))
                .chartPlotStyle { plot in
                    plot.frame(maxWidth: .infinity, alignment: .leading)
                }
                .chartXAxis {
                    if config.aggregation == .daily && selectedRange == .today {
                        AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        }
                    } else if config.aggregation == .daily && (selectedRange == .days7 || isAllShortWindow) {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    } else if config.aggregation == .daily {
                        AxisMarks(values: .stride(by: .day)) { value in
                            if let date = value.as(Date.self), Calendar.current.component(.weekday, from: date) == 2 {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.day().month())
                            }
                        }
                    } else if config.aggregation == .weekly {
                        AxisMarks(values: .stride(by: .weekOfYear)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month())
                        }
                    } else {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { event in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let plotOrigin = geo[plotFrame].origin
                                        let xPosition = event.location.x - plotOrigin.x
                                        if let tappedDate: Date = proxy.value(atX: xPosition) {
                                            drillDown(from: tappedDate, using: points, currentConfig: config)
                                        }
                                    }
                            )
                    }
                }
                .onTapGesture(count: 2) {
                    if !drillStack.isEmpty {
                        _ = drillStack.popLast()
                    }
                }
            }
            .scrollDisabled(!enableHorizontalScroll)
        }
    }

    private func points(from profile: ChallengeProfile, days: Int, startDate: Date, config: HistoryChartConfig) -> [DayPoint] {
        if selectedRange == .today {
            return todayHourlyPoints(from: profile)
        }

        let cal = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"

        let usedDays = max(1, (cal.dateComponents([.day], from: cal.startOfDay(for: startDate), to: Date()).day ?? 0) + 1)
        let effectiveDays = days == Int.max ? max(7, usedDays) : days

        let allDailyPoints: [DayPoint] = (0..<effectiveDays).map { offset in
            let date = cal.startOfDay(
                for: cal.date(byAdding: .day, value: -(effectiveDays - offset - 1), to: Date()) ?? Date()
            )
            let key = f.string(from: date)
            let stats = profile.dailyStats[key] ?? DailyStats()
            return DayPoint(date: date, smoked: stats.smoked, resisted: stats.resisted)
        }

        let dailyPoints: [DayPoint]
        if let interval = config.interval {
            dailyPoints = allDailyPoints.filter { interval.contains($0.date) }
        } else {
            dailyPoints = allDailyPoints
        }

        switch config.aggregation {
        case .daily:
            return dailyPoints
        case .weekly:
            return weeklyAverages(from: dailyPoints)
        case .monthly:
            return monthlyAverages(from: dailyPoints)
        }
    }

    private func todayHourlyPoints(from profile: ChallengeProfile) -> [DayPoint] {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let sixAM = calendar.date(byAdding: .hour, value: 6, to: todayStart) ?? todayStart
        let chartStart = now >= sixAM ? sixAM : todayStart

        let todayEvents = (profile.actionEvents ?? []).filter { event in
            calendar.isDate(event.date, inSameDayAs: now)
        }

        let currentHour = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now)) ?? now
        let hours = max(0, calendar.dateComponents([.hour], from: chartStart, to: currentHour).hour ?? 0)

        return (0...hours).map { offset in
            let hourStart = calendar.date(byAdding: .hour, value: offset, to: chartStart) ?? chartStart
            let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart) ?? hourStart
            let eventsInHour = todayEvents.filter { event in
                event.date >= hourStart && event.date < hourEnd
            }
            let smoked = eventsInHour.filter { $0.type == .smoked }.count
            let resisted = eventsInHour.filter { $0.type == .resisted }.count
            return DayPoint(date: hourStart, smoked: smoked, resisted: resisted)
        }
    }

    private func weeklyAverages(from dailyPoints: [DayPoint]) -> [DayPoint] {
        var groups: [Date: [DayPoint]] = [:]
        let calendar = Calendar.current

        for point in dailyPoints {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: point.date)?.start ?? point.date
            groups[weekStart, default: []].append(point)
        }

        return groups.keys.sorted().compactMap { weekStart in
            guard let week = groups[weekStart], !week.isEmpty else { return nil }
            let avgSmoked = Int((Double(week.map(\.smoked).reduce(0, +)) / Double(week.count)).rounded())
            let avgResisted = Int((Double(week.map(\.resisted).reduce(0, +)) / Double(week.count)).rounded())
            return DayPoint(date: weekStart, smoked: avgSmoked, resisted: avgResisted)
        }
    }

    private func monthlyAverages(from dailyPoints: [DayPoint]) -> [DayPoint] {
        var groups: [Date: [DayPoint]] = [:]
        let calendar = Calendar.current

        for point in dailyPoints {
            let c = calendar.dateComponents([.year, .month], from: point.date)
            let monthStart = calendar.date(from: c) ?? point.date
            groups[monthStart, default: []].append(point)
        }

        return groups.keys.sorted().compactMap { monthStart in
            guard let month = groups[monthStart], !month.isEmpty else { return nil }
            let avgSmoked = Int((Double(month.map(\.smoked).reduce(0, +)) / Double(month.count)).rounded())
            let avgResisted = Int((Double(month.map(\.resisted).reduce(0, +)) / Double(month.count)).rounded())
            return DayPoint(date: monthStart, smoked: avgSmoked, resisted: avgResisted)
        }
    }

    private func availableRanges(startDate: Date) -> [HistoryRange] {
        let usedDays = max(1, (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Date()).day ?? 0) + 1)
        return HistoryRange.allCases.filter { usedDays >= minimumRequiredDays(for: $0) }
    }

    private func minimumRequiredDays(for range: HistoryRange) -> Int {
        switch range {
        case .today, .days7, .all:
            return 1
        case .days30:
            return 30
        case .months6:
            return 182
        case .year1:
            return 365
        }
    }

    private func ensureValidSelectedRange() {
        guard let startDate = viewModel.profile?.challengeStartDate else { return }
        let allowed = availableRanges(startDate: startDate)
        if !allowed.contains(selectedRange) {
            selectedRange = .days7
            drillStack = []
        }
    }

    private func baseChartConfig(startDate: Date) -> HistoryChartConfig {
        switch selectedRange {
        case .today, .days7:
            return HistoryChartConfig(aggregation: .daily, style: .line, interval: nil)
        case .days30:
            return HistoryChartConfig(aggregation: .weekly, style: .bar, interval: nil)
        case .months6, .year1:
            return HistoryChartConfig(aggregation: .monthly, style: .bar, interval: nil)
        case .all:
            let usedDays = max(1, (Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0) + 1)
            if usedDays <= 90 {
                return HistoryChartConfig(aggregation: .daily, style: .line, interval: nil)
            } else if usedDays <= 365 {
                return HistoryChartConfig(aggregation: .weekly, style: .bar, interval: nil)
            } else {
                return HistoryChartConfig(aggregation: .monthly, style: .bar, interval: nil)
            }
        }
    }

    private func currentConfig(startDate: Date) -> HistoryChartConfig {
        drillStack.last ?? baseChartConfig(startDate: startDate)
    }

    private func drillDown(from selectedDate: Date, using points: [DayPoint], currentConfig: HistoryChartConfig) {
        guard currentConfig.style == .bar else { return }
        guard let nearest = nearestPointDate(to: selectedDate, in: points) else { return }
        let cal = Calendar.current

        switch currentConfig.aggregation {
        case .monthly:
            if let monthInterval = cal.dateInterval(of: .month, for: nearest) {
                drillStack.append(HistoryChartConfig(aggregation: .weekly, style: .bar, interval: monthInterval))
            }
        case .weekly:
            if let weekInterval = cal.dateInterval(of: .weekOfYear, for: nearest) {
                drillStack.append(HistoryChartConfig(aggregation: .daily, style: .line, interval: weekInterval))
            }
        case .daily:
            break
        }
    }

    private func nearestPointDate(to target: Date, in points: [DayPoint]) -> Date? {
        points.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        })?.date
    }

    private func xDomain(for points: [DayPoint], selectedRange: HistoryRange) -> ClosedRange<Date> {
        if selectedRange == .today {
            let calendar = Calendar.current
            let now = Date()
            let dayStart = calendar.startOfDay(for: now)
            let sixAM = calendar.date(byAdding: .hour, value: 6, to: dayStart) ?? dayStart
            let start = now >= sixAM ? sixAM : dayStart
            let end = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now)) ?? now
            return start...end
        }
        let sorted = points.map(\.date).sorted()
        let start = sorted.first ?? Date()
        let end = sorted.last ?? Date()
        return start...end
    }

    private func yDomain(for points: [DayPoint], metric: ChartMetric) -> ClosedRange<Double> {
        let maxValue = points.map { Double(metric.value(from: $0)) }.max() ?? 1
        let upper = max(2, maxValue + 1)
        return -0.5...upper
    }
}

private struct FullScreenHistoryChartView: View {
    @Environment(\.dismiss) private var dismiss
    let points: [DayPoint]
    let title: String
    let config: HistoryChartConfig
    let selectedRange: HistoryRange

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let availableWidth = max(200, proxy.size.width - 24)
                let chartHeight = max(180, proxy.size.height - 32)
                let contentWidth = max(availableWidth, CGFloat(points.count) * 28)
                let safeWidth = contentWidth.isFinite && contentWidth > 0 ? contentWidth : availableWidth
                let safeHeight = chartHeight.isFinite && chartHeight > 0 ? chartHeight : 220.0

                VStack(alignment: .leading, spacing: 16) {
                    fullScreenSingleMetricChart(points: points, safeWidth: safeWidth, safeHeight: safeHeight, metric: .smoked)
                    fullScreenSingleMetricChart(points: points, safeWidth: safeWidth, safeHeight: safeHeight, metric: .resisted)
                }
                .padding(12)
                .navigationTitle("Grafico \(title)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Chiudi") { dismiss() }
                    }
                }
            }
        }
    }

    private func xDomain(for points: [DayPoint]) -> ClosedRange<Date> {
        if selectedRange == .today {
            let calendar = Calendar.current
            let now = Date()
            let dayStart = calendar.startOfDay(for: now)
            let sixAM = calendar.date(byAdding: .hour, value: 6, to: dayStart) ?? dayStart
            let start = now >= sixAM ? sixAM : dayStart
            let end = calendar.date(from: calendar.dateComponents([.year, .month, .day, .hour], from: now)) ?? now
            return start...end
        }
        let sorted = points.map(\.date).sorted()
        let start = sorted.first ?? Date()
        let end = sorted.last ?? Date()
        return start...end
    }

    private func yDomain(for points: [DayPoint], metric: ChartMetric) -> ClosedRange<Double> {
        let maxValue = points.map { Double(metric.value(from: $0)) }.max() ?? 1
        let upper = max(2, maxValue + 1)
        return -0.5...upper
    }

    private func fullScreenSingleMetricChart(points: [DayPoint], safeWidth: CGFloat, safeHeight: CGFloat, metric: ChartMetric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(metric.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(metric.color)

            ScrollView(.horizontal, showsIndicators: true) {
                Chart(points) { point in
                    if config.style == .line {
                        LineMark(
                            x: .value("Periodo", point.date),
                            y: .value(metric.title, metric.value(from: point))
                        )
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(metric.color)
                        .symbol(.circle)
                    } else {
                        BarMark(
                            x: .value("Periodo", point.date),
                            y: .value(metric.title, metric.value(from: point))
                        )
                        .foregroundStyle(metric.color)
                    }
                }
                .frame(width: safeWidth, height: max(180, safeHeight * 0.45))
                .chartXScale(domain: xDomain(for: points))
                .chartYScale(domain: yDomain(for: points, metric: metric))
                .chartPlotStyle { plot in
                    plot.frame(maxWidth: .infinity, alignment: .leading)
                }
                .chartXAxis {
                    if config.aggregation == .daily && selectedRange == .today {
                        AxisMarks(values: .stride(by: .hour, count: 2)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
                        }
                    } else if config.aggregation == .daily {
                        AxisMarks(values: .stride(by: .day)) { value in
                            if let date = value.as(Date.self), Calendar.current.component(.weekday, from: date) == 2 {
                                AxisGridLine()
                                AxisTick()
                                AxisValueLabel(format: .dateTime.day().month())
                            }
                        }
                    } else if config.aggregation == .weekly {
                        AxisMarks(values: .stride(by: .weekOfYear)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.day().month())
                        }
                    } else {
                        AxisMarks(values: .stride(by: .month)) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
            }
        }
    }
}
