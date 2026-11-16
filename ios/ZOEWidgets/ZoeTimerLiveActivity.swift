import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit
import ZoeCore
import ZoeShared
import ZoeUI

/// ZOE nella Dynamic Island e nella schermata di blocco mentre scorre un timer o una sessione di focus.
struct ZoeTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ZoeTimerAttributes.self) { context in
            LockScreenTimerView(context: context)
                .activityBackgroundTint(Color(hex: "#0a0b16").opacity(0.92))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let st = context.state
            let look = context.attributes.settings
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ZoeMascotView(settings: look, expression: st.mood, animated: false)
                        .frame(width: 56)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: st)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color(hex: "#3ee0b0"))
                        .frame(maxWidth: 110, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(title(st, name: look.name)).font(.headline).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 10) {
                        TimerBar(state: st, tint: Color(hex: look.color))
                        if !st.finished {
                            Button(intent: StopTimerIntent()) {
                                Label("Stop", systemImage: "xmark")
                                    .font(.caption.weight(.bold))
                            }
                            .tint(Color(hex: look.color))
                        }
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                ZoeMascotView(settings: look, expression: st.mood, animated: false, showsAccessory: false)
                    .frame(width: 26)
            } compactTrailing: {
                Countdown(state: st)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color(hex: "#3ee0b0"))
                    .frame(maxWidth: 48)
            } minimal: {
                ZoeMascotView(settings: look, expression: st.mood, animated: false, showsAccessory: false)
                    .frame(width: 22)
            }
            .keylineTint(Color(hex: look.color))
        }
    }
}

private func title(_ st: ZoeTimerAttributes.ContentState, name: String) -> String {
    let focus = st.label == "Focus"
    if st.finished { return focus ? "Focus finito! ☕" : "Tempo scaduto! ⏰" }
    return focus ? "\(name) · Focus" : (st.label == "Timer" ? "\(name) · Timer" : st.label)
}

private struct Countdown: View {
    let state: ZoeTimerAttributes.ContentState
    var body: some View {
        if state.finished || state.end <= state.start {
            Text("Fatto!")
        } else {
            Text(timerInterval: state.start...state.end, countsDown: true)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct TimerBar: View {
    let state: ZoeTimerAttributes.ContentState
    let tint: Color
    var body: some View {
        if state.finished || state.end <= state.start {
            ProgressView(value: 1).tint(tint)
        } else {
            ProgressView(timerInterval: state.start...state.end, countsDown: false,
                         label: { EmptyView() }, currentValueLabel: { EmptyView() })
                .tint(tint)
        }
    }
}

private struct LockScreenTimerView: View {
    let context: ActivityViewContext<ZoeTimerAttributes>
    var body: some View {
        let st = context.state
        let look = context.attributes.settings
        HStack(spacing: 14) {
            ZoeMascotView(settings: look, expression: st.mood, animated: false)
                .frame(width: 72)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title(st, name: look.name)).font(.headline).foregroundStyle(.white).lineLimit(1)
                    Spacer(minLength: 0)
                    Countdown(state: st)
                        .font(.title2.weight(.bold).monospacedDigit())
                        .foregroundStyle(Color(hex: "#3ee0b0"))
                        .frame(maxWidth: 120, alignment: .trailing)
                }
                HStack(spacing: 10) {
                    TimerBar(state: st, tint: Color(hex: look.color))
                    if !st.finished {
                        Button(intent: StopTimerIntent()) {
                            Image(systemName: "xmark").font(.caption.weight(.bold))
                        }
                        .tint(Color(hex: look.color))
                        .accessibilityLabel("Ferma il timer")
                    }
                }
            }
        }
        .padding(16)
    }
}

#Preview("Isola espansa", as: .dynamicIsland(.expanded), using: ZoeTimerAttributes(settings: ZoeSettings())) {
    ZoeTimerLiveActivity()
} contentStates: {
    ZoeTimerAttributes.ContentState(start: .now, end: .now.addingTimeInterval(25 * 60), label: "Focus", expression: "pensierosa")
}
