import SwiftUI

// MARK: Agenda

/// Day by day, only the days with something on (and today), month after month as you scroll.
struct CalendarAgenda: View {
    var months: [String]
    var selected: Date
    var loaded: Bool
    var items: (Date) -> [CalendarItem]
    var busy: String?
    var toggle: (CalendarItem) -> Void
    var showEvent: (CalendarItem) -> Void
    var more: () -> Void

    /// The day last scrolled to, so loading more months never jumps back.
    @State private var scrolled: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(months, id: \.self) { key in
                        Section {
                            let days = days(in: key)
                            if days.isEmpty {
                                Text("Nada este mes.")
                                    .font(.subheadline)
                                    .foregroundStyle(CarliColor.text3)
                                    .padding(.horizontal, CarliSpace.s16)
                                    .padding(.vertical, CarliSpace.s12)
                            }
                            ForEach(days, id: \.self) { day in
                                AgendaDay(day: day, items: items(day), busy: busy, toggle: toggle, showEvent: showEvent)
                                    .id(CarliDate.isoDay(day))
                            }
                        } header: {
                            Text(monthTitle(key))
                                .font(.headline)
                                .foregroundStyle(CarliColor.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, CarliSpace.s16)
                                .padding(.vertical, CarliSpace.s8)
                                .background(CarliColor.bg)
                        }
                    }
                    if loaded {
                        Color.clear.frame(height: 1).onAppear(perform: more)
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(CarliSpace.s24)
                    }
                }
                .padding(.bottom, CarliSpace.s32)
            }
            .task(id: "\(CarliDate.isoDay(selected))-\(loaded)") {
                let key = CarliDate.isoDay(selected)
                guard loaded, scrolled != key, let target = target else { return }
                scrolled = key
                proxy.scrollTo(CarliDate.isoDay(target), anchor: .top)
            }
        }
    }

    /// Days of a month worth a row: those with items, plus today so "now" is always findable.
    private func days(in key: String) -> [Date] {
        guard let bounds = CalendarLayout.bounds(ofMonth: key) else { return [] }
        var days: [Date] = []
        var day = bounds.from
        while day <= bounds.to {
            if CarliDate.calendar.isDateInToday(day) || !items(day).isEmpty { days.append(day) }
            day = CalendarLayout.add(days: 1, to: day)
        }
        return days
    }

    /// The first shown day on or after the selected one.
    private var target: Date? {
        months.lazy.flatMap { days(in: $0) }.first { $0 >= CalendarLayout.startOfDay(selected) }
    }

    private func monthTitle(_ key: String) -> String {
        guard let first = CalendarLayout.bounds(ofMonth: key)?.from else { return key }
        return CalendarLayout.title(.month, selected: first)
    }
}

private struct AgendaDay: View {
    var day: Date
    var items: [CalendarItem]
    var busy: String?
    var toggle: (CalendarItem) -> Void
    var showEvent: (CalendarItem) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: CarliSpace.s12) {
            DayBadge(day: day, large: true)
                .frame(width: 44)
            VStack(spacing: 6) {
                if items.isEmpty {
                    Text("Nada para hoy.")
                        .font(.subheadline)
                        .foregroundStyle(CarliColor.text3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, CarliSpace.s8)
                }
                ForEach(items, id: \.key) { item in
                    HStack(spacing: 6) {
                        if item.kind == .tasks {
                            Button { toggle(item) } label: {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(item.done ? CarliColor.primary : CarliColor.text3)
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.plain)
                            .disabled(busy == item.id)
                            .accessibilityLabel(item.done ? "Marcar \(item.title) como pendiente" : "Marcar \(item.title) como hecha")
                            .sensoryFeedback(.success, trigger: item.done)
                        }
                        CalendarItemLink(item: item, showEvent: showEvent) {
                            AgendaChip(item: item)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, CarliSpace.s16)
        .padding(.vertical, CarliSpace.s8)
    }
}

/// One item in the agenda: a filled card in its Google calendar's colour, or a plain card
/// with its module's symbol for carli items.
private struct AgendaChip: View {
    var item: CalendarItem

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CarliSpace.s8) {
            if item.kind != .google && item.kind != .tasks {
                Image(systemName: item.kind?.symbol ?? "circle").font(.footnote)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .strikethrough(item.done && item.kind == .tasks)
                    .lineLimit(2)
                let detail = [item.allDay ? nil : item.timeRange, item.subtitle].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !detail.isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .monospacedDigit()
                        .lineLimit(1)
                        .opacity(0.85)
                }
            }
            Spacer(minLength: 0)
            if item.meta?.important == true, !item.done {
                Image(systemName: "star.fill").font(.caption).accessibilityLabel("Importante")
            }
        }
        .foregroundStyle(ItemStyle.foreground(item))
        .padding(.horizontal, CarliSpace.s12)
        .padding(.vertical, CarliSpace.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ItemStyle.background(item), in: .rect(cornerRadius: CarliRadius.control))
        .overlay {
            if item.kind != .google {
                RoundedRectangle(cornerRadius: CarliRadius.control).stroke(CarliColor.border)
            }
        }
        .opacity(ItemStyle.faded(item) ? 0.55 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Colours shared by every mode: Google events take their calendar's colour with white text;
/// carli items stay in ink on a plain surface, as the app uses no accent colour.
enum ItemStyle {
    static func background(_ item: CalendarItem) -> Color {
        item.kind == .google ? (item.tint ?? CarliColor.neutralFill) : CarliColor.surface
    }

    static func foreground(_ item: CalendarItem) -> Color {
        item.kind == .google ? .white : CarliColor.text
    }

    static func faded(_ item: CalendarItem) -> Bool {
        item.done || item.kind == .templates
    }
}

/// Weekday and day number; today's number sits in an ink circle.
struct DayBadge: View {
    var day: Date
    var large = false

    var body: some View {
        let today = CarliDate.calendar.isDateInToday(day)
        VStack(spacing: 2) {
            Text(CarliDate.weekdays[CarliDate.calendar.component(.weekday, from: day) - 1].prefix(3))
                .font(.caption2.weight(.medium))
                .textCase(.uppercase)
                .foregroundStyle(today ? CarliColor.text : CarliColor.text2)
            Text("\(CarliDate.calendar.component(.day, from: day))")
                .font(large ? .title3.weight(.semibold) : .subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(today ? CarliColor.onPrimary : CarliColor.text)
                .frame(width: large ? 36 : 28, height: large ? 36 : 28)
                .background(today ? CarliColor.primary : .clear, in: .circle)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(CarliDate.long(day))\(today ? ", hoy" : "")")
    }
}

// MARK: Day, 3 days, week

/// The hour grid: day headers, a row of all-day items, then 24 hours where timed items sit
/// at their time, side by side when they overlap.
struct CalendarTimeline: View {
    var days: [Date]
    var items: (Date) -> [CalendarItem]
    /// The hour the last page was scrolled to; nil until the first page settles.
    var topHour: Int?
    /// Only the page on screen reports its scroll, so the pages beside it follow it.
    var isCurrent: Bool
    var scrolledTo: (Int) -> Void
    var pickDay: (Date) -> Void
    var showEvent: (CalendarItem) -> Void

    private let gutter: CGFloat = 46
    private var compact: Bool { days.count > 3 }
    private var hourHeight: CGFloat { compact ? 46 : 58 }

    var body: some View {
        VStack(spacing: 0) {
            header
            allDayRow
            Rectangle().fill(CarliColor.border).frame(height: 0.5)
            ScrollViewReader { proxy in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        hours
                        HStack(spacing: 0) {
                            Color.clear.frame(width: gutter)
                            ForEach(days, id: \.self) { day in
                                column(day)
                            }
                        }
                    }
                    .frame(height: hourHeight * 24)
                    .padding(.top, CarliSpace.s8)
                    .padding(.bottom, CarliSpace.s32)
                }
                .calendarVerticalScroll()
                .onAppear { proxy.scrollTo(topHour ?? firstHour, anchor: .top) }
                .onChange(of: topHour) {
                    if !isCurrent, let topHour { proxy.scrollTo(topHour, anchor: .top) }
                }
                .onScrollGeometryChange(for: Int.self) { geo in
                    min(max(Int(((geo.contentOffset.y + geo.contentInsets.top) / hourHeight).rounded()), 0), 23)
                } action: { _, hour in
                    if isCurrent { scrolledTo(hour) }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: gutter, height: 1)
            ForEach(days, id: \.self) { day in
                Button { pickDay(day) } label: {
                    DayBadge(day: day, large: !compact)
                        .frame(maxWidth: .infinity)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(days.count == 1)
            }
        }
        .padding(.bottom, CarliSpace.s4)
    }

    /// All-day items per day; on narrow columns only the first two and a "+N" that opens the day.
    @ViewBuilder
    private var allDayRow: some View {
        let perDay = days.map { day in items(day).filter(\.allDay) }
        if perDay.contains(where: { !$0.isEmpty }) {
            let limit = days.count == 1 ? Int.max : 2
            HStack(alignment: .top, spacing: 0) {
                Text("Todo el día")
                    .font(.system(size: 9))
                    .foregroundStyle(CarliColor.text3)
                    .multilineTextAlignment(.trailing)
                    .frame(width: gutter - 6, alignment: .trailing)
                    .padding(.trailing, 6)
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    let list = perDay[index]
                    VStack(spacing: 2) {
                        ForEach(list.prefix(limit), id: \.key) { item in
                            CalendarItemLink(item: item, showEvent: showEvent) {
                                EventBlock(item: item, compact: compact, showTime: false)
                                    .frame(height: compact ? 18 : 22)
                            }
                        }
                        if list.count > limit {
                            Button("+\(list.count - limit)") { pickDay(day) }
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(CarliColor.text2)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.vertical, CarliSpace.s4)
        }
    }

    private var hours: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                HStack(alignment: .top, spacing: 6) {
                    Text(hour == 0 ? "" : String(format: "%02d:00", hour))
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundStyle(CarliColor.text3)
                        .frame(width: gutter - 6, alignment: .trailing)
                        .offset(y: -6)
                    Rectangle().fill(CarliColor.border).frame(height: 0.5)
                }
                .frame(height: hourHeight, alignment: .top)
                .id(hour)
            }
        }
    }

    private func column(_ day: Date) -> some View {
        let placed = CalendarLayout.place(items(day))
        return GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .topLeading) {
                Rectangle().fill(CarliColor.border).frame(width: 0.5).frame(maxHeight: .infinity)
                ForEach(placed, id: \.item.key) { p in
                    let laneWidth = width / CGFloat(p.lanes)
                    let length = max(p.end - p.start, CalendarLayout.defaultLength)
                    let height = max(CGFloat(length) / 60 * hourHeight - 2, 18)
                    CalendarItemLink(item: p.item, showEvent: showEvent) {
                        EventBlock(item: p.item, compact: compact, showTime: height >= 34)
                    }
                    .frame(width: max(laneWidth - 2, 8), height: height)
                    .offset(x: CGFloat(p.lane) * laneWidth + 1, y: CGFloat(p.start) / 60 * hourHeight + 1)
                }
                if CarliDate.calendar.isDateInToday(day) {
                    NowLine(hourHeight: hourHeight)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Opens on the current hour today, otherwise just before the first event or at 07:00.
    private var firstHour: Int {
        if days.contains(where: CarliDate.calendar.isDateInToday) {
            return max(CarliDate.calendar.component(.hour, from: .now) - 1, 0)
        }
        let earliest = days.flatMap(items).compactMap { $0.allDay ? nil : CalendarLayout.minutes($0.time) }.min()
        return min((earliest ?? 7 * 60) / 60, 7)
    }
}

private struct NowLine: View {
    var hourHeight: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let c = CarliDate.calendar.dateComponents([.hour, .minute], from: context.date)
            let y = CGFloat((c.hour ?? 0) * 60 + (c.minute ?? 0)) / 60 * hourHeight
            HStack(spacing: 0) {
                Circle().fill(CarliColor.primary).frame(width: 8, height: 8)
                Rectangle().fill(CarliColor.primary).frame(height: 1.5)
            }
            .offset(x: -4, y: y - 4)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

/// An item drawn on the grid or in the month: a small block in its colour.
struct EventBlock: View {
    var item: CalendarItem
    var compact: Bool
    var showTime: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                if item.kind != .google {
                    Image(systemName: item.kind == .tasks ? (item.done ? "checkmark.circle.fill" : "circle") : (item.kind?.symbol ?? "circle"))
                        .font(.system(size: compact ? 8 : 10))
                }
                Text(item.title)
                    .lineLimit(compact ? 4 : 3)
                    .strikethrough(item.done && item.kind == .tasks)
            }
            .font(.system(size: compact ? 10 : 12, weight: .semibold))
            if showTime, let range = item.timeRange {
                Text(range)
                    .font(.system(size: compact ? 9 : 11).monospacedDigit())
                    .lineLimit(1)
                    .opacity(0.85)
            }
        }
        .foregroundStyle(ItemStyle.foreground(item))
        .padding(.horizontal, compact ? 3 : 6)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ItemStyle.background(item), in: .rect(cornerRadius: 5))
        .overlay {
            if item.kind != .google {
                RoundedRectangle(cornerRadius: 5).stroke(CarliColor.border)
            }
        }
        .clipShape(.rect(cornerRadius: 5))
        .opacity(ItemStyle.faded(item) ? 0.55 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([item.title, item.timeRange ?? "todo el día"].joined(separator: ", "))
    }
}

// MARK: Month

/// Whole weeks covering the month; each day lists what fits and "+N" for the rest. Tapping a day opens it.
struct CalendarMonthGrid: View {
    var month: Date
    var days: [Date]
    var items: (Date) -> [CalendarItem]
    var pickDay: (Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(TaskDates.weekdaysMondayFirst, id: \.self) { letter in
                    Text(letter)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(CarliColor.text3)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, CarliSpace.s4)
            GeometryReader { geo in
                let rows = max(days.count / 7, 1)
                let rowHeight = max(geo.size.height / CGFloat(rows), 72)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(0..<rows, id: \.self) { row in
                            HStack(spacing: 0) {
                                ForEach(days[(row * 7)..<min(row * 7 + 7, days.count)], id: \.self) { day in
                                    cell(day, height: rowHeight)
                                }
                            }
                        }
                    }
                }
                .calendarVerticalScroll()
                .scrollDisabled(rowHeight * CGFloat(rows) <= geo.size.height + 1)
            }
        }
        .padding(.horizontal, CarliSpace.s4)
    }

    private func cell(_ day: Date, height: CGFloat) -> some View {
        let list = items(day)
        let room = max(Int((height - 28) / 15), 0)
        let shown = list.count > room ? max(room - 1, 0) : list.count
        let inMonth = CarliDate.calendar.isDate(day, equalTo: month, toGranularity: .month)
        let today = CarliDate.calendar.isDateInToday(day)
        return Button { pickDay(day) } label: {
            VStack(spacing: 2) {
                Text("\(CarliDate.calendar.component(.day, from: day))")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(today ? CarliColor.onPrimary : CarliColor.text)
                    .frame(width: 22, height: 22)
                    .background(today ? CarliColor.primary : .clear, in: .circle)
                ForEach(list.prefix(shown), id: \.key) { item in
                    Text(item.title)
                        .font(.system(size: 9.5, weight: .medium))
                        .lineLimit(1)
                        .strikethrough(item.done && item.kind == .tasks)
                        .foregroundStyle(ItemStyle.foreground(item))
                        .padding(.horizontal, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ItemStyle.background(item), in: .rect(cornerRadius: 3))
                        .overlay {
                            if item.kind != .google { RoundedRectangle(cornerRadius: 3).stroke(CarliColor.border, lineWidth: 0.5) }
                        }
                        .opacity(ItemStyle.faded(item) ? 0.55 : 1)
                }
                if list.count > shown {
                    Text("+\(list.count - shown)")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(CarliColor.text2)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, 3)
            .padding(.horizontal, 1)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay(alignment: .top) { Rectangle().fill(CarliColor.border).frame(height: 0.5) }
            .opacity(inMonth ? 1 : 0.4)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(CarliDate.long(day))\(today ? ", hoy" : ""), \(list.count == 0 ? "nada" : "\(list.count) elementos")")
    }
}

// MARK: Year

/// Twelve small months; tapping one opens it.
struct CalendarYearGrid: View {
    var year: Date
    var pickMonth: (Date) -> Void

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CarliSpace.s16), count: 3), spacing: CarliSpace.s24) {
                ForEach(0..<12, id: \.self) { offset in
                    let first = CarliDate.calendar.date(byAdding: .month, value: offset, to: year) ?? year
                    Button { pickMonth(first) } label: { MiniMonth(first: first) }
                        .buttonStyle(.plain)
                }
            }
            .padding(CarliSpace.s16)
        }
        .calendarVerticalScroll()
    }
}

private struct MiniMonth: View {
    var first: Date

    var body: some View {
        let current = CarliDate.calendar.isDate(first, equalTo: .now, toGranularity: .month)
        let lead = FrequencyDraft.isoWeekday(first) - 1
        let count = CarliDate.calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        VStack(alignment: .leading, spacing: CarliSpace.s4) {
            Text(CarliDate.months[CarliDate.calendar.component(.month, from: first) - 1].capitalizedFirst)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(current ? CarliColor.text : CarliColor.text2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 3) {
                ForEach(0..<(lead + count), id: \.self) { index in
                    if index < lead {
                        Color.clear.frame(height: 14)
                    } else {
                        let day = CalendarLayout.add(days: index - lead, to: first)
                        let today = CarliDate.calendar.isDateInToday(day)
                        Text("\(index - lead + 1)")
                            .font(.system(size: 9, weight: today ? .bold : .regular).monospacedDigit())
                            .foregroundStyle(today ? CarliColor.onPrimary : CarliColor.text)
                            .frame(width: 15, height: 15)
                            .background(today ? CarliColor.primary : .clear, in: .circle)
                    }
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(CalendarLayout.title(.month, selected: first))
    }
}
