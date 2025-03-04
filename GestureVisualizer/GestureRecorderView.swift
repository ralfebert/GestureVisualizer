import SwiftUI

struct TouchState: Codable, Equatable {
    let touches: [TouchPoint]
}

struct TouchPoint: Identifiable, Comparable, Equatable, Codable {
    let id: Int
    let timestamp: TimeInterval
    let location: CGPoint

    private var compareValues: (Int, CGFloat, CGFloat) {
        return (id, location.x, location.y)
    }

    static func < (lhs: TouchPoint, rhs: TouchPoint) -> Bool {
        return lhs.compareValues < rhs.compareValues
    }

    static func == (lhs: TouchPoint, rhs: TouchPoint) -> Bool {
        return lhs.compareValues == rhs.compareValues
    }
}

struct TouchPaths {
    let paths: [Int: [TouchPoint]]

    init(history: [TouchState]) {
        self.paths = Dictionary(grouping: history.flatMap { $0.touches }, by: { $0.id })
    }
}

struct GestureRecorderView: View {
    @State var history: [TouchState] = []

    let colors = [Color.red, .blue, .green, .orange, .pink, .purple, .brown, .cyan]

    var body: some View {
        ZStack {
            TouchRecorderUIView(events: $history)
                .ignoresSafeArea()

            Canvas { context, size in
                // Draw touch paths (history)
                let touchPaths = TouchPaths(history: history)
                for (id, touchPoints) in touchPaths.paths.sorted(by: { $0.key < $1.key }) {
                    let color = colors[id % colors.count]

                    // Draw the path line connecting all points
                    if touchPoints.count > 1 {
                        var path = Path()
                        path.move(to: touchPoints[0].location)
                        for point in touchPoints.dropFirst() {
                            path.addLine(to: point.location)
                        }
                        context.stroke(path, with: .color(color), lineWidth: 0.5)
                    }

                    // Draw small dots at each touch point
                    for point in touchPoints {
                        context.fill(
                            Path(
                                ellipseIn: CGRect(origin: point.location, size: .zero).insetBy(
                                    dx: -3, dy: -3)),
                            with: .color(color)
                        )
                    }
                }
                
                // Draw current touches
                if let event = history.last {
                    for touch in event.touches {
                        context.fill(
                            Path(
                                ellipseIn: CGRect(origin: touch.location, size: .zero).insetBy(
                                    dx: -50, dy: -50)),
                            with: .color(colors[touch.id % colors.count].opacity(0.5)))
                    }
                }

            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onChange(of: history) {
            if let lastEvent = history.last, lastEvent.touches.isEmpty {
                let jsonEncoder = JSONEncoder()
                jsonEncoder.outputFormatting = .prettyPrinted
                print(String(data: try! jsonEncoder.encode(history), encoding: .utf8)!)
            }
        }
    }
}

struct TouchRecorderUIView: UIViewRepresentable {
    @Binding var events: [TouchState]

    func makeUIView(context: Context) -> UIView {
        let view = GestureRecorderUIView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.touchesChanged = { touchEvent in
            if let lastEvent = self.events.last, lastEvent.touches.isEmpty {
                self.events.removeAll()
            }
            self.events.append(touchEvent)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

}

class GestureRecorderUIView: UIView {
    private var touches: Set<UITouch> = [] {
        didSet {
            // Clean up ids dictionary to only keep entries for current touches
            if touches.isEmpty {
                ids.removeAll()
            }

            let event = TouchState(
                touches: touches.map { touch in
                    let touchId = ObjectIdentifier(touch)
                    let id: Int
                    if let existingId = ids[touchId] {
                        id = existingId
                    } else {
                        id = ids.values.max().map { $0 + 1 } ?? 0
                        ids[touchId] = id
                    }
                    return TouchPoint(
                        id: id, timestamp: touch.timestamp, location: touch.location(in: self))
                }
            )

            self.touchesChanged?(event)
        }
    }

    var touchesChanged: ((TouchState) -> Void)?
    var ids = [ObjectIdentifier: Int]()

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.touches.formUnion(touches)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        self.touches.formUnion(touches)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        self.touches.subtract(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        self.touches.subtract(touches)
    }
}

#Preview {
    GestureRecorderView()
}
