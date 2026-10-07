import SwiftUI

struct ArchiveView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedMonth: Int?

    var body: some View {
        let archive = model.archive
        let month = archive.months.first { $0.month == selectedMonth } ?? archive.months.last!
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(kicker: "Bound volumes", title: "The Archive")
                Text("Volume \(Roman.numeral(archive.volume)), \(Roman.numeral(month.year)) · \(EditionFormat.spelled(archive.editionCount)) editions")
                    .typeStyle(.text(14, italic: true, relativeTo: .subheadline))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 6)

                Bookshelf(months: archive.months, selected: month.month) { picked in
                    withAnimation(.easeOut(duration: 0.25)) { selectedMonth = picked }
                }
                .padding(.top, 20)

                HStack(alignment: .firstTextBaseline) {
                    Text("\(EditionFormat.month(month.firstDay)) \(Roman.numeral(month.year))")
                        .typeStyle(.display(24, italic: true, relativeTo: .title2))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(month.entries.count) \(month.entries.count == 1 ? "edition" : "editions")")
                        .typeStyle(.text(12.5, italic: true, relativeTo: .caption))
                        .foregroundStyle(Theme.inkMuted)
                }
                .padding(.top, 26)

                DoubleRule()
                    .padding(.top, 8)
                Ledger(entries: month.entries.reversed()) { model.showToday() }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .paperScreen()
        .sensoryFeedback(.selection, trigger: selectedMonth)
    }
}

// MARK: - Shelf

/// A wooden shelf of leather-bound months. The chosen month is pulled up 14 pt.
private struct Bookshelf: View {
    let months: [ArchiveMonth]
    let selected: Int
    let pick: (Int) -> Void

    private static let heights: [CGFloat] = [150, 142, 154, 146, 150, 140, 152, 148, 144, 156, 150, 146]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(months.enumerated()), id: \.element.id) { index, month in
                    if index > 0 { Spacer(minLength: 2) }
                    Spine(
                        title: EditionFormat.monthAbbreviation(month.firstDay),
                        numeral: Roman.numeral(month.month),
                        leather: Theme.Leather.all[index % Theme.Leather.all.count],
                        height: Self.heights[index % Self.heights.count],
                        isSelected: month.month == selected
                    )
                    .onTapGesture { pick(month.month) }
                    .accessibilityElement()
                    .accessibilityLabel(EditionFormat.month(month.firstDay))
                    .accessibilityAddTraits(month.month == selected ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { pick(month.month) }
                }
            }
            .frame(height: 166, alignment: .bottom)
            .padding(.horizontal, 12)
            .padding(.top, 26)

            Rectangle()
                .fill(LinearGradient(colors: [Theme.Wood.ledgeTop, Theme.Wood.ledgeBottom], startPoint: .top, endPoint: .bottom))
                .frame(height: 9)
                .overlay(alignment: .top) {
                    Rectangle().fill(Color(hex: 0xD6B776, opacity: 0.6)).frame(height: 1)
                }
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 3, bottomTrailingRadius: 3))
        }
        .background {
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(colors: [Theme.Wood.panelTop, Theme.Wood.panelBottom], startPoint: .top, endPoint: .bottom)
                        .shadow(.inner(color: .black.opacity(0.5), radius: 5, y: 3))
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color(hex: 0xC4A262, opacity: 0.4), lineWidth: 0.5)
        }
    }
}

private struct Spine: View {
    let title: String
    let numeral: String
    let leather: Color
    let height: CGFloat
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            GiltBand()
            Spacer(minLength: 0)
            Text(title)
                .typeStyle(.display(10.5, tracking: 0.24, relativeTo: nil))
                .textCase(.uppercase)
                .foregroundStyle(Theme.gilt)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 27, height: 40)
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                Text(numeral)
                    .typeStyle(.display(9, relativeTo: nil))
                    .foregroundStyle(Theme.gilt)
                    .fixedSize()
                GiltBand()
            }
        }
        .padding(.top, 9)
        .padding(.bottom, 8)
        .frame(width: 27, height: height)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 1.5, topTrailingRadius: 1.5)
                .fill(
                    leather
                        .shadow(.inner(color: .white.opacity(0.08), radius: 0, x: 2))
                        .shadow(.inner(color: .black.opacity(0.35), radius: 2.5, x: -4))
                )
        }
        .overlay {
            if isSelected {
                UnevenRoundedRectangle(topLeadingRadius: 1.5, topTrailingRadius: 1.5)
                    .stroke(Theme.gilt, lineWidth: 1)
            }
        }
        .shadow(color: .black.opacity(isSelected ? 0.6 : 0), radius: 6, y: 8)
        .offset(y: isSelected ? -14 : 0)
        .contentShape(Rectangle())
    }
}

/// Two gilt lines tooled across a spine.
private struct GiltBand: View {
    var body: some View {
        VStack(spacing: 2) {
            Rectangle().frame(height: 1)
            Rectangle().frame(height: 1)
        }
        .foregroundStyle(Theme.giltRule)
        .opacity(0.8)
    }
}

// MARK: - Ledger

/// The month's editions in a ruled ledger with a burgundy double margin.
private struct Ledger: View {
    let entries: [ArchiveEntry]
    let openCurrent: () -> Void
    var columns = LedgerColumns()

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("No.")
                    .padding(.vertical, 8)
                    .frame(width: columns.number, alignment: .leading)
                    .overlay(alignment: .trailing) { LedgerMargin() }
                Text("Date")
                    .padding(.leading, 10)
                    .frame(width: columns.date, alignment: .leading)
                Text("The Big Story")
                    .padding(.leading, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Min")
                    .frame(width: columns.minutes, alignment: .trailing)
            }
            .typeStyle(.label(8.5, tracking: 0.2))
            .foregroundStyle(Theme.inkMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .overlay(alignment: .bottom) { Hairline(color: Theme.ruleStrong) }
            .accessibilityHidden(true)

            ForEach(entries) { entry in
                if entry.isCurrent {
                    Button(action: openCurrent) { LedgerRow(entry: entry) }
                        .buttonStyle(PressedRowStyle())
                        .accessibilityHint("Returns to today’s edition")
                } else {
                    LedgerRow(entry: entry)
                }
            }
        }
    }
}

private struct LedgerRow: View {
    let entry: ArchiveEntry
    var columns = LedgerColumns()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(Roman.numeral(entry.number))
                .typeStyle(.display(12, tracking: 0.04, relativeTo: .caption))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.vertical, 13)
                .frame(width: columns.number, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .top)
                .overlay(alignment: .trailing) { LedgerMargin() }
            VStack(alignment: .leading, spacing: 2) {
                Text(EditionFormat.weekdayAbbreviation(entry.date))
                    .typeStyle(.label(8.5, tracking: 0.18))
                    .foregroundStyle(Theme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("\(EditionCalendar.calendar.component(.day, from: entry.date))")
                    .typeStyle(.display(20, lineHeight: 1, relativeTo: .title3))
                    .foregroundStyle(Theme.ink)
            }
            .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 0))
            .frame(width: columns.date, alignment: .leading)
            Text(entry.headline)
                .typeStyle(.text(14.5, lineHeight: 1.32, relativeTo: .subheadline))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .padding(EdgeInsets(top: 11, leading: 4, bottom: 11, trailing: 6))
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(entry.readMinutes)")
                .typeStyle(TypeStyle(face: .newsreader, size: 12.5, tabularFigures: true, relativeTo: .caption))
                .foregroundStyle(Theme.inkMuted)
                .padding(.vertical, 13)
                .frame(width: columns.minutes, alignment: .trailing)
        }
        .fixedSize(horizontal: false, vertical: true)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) { Hairline() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Number \(entry.number), \(EditionFormat.storyDate(entry.date)). \(entry.headline). \(entry.readMinutes) minutes.")
    }
}

/// Ledger column widths (72 · 50 · flexible · 26 at the default text size). They grow with
/// Dynamic Type, but only so far, so the headline column keeps most of the width.
private struct LedgerColumns: DynamicProperty {
    @ScaledMetric(relativeTo: .caption) private var scaledNumber: CGFloat = 72
    @ScaledMetric(relativeTo: .caption2) private var scaledDate: CGFloat = 50
    @ScaledMetric(relativeTo: .caption) private var scaledMinutes: CGFloat = 26

    var number: CGFloat { min(scaledNumber, 88) }
    var date: CGFloat { min(scaledDate, 64) }
    var minutes: CGFloat { min(scaledMinutes, 34) }
}

/// 3 pt burgundy double rule down the ledger's number column.
private struct LedgerMargin: View {
    var body: some View {
        HStack(spacing: 1) {
            Rectangle().frame(width: 1)
            Rectangle().frame(width: 1)
        }
        .foregroundStyle(Theme.burgundy)
    }
}
