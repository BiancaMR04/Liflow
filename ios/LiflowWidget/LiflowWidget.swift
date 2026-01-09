import WidgetKit
import SwiftUI

private let appGroupId = "group.com.example.liflow"

private let keyDayTasksJson = "liflow_widget_day_tasks_json"

struct DayTask: Identifiable {
    let id: String
    let time: String
    let title: String
    let weekId: String
    let dayId: String
}

struct LiflowEntry: TimelineEntry {
    let date: Date
    let current: DayTask?
    let nextRefresh: Date
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> LiflowEntry {
        LiflowEntry(
            date: Date(),
            current: DayTask(id: "", time: "08:30", title: "Escovar os dentes", weekId: "", dayId: ""),
            nextRefresh: Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (LiflowEntry) -> Void) {
        completion(makeEntry(now: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LiflowEntry>) -> Void) {
        let entry = makeEntry(now: Date())
        completion(Timeline(entries: [entry], policy: .after(entry.nextRefresh)))
    }

    private func makeEntry(now: Date) -> LiflowEntry {
        let tasks = loadTasks()
        let (current, nextRefresh) = pickCurrent(tasks: tasks, now: now)
        return LiflowEntry(date: now, current: current, nextRefresh: nextRefresh)
    }

    private func loadTasks() -> [DayTask] {
        guard let defaults = UserDefaults(suiteName: appGroupId) else { return [] }
        guard let json = defaults.string(forKey: keyDayTasksJson) else { return [] }
        guard let data = json.data(using: .utf8) else { return [] }

        do {
            let raw = try JSONSerialization.jsonObject(with: data, options: [])
            guard let array = raw as? [[String: Any]] else { return [] }

            return array.compactMap { item in
                let id = (item["activityId"] as? String) ?? ""
                let time = (item["time"] as? String) ?? ""
                let title = (item["title"] as? String) ?? ""
                let weekId = (item["weekId"] as? String) ?? ""
                let dayId = (item["dayId"] as? String) ?? ""

                if time.isEmpty || title.isEmpty { return nil }
                return DayTask(id: id, time: time, title: title, weekId: weekId, dayId: dayId)
            }
        } catch {
            return []
        }
    }

    private func parseMinutes(_ hhmm: String) -> Int? {
        let parts = hhmm.split(separator: ":")
        if parts.count != 2 { return nil }
        guard let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        if h < 0 || h > 23 { return nil }
        if m < 0 || m > 59 { return nil }
        return h * 60 + m
    }

    // Rule:
    // - If now is between task[i].time and task[i+1].time, show task[i]
    // - If now is before the first task, show the first task
    // - If now is after the last task, keep showing the last task
    // Refresh time:
    // - Next task boundary (task[i+1].time) if exists, otherwise next day at 00:01
    private func pickCurrent(tasks: [DayTask], now: Date) -> (DayTask?, Date) {
        guard !tasks.isEmpty else {
            return (nil, Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800))
        }

        let calendar = Calendar.current
        let nowMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)

        let minutesList: [(DayTask, Int)] = tasks.compactMap { t in
            guard let m = parseMinutes(t.time) else { return nil }
            return (t, m)
        }.sorted { $0.1 < $1.1 }

        guard !minutesList.isEmpty else {
            return (nil, Calendar.current.date(byAdding: .minute, value: 30, to: now) ?? now.addingTimeInterval(1800))
        }

        // Before first
        if nowMinutes < minutesList[0].1 {
            let next = dateToday(atMinutes: minutesList[0].1, now: now)
            return (minutesList[0].0, next)
        }

        // Between
        for idx in 0..<(minutesList.count) {
            let current = minutesList[idx]
            let nextIdx = idx + 1
            if nextIdx < minutesList.count {
                let next = minutesList[nextIdx]
                if nowMinutes >= current.1 && nowMinutes < next.1 {
                    return (current.0, dateToday(atMinutes: next.1, now: now))
                }
            }
        }

        // After last
        let last = minutesList[minutesList.count - 1]
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now.addingTimeInterval(86400)
        let refresh = calendar.date(byAdding: .minute, value: 1, to: tomorrow) ?? tomorrow.addingTimeInterval(60)
        return (last.0, refresh)
    }

    private func dateToday(atMinutes minutes: Int, now: Date) -> Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .minute, value: minutes, to: start) ?? now
    }
}

struct LiflowWidgetView: View {
    var entry: Provider.Entry

    // Cores estilo Structured
    private let pinkBackground = Color(red: 0.99, green: 0.91, blue: 0.90)
    private let cardWhite = Color.white
    private let accentPink = Color(red: 0.95, green: 0.63, blue: 0.61)
    private let textPrimary = Color.black
    private let textSecondary = Color.gray.opacity(0.8)

    var body: some View {
        ZStack {
            // Fundo rosa
            RoundedRectangle(cornerRadius: 26)
                .fill(pinkBackground)

            if let task = entry.current {
                // Card branco
                HStack(alignment: .top, spacing: 12) {

                    // Bolinha vazada
                    Circle()
                        .stroke(accentPink, lineWidth: 2)
                        .frame(width: 16, height: 16)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        // Hora da tarefa (EXATA)
                        Text(task.time)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(textSecondary)

                        // Título
                        Text(task.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(textPrimary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(cardWhite)
                        .shadow(
                            color: Color.black.opacity(0.08),
                            radius: 16,
                            x: 0,
                            y: 6
                        )
                )
                .padding(14)
            } else {
                Text("Sem tarefa agora")
                    .font(.headline)
            }
        }
    }
}


@main
struct LiflowWidget: Widget {
    let kind: String = "LiflowWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            LiflowWidgetView(entry: entry)
        }
        .configurationDisplayName("Liflow")
        .description("Mostra a tarefa atual")
        .supportedFamilies([.systemSmall])
    }
}
