import AppKit
import SwiftUI

struct ScrollWheelReceiver: NSViewRepresentable {
    let onScroll: (CGFloat) -> Void

    func makeNSView(context: Context) -> ReceiverView {
        let view = ReceiverView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ view: ReceiverView, context: Context) {
        view.onScroll = onScroll
    }

    final class ReceiverView: NSView {
        var onScroll: ((CGFloat) -> Void)?

        override func scrollWheel(with event: NSEvent) {
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 6
            onScroll?(delta)
        }
    }
}
