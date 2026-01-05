//
//  ContentView.swift
//  SanityApp
//
//  Created by Friederike Quint on 28.12.25.
//

import SwiftUI
import Foundation
import UIKit
import UniformTypeIdentifiers
import UserNotifications

struct ContentView: View {
    @StateObject private var store = MoodEntryStore()
    @StateObject private var appSettings = AppSettings()

    var body: some View {
        NavigationStack {
            DailyEntryView()
                .environmentObject(store)
                .environmentObject(appSettings)
        }
        .task {
            if appSettings.remindersEnabled {
                let granted = await NotificationScheduler.requestAuthorizationIfNeeded()
                await MainActor.run {
                    if granted {
                        NotificationScheduler.rescheduleDailyReminders()
                    } else {
                        appSettings.remindersEnabled = false
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            if appSettings.remindersEnabled {
                NotificationScheduler.rescheduleDailyReminders()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            if appSettings.remindersEnabled {
                NotificationScheduler.rescheduleDailyReminders()
            }
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @State private var notificationsErrorMessage: String? = nil
    @State private var showNotificationsError: Bool = false

    private var timeZoneOptions: [TimeZone] {
        let candidates = [
            "Pacific/Honolulu",
            "America/Los_Angeles",
            "America/New_York",
            "Europe/London",
            "Europe/Berlin",
            "Asia/Tokyo",
            "Australia/Sydney"
        ]
        return candidates.compactMap { TimeZone(identifier: $0) }
    }

    var body: some View {
        Form {
            Section("Reminders") {
                Toggle("Daily reminders", isOn: $appSettings.remindersEnabled)
                    .onChange(of: appSettings.remindersEnabled) { newValue in
                        if newValue {
                            Task {
                                let granted = await NotificationScheduler.requestAuthorizationIfNeeded()
                                await MainActor.run {
                                    if granted {
                                        NotificationScheduler.rescheduleDailyReminders()
                                    } else {
                                        appSettings.remindersEnabled = false
                                        notificationsErrorMessage = "Notifications are not allowed. You can enable them in iOS Settings."
                                        showNotificationsError = true
                                    }
                                }
                            }
                        } else {
                            NotificationScheduler.cancelDailyReminders()
                        }
                    }
            }

            Section("Debug") {
                Toggle("Override timezone", isOn: $appSettings.useDebugTimezoneOverride)

                Picker("Timezone", selection: $appSettings.debugTimezoneIdentifier) {
                    ForEach(timeZoneOptions, id: \.identifier) { tz in
                        Text(tz.identifier).tag(tz.identifier)
                    }
                }
                .disabled(!appSettings.useDebugTimezoneOverride)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Notifications", isPresented: $showNotificationsError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(notificationsErrorMessage ?? "Unknown error")
        }
    }
}

private final class AppSettings: ObservableObject {
    private static let remindersEnabledDefaultsKey = "sanityapp.remindersEnabled"

    @Published var useDebugTimezoneOverride: Bool = false
    @Published var debugTimezoneIdentifier: String = TimeZone.current.identifier
    @Published var remindersEnabled: Bool {
        didSet {
            UserDefaults.standard.set(remindersEnabled, forKey: Self.remindersEnabledDefaultsKey)
        }
    }

    init() {
        self.remindersEnabled = UserDefaults.standard.bool(forKey: Self.remindersEnabledDefaultsKey)
    }

    var effectiveTimeZone: TimeZone {
        if useDebugTimezoneOverride, let tz = TimeZone(identifier: debugTimezoneIdentifier) {
            return tz
        }
        return TimeZone.current
    }
}

private enum NotificationScheduler {
    private static let reminderIdentifiers: [String] = [
        "sanityapp.dailyReminder.1800",
        "sanityapp.dailyReminder.2330"
    ]

    static func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    static func rescheduleDailyReminders() {
        cancelDailyReminders()

        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "SanityApp"
        content.body = "Log your daily mood."
        content.sound = .default

        let times: [(id: String, hour: Int, minute: Int)] = [
            (reminderIdentifiers[0], 18, 0),
            (reminderIdentifiers[1], 23, 30)
        ]

        for item in times {
            var components = DateComponents()
            components.hour = item.hour
            components.minute = item.minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: item.id, content: content, trigger: trigger)

            center.add(request)
        }
    }

    static func cancelDailyReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: reminderIdentifiers)
    }
}

private final class MoodEntryStore: ObservableObject {
    struct DailyEntry {
        let mood: MoodOption
        let stress: Int
    }

    @Published private(set) var entries: [String: DailyEntry] = [:]

    func mood(for date: Date) -> MoodOption? {
        entries[Self.key(for: date)]?.mood
    }

    func stress(for date: Date) -> Int? {
        entries[Self.key(for: date)]?.stress
    }

    func entry(for date: Date) -> DailyEntry? {
        entries[Self.key(for: date)]
    }

    func setEntry(mood: MoodOption, stress: Int, for date: Date) {
        let key = Self.key(for: date)
        guard entries[key] == nil else {
            return
        }
        entries[key] = DailyEntry(mood: mood, stress: stress)
    }

    func removeEntry(for date: Date) {
        entries.removeValue(forKey: Self.key(for: date))
    }

    private static func key(for date: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }
}

private struct DailyEntryView: View {
    @EnvironmentObject private var store: MoodEntryStore
    @EnvironmentObject private var appSettings: AppSettings
    @State private var selectedMood: MoodOption? = nil
    @State private var selectedStress: Int? = nil
    @State private var noteText: String = ""
    @State private var navigateToCalendar: Bool = false
    @State private var showSavedNotice: Bool = false
    @State private var showAvailabilityNotice: Bool = false
    @State private var availabilityNoticeMessage: String = ""

    private var today: Date { Date() }

    private var savedMoodForToday: MoodOption? {
        store.mood(for: today)
    }

    private var savedStressForToday: Int? {
        store.stress(for: today)
    }

    private var isTodaySaved: Bool {
        savedMoodForToday != nil
    }

    private enum AnswerWindowState {
        case before
        case open
        case after
    }

    private var answerWindowState: AnswerWindowState {
        var calendar = Calendar.current
        calendar.timeZone = appSettings.effectiveTimeZone
        let now = Date()

        let day = calendar.dateComponents([.year, .month, .day], from: now)
        let windowStart = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 18, minute: 0))
        let windowEnd = calendar.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 23, minute: 59, second: 59))

        guard let windowStart, let windowEnd else {
            return .after
        }

        if now < windowStart {
            return .before
        }
        if now > windowEnd {
            return .after
        }
        return .open
    }

    private var isAnsweringAllowedNow: Bool {
        answerWindowState == .open
    }

    private func showAvailabilityMessage() {
        switch answerWindowState {
        case .before:
            availabilityNoticeMessage = "There is still some time until you can answer 😉"
        case .after:
            availabilityNoticeMessage = "Answering is closed for today."
        case .open:
            availabilityNoticeMessage = ""
        }
        showAvailabilityNotice = !availabilityNoticeMessage.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    AppTitleHeader(
                        title: "SanityApp",
                        iconAssetName: "SanityAppIcon",
                        fallbackToMarkIfMissing: true
                    )

                Text(verbatim: "\(AppConfig.dailyQuestion) - \(formattedShortDate(today)).")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if showSavedNotice {
                    SavedAnswerNotice(
                        onRevert: {
                            store.removeEntry(for: today)
                            selectedMood = nil
                            selectedStress = nil
                            showSavedNotice = false
                        },
                        onClose: {
                            showSavedNotice = false
                        }
                    )
                }

                if showAvailabilityNotice {
                    AvailabilityNotice(
                        message: availabilityNoticeMessage,
                        onClose: {
                            showAvailabilityNotice = false
                        }
                    )
                }

                MoodSelector(
                    selectedMood: $selectedMood,
                    isLocked: isTodaySaved || !isAnsweringAllowedNow,
                    onLockedAttempt: {
                        if isTodaySaved {
                            showSavedNotice = true
                        } else {
                            showAvailabilityMessage()
                        }
                    }
                )

                AppSectionHeader(title: "Stress")

                StressSelector(
                    selectedStress: $selectedStress,
                    isLocked: isTodaySaved || !isAnsweringAllowedNow,
                    onLockedAttempt: {
                        if isTodaySaved {
                            showSavedNotice = true
                        } else {
                            showAvailabilityMessage()
                        }
                    }
                )

                AppSectionHeader(title: "Optional note")

                AppCard {
                    NoteTextView(text: $noteText)
                        .frame(minHeight: 110, maxHeight: 180)
                }

                AppCard {
                    Button {
                        if !isAnsweringAllowedNow {
                            showAvailabilityMessage()
                            return
                        }
                        if isTodaySaved {
                            showSavedNotice = true
                            return
                        }

                        if let mood = selectedMood, let stress = selectedStress {
                            store.setEntry(mood: mood, stress: stress, for: today)
                            navigateToCalendar = true
                        }
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedMood == nil || selectedStress == nil || isTodaySaved || !isAnsweringAllowedNow)
                }
                }
                .padding(AppSpacing.lg)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                dismissKeyboard()
            }
        )
        .scrollDismissesKeyboard(.interactively)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationDestination(isPresented: $navigateToCalendar) {
            CalendarView()
                .environmentObject(store)
                .environmentObject(appSettings)
        }
        .onAppear {
            if let entry = store.entry(for: today) {
                selectedMood = entry.mood
                selectedStress = entry.stress
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: CalendarView().environmentObject(store).environmentObject(appSettings)) {
                    Image(systemName: "calendar")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: SettingsView().environmentObject(appSettings)) {
                    Image(systemName: "gearshape")
                }
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    dismissKeyboard()
                }
            }
        }
    }
}

private struct CalendarView: View {
    @EnvironmentObject private var store: MoodEntryStore
    @EnvironmentObject private var appSettings: AppSettings

    private enum ExportKind {
        case csv
        case json

        var contentType: UTType {
            switch self {
            case .csv:
                return .commaSeparatedText
            case .json:
                return .json
            }
        }

        var defaultFilename: String {
            switch self {
            case .csv:
                return "SanityApp-MoodExport"
            case .json:
                return "SanityApp-MoodExport"
            }
        }
    }

    @State private var exportKind: ExportKind = .csv
    @State private var exportDocument: ExportDocument = ExportDocument(text: "")
    @State private var isExporting: Bool = false
    @State private var exportErrorMessage: String? = nil

    private var yearsToShow: [Int] {
        var calendar = Calendar.current
        calendar.timeZone = appSettings.effectiveTimeZone
        let now = Date()

        let currentYear = calendar.component(.year, from: now)
        let currentMonth = calendar.component(.month, from: now)

        let startYear = min(max(AppConfig.supportedYears.lowerBound, currentYear), AppConfig.supportedYears.upperBound)
        var endYear = startYear

        if currentMonth == 12, startYear == currentYear {
            endYear = min(startYear + 1, AppConfig.supportedYears.upperBound)
        }

        return Array(startYear...endYear)
    }

    private var shouldShowDecemberPreview: Bool {
        var calendar = Calendar.current
        calendar.timeZone = appSettings.effectiveTimeZone
        let now = Date()
        let currentYear = calendar.component(.year, from: now)
        return currentYear == (AppConfig.supportedYears.lowerBound - 1)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    AppHeader(title: "Calendar")

                VStack(spacing: AppSpacing.lg) {
                    if shouldShowDecemberPreview {
                        Text(verbatim: "Your mood in \(AppConfig.supportedYears.lowerBound - 1)")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        MonthView(year: AppConfig.supportedYears.lowerBound - 1, month: 12)
                            .environmentObject(store)
                    }

                    ForEach(yearsToShow, id: \.self) { year in
                        Text(verbatim: "Your mood in \(year)")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: AppSpacing.lg) {
                            ForEach(1...12, id: \.self) { month in
                                MonthView(year: year, month: month)
                                    .environmentObject(store)
                            }
                        }
                    }
                }

                AppSectionHeader(title: "Export")

                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Button {
                            exportKind = .csv
                            exportDocument = ExportDocument(text: makeCSV(from: store.entries))
                            isExporting = true
                        } label: {
                            Text("Download CSV")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            exportKind = .json
                            exportDocument = ExportDocument(text: makeJSON(from: store.entries))
                            isExporting = true
                        } label: {
                            Text("Download JSON")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                }
                .padding(AppSpacing.lg)
            }
        }
        .scrollIndicators(.visible)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportKind.contentType,
            defaultFilename: exportKind.defaultFilename
        ) { result in
            if case .failure(let error) = result {
                exportErrorMessage = error.localizedDescription
            }
        }
        .alert("Export failed", isPresented: Binding(get: { exportErrorMessage != nil }, set: { isPresented in
            if !isPresented { exportErrorMessage = nil }
        })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Unknown error")
        }
    }

    private func makeCSV(from entries: [String: MoodEntryStore.DailyEntry]) -> String {
        let sorted = entries.sorted(by: { $0.key < $1.key })
        var lines: [String] = ["date,mood_value,mood_label,stress_value"]
        for (date, entry) in sorted {
            lines.append("\(date),\(entry.mood.rawValue),\(entry.mood.title),\(entry.stress)")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func makeJSON(from entries: [String: MoodEntryStore.DailyEntry]) -> String {
        struct ExportRow: Codable {
            let date: String
            let moodValue: Int
            let moodLabel: String
            let stressValue: Int
        }

        let rows: [ExportRow] = entries
            .sorted(by: { $0.key < $1.key })
            .map { ExportRow(date: $0.key, moodValue: $0.value.mood.rawValue, moodLabel: $0.value.mood.title, stressValue: $0.value.stress) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = (try? encoder.encode(rows)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self) + "\n"
    }
}

private struct MonthView: View {
    @EnvironmentObject private var store: MoodEntryStore

    let year: Int
    let month: Int

    private var calendar: Calendar { Calendar.current }

    private var monthStart: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL"
        return formatter.string(from: monthStart)
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingEmptyCells: Int {
        let weekday = calendar.component(.weekday, from: monthStart) // 1..7 (Sun..Sat)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdayHeaders: [String] {
        let symbols = DateFormatter().shortStandaloneWeekdaySymbols ?? []
        guard symbols.count == 7 else {
            return ["Mo", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }

        let startIndex = (calendar.firstWeekday - 1 + 7) % 7
        let ordered = Array(symbols[startIndex...] + symbols[..<startIndex])

        return ordered.map { symbol in
            switch symbol.lowercased() {
            case "mon": return "Mo"
            case "tue": return "Tue"
            case "wed": return "Wed"
            case "thu": return "Thu"
            case "fri": return "Fri"
            case "sat": return "Sat"
            case "sun": return "Sun"
            default:
                if symbol.count >= 3 { return String(symbol.prefix(3)) }
                if symbol.count == 2 { return symbol }
                return symbol
            }
        }
    }

    private var daySlots: [Int?] {
        Array(repeating: nil, count: leadingEmptyCells) + Array(1...daysInMonth).map(Optional.some)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(monthTitle)
                .font(.headline)

            let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs, alignment: .leading), count: 7)

            LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                ForEach(weekdayHeaders, id: \.self) { label in
                    Text(label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: columns, spacing: AppSpacing.xs) {
                ForEach(Array(daySlots.enumerated()), id: \.offset) { index, day in
                    if let day {
                        let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? Date()
                        DayCell(day: day, mood: store.mood(for: date))
                            .id("day-\(year)-\(month)-\(day)")
                    } else {
                        Color.clear
                            .frame(height: 28)
                            .id("empty-\(year)-\(month)-\(index)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

private struct AvailabilityNotice: View {
    let message: String
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemGray5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct DayCell: View {
    let day: Int
    let mood: MoodOption?

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill((mood?.color ?? Color.clear).opacity(mood == nil ? 0 : 0.85))

            Text("\(day)")
                .font(.caption.weight(.semibold))
                .foregroundColor(mood == nil ? .primary : .white)
                .lineLimit(1)
                .padding(.top, 5)
                .padding(.leading, 6)
        }
        .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
    }
}

private enum MoodOption: Int, CaseIterable, Identifiable {
    case veryBad = 1
    case bad
    case okay
    case good
    case veryGood

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .veryBad: return "Very bad"
        case .bad: return "Bad"
        case .okay: return "Okay"
        case .good: return "Good"
        case .veryGood: return "Very good"
        }
    }

    var color: Color {
        switch self {
        case .veryBad: return Color(red: 0.61, green: 0.15, blue: 0.20)
        case .bad: return Color(red: 0.86, green: 0.43, blue: 0.16)
        case .okay: return Color(red: 0.18, green: 0.62, blue: 0.62)
        case .good: return Color(red: 0.12, green: 0.40, blue: 0.70)
        case .veryGood: return Color(red: 0.16, green: 0.56, blue: 0.35)
        }
    }
}

private struct MoodSelector: View {
    @Binding var selectedMood: MoodOption?
    let isLocked: Bool
    let onLockedAttempt: () -> Void

    init(selectedMood: Binding<MoodOption?>, isLocked: Bool = false, onLockedAttempt: @escaping () -> Void = {}) {
        _selectedMood = selectedMood
        self.isLocked = isLocked
        self.onLockedAttempt = onLockedAttempt
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            ForEach(MoodOption.allCases) { option in
                Button {
                    if isLocked {
                        if selectedMood != option {
                            onLockedAttempt()
                        }
                        return
                    }

                    selectedMood = option
                } label: {
                    MoodOptionRow(
                        option: option,
                        isSelected: selectedMood == option,
                        shouldFade: selectedMood != nil && selectedMood != option
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct StressSelector: View {
    @Binding var selectedStress: Int?
    let isLocked: Bool
    let onLockedAttempt: () -> Void

    @State private var sliderValue: Double = 5
    @State private var hasInteracted: Bool = false

    init(selectedStress: Binding<Int?>, isLocked: Bool = false, onLockedAttempt: @escaping () -> Void = {}) {
        _selectedStress = selectedStress
        self.isLocked = isLocked
        self.onLockedAttempt = onLockedAttempt
    }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("How stressed did you feel today? (0–10)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            AppCard {
                VStack(spacing: AppSpacing.xs) {
                    StressSlider(
                        value: Binding(
                            get: { Int(sliderValue) },
                            set: { newValue in
                                sliderValue = Double(newValue)
                                hasInteracted = true
                                selectedStress = newValue
                            }
                        ),
                        hasInteracted: $hasInteracted,
                        isLocked: isLocked,
                        onLockedAttempt: onLockedAttempt
                    )
                }
            }

            Text("0 = Not at all stressed   •   10 = Extremely stressed")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            sliderValue = Double(selectedStress ?? 5)
            hasInteracted = selectedStress != nil
        }
        .onChange(of: selectedStress) { newValue in
            if let newValue {
                sliderValue = Double(newValue)
                hasInteracted = true
            } else {
                sliderValue = 5
                hasInteracted = false
            }
        }
    }
}

private struct StressSlider: View {
    @Binding var value: Int
    @Binding var hasInteracted: Bool
    let isLocked: Bool
    let onLockedAttempt: () -> Void

    private let minValue: Int = 0
    private let maxValue: Int = 10

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                    .frame(height: 8)

                GeometryReader { geo in
                    let width = geo.size.width
                    let steps = maxValue - minValue
                    let stepWidth = width / CGFloat(steps)
                    let clamped = min(max(value, minValue), maxValue)
                    let x = CGFloat(clamped - minValue) * stepWidth

                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color.accentColor.opacity(0.25))
                            .frame(width: x, height: 8)

                        ZStack {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 30, height: 30)

                            Text(hasInteracted ? "\(clamped)" : "—")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: x - 15)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    if isLocked {
                                        onLockedAttempt()
                                        return
                                    }

                                    let raw = gesture.location.x
                                    let stepped = Int(round(raw / stepWidth)) + minValue
                                    let next = min(max(stepped, minValue), maxValue)
                                    if next != value {
                                        value = next
                                    }
                                    hasInteracted = true
                                }
                        )
                        .accessibilityLabel("Stress")
                        .accessibilityValue(hasInteracted ? "\(clamped)" : "Not set")
                    }
                }
                .frame(height: 30)
            }

            HStack {
                Text("0")
                Spacer(minLength: 0)
                Text("5")
                Spacer(minLength: 0)
                Text("10")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            GeometryReader { geo in
                let width = geo.size.width
                let steps = maxValue - minValue
                let stepWidth = width / CGFloat(steps)
                HStack(spacing: 0) {
                    ForEach(0...steps, id: \.self) { idx in
                        Rectangle()
                            .fill(Color.primary.opacity(0.20))
                            .frame(width: 1, height: idx % 5 == 0 ? 8 : 5)
                            .frame(width: stepWidth, alignment: .leading)
                    }
                }
            }
            .frame(height: 10)
        }
    }
}

private struct MoodOptionRow: View {
    let option: MoodOption
    let isSelected: Bool
    let shouldFade: Bool

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(option.color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                    )

                Text(option.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(option.color)
                }
            }
        }
        .opacity(shouldFade ? 0.35 : 1.0)
    }
}

private struct SavedAnswerNotice: View {
    let onRevert: () -> Void
    let onClose: () -> Void

    private var message: AttributedString {
        var text = AttributedString("You already saved your answer. Click here if this was a mistake.")
        if let range = text.range(of: "here") {
            text[range].foregroundColor = .blue
            text[range].underlineStyle = .single
            text[range].link = URL(string: "sanityapp://revert")
        }
        return text
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.md)
                .environment(\.openURL, OpenURLAction { url in
                    if url.scheme == "sanityapp" && url.host == "revert" {
                        onRevert()
                        return .handled
                    }
                    return .systemAction
                })

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .buttonStyle(.plain)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .systemGray5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private enum AppSpacing {
    static let xs: CGFloat = 6
    static let sm: CGFloat = 10
    static let md: CGFloat = 14
    static let lg: CGFloat = 18
}

private struct AppHeader: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(.largeTitle.weight(.bold))
            AppSeparator()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppTitleHeader: View {
    let title: String
    let iconSystemName: String
    let secondaryIconSystemName: String?
    let useMark: Bool
    let iconAssetName: String?
    let fallbackToMarkIfMissing: Bool

    init(
        title: String,
        iconSystemName: String = "",
        secondaryIconSystemName: String? = nil,
        useMark: Bool = false,
        iconAssetName: String? = nil,
        fallbackToMarkIfMissing: Bool = false
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.secondaryIconSystemName = secondaryIconSystemName
        self.useMark = useMark
        self.iconAssetName = iconAssetName
        self.fallbackToMarkIfMissing = fallbackToMarkIfMissing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                if let iconAssetName {
                    if UIImage(named: iconAssetName) != nil {
                        Image(iconAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.trailing, 2)
                    } else if fallbackToMarkIfMissing {
                        SanityAppMark()
                            .frame(width: 42, height: 42)
                            .padding(.trailing, 2)
                    }
                } else if useMark {
                    SanityAppMark()
                        .frame(width: 42, height: 42)
                        .padding(.trailing, 2)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: iconSystemName)
                        if let secondaryIconSystemName {
                            Image(systemName: secondaryIconSystemName)
                        }
                    }
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tint)
                }
                Text(title)
                    .font(.largeTitle.weight(.bold))
                Spacer(minLength: 0)
            }
            AppSeparator()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AppSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.top, AppSpacing.sm)
    }
}

private struct AppCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

private struct AppSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }
}

private struct SanityAppMark: View {
    private let ink = Color(red: 0.18, green: 0.27, blue: 0.36).opacity(0.82)

    var body: some View {
        ZStack {
            SanityCap()
                .fill(ink)

            SanityCapBand()
                .fill(ink.opacity(0.92))
                .offset(y: 6)

            Circle()
                .fill(Color.white.opacity(0.65))
                .overlay(
                    Circle()
                        .stroke(ink.opacity(0.10), lineWidth: 1.5)
                )
                .frame(width: 22, height: 22)
                .offset(y: 12)

            Circle()
                .fill(ink.opacity(0.78))
                .frame(width: 2.2, height: 2.2)
                .offset(x: -4, y: 10)

            Circle()
                .fill(ink.opacity(0.78))
                .frame(width: 2.2, height: 2.2)
                .offset(x: 4, y: 10)

            Path { path in
                path.move(to: CGPoint(x: 12, y: 23))
                path.addQuadCurve(to: CGPoint(x: 22, y: 23), control: CGPoint(x: 17, y: 28))
            }
            .stroke(ink.opacity(0.70), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .drawingGroup()
    }
}

private struct SanityCap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let topY = h * 0.20
        let midY = h * 0.45
        path.move(to: CGPoint(x: w * 0.50, y: topY))
        path.addLine(to: CGPoint(x: w * 0.16, y: midY))
        path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.60))
        path.addLine(to: CGPoint(x: w * 0.84, y: midY))
        path.closeSubpath()
        return path
    }
}

private struct SanityCapBand: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.28, y: h * 0.56))
        path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.56), control: CGPoint(x: w * 0.50, y: h * 0.70))
        path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.72))
        path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.72), control: CGPoint(x: w * 0.50, y: h * 0.86))
        path.closeSubpath()
        return path
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.91, blue: 0.99),
                    Color(red: 0.89, green: 0.97, blue: 0.99),
                    Color(red: 0.94, green: 0.99, blue: 0.90),
                    Color(red: 1.00, green: 0.92, blue: 0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.86, green: 0.93, blue: 1.00).opacity(0.88),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    Color(red: 1.00, green: 0.88, blue: 0.95).opacity(0.78),
                    Color.clear,
                ],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 460
            )
        }
        .ignoresSafeArea()
    }
}

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

private func formattedShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd. MMM yyyy"
    return formatter.string(from: date)
}

private struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json, .plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            text = string
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = text.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

private struct NoteTextView: UIViewRepresentable {
    @Binding var text: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}

#Preview {
    ContentView()
}

private func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
