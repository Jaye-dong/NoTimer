import SwiftUI
import WidgetKit

@main
struct NoTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        CurrentTimerWidget()
        TimerLiveActivity()
    }
}
