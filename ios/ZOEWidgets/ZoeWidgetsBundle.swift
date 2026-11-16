import SwiftUI
import WidgetKit

/// L'estensione dei widget: il widget di ZOE (Home e schermata di blocco) e la Live Activity del timer.
@main
struct ZoeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ZoeWidget()
        ZoeTimerLiveActivity()
    }
}
