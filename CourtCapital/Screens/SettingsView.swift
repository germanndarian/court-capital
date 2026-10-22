import SwiftUI

struct SettingsView: View {
    @AppStorage(Preferences.morningNotification) private var notificationsOn = false
    @AppStorage(Preferences.deliveryMinutes) private var deliveryMinutes = Preferences.defaultDeliveryMinutes
    @AppStorage(Preferences.appearance) private var appearance = Appearance.automatic
    @State private var choosingTime = false
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
        .onChange(of: deliveryMinutes) { _, minutes in
            guard notificationsOn else { return }
            Task { await MorningNotification.schedule(minutesAfterMidnight: minutes) }
        }
        .alert("Notifications are off", isPresented: $showDeniedAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Allow notifications for Court & Capital in the Settings app to get the morning edition.")
        }
    }

    /// Turning the notification on asks for permission first and stays off if it is refused.
    private var notificationBinding: Binding<Bool> {
        Binding {
            notificationsOn
        } set: { isOn in
            guard isOn else {
                notificationsOn = false
                MorningNotification.cancel()
                return
            }
            notificationsOn = true
            Task {
                if await MorningNotification.requestPermission() {
                    await MorningNotification.schedule(minutesAfterMidnight: deliveryMinutes)
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
