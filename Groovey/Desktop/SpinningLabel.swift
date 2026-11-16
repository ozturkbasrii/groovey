import AppKit
import Combine
import SwiftUI

/// The record's turning label, drawn as a Core Animation layer on top of the SwiftUI scene.
///
/// Rotating it inside SwiftUI would redraw the whole full-screen scene thirty times a
/// second. As a layer the rotation runs in the window server and costs the app nothing.
final class SpinningLabelView: NSView {
    private let squashLayer = CALayer()
    private let rotor = CALayer()
    private let spindle = CALayer()
    private var spinning = false

    /// Seconds per turn at 33⅓ rpm.
    private static let period: CFTimeInterval = 1.8

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false

        rotor.masksToBounds = true
        rotor.contentsGravity = .resizeAspectFill
        rotor.borderColor = NSColor.black.withAlphaComponent(0.55).cgColor
        spindle.backgroundColor = NSColor(white: 0.82, alpha: 1).cgColor
        spindle.borderColor = NSColor(white: 0.45, alpha: 1).cgColor

        squashLayer.addSublayer(rotor)
        squashLayer.addSublayer(spindle)
        layer?.addSublayer(squashLayer)
        rotor.speed = 0
        addRotation()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Layers drop their animations when they leave a window.
        if window != nil { addRotation() }
    }

    private func addRotation() {
        guard rotor.animation(forKey: "spin") == nil else { return }
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = -2 * Double.pi   // clockwise on screen
        rotation.duration = Self.period
        rotation.repeatCount = .infinity
        rotation.isRemovedOnCompletion = false
        rotor.add(rotation, forKey: "spin")
    }

    /// Places the label. `squash` is the vertical foreshortening of the turntable (1 when seen from straight above).
    func layout(diameter: CGFloat, squash: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let square = CGRect(x: 0, y: 0, width: diameter, height: diameter)
        squashLayer.bounds = square
        squashLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        squashLayer.setAffineTransform(CGAffineTransform(scaleX: 1, y: squash))

        rotor.bounds = square
        rotor.position = CGPoint(x: square.midX, y: square.midY)
        rotor.cornerRadius = diameter / 2
        rotor.borderWidth = max(1, diameter * 0.012)

        let hub = diameter * 0.085
        spindle.bounds = CGRect(x: 0, y: 0, width: hub, height: hub)
        spindle.position = rotor.position
        spindle.cornerRadius = hub / 2
        spindle.borderWidth = max(0.5, hub * 0.08)
        CATransaction.commit()
    }

    func setImage(_ image: CGImage?) {
        // A frozen layer cannot run a cross-fade, so only fade while turning.
        if spinning {
            let fade = CATransition()
            fade.type = .fade
            fade.duration = 0.8
            squashLayer.add(fade, forKey: "fade")
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        rotor.contents = image
        CATransaction.commit()
    }

    func setSpinning(_ shouldSpin: Bool) {
        guard shouldSpin != spinning else { return }
        spinning = shouldSpin
        if shouldSpin {
            let pausedAt = rotor.timeOffset
            rotor.speed = 1
            rotor.timeOffset = 0
            rotor.beginTime = 0
            rotor.beginTime = rotor.convertTime(CACurrentMediaTime(), from: nil) - pausedAt
        } else {
            let now = rotor.convertTime(CACurrentMediaTime(), from: nil)
            rotor.speed = 0
            rotor.timeOffset = now
        }
    }
}

/// Keeps one window's spinning label in step with the song, theme and window size.
final class LabelOverlay {
    let view = SpinningLabelView(frame: .zero)

    private unowned let model: AppModel
    private weak var container: NSView?
    private let state: WindowState
    private var cancellable: AnyCancellable?
    private var imageKey: String?

    init(model: AppModel, state: WindowState, container: NSView) {
        self.model = model
        self.state = state
        self.container = container
        container.addSubview(view)

        cancellable = Publishers.Merge4(
            model.nowPlaying.objectWillChange, model.settings.objectWillChange,
            state.objectWillChange, model.power.objectWillChange
        )
        // objectWillChange fires before the new values are in place; read them on the next turn.
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in self?.refresh() }
        refresh()
    }

    func refresh() {
        guard let container else { return }
        let placement = StageLayout.label(theme: model.settings.theme, in: container.bounds.size)
        let height = placement.diameter * placement.squash
        // AppKit's origin is bottom-left; the stage is laid out from the top.
        view.frame = CGRect(
            x: placement.center.x - placement.diameter / 2,
            y: container.bounds.height - placement.center.y - height / 2,
            width: placement.diameter, height: height
        )
        view.layout(diameter: placement.diameter, squash: placement.squash)

        let nowPlaying = model.nowPlaying
        let track = nowPlaying.track
        let key = "\(track?.id ?? "")|\(nowPlaying.artwork == nil ? "plain" : "art")|\(nowPlaying.palette.accent.description)"
        if key != imageKey {
            imageKey = key
            // Always reached on the main queue (init and the main-queue sink above).
            let image = MainActor.assumeIsolated {
                RecordLabel.image(artwork: nowPlaying.artwork, accent: nowPlaying.palette.accent)
            }
            view.setImage(image)
        }
        view.setSpinning((track?.isPlaying ?? false) && state.isVisible && model.power.displaysAwake)
    }
}
