//
//  TBEditorSession.swift
//  Background Removal
//
//  Editing state shared by TextBehindSubjectVC and its tool panels: the document, the
//  selected text layer and undo / redo. Undo stores document snapshots (small value types),
//  never rendered images.
//
//  • `change(live:)` – preview while a slider moves / a finger drags (no undo step yet).
//  • `commit()`     – ends the edit: one undo step for everything since the last commit.
//

import UIKit

final class TBEditorSession {

    private(set) var document: TextBehindDocument
    var selectedTextID: UUID? {
        didSet { if oldValue != selectedTextID { onSelectionChange?() } }
    }

    /// Re-render request. `final` = the edit is finished (render at full preview quality).
    var onChange: ((_ final: Bool) -> Void)?
    var onSelectionChange: (() -> Void)?
    /// Persist after each committed step.
    var onCommit: ((TextBehindDocument) -> Void)?

    private var pendingBase: TextBehindDocument?
    private(set) var undoStack: [TextBehindDocument] = []
    private(set) var redoStack: [TextBehindDocument] = []
    private let historyLimit = 60

    init(document: TextBehindDocument) {
        self.document = document
        selectedTextID = document.texts.last?.id
    }

    var selectedText: TextLayerModel? { document.text(selectedTextID) }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Editing

    /// Applies a change. `commit: true` records it as one undo step right away.
    func change(commit: Bool = true, _ mutation: (inout TextBehindDocument) -> Void) {
        if pendingBase == nil { pendingBase = document }
        mutation(&document)
        if commit {
            self.commit()
        } else {
            onChange?(false)
        }
    }

    /// Changes the selected text layer (ignored when it is locked, unless `force`).
    func changeSelectedText(commit: Bool = true, force: Bool = false, _ mutation: (inout TextLayerModel) -> Void) {
        guard let id = selectedTextID, let index = document.texts.firstIndex(where: { $0.id == id }),
              force || !document.texts[index].isLocked else { return }
        change(commit: commit) { mutation(&$0.texts[index]) }
    }

    /// Finishes the current edit as one undo step.
    func commit() {
        guard let base = pendingBase else { return }
        pendingBase = nil
        if base != document {
            undoStack.append(base)
            if undoStack.count > historyLimit { undoStack.removeFirst() }
            redoStack.removeAll()
            onCommit?(document)
        }
        onChange?(true)
    }

    /// Restores a state without recording it (used by ✕ on a panel).
    func revert(to snapshot: TextBehindDocument, undoCount: Int) {
        pendingBase = nil
        document = snapshot
        if undoStack.count > undoCount { undoStack.removeSubrange(undoCount...) }
        if document.text(selectedTextID) == nil { selectedTextID = document.texts.last?.id }
        onCommit?(document)
        onChange?(true)
    }

    func undo() {
        commit()
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(document)
        document = previous
        if document.text(selectedTextID) == nil { selectedTextID = document.texts.last?.id }
        onCommit?(document)
        onChange?(true)
    }

    func redo() {
        commit()
        guard let next = redoStack.popLast() else { return }
        undoStack.append(document)
        document = next
        if document.text(selectedTextID) == nil { selectedTextID = document.texts.last?.id }
        onCommit?(document)
        onChange?(true)
    }

    // MARK: - Text layers

    func addText() {
        let number = document.texts.count + 1
        var layer = TextLayerModel(name: "Text \(number)")
        layer.centerY = min(0.8, 0.2 + 0.1 * Double(document.texts.count % 6))
        if let recent = EditorRecents.fonts.first { layer.fontName = recent }
        change { $0.texts.append(layer) }
        selectedTextID = layer.id
    }

    func duplicateSelectedText() {
        guard let source = selectedText else { return }
        var copy = source
        copy.id = UUID()
        copy.name = source.name + " copy"
        copy.centerX = min(0.95, source.centerX + 0.04)
        copy.centerY = min(0.95, source.centerY + 0.04)
        copy.isLocked = false
        change {
            let index = ($0.texts.firstIndex { $0.id == source.id } ?? $0.texts.count - 1) + 1
            $0.texts.insert(copy, at: index)
        }
        selectedTextID = copy.id
    }

    func deleteText(_ id: UUID) {
        change { $0.texts.removeAll { $0.id == id } }
        if selectedTextID == id { selectedTextID = document.texts.last?.id }
    }

    /// Moves a text layer forward (+1) or backward (-1) among the text layers. The subject
    /// always stays between "behind" and "in front" texts.
    func moveText(_ id: UUID, by delta: Int) {
        guard let index = document.texts.firstIndex(where: { $0.id == id }) else { return }
        let target = index + delta
        guard document.texts.indices.contains(target) else { return }
        change { $0.texts.swapAt(index, target) }
    }
}

/// What the panels need from the editor screen.
protocol TBPanelHost: AnyObject {
    var session: TBEditorSession { get }
    var viewModel: BackgroundRemovalViewModel! { get }
    var itemID: UUID! { get }
    func presentColorPicker(initial: UIColor, completion: @escaping (UIColor) -> Void)
    func presentBackgroundPhotoPicker()
    func openMaskBrush()
    func setMaskPreview(_ enabled: Bool)
    func showMessage(_ title: String, _ message: String)
    func confirm(_ title: String, _ message: String, action: String, completion: @escaping () -> Void)
    func promptText(_ title: String, initial: String, completion: @escaping (String) -> Void)
}
