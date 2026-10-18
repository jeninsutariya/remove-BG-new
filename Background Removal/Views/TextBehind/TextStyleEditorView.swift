//
//  TextStyleEditorView.swift
//  Background Removal
//
//  Text tool: multiple text layers, each edited independently.
//  • Edit   – multiline text, add / duplicate / delete, alignment, capitalization
//  • Font   – every installed family and face (searchable), recently used fonts
//  • Size   – size, rotation, letter & line spacing, width, position
//  • Style  – bold / italic / underline / strikethrough, outline, highlight, blend mode
//  • Color  – solid (presets, recents, picker, hex) or gradient fill, opacity
//  • Layers – select, show / hide, lock, behind / in front of the subject, order, rename
//

import UIKit

final class TextStyleEditorView: TBPanelView, UITextViewDelegate, UITableViewDataSource, UITableViewDelegate,
                                 UITextFieldDelegate {

    private enum Tab: Int, CaseIterable {
        case edit, font, size, style, color, layers
        var title: String {
            switch self {
            case .edit: return "Edit"
            case .font: return "Font"
            case .size: return "Size"
            case .style: return "Style"
            case .color: return "Color"
            case .layers: return "Layers"
            }
        }
    }

    override var preferredHeight: CGFloat { 360 }

    private let layerStrip = TBChipStrip([])
    private let addButton = TBStyle.button("Add", symbol: "plus", filled: true)
    private let tabs = TBStyle.segmented(Tab.allCases.map(\.title))
    private let emptyLabel = TBStyle.label("Add a text layer to start.", size: 14, weight: .regular, color: TBStyle.secondary)
    private var sections: [Tab: UIStackView] = [:]

    // Edit
    private let textView = UITextView()
    private let alignmentControl = UISegmentedControl(items: [
        UIImage(systemName: "text.alignleft") as Any, UIImage(systemName: "text.aligncenter") as Any,
        UIImage(systemName: "text.alignright") as Any])
    private let caseControl = TBStyle.segmented(TBCapitalization.allCases.map(\.title))

    // Font
    private let searchField = UITextField()
    private let recentFonts = TBChipStrip([])
    private let familyTable = UITableView(frame: .zero, style: .plain)
    private let faceStrip = TBChipStrip([])
    private var filteredFamilies: [FontFamily] = FontCatalog.families
    private var recentFontNames: [String] = []
    private var shownFaces: [FontFace] = []

    // Size
    private let sizeRow = TBSliderRow("Font size", min: 30, max: 700)
    private let rotationRow = TBSliderRow("Rotation", min: -180, max: 180) { "\(Int($0.rounded()))°" }
    private let letterRow = TBSliderRow("Character spacing", min: -0.1, max: 0.6) { String(format: "%.2f", $0) }
    private let lineRow = TBSliderRow("Line spacing", min: 0.6, max: 2.5) { String(format: "%.2f", $0) }
    private let widthRow = TBSliderRow("Text width", min: 0.2, max: 1.0) { "\(Int(($0 * 100).rounded()))%" }
    private let xRow = TBSliderRow("Horizontal position", min: 0, max: 1) { "\(Int(($0 * 100).rounded()))%" }
    private let yRow = TBSliderRow("Vertical position", min: 0, max: 1) { "\(Int(($0 * 100).rounded()))%" }

    // Style
    private let styleChips = TBChipStrip(["Bold", "Italic", "Underline", "Strikethrough"], multiSelect: true)
    private let strokeSwitch = TBSwitchRow("Outline")
    private let strokeColors = TBColorStrip(showsHexField: false)
    private let strokeWidthRow = TBSliderRow("Outline width", min: 1, max: 40)
    private let highlightSwitch = TBSwitchRow("Highlight behind text")
    private let highlightColors = TBColorStrip(showsHexField: false)
    private let blendChips = TBChipStrip(TBBlendMode.allCases.map(\.title))

    // Color
    private let fillControl = TBStyle.segmented(["Solid", "Gradient"])
    private let fillColors = TBColorStrip()
    private let fillGradient = TBGradientEditor()
    private let opacityRow = TBSliderRow("Opacity", min: 0, max: 100) { "\(Int($0.rounded()))%" }

    // Layers
    private let layersTable = UITableView(frame: .zero, style: .plain)

    init(host: TBPanelHost) {
        super.init(title: "Text", host: host)
        build()
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private var selected: TextLayerModel? { session?.selectedText }

    // MARK: - Build

    private func build() {
        addButton.accessibilityLabel = "Add text"
        addButton.addAction(UIAction { [weak self] _ in
            self?.session?.addText()
            self?.refresh()
            self?.tabs.selectedSegmentIndex = Tab.edit.rawValue
            self?.showTab(.edit)
            self?.textView.becomeFirstResponder()
            self?.textView.selectAll(nil)
        }, for: .touchUpInside)
        layerStrip.onSelect = { [weak self] index in
            guard let self, let texts = self.session?.document.texts, texts.indices.contains(index) else { return }
            self.session?.selectedTextID = texts[index].id
            self.refresh()
        }
        tabs.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        emptyLabel.textAlignment = .center

        content.addArrangedSubview(TBStyle.hStack([layerStrip, addButton]))
        content.addArrangedSubview(tabs)
        content.addArrangedSubview(emptyLabel)
        sections[.edit] = buildEdit()
        sections[.font] = buildFont()
        sections[.size] = buildSize()
        sections[.style] = buildStyle()
        sections[.color] = buildColor()
        sections[.layers] = buildLayers()
        for tab in Tab.allCases { if let section = sections[tab] { content.addArrangedSubview(section) } }
        showTab(.edit)
    }

    private func buildEdit() -> UIStackView {
        textView.font = TBStyle.font(16, .medium)
        textView.textColor = TBStyle.text
        textView.backgroundColor = TBStyle.field
        textView.layer.cornerRadius = 12
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        textView.delegate = self
        textView.accessibilityLabel = "Text"
        textView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let doneBar = UIToolbar()
        doneBar.items = [UIBarButtonItem(systemItem: .flexibleSpace),
                         UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(endTextEditing))]
        doneBar.sizeToFit()
        textView.inputAccessoryView = doneBar

        alignmentControl.applyEditorStyle()
        alignmentControl.heightAnchor.constraint(equalToConstant: 34).isActive = true
        alignmentControl.addTarget(self, action: #selector(alignmentChanged), for: .valueChanged)
        caseControl.addTarget(self, action: #selector(caseChanged), for: .valueChanged)

        let duplicate = TBStyle.button("Duplicate", symbol: "plus.square.on.square")
        duplicate.addAction(UIAction { [weak self] _ in
            self?.session?.duplicateSelectedText()
            self?.refresh()
        }, for: .touchUpInside)
        let delete = TBStyle.button("Delete", symbol: "trash")
        delete.addAction(UIAction { [weak self] _ in self?.deleteSelected() }, for: .touchUpInside)

        return TBStyle.vStack([textView,
                               TBStyle.hStack([TBStyle.label("Align", size: 13), alignmentControl], spacing: 12),
                               TBStyle.hStack([TBStyle.label("Case", size: 13), caseControl], spacing: 18),
                               TBStyle.hStack([duplicate, delete, UIView()])])
    }

    private func buildFont() -> UIStackView {
        searchField.placeholder = "Search fonts"
        searchField.font = TBStyle.font(14, .medium)
        searchField.backgroundColor = TBStyle.field
        searchField.layer.cornerRadius = 10
        searchField.clearButtonMode = .whileEditing
        searchField.autocorrectionType = .no
        searchField.returnKeyType = .search
        searchField.delegate = self
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = TBStyle.secondary
        icon.contentMode = .center
        icon.frame = CGRect(x: 0, y: 0, width: 32, height: 20)
        searchField.leftView = icon
        searchField.leftViewMode = .always
        searchField.heightAnchor.constraint(equalToConstant: 36).isActive = true
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)

        recentFonts.onSelect = { [weak self] index in
            guard let self, self.recentFontNames.indices.contains(index) else { return }
            self.setFont(self.recentFontNames[index])
        }
        familyTable.dataSource = self
        familyTable.delegate = self
        familyTable.rowHeight = TBFontCell.height
        familyTable.backgroundColor = TBStyle.field
        familyTable.layer.cornerRadius = 12
        familyTable.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        familyTable.register(TBFontCell.self, forCellReuseIdentifier: TBFontCell.reuseIdentifier)
        familyTable.heightAnchor.constraint(equalToConstant: TBFontCell.height * 4).isActive = true
        faceStrip.onSelect = { [weak self] index in
            guard let self, self.shownFaces.indices.contains(index) else { return }
            self.setFont(self.shownFaces[index].postScriptName)
        }
        return TBStyle.vStack([searchField, TBStyle.label("Recently used", size: 12, color: TBStyle.secondary),
                               recentFonts, familyTable, TBStyle.label("Style", size: 12, color: TBStyle.secondary),
                               faceStrip], spacing: 8)
    }

    private func buildSize() -> UIStackView {
        let minus = TBStyle.button("", symbol: "minus")
        minus.accessibilityLabel = "Smaller"
        minus.addAction(UIAction { [weak self] _ in self?.stepSize(-10) }, for: .touchUpInside)
        let plus = TBStyle.button("", symbol: "plus")
        plus.accessibilityLabel = "Bigger"
        plus.addAction(UIAction { [weak self] _ in self?.stepSize(10) }, for: .touchUpInside)
        sizeRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.fontScale = Double(value) }
        }
        rotationRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.rotation = Double(value) }
        }
        letterRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.letterSpacing = Double(value) }
        }
        lineRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.lineSpacing = Double(value) }
        }
        widthRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.widthFraction = Double(value) }
        }
        xRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.centerX = Double(value) }
        }
        yRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.centerY = Double(value) }
        }
        let center = TBStyle.button("Center", symbol: "align.horizontal.center")
        center.addAction(UIAction { [weak self] _ in
            self?.session?.changeSelectedText { $0.centerX = 0.5 }
            self?.refresh()
        }, for: .touchUpInside)
        let straighten = TBStyle.button("Reset rotation", symbol: "arrow.counterclockwise")
        straighten.addAction(UIAction { [weak self] _ in
            self?.session?.changeSelectedText { $0.rotation = 0 }
            self?.refresh()
        }, for: .touchUpInside)
        return TBStyle.vStack([TBStyle.hStack([sizeRow, minus, plus]), rotationRow, letterRow, lineRow, widthRow,
                               xRow, yRow, TBStyle.hStack([center, straighten, UIView()])])
    }

    private func buildStyle() -> UIStackView {
        styleChips.onSelect = { [weak self] index in
            self?.session?.changeSelectedText {
                switch index {
                case 0: $0.bold.toggle()
                case 1: $0.italic.toggle()
                case 2: $0.underline.toggle()
                default: $0.strikethrough.toggle()
                }
            }
            self?.refresh()
        }
        strokeSwitch.onChange = { [weak self] on in
            self?.session?.changeSelectedText { $0.stroke.isOn = on }
            self?.refresh()
        }
        strokeColors.onSelect = { [weak self] hex in
            self?.session?.changeSelectedText { $0.stroke.hex = hex; $0.stroke.isOn = true }
            self?.refresh()
        }
        strokeColors.onCustom = { [weak self] in
            self?.host?.presentColorPicker(initial: .black) { self?.strokeColors.pickCustom($0) }
        }
        strokeWidthRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.stroke.width = Double(value) }
        }
        highlightSwitch.onChange = { [weak self] on in
            self?.session?.changeSelectedText { $0.highlight.isOn = on }
            self?.refresh()
        }
        highlightColors.onSelect = { [weak self] hex in
            self?.session?.changeSelectedText { $0.highlight.hex = hex; $0.highlight.isOn = true }
            self?.refresh()
        }
        highlightColors.onCustom = { [weak self] in
            self?.host?.presentColorPicker(initial: .yellow) { self?.highlightColors.pickCustom($0) }
        }
        blendChips.onSelect = { [weak self] index in
            self?.session?.changeSelectedText { $0.blendMode = TBBlendMode.allCases[index] }
        }
        return TBStyle.vStack([styleChips, strokeSwitch, strokeColors, strokeWidthRow, highlightSwitch, highlightColors,
                               TBStyle.label("Blend mode", size: 13), blendChips])
    }

    private func buildColor() -> UIStackView {
        fillControl.addTarget(self, action: #selector(fillTypeChanged), for: .valueChanged)
        fillColors.onSelect = { [weak self] hex in
            self?.session?.changeSelectedText { $0.fill = .solid(hex: hex) }
        }
        fillColors.onCustom = { [weak self] in
            self?.host?.presentColorPicker(initial: .white) { self?.fillColors.pickCustom($0) }
        }
        fillGradient.onChange = { [weak self] spec, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.fill = .gradient(spec) }
        }
        fillGradient.onPickStop = { [weak self] index, color in
            self?.host?.presentColorPicker(initial: color) { self?.fillGradient.setStop(index, color: $0) }
        }
        opacityRow.onChange = { [weak self] value, finished in
            self?.session?.changeSelectedText(commit: finished) { $0.opacity = Double(value) / 100 }
        }
        return TBStyle.vStack([fillControl, fillColors, fillGradient, opacityRow])
    }

    private func buildLayers() -> UIStackView {
        layersTable.dataSource = self
        layersTable.delegate = self
        layersTable.rowHeight = 48
        layersTable.backgroundColor = .clear
        layersTable.register(TBLayerCell.self, forCellReuseIdentifier: "layer")
        layersTable.heightAnchor.constraint(equalToConstant: 200).isActive = true
        let note = TBStyle.label("Behind = hidden by the subject. The subject always stays between “behind” and “front” texts.",
                                 size: 12, weight: .regular, color: TBStyle.secondary)
        note.numberOfLines = 0
        return TBStyle.vStack([layersTable, note], spacing: 6)
    }

    // MARK: - Refresh

    override func refresh() {
        guard let session else { return }
        let texts = session.document.texts
        layerStrip.setTitles(texts.map { $0.isHidden ? "\($0.name) (hidden)" : $0.name })
        if let index = texts.firstIndex(where: { $0.id == session.selectedTextID }) { layerStrip.setSelected([index]) }
        emptyLabel.isHidden = !texts.isEmpty
        tabs.isEnabled = !texts.isEmpty
        layersTable.reloadData()
        guard let layer = selected else {
            sections.values.forEach { $0.isHidden = true }
            return
        }
        showTab(Tab(rawValue: tabs.selectedSegmentIndex) ?? .edit)
        let editable = !layer.isLocked
        for tab in [Tab.edit, .font, .size, .style, .color] {
            sections[tab]?.isUserInteractionEnabled = editable
            sections[tab]?.alpha = editable ? 1 : 0.45
        }

        if !textView.isFirstResponder { textView.text = layer.text }
        alignmentControl.selectedSegmentIndex = TBTextAlignment.allCases.firstIndex(of: layer.alignment) ?? 1
        caseControl.selectedSegmentIndex = TBCapitalization.allCases.firstIndex(of: layer.capitalization) ?? 0

        recentFontNames = EditorRecents.fonts.filter { FontCatalog.face($0) != nil }
        recentFonts.setTitles(recentFontNames.isEmpty ? [] : recentFontNames.map(FontCatalog.displayName))
        if let index = recentFontNames.firstIndex(of: layer.fontName) { recentFonts.setSelected([index]) }
        let family = FontCatalog.family(containing: layer.fontName)
        shownFaces = family?.faces ?? []
        faceStrip.setTitles(shownFaces.map(\.styleName))
        if let index = shownFaces.firstIndex(where: { $0.postScriptName == layer.fontName }) { faceStrip.setSelected([index]) }
        // Update the visible rows' selection without reloading (keeps the scroll position).
        for case let cell as TBFontCell in familyTable.visibleCells {
            guard let indexPath = familyTable.indexPath(for: cell), filteredFamilies.indices.contains(indexPath.row) else { continue }
            let family = filteredFamilies[indexPath.row]
            cell.configure(family, selected: FontCatalog.family(containing: layer.fontName) == family)
        }

        sizeRow.value = Float(layer.fontScale)
        rotationRow.value = Float(layer.rotation)
        letterRow.value = Float(layer.letterSpacing)
        lineRow.value = Float(layer.lineSpacing)
        widthRow.value = Float(layer.widthFraction)
        xRow.value = Float(layer.centerX)
        yRow.value = Float(layer.centerY)

        var styles = Set<Int>()
        if layer.bold { styles.insert(0) }
        if layer.italic { styles.insert(1) }
        if layer.underline { styles.insert(2) }
        if layer.strikethrough { styles.insert(3) }
        styleChips.setSelected(styles)
        strokeSwitch.toggle.isOn = layer.stroke.isOn
        strokeColors.setSelected(layer.stroke.hex)
        strokeWidthRow.value = Float(layer.stroke.width)
        highlightSwitch.toggle.isOn = layer.highlight.isOn
        highlightColors.setSelected(layer.highlight.hex)
        blendChips.setSelected([TBBlendMode.allCases.firstIndex(of: layer.blendMode) ?? 0])

        switch layer.fill {
        case .solid(let hex):
            fillControl.selectedSegmentIndex = 0
            fillColors.setSelected(hex)
        case .gradient(let spec):
            fillControl.selectedSegmentIndex = 1
            fillGradient.configure(spec)
        }
        fillColors.isHidden = fillControl.selectedSegmentIndex != 0
        fillGradient.isHidden = fillControl.selectedSegmentIndex != 1
        opacityRow.value = Float(layer.opacity * 100)
    }

    private func showTab(_ tab: Tab) {
        for (key, section) in sections { section.isHidden = key != tab || selected == nil }
    }

    @objc private func tabChanged() {
        endEditing(true)
        let tab = Tab(rawValue: tabs.selectedSegmentIndex) ?? .edit
        showTab(tab)
        // Only when the Font tab is opened – never while the user scrolls and picks fonts.
        if tab == .font { scrollFontListToSelection() }
    }

    // MARK: - Actions

    private func deleteSelected() {
        guard let layer = selected else { return }
        host?.confirm("Delete “\(layer.name)”?", "You can undo this.", action: "Delete") { [weak self] in
            self?.session?.deleteText(layer.id)
            self?.refresh()
        }
    }

    @objc private func alignmentChanged() {
        let alignment = TBTextAlignment.allCases[max(0, alignmentControl.selectedSegmentIndex)]
        session?.changeSelectedText { $0.alignment = alignment }
    }

    @objc private func caseChanged() {
        let capitalization = TBCapitalization.allCases[max(0, caseControl.selectedSegmentIndex)]
        session?.changeSelectedText { $0.capitalization = capitalization }
    }

    @objc private func fillTypeChanged() {
        guard let layer = selected else { return }
        if fillControl.selectedSegmentIndex == 1 {
            if case .gradient = layer.fill { return }
            session?.changeSelectedText { $0.fill = .gradient(GradientSpec.presets[0]) }
        } else {
            if case .solid = layer.fill { return }
            session?.changeSelectedText { $0.fill = .solid(hex: "FFFFFF") }
        }
        refresh()
    }

    private func stepSize(_ delta: Double) {
        session?.changeSelectedText { $0.fontScale = min(700, max(30, $0.fontScale + delta)) }
        refresh()
    }

    private func setFont(_ postScriptName: String) {
        guard FontCatalog.face(postScriptName) != nil else {
            host?.showMessage("Font unavailable", "This font face can't be used on this device.")
            return
        }
        session?.changeSelectedText { $0.fontName = postScriptName }
        EditorRecents.add(font: postScriptName)
        refresh()
    }

    @objc private func endTextEditing() {
        textView.resignFirstResponder()
    }

    @objc private func searchChanged() {
        let query = (searchField.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        filteredFamilies = query.isEmpty ? FontCatalog.families
            : FontCatalog.families.filter { $0.name.lowercased().contains(query) }
        familyTable.reloadData()
    }

    private func scrollFontListToSelection() {
        guard let layer = selected, let family = FontCatalog.family(containing: layer.fontName),
              let row = filteredFamilies.firstIndex(of: family) else { return }
        familyTable.scrollToRow(at: IndexPath(row: row, section: 0), at: .middle, animated: false)
    }

    // MARK: - Text view

    func textViewDidChange(_ textView: UITextView) {
        session?.changeSelectedText(commit: false) { $0.text = textView.text }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        // Ending the keyboard keeps the text – it is committed as one undo step.
        session?.commit()
        refresh()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // MARK: - Tables (font families, layers)

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView == familyTable ? filteredFamilies.count : (session?.document.texts.count ?? 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == familyTable {
            let cell = tableView.dequeueReusableCell(withIdentifier: TBFontCell.reuseIdentifier, for: indexPath) as! TBFontCell
            let family = filteredFamilies[indexPath.row]
            let current = selected.flatMap { FontCatalog.family(containing: $0.fontName) }
            cell.configure(family, selected: current == family)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "layer", for: indexPath) as! TBLayerCell
        guard let session else { return cell }
        // Front-most first, in the order they are drawn.
        let layer = session.textsFrontToBack[indexPath.row]
        cell.configure(layer, selected: layer.id == session.selectedTextID)
        cell.onAction = { [weak self] action in self?.layerAction(action, layer: layer) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView == familyTable {
            setFont(filteredFamilies[indexPath.row].defaultFace.postScriptName)
            return
        }
        guard let session else { return }
        session.selectedTextID = session.textsFrontToBack[indexPath.row].id
        refresh()
    }

    private func layerAction(_ action: TBLayerCell.Action, layer: TextLayerModel) {
        guard let session else { return }
        let previous = session.selectedTextID
        session.selectedTextID = layer.id
        switch action {
        case .visibility:
            session.changeSelectedText(force: true) { $0.isHidden.toggle() }
        case .lock:
            session.changeSelectedText(force: true) { $0.isLocked.toggle() }
        case .placement:
            session.changeSelectedText { $0.isBehindSubject.toggle() }
        case .forward:
            session.moveText(layer.id, by: 1)
        case .backward:
            session.moveText(layer.id, by: -1)
        case .rename:
            session.selectedTextID = previous
            host?.promptText("Rename layer", initial: layer.name) { [weak self] name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                self?.session?.selectedTextID = layer.id
                self?.session?.changeSelectedText(force: true) { $0.name = trimmed }
                self?.refresh()
            }
            return
        }
        refresh()
    }
}

/// Font family row: the family name drawn in its own font (scaled down to fit, never
/// clipped), the number of styles and a selected checkmark.
final class TBFontCell: UITableViewCell {
    static let reuseIdentifier = "TBFontCell"
    static let height: CGFloat = 50

    private let previewLabel = UILabel()
    private let detailLabel = TBStyle.label("", size: 12, weight: .regular, color: TBStyle.secondary)
    private let checkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        previewLabel.textColor = TBStyle.text
        previewLabel.numberOfLines = 1
        previewLabel.adjustsFontSizeToFitWidth = true
        previewLabel.minimumScaleFactor = 0.5
        previewLabel.baselineAdjustment = .alignCenters
        previewLabel.lineBreakMode = .byTruncatingTail
        detailLabel.textAlignment = .right
        detailLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        detailLabel.setContentHuggingPriority(.required, for: .horizontal)
        checkView.tintColor = TBStyle.accent
        checkView.contentMode = .scaleAspectFit
        [previewLabel, detailLabel, checkView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }
        NSLayoutConstraint.activate([
            previewLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            previewLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            previewLabel.heightAnchor.constraint(lessThanOrEqualTo: contentView.heightAnchor, constant: -6),
            detailLabel.leadingAnchor.constraint(greaterThanOrEqualTo: previewLabel.trailingAnchor, constant: 8),
            detailLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkView.leadingAnchor.constraint(equalTo: detailLabel.trailingAnchor, constant: 8),
            checkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            checkView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkView.widthAnchor.constraint(equalToConstant: 20),
            checkView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ family: FontFamily, selected: Bool) {
        // Fall back to the app font when a face can't be created.
        let font = UIFont(name: family.defaultFace.postScriptName, size: 18) ?? TBStyle.font(16)
        previewLabel.font = font
        previewLabel.text = family.name
        detailLabel.text = family.faces.count > 1 ? "\(family.faces.count) styles" : "1 style"
        checkView.isHidden = !selected
        contentView.backgroundColor = selected ? TBStyle.accent.withAlphaComponent(0.08) : .clear
        accessibilityLabel = "\(family.name), \(detailLabel.text ?? "")"
        accessibilityTraits = selected ? [.button, .selected] : .button
    }
}

/// Row in the Layers list: a small preview of the text, its name, and fixed-size action icons.
final class TBLayerCell: UITableViewCell {
    enum Action { case visibility, lock, placement, forward, backward, rename }

    var onAction: ((Action) -> Void)?
    private let thumbnail = UIImageView()
    private let nameButton = UIButton(type: .system)
    private let eye = UIButton(type: .system)
    private let lock = UIButton(type: .system)
    private let placement = UIButton(type: .system)
    private let up = UIButton(type: .system)
    private let down = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        thumbnail.contentMode = .scaleAspectFit
        thumbnail.backgroundColor = TBStyle.field
        thumbnail.layer.cornerRadius = 8
        thumbnail.clipsToBounds = true
        nameButton.titleLabel?.font = TBStyle.font(14, .semibold)
        nameButton.titleLabel?.lineBreakMode = .byTruncatingTail
        nameButton.contentHorizontalAlignment = .leading
        nameButton.setTitleColor(TBStyle.text, for: .normal)
        placement.titleLabel?.font = TBStyle.font(12, .semibold)
        let items: [(UIButton, Action, String)] = [
            (nameButton, .rename, "Rename"), (eye, .visibility, "Show or hide"), (lock, .lock, "Lock or unlock"),
            (placement, .placement, "Behind or in front of the subject"), (up, .forward, "Move forward"),
            (down, .backward, "Move backward")]
        for (button, action, label) in items {
            button.accessibilityLabel = label
            button.tintColor = TBStyle.text
            button.addAction(UIAction { [weak self] _ in self?.onAction?(action) }, for: .touchUpInside)
        }
        setIcon(up, "chevron.up")
        setIcon(down, "chevron.down")
        // Icons have a fixed size so they can't grow with the image they show.
        for button in [eye, lock, up, down] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.widthAnchor.constraint(equalToConstant: 34).isActive = true
        thumbnail.heightAnchor.constraint(equalToConstant: 34).isActive = true
        placement.setContentHuggingPriority(.required, for: .horizontal)
        placement.setContentCompressionResistancePriority(.required, for: .horizontal)
        nameButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = TBStyle.hStack([thumbnail, nameButton, placement, eye, lock, up, down], spacing: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setIcon(_ button: UIButton, _ symbol: String) {
        button.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)),
                        for: .normal)
    }

    func configure(_ layer: TextLayerModel, selected: Bool) {
        nameButton.setTitle(layer.name, for: .normal)
        nameButton.setTitleColor(selected ? TBStyle.accent : TBStyle.text, for: .normal)
        setIcon(eye, layer.isHidden ? "eye.slash" : "eye")
        setIcon(lock, layer.isLocked ? "lock.fill" : "lock.open")
        placement.setTitle(layer.isBehindSubject ? "Behind" : "Front", for: .normal)
        thumbnail.image = TBLayerCell.preview(of: layer)
        contentView.backgroundColor = selected ? TBStyle.field : .clear
        contentView.layer.cornerRadius = 10
    }

    /// 34 pt preview of the layer: "Aa" in its font and fill colour.
    static func preview(of layer: TextLayerModel) -> UIImage {
        var preview = layer
        preview.text = "Aa"
        preview.capitalization = .none
        preview.rotation = 0
        preview.centerX = 0.5
        preview.centerY = 0.5
        preview.widthFraction = 1
        preview.fontScale = 440
        preview.isHidden = false
        preview.opacity = max(layer.opacity, 0.3)
        preview.shadow.isOn = false
        let size = CGSize(width: 68, height: 68)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(white: 0.55, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            TextRenderingService.draw(preview, in: context.cgContext, canvasSize: size)
        }
    }
}
