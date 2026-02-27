import AppKit
import SwiftUI

struct TetrisKeyCaptureView: NSViewRepresentable {
    let onControl: (TetrisControlAction) -> Void

    func makeNSView(context: Context) -> TetrisKeyCaptureNSView {
        let view = TetrisKeyCaptureNSView()
        view.onControl = onControl
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: TetrisKeyCaptureNSView, context: Context) {
        nsView.onControl = onControl
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

final class TetrisKeyCaptureNSView: NSView {
    var onControl: ((TetrisControlAction) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let action = map(event.keyCode) else {
            super.keyDown(with: event)
            return
        }
        onControl?(action)
    }

    private func map(_ keyCode: UInt16) -> TetrisControlAction? {
        switch keyCode {
        case 123:
            return .left
        case 124:
            return .right
        case 125:
            return .down
        case 36, 76:
            return .rotate
        case 49:
            return .hardDrop
        default:
            return nil
        }
    }
}
