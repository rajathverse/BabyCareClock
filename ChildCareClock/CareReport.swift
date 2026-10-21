import SwiftUI

/// A day's log as shareable text or an image, e.g. to show the pediatrician.
@MainActor
struct CareReport {
    let day: Date
    let state: CareState
    let now: Date

    private var babyName: String { state.baby?.name ?? "Baby" }

    var entries: [CareTimelineEntry] {
        CareEngine.timeline(for: day, in: state, now: now).filter { $0.kind == .done || $0.kind == .skipped }
    }

    var title: String {
        "\(babyName)'s day · \(day.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))"
    }

    var text: String {
        var lines = [title, ""]
        let entries = entries
        if entries.isEmpty {
            lines.append("Nothing logged.")
        } else {
            for entry in entries {
                var line = "\(entry.kind == .done ? "✓" : "–") \(entry.date.shortTime)  \(entry.item.name)"
                let extras = [entry.item.dosage, entry.note].filter { !$0.isEmpty }
                if !extras.isEmpty { line += " (\(extras.joined(separator: ", ")))" }
                if entry.kind == .skipped { line += " — skipped" }
                lines.append(line)
            }
            lines.append("")
            lines.append("Totals: " + totals(entries).map { "\($0.name) ×\($0.count)" }.joined(separator: ", "))
        }
        lines.append("")
        lines.append(state.baby?.caregiverTitle.map { "Shared by \($0) from Baby Care Clock" } ?? "Shared from Baby Care Clock")
        return lines.joined(separator: "\n")
    }

    func image() -> Image? {
        let renderer = ImageRenderer(content: ReportCard(report: self).frame(width: 390))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }

    func totals(_ entries: [CareTimelineEntry]) -> [(name: String, count: Int)] {
        Dictionary(grouping: entries.filter { $0.kind == .done }, by: \.item.name)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.name < $1.name : $0.count > $1.count }
    }
}

private struct ReportCard: View {
    let report: CareReport

    var body: some View {
        let entries = report.entries
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "clock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppPalette.primary)
                Text(report.title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(AppPalette.text)
            }
            if entries.isEmpty {
                Text("Nothing logged.")
                    .foregroundStyle(AppPalette.secondaryText)
            }
            ForEach(entries) { entry in
                HStack(spacing: 10) {
                    Text(entry.date.shortTime)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .frame(width: 70, alignment: .trailing)
                        .foregroundStyle(AppPalette.secondaryText)
                    SymbolBadge(symbol: entry.item.symbol, kind: entry.item.kind, size: 28)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.item.name)
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                            .foregroundStyle(AppPalette.text)
                        let extras = [entry.item.dosage, entry.note, entry.kind == .skipped ? "Skipped" : ""].filter { !$0.isEmpty }
                        if !extras.isEmpty {
                            Text(extras.joined(separator: " · "))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(AppPalette.secondaryText)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            if !entries.isEmpty {
                Divider()
                Text(report.totals(entries).map { "\($0.name) ×\($0.count)" }.joined(separator: "   "))
                    .font(.system(.footnote, design: .rounded, weight: .semibold))
                    .foregroundStyle(AppPalette.text)
            }
            Text("Baby Care Clock")
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(AppPalette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(22)
        .background(
            LinearGradient(colors: [Color(UIColor(hex: 0xF8F5FF)), Color(UIColor(hex: 0xFFF4EF)), Color(UIColor(hex: 0xF1FAF6))], startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .light)
    }
}
