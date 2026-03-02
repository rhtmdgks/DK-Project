//
//  MealDepartureWidget.swift
//  MealDepartureWidget
//
//  급식 출발 알림 홈 화면 위젯. 탭 시 앱의 급식 출발 알림 화면을 연다.
//

import SwiftUI
import WidgetKit

struct MealDepartureEntry: TimelineEntry {
    let date: Date
}

struct MealDepartureProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealDepartureEntry {
        MealDepartureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (MealDepartureEntry) -> Void) {
        completion(MealDepartureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MealDepartureEntry>) -> Void) {
        let entry = MealDepartureEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct MealDepartureWidgetView: View {
    var entry: MealDepartureProvider.Entry

    private let openURL = URL(string: "laon://meal-departure-alert")!

    var body: some View {
        VStack(spacing: 6) {
            Text("급식 출발 알림")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("탭하여 열기")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 1.0, green: 0.62, blue: 0.26))
        .widgetURL(openURL)
    }
}

struct MealDepartureWidget: Widget {
    let kind: String = "MealDepartureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealDepartureProvider()) { entry in
            MealDepartureWidgetView(entry: entry)
        }
        .configurationDisplayName("급식 출발 알림")
        .description("탭하면 앱에서 급식 출발 알림 화면을 엽니다.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 이번 시간 남은 시간

struct ClassTimeLeftEntry: TimelineEntry {
    let date: Date
}

struct ClassTimeLeftProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClassTimeLeftEntry { ClassTimeLeftEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (ClassTimeLeftEntry) -> Void) {
        completion(ClassTimeLeftEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClassTimeLeftEntry>) -> Void) {
        completion(Timeline(entries: [ClassTimeLeftEntry(date: Date())], policy: .atEnd))
    }
}

struct ClassTimeLeftWidgetView: View {
    var entry: ClassTimeLeftProvider.Entry
    private let openURL = URL(string: "laon://")!

    var body: some View {
        VStack(spacing: 6) {
            Text("이번 시간 남은 시간")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("탭하여 열기")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.36, green: 0.49, blue: 1.0))
        .widgetURL(openURL)
    }
}

struct ClassTimeLeftWidget: Widget {
    let kind: String = "ClassTimeLeftWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClassTimeLeftProvider()) { entry in
            ClassTimeLeftWidgetView(entry: entry)
        }
        .configurationDisplayName("이번 시간 남은 시간")
        .description("탭하면 앱을 엽니다.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 오늘의 시간표

struct TodayTimetableEntry: TimelineEntry {
    let date: Date
}

struct TodayTimetableProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayTimetableEntry { TodayTimetableEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (TodayTimetableEntry) -> Void) {
        completion(TodayTimetableEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTimetableEntry>) -> Void) {
        completion(Timeline(entries: [TodayTimetableEntry(date: Date())], policy: .atEnd))
    }
}

struct TodayTimetableWidgetView: View {
    var entry: TodayTimetableProvider.Entry
    private let openURL = URL(string: "laon://")!

    var body: some View {
        VStack(spacing: 6) {
            Text("오늘의 시간표")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("탭하여 열기")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.42, green: 0.36, blue: 0.91))
        .widgetURL(openURL)
    }
}

struct TodayTimetableWidget: Widget {
    let kind: String = "TodayTimetableWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTimetableProvider()) { entry in
            TodayTimetableWidgetView(entry: entry)
        }
        .configurationDisplayName("오늘의 시간표")
        .description("탭하면 앱을 엽니다.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - 급식 출발 카운트다운

struct MealDepartureCountdownEntry: TimelineEntry {
    let date: Date
}

struct MealDepartureCountdownProvider: TimelineProvider {
    func placeholder(in context: Context) -> MealDepartureCountdownEntry { MealDepartureCountdownEntry(date: Date()) }
    func getSnapshot(in context: Context, completion: @escaping (MealDepartureCountdownEntry) -> Void) {
        completion(MealDepartureCountdownEntry(date: Date()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<MealDepartureCountdownEntry>) -> Void) {
        completion(Timeline(entries: [MealDepartureCountdownEntry(date: Date())], policy: .atEnd))
    }
}

struct MealDepartureCountdownWidgetView: View {
    var entry: MealDepartureCountdownProvider.Entry
    private let openURL = URL(string: "laon://")!

    var body: some View {
        VStack(spacing: 6) {
            Text("급식 출발")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text("탭하여 열기")
                .font(.caption)
                .foregroundColor(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0, green: 0.72, blue: 0.58))
        .widgetURL(openURL)
    }
}

struct MealDepartureCountdownWidget: Widget {
    let kind: String = "MealDepartureCountdownWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MealDepartureCountdownProvider()) { entry in
            MealDepartureCountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("급식 출발 카운트다운")
        .description("탭하면 앱을 엽니다.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget Bundle (진입점)

@main
struct LaonWidgetBundle: WidgetBundle {
    var body: some Widget {
        MealDepartureWidget()
        ClassTimeLeftWidget()
        TodayTimetableWidget()
        MealDepartureCountdownWidget()
    }
}

struct MealDepartureWidget_Previews: PreviewProvider {
    static var previews: some View {
        MealDepartureWidgetView(entry: MealDepartureEntry(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
