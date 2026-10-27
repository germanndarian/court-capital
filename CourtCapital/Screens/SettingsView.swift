import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.morningNotification) private var notificationsOn = false
    @AppStorage(Preferences.deliveryMinutes) private var deliveryMinutes = Preferences.defaultDeliveryMinutes
    @AppStorage(Preferences.appearance) private var appearance = Appearance.automatic
    @AppStorage(Preferences.pausedThrough) private var pausedThrough = ""
    @State private var choosingTime = false
    @State private var choosingPause = false
    @State private var showDeniedAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeading(kicker: "Preferences", title: "Settings")

                SettingsSectionHeader(numeral: "I", title: "Morning edition")
                    .padding(.top, 30)
                Toggle(isOn: notificationBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Morning notification")
                            .typeStyle(.text(17, weight: 500, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                        Text("Weekdays, when the edition is ready")
                            .typeStyle(.text(13.5, italic: true, lineHeight: 1.35, relativeTo: .footnote))
                            .foregroundStyle(Theme.inkMuted)
                    }
                }
                .toggleStyle(BrassToggleStyle())
                .padding(.vertical, 16)
                .overlay(alignment: .bottom) { Hairline() }

                Button {
                    choosingTime = true
                } label: {
                    HStack(spacing: 16) {
                        Text("Delivery time")
                            .typeStyle(.text(17, weight: 500, relativeTo: .body))
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(EditionFormat.time(minutesAfterMidnight: deliveryMinutes))
                            .typeStyle(.text(16, relativeTo: .body))
                            .foregroundStyle(Theme.inkMuted)
                        Chevron()
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!notificationsOn)
                .opacity(notificationsOn ? 1 : 0.4)
                .animation(.easeOut(duration: 0.2), value: notificationsOn)
                .overlay(alignment: .bottom) { Hairline() }

                Button {
                    choosingPause = true
                } label: {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Take a break")
                                .typeStyle(.text(17, weight: 500, relativeTo: .body))
                                .foregroundStyle(Theme.ink)
                            Text("No edition for a few days")
                                .typeStyle(.text(13.5, italic: true, lineHeight: 1.35, relativeTo: .footnote))
                                .foregroundStyle(Theme.inkMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Text(pauseSummary)
                            .typeStyle(.text(16, relativeTo: .body))
                            .foregroundStyle(isPaused ? Theme.brassText : Theme.inkMuted)
                        Chevron()
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .bottom) { Hairline() }
                .accessibilityValue(pauseSummary)

                SettingsSectionHeader(numeral: "II", title: "Appearance")
                    .padding(.top, 34)
                HStack(spacing: 12) {
                    ForEach(Appearance.allCases) { option in
                        AppearanceSwatch(appearance: option, isSelected: option == appearance) {
                            appearance = option
                        }
                    }
                }
                .padding(.top, 16)
                Text(appearance.note)
                    .typeStyle(.text(13, italic: true, lineHeight: 1.4, relativeTo: .footnote))
                    .foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)

                SettingsFooter()
                    .padding(.top, 48)
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .paperScreen()
        .sensoryFeedback(.selection, trigger: appearance)
        .sheet(isPresented: $choosingTime) {
            DeliveryTimeSheet(minutes: $deliveryMinutes)
                .presentationDetents([.height(320)])
        }
        .sheet(isPresented: $choosingPause) {
            PauseSheet(pausedThrough: $pausedThrough)
                .presentationDetents([.height(380)])
        }
        .onChange(of: deliveryMinutes) { _, _ in
            Task { await MorningNotification.refresh() }
        }
        .onChange(of: pausedThrough) { _, _ in
            Task { await MorningNotification.refresh() }
        }
        .alert("Notifications are off", isPresented: $showDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications for Court & Capital in the Settings app to get the morning edition.")
        }
    }

    private var isPaused: Bool { EditionPause.isPaused(through: pausedThrough) }

    /// "Off", or "Until 30 Oct" (the last day of the break)
    private var pauseSummary: String {
        guard isPaused, let last = EditionCalendar.date(from: pausedThrough) else { return "Off" }
        return "Until \(EditionFormat.short(last).split(separator: " ").dropFirst().joined(separator: " "))"
    }

    /// Turning the notification on asks for permission first and stays off if it is refused.
    private var notificationBinding: Binding<Bool> {
        Binding {
            notificationsOn
        } set: { isOn in
            guard isOn else {
                notificationsOn = false
                Task { await MorningNotification.cancel() }
                return
            }
            notificationsOn = true
            Task {
                if await MorningNotification.requestPermission() {
                    await MorningNotification.refresh()
                } else {
                    notificationsOn = false
                    showDeniedAlert = true
                }
            }
        }
    }
}

private struct SettingsSectionHeader: View {
    let numeral: String
    let title: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(numeral).")
                    .typeStyle(.display(20, italic: true, relativeTo: .title3))
                    .foregroundStyle(Theme.brassText)
                Text(title)
                    .typeStyle(.label(10))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 8)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Hairline(color: Theme.ruleStrong, thickness: 1.5)
        }
    }
}

/// Track tinted green by day and brass by night; cream knob with a brass ring.
struct BrassToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 16) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? Theme.toggleOn : Theme.paperInset)
                    .overlay(Capsule().strokeBorder(Theme.ruleStrong, lineWidth: 0.5))
                Circle()
                    .fill(Theme.knob)
                    .overlay(Circle().stroke(Theme.brass, lineWidth: 1).padding(-0.5))
                    .shadow(color: .black.opacity(0.25), radius: 2, y: 2)
                    .frame(width: 27, height: 27)
                    .padding(2)
            }
            .frame(width: 51, height: 31)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) { configuration.isOn.toggle() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
        .sensoryFeedback(.selection, trigger: configuration.isOn)
    }
}

private struct AppearanceSwatch: View {
    let appearance: Appearance
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 9) {
                swatch
                    .overlay(Rectangle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5))
                    .padding(4)
                    .frame(height: 92)
                    .frame(maxWidth: .infinity)
                    .overlay {
                        DoubleRectangle(width: 3)
                            .foregroundStyle(isSelected ? Theme.brass : .clear)
                    }
                Text(appearance.title)
                    .typeStyle(.label(9.5, tracking: 0.2))
                    .foregroundStyle(isSelected ? Theme.ink : Theme.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(appearance.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder private var swatch: some View {
        let sample = Text("Aa").typeStyle(.display(26, relativeTo: nil))
        switch appearance {
        case .day:
            Color(hex: 0xF4EEE1).overlay(sample.foregroundStyle(Color(hex: 0x16202F)))
        case .night:
            Color(hex: 0x0E1B15).overlay(sample.foregroundStyle(Color(hex: 0xECE3CD)))
        case .automatic:
            DiagonalSplit(first: Color(hex: 0xF4EEE1), second: Color(hex: 0x0E1B15))
                .overlay(sample.foregroundStyle(Color(hex: 0xA27D3A)))
        }
    }
}

/// `linear-gradient(135deg, first 50%, second 50%)`: split along a 45° line through the centre.
private struct DiagonalSplit: View {
    let first: Color
    let second: Color

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(second))
            let reach = size.width / 2 + size.height / 2
            var path = Path()
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: reach, y: 0))
            path.addLine(to: CGPoint(x: 0, y: reach))
            path.closeSubpath()
            context.fill(path, with: .color(first))
        }
    }
}

/// A CSS `double` border on a rectangle.
private struct DoubleRectangle: View {
    let width: CGFloat

    var body: some View {
        let line = width / 3
        ZStack {
            Rectangle().inset(by: line / 2).stroke(lineWidth: line)
            Rectangle().inset(by: width - line / 2).stroke(lineWidth: line)
        }
    }
}

private struct SettingsFooter: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 8) {
            Crest(diameter: 46, monogram: 14)
            Wordmark(style: .display(17, relativeTo: .headline), brassAmpersand: false)
            Text("Version \(version) · Est. \(Roman.numeral(2026))")
                .typeStyle(.label(9, tracking: 0.2))
                .foregroundStyle(Theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct DeliveryTimeSheet: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    private var date: Binding<Date> {
        Binding {
            EditionCalendar.calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
        } set: { newValue in
            let parts = EditionCalendar.calendar.dateComponents([.hour, .minute], from: newValue)
            minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Delivery time")
                    .typeStyle(.label(10))
                    .foregroundStyle(Theme.brassText)
                Spacer()
                Button("Done") { dismiss() }
                    .typeStyle(.label(10))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            DatePicker("Delivery time", selection: date, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding(.top, 8)
            Spacer(minLength: 0)
        }
        .presentationBackground { PaperBackground() }
    }
}

/// Choose how many days to go without the edition. The app stays quiet until then: no
/// morning notification and no "running late" note.
private struct PauseSheet: View {
    @Binding var pausedThrough: String
    @State private var days = 7
    @Environment(\.dismiss) private var dismiss

    private var isPaused: Bool { EditionPause.isPaused(through: pausedThrough) }
    private var resume: Date? { EditionPause.resumeDay(after: EditionPause.lastDay(forDays: days)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Take a break")
                    .typeStyle(.label(10))
                    .foregroundStyle(Theme.brassText)
                Spacer()
                Button("Close") { dismiss() }
                    .typeStyle(.label(10))
                    .foregroundStyle(Theme.ink)
            }
            .padding(.top, 20)

            if isPaused, let resumeDay = EditionPause.resumeDay(after: pausedThrough) {
                Text("On a break")
                    .typeStyle(.display(30, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 22)
                Text("The edition is back \(EditionFormat.storyDate(resumeDay)).")
                    .typeStyle(.text(16, italic: true, relativeTo: .body))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 8)
                SheetButton(title: "Resume now") {
                    pausedThrough = ""
                    dismiss()
                }
                .padding(.top, 28)
            } else {
                Text("No edition for")
                    .typeStyle(.display(22, italic: true, relativeTo: .title3))
                    .foregroundStyle(Theme.inkMuted)
                    .padding(.top, 18)
                HStack(spacing: 28) {
                    RoundButton(symbol: "−", enabled: days > 1) { days -= 1 }
                    VStack(spacing: 4) {
                        Text("\(days)")
                            .typeStyle(.display(48, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.numericText())
                        Text(days == 1 ? "day" : "days")
                            .typeStyle(.label(10))
                            .foregroundStyle(Theme.inkMuted)
                    }
                    .frame(minWidth: 80)
                    RoundButton(symbol: "+", enabled: days < EditionPause.maxDays) { days += 1 }
                }
                .padding(.top, 10)
                .animation(.snappy, value: days)
                .sensoryFeedback(.selection, trigger: days)
                .accessibilityElement()
                .accessibilityLabel("Days without the edition")
                .accessibilityValue("\(days)")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: days = min(days + 1, EditionPause.maxDays)
                    case .decrement: days = max(days - 1, 1)
                    @unknown default: break
                    }
                }
                if let resume {
                    Text("Back \(EditionFormat.storyDate(resume)).")
                        .typeStyle(.text(15, italic: true, relativeTo: .body))
                        .foregroundStyle(Theme.inkMuted)
                        .padding(.top, 12)
                }
                SheetButton(title: "Start the break") {
                    pausedThrough = EditionPause.lastDay(forDays: days)
                    dismiss()
                }
                .padding(.top, 22)
            }

            Text("Your Claude task keeps writing to Notion; the app simply stays quiet. Editions from the break wait in the archive.")
                .typeStyle(.text(12.5, italic: true, lineHeight: 1.4, relativeTo: .caption))
                .foregroundStyle(Theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .presentationBackground { PaperBackground() }
    }
}

/// A brass ring with a − or +.
private struct RoundButton: View {
    let symbol: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(symbol)
                .typeStyle(.display(26, relativeTo: nil))
                .foregroundStyle(Theme.brassText)
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(Theme.brass, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityHidden(true)
    }
}

/// Letter-spaced caps between double rules, the sheet's main action.
struct SheetButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                DoubleRule(color: Theme.brass)
                Text(title)
                    .typeStyle(.label(11))
                    .foregroundStyle(Theme.ink)
                    .padding(.vertical, 13)
                DoubleRule(color: Theme.brass, mirrored: true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedRowStyle())
    }
}
