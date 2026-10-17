//
//  EditSession.swift
//  Background Removal
//
//  The photo being edited: original, matte, edits, cached cutout and undo/redo.
//

import UIKit

final class EditSession {

    private struct State {
        var mask: CGImage
        var spec: EditSpec
    }

    let original: UIImage
    var name: String
    private(set) var cutout: UIImage
    /// Photo backgrounds referenced by `BackgroundSpec.photo(id:)`.
    var photos: [String: UIImage] = [:]
    var photoOrder: [String] = []

    private var state: State
    private var undoStack: [State] = []
    private var redoStack: [State] = []

    var onChange: (() -> Void)?

    init(original: UIImage, mask: CGImage, name: String = "Cutout") {
        self.original = original
        self.name = name
        self.state = State(mask: mask, spec: EditSpec())
        self.cutout = Self.makeCutout(original: original, mask: mask)
    }

    var spec: EditSpec { state.spec }
    var mask: CGImage { state.mask }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var pixelSize: CGSize {
        CGSize(width: original.size.width * original.scale, height: original.size.height * original.scale)
    }

    func apply(spec newSpec: EditSpec) {
        guard newSpec != state.spec else { return }
        commit(State(mask: state.mask, spec: newSpec))
    }

    func apply(mask newMask: CGImage) {
        commit(State(mask: newMask, spec: state.spec))
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(state)
        set(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(state)
        set(next)
    }

    @discardableResult
    func addPhoto(_ image: UIImage) -> String {
        let id = UUID().uuidString
        photos[id] = BGRemovalEngine.normalized(image, maxDimension: 2048)
        photoOrder.insert(id, at: 0)
        return id
    }

    func render(options: EditRenderer.Options = EditRenderer.Options()) -> UIImage {
        EditRenderer.render(session: self, options: options)
    }

    private func commit(_ newState: State) {
        undoStack.append(state)
        if undoStack.count > 40 { undoStack.removeFirst() }
        redoStack.removeAll()
        set(newState)
    }

    private func set(_ newState: State) {
        let maskChanged = newState.mask !== state.mask
        state = newState
        if maskChanged { cutout = Self.makeCutout(original: original, mask: newState.mask) }
        onChange?()
    }

    private static func makeCutout(original: UIImage, mask: CGImage) -> UIImage {
        guard let cg = original.cgImage, let cut = BGRemovalEngine.cutout(original: cg, mask: mask) else { return original }
        return UIImage(cgImage: cut)
    }
}
