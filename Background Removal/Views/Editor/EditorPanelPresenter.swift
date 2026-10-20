//
//  EditorPanelPresenter.swift
//  Background Removal
//
//  One presentation system for every editor tool panel (Background, Text, Refine, Shadow,
//  Resize) in RemovingBackgroundEditorVC and TextBehindSubjectVC.
//
//  Open:   the bottom tool bar is hidden; a full-width container anchored to the bottom of the
//          screen slides up; the panel inside it ends at the bottom safe area (and stays above
//          the keyboard); the canvas takes the space above it.
//  Switch: the panel inside the container is replaced – the tool bar stays hidden and nothing
//          else moves.
//  Close:  the container slides down and the tool bar and normal canvas layout come back.
//
//  The panel's height never depends on its own safe-area insets (the panel itself never
//  reaches the home-indicator area; the container's background fills that part).
//

import UIKit

final class EditorPanelPresenter {

    private weak var rootView: UIView?
    private let toolbar: UIView
    private let canvas: UIView
    /// The canvas → tool bar constraint used when no panel is open.
    private let normalCanvasBottom: NSLayoutConstraint
    /// Views hidden together with the tool bar (e.g. the thumbnail strip).
    private let alsoHidden: [UIView]
    /// Respect the keyboard (panels with text input).
    private let followsKeyboard: Bool

    private let container = UIView()
    private(set) var panel: UIView?
    private var containerConstraints: [NSLayoutConstraint] = []
    private var panelConstraints: [NSLayoutConstraint] = []
    /// Hidden state of `alsoHidden` views before a panel opened (restored exactly on close).
    private var hiddenBeforeShowing: [ObjectIdentifier: Bool] = [:]

    var isOpen: Bool { panel != nil }

    init(rootView: UIView, toolbar: UIView, canvas: UIView, normalCanvasBottom: NSLayoutConstraint,
         alsoHidden: [UIView] = [], followsKeyboard: Bool) {
        self.rootView = rootView
        self.toolbar = toolbar
        self.canvas = canvas
        self.normalCanvasBottom = normalCanvasBottom
        self.alsoHidden = alsoHidden
        self.followsKeyboard = followsKeyboard

        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = UIColor(named: "Surface Color") ?? .systemBackground
        container.layer.cornerRadius = 32
        container.layer.cornerCurve = .continuous
        container.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowRadius = 16
        container.layer.shadowOffset = CGSize(width: 0, height: -6)
    }

    /// Shows `panel`, replacing the current one if a panel is already open.
    /// - Parameter preferredHeight: for panels without an intrinsic height (scrolling content).
    func show(_ panel: UIView, preferredHeight: CGFloat?) {
        guard let rootView else { return }
        // Also counts as replacing when a close animation is still running.
        let replacing = isOpen || container.superview != nil
        if replacing {
            container.layer.removeAllAnimations()
            container.transform = .identity
        }
        if let old = self.panel {
            NSLayoutConstraint.deactivate(panelConstraints)
            panelConstraints = []
            old.removeFromSuperview()
        }

        // The container draws the rounded corners, background and shadow.
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.backgroundColor = .clear
        panel.layer.cornerRadius = 0
        panel.layer.shadowOpacity = 0
        // The container must be in the screen's hierarchy before the panel is constrained to
        // the screen's safe area / keyboard guide (otherwise: "no common ancestor" crash).
        if container.superview == nil { rootView.addSubview(container) }
        container.addSubview(panel)
        self.panel = panel

        let safe = rootView.safeAreaLayoutGuide
        var constraints = [
            panel.topAnchor.constraint(equalTo: container.topAnchor),
            panel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            panel.heightAnchor.constraint(greaterThanOrEqualToConstant: 150)
        ]
        // Ends at the bottom safe area; above the keyboard while typing.
        if followsKeyboard {
            let atSafeBottom = panel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -4)
            atSafeBottom.priority = UILayoutPriority(740)
            constraints += [
                atSafeBottom,
                panel.bottomAnchor.constraint(lessThanOrEqualTo: safe.bottomAnchor, constant: -4),
                panel.bottomAnchor.constraint(lessThanOrEqualTo: rootView.keyboardLayoutGuide.topAnchor, constant: -4)
            ]
        } else {
            constraints.append(panel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -4))
        }
        if let preferredHeight {
            let preferred = panel.heightAnchor.constraint(equalToConstant: preferredHeight)
            preferred.priority = .defaultHigh
            constraints.append(preferred)
        }
        // Never more than 60% of the screen (the canvas keeps the rest).
        let maxHeight = panel.heightAnchor.constraint(lessThanOrEqualTo: rootView.heightAnchor, multiplier: 0.6)
        maxHeight.priority = UILayoutPriority(999)
        constraints.append(maxHeight)
        panelConstraints = constraints
        NSLayoutConstraint.activate(panelConstraints)

        if replacing {
            if normalCanvasBottom.isActive {
                // Opened while the previous panel was still closing: back to the editing layout.
                normalCanvasBottom.isActive = false
                NSLayoutConstraint.activate(containerConstraints)
                toolbar.isHidden = true
                toolbar.alpha = 1
                alsoHidden.forEach { $0.isHidden = true }
            }
            // Same container, new content: no slide, the tool bar stays hidden.
            UIView.performWithoutAnimation { rootView.layoutIfNeeded() }
            panel.alpha = 0
            UIView.animate(withDuration: 0.15) { panel.alpha = 1 }
            return
        }

        containerConstraints = [
            container.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),
            canvas.bottomAnchor.constraint(equalTo: container.topAnchor, constant: -8)
        ]
        normalCanvasBottom.isActive = false
        NSLayoutConstraint.activate(containerConstraints)
        toolbar.isHidden = true
        hiddenBeforeShowing = Dictionary(uniqueKeysWithValues: alsoHidden.map { (ObjectIdentifier($0), $0.isHidden) })
        alsoHidden.forEach { $0.isHidden = true }

        // Final layout first, then slide the container up from the bottom.
        UIView.performWithoutAnimation { rootView.layoutIfNeeded() }
        container.transform = CGAffineTransform(translationX: 0, y: container.bounds.height)
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.92, initialSpringVelocity: 0) {
            self.container.transform = .identity
        }
        UIAccessibility.post(notification: .screenChanged, argument: panel)
    }

    /// Slides the panel down and restores the tool bar and normal canvas layout.
    ///
    /// The normal layout is restored by re-activating the storyboard's canvas constraint – the
    /// same one used before any panel opened – so Auto Layout recomputes the full canvas size
    /// (never derived from the reduced size). The canvas grows while the panel slides away, so
    /// both animations end in the same, final state.
    func dismiss(animated: Bool = true) {
        guard let rootView, let panel else { return }
        self.panel = nil

        // 1. Back to the normal layout state (one constraint swap, nothing is recreated).
        NSLayoutConstraint.deactivate(containerConstraints.filter { $0.firstItem === canvas || $0.secondItem === canvas })
        normalCanvasBottom.isActive = true
        toolbar.isHidden = false
        for view in alsoHidden { view.isHidden = hiddenBeforeShowing[ObjectIdentifier(view)] ?? false }

        let finish = { [weak self] in
            // A new panel was shown while closing: keep the container.
            guard let self, self.panel == nil else { return }
            NSLayoutConstraint.deactivate(self.panelConstraints + self.containerConstraints)
            self.panelConstraints = []
            self.containerConstraints = []
            panel.removeFromSuperview()
            self.container.removeFromSuperview()
            self.container.transform = .identity
            rootView.layoutIfNeeded()
        }
        guard animated else {
            rootView.layoutIfNeeded()
            finish()
            return
        }
        toolbar.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut], animations: {
            // 2. Canvas grows back while the panel slides down.
            self.container.transform = CGAffineTransform(translationX: 0, y: self.container.bounds.height)
            self.toolbar.alpha = 1
            rootView.layoutIfNeeded()
        }, completion: { _ in
            // 3. Remove the panel once it is off screen.
            finish()
        })
    }
}
