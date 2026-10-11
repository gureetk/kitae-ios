// Kitae for iPhone
// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The fourth tab: the plan being followed, a few totals, the last 16 weeks of training, and
/// Settings.
struct YouView: View {
    @Environment(AppModel.self) private var model
    @State private var totals = TrainingTotals()
    @State private var weeks: ActivityWeeks?
    @State private var line = YouLines.random()
    /// The current plan, being edited over You.
    @State private var editing: PlanEditor?
    @State private var showsSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    planCard
                    HStack(spacing: 10) {
                        StatTile(title: "Lifts", value: totals.lifts)
                        StatTile(title: "Days", value: totals.days)
                        StatTile(title: "Exercises", value: totals.exercises)
                    }
                    if let weeks {
                        ActivityCard(weeks: weeks)
                    }
                    Text(totals.lifts == 0 ? YouLines.beforeFirstSet : line)
                        .font(.kitaeMono(12, relativeTo: .caption))
                        .foregroundStyle(.inkSoft)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                        .padding(.horizontal, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Color.paper)
            .navigationTitle("You")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") {
                        showsSettings = true
                    }
                }
            }
            .navigationDestination(isPresented: $showsSettings) {
                SettingsView()
            }
            .navigationDestination(item: $editing) { editor in
                PlanEditView(editor: editor)
            }
        }
        // Read again after a workout, plan or exercise changes, and as sets are ticked off.
        .task(id: [model.historyRevision, model.workout?.doneCount ?? -1]) {
            load()
            await openDebugScreen()
        }
    }

    // MARK: Current plan

    @ViewBuilder
    private var planCard: some View {
        if let plan = model.currentPlan {
            Button {
                edit(plan)
            } label: {
                PlanCardLabel(caption: ".current plan", title: plan.name, detail: plan.sizeLabel)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the plan to change its days and exercises")
            .contextMenu {
                Button("Edit plan", systemImage: "pencil") { edit(plan) }
                Button("All plans", systemImage: "list.bullet") { model.isChoosingPlan = true }
            }
        } else {
            Button {
                model.isChoosingPlan = true
            } label: {
                PlanCardLabel(caption: ".no plan yet", title: "Choose a plan", detail: "Pick one to follow, or make your own")
            }
            .buttonStyle(.plain)
        }
    }

    private func edit(_ plan: Plan) {
        editing = model.planEditor(for: PlanEditRoute(planID: plan.id, dayID: model.selectedDay?.id))
    }

    // MARK: Loading

    private func load() {
        let today = EpochDay.of(.now)
        let firstWeekday = Calendar.current.firstWeekday
        do {
            let loaded = try model.database.read { db in
                (try Stats.totals(db), try Stats.activity(db, today: today, firstWeekday: firstWeekday))
            }
            totals = loaded.0
            weeks = loaded.1
        } catch {
            model.problem = "Couldn't count your workouts. \(error.localizedDescription)"
        }
    }

    /// `-KitaeScreen settings`: opens Settings.
    private func openDebugScreen() async {
        #if DEBUG
        guard DebugLaunch.screen == "settings", DebugLaunch.consume("settings") else { return }
        try? await Task.sleep(for: .milliseconds(500))
        showsSettings = true
        #endif
    }
}

/// The plan card's label: a caption, the plan's name and its size.
private struct PlanCardLabel: View {
    let caption: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(.kitaeMono(12, relativeTo: .caption))
                Text(title)
                    .font(.kitaeDisplay(34, relativeTo: .title))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    // Darker Grotesque's line height leaves a lot of air above and below.
                    .padding(.vertical, -5)
                Text(detail)
                    .font(.footnote)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward")
                .font(.system(size: 15, weight: .bold))
        }
        .foregroundStyle(.onOliveSoft)
        .padding(.leading, 20)
        .padding(.trailing, 18)
        .padding(.vertical, 16)
        .frame(minHeight: 104)
        .background(.oliveSoft, in: .rect(cornerRadius: 24))
        .contentShape(.rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

/// One of the three totals: Lifts, Days and Exercises.
private struct StatTile: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.kitaeDisplay(20, relativeTo: .headline))
                .foregroundStyle(.inkSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.vertical, -2)
            Spacer(minLength: 0)
            Text(value.formatted())
                .font(.kitaeMono(28, relativeTo: .title, bold: true))
                .tracking(-1)
                .foregroundStyle(.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.vertical, -5)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(14)
        .background(.card, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

/// The last 16 weeks: a square for each day, olive when a set was done.
private struct ActivityCard: View {
    let weeks: ActivityWeeks

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.kitaeDisplay(24, relativeTo: .title3))
                    .foregroundStyle(.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("Last 16 weeks")
                    .font(.footnote)
                    .foregroundStyle(.inkSoft)
            }
            VStack(alignment: .leading, spacing: 8) {
                DayGrid(rows: 7, columns: ActivityWeeks.count, spacing: 4, labelWidth: 12, labelSpacing: 8) {
                    ForEach(Array(weeks.rowLetters().enumerated()), id: \.offset) { _, letter in
                        Text(letter)
                            .font(.kitaeMono(10, relativeTo: .caption2))
                            .foregroundStyle(.inkSoft)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    ForEach(0..<ActivityWeeks.count, id: \.self) { week in
                        ForEach(0..<7, id: \.self) { row in
                            square(weeks.day(week: week, row: row))
                        }
                    }
                }
                HStack {
                    Text(HistoryDates.dayAndMonth(weeks.first))
                    Spacer(minLength: 8)
                    Text(HistoryDates.dayAndMonth(weeks.today))
                }
                .font(.kitaeMono(11, relativeTo: .caption2))
                .foregroundStyle(.inkSoft)
                .padding(.leading, 20)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Days trained in the last 16 weeks")
            .accessibilityValue("\(weeks.trainedCount)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.card, in: .rect(cornerRadius: 24))
    }

    private func square(_ day: Int) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(weeks.trained.contains(day) ? Color.olive : Color.dayOff)
            .opacity(day > weeks.today ? 0.4 : 1)
    }
}

/// Square cells in columns, filling the width, after a column of row labels. The labels come
/// first, then the cells a column at a time.
private struct DayGrid: Layout {
    let rows: Int
    let columns: Int
    let spacing: CGFloat
    let labelWidth: CGFloat
    let labelSpacing: CGFloat

    private func cellSize(width: CGFloat) -> CGFloat {
        let free = width - labelWidth - labelSpacing - CGFloat(columns - 1) * spacing
        return max(free / CGFloat(columns), 4)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? (labelWidth + labelSpacing + CGFloat(columns) * 14 + CGFloat(columns - 1) * spacing)
        let cell = cellSize(width: width)
        return CGSize(width: width, height: CGFloat(rows) * cell + CGFloat(rows - 1) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let cell = cellSize(width: bounds.width)
        let size = ProposedViewSize(width: cell, height: cell)
        for (index, subview) in subviews.enumerated() {
            if index < rows {
                let y = bounds.minY + CGFloat(index) * (cell + spacing) + cell / 2
                subview.place(
                    at: CGPoint(x: bounds.minX + labelWidth / 2, y: y),
                    anchor: .center,
                    proposal: ProposedViewSize(width: labelWidth, height: cell)
                )
            } else {
                let column = (index - rows) / rows
                let row = (index - rows) % rows
                let x = bounds.minX + labelWidth + labelSpacing + CGFloat(column) * (cell + spacing)
                let y = bounds.minY + CGFloat(row) * (cell + spacing)
                subview.place(at: CGPoint(x: x, y: y), proposal: size)
            }
        }
    }
}

/// Short lines at the bottom of You, one each time Kitae opens.
enum YouLines {
    static let all = [
        "every filled square is a day you showed up",
        "strength is built on ordinary days",
        "the log remembers so you don't have to",
        "light days count too",
        "slow progress is still progress",
    ]

    /// Until the first set is done.
    static let beforeFirstSet = "tick off a set and the first square fills in"

    static func random() -> String {
        all.randomElement() ?? all[0]
    }
}
