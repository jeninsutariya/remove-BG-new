//
//  FontCatalog.swift
//  Background Removal
//
//  Every font family available to the app (system fonts and the fonts bundled in the app's
//  Info.plist), discovered at runtime with UIKit + Core Text – nothing is hard-coded.
//

import UIKit
import CoreText

struct FontFace: Hashable {
    let postScriptName: String
    /// Localized style name from Core Text ("Regular", "Bold Italic", …).
    let styleName: String
    let weight: CGFloat
    let isItalic: Bool
}

struct FontFamily: Hashable {
    let name: String
    let faces: [FontFace]

    /// Face used when the family is picked (Regular / Book / the lightest upright face).
    var defaultFace: FontFace {
        faces.first { !$0.isItalic && abs($0.weight) < 0.05 } ?? faces.first { !$0.isItalic } ?? faces[0]
    }
}

enum FontCatalog {

    static let families: [FontFamily] = {
        UIFont.familyNames.sorted().compactMap { family -> FontFamily? in
            let faces = UIFont.fontNames(forFamilyName: family).compactMap { FontCatalog.face($0) }.sorted {
                $0.weight != $1.weight ? $0.weight < $1.weight : (!$0.isItalic && $1.isItalic)
            }
            return faces.isEmpty ? nil : FontFamily(name: family, faces: faces)
        }
    }()

    private static let familyByFace: [String: FontFamily] = {
        var map: [String: FontFamily] = [:]
        for family in FontCatalog.families { family.faces.forEach { map[$0.postScriptName] = family } }
        return map
    }()

    static func family(containing postScriptName: String) -> FontFamily? {
        familyByFace[postScriptName]
    }

    static func face(_ postScriptName: String) -> FontFace? {
        let ctFont = CTFontCreateWithName(postScriptName as CFString, 12, nil)
        // Core Text substitutes a fallback for unknown names; reject those.
        guard (CTFontCopyPostScriptName(ctFont) as String) == postScriptName else { return nil }
        let style = (CTFontCopyName(ctFont, kCTFontStyleNameKey) as String?) ?? postScriptName
        let traits = CTFontCopyTraits(ctFont) as NSDictionary
        let weight = (traits[kCTFontWeightTrait] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
        let symbolic = (traits[kCTFontSymbolicTrait] as? NSNumber)?.uint32Value ?? 0
        let italic = symbolic & CTFontSymbolicTraits.traitItalic.rawValue != 0
        return FontFace(postScriptName: postScriptName, styleName: style, weight: weight, isItalic: italic)
    }

    /// "Family · Style" for display.
    static func displayName(_ postScriptName: String) -> String {
        guard let family = family(containing: postScriptName),
              let face = family.faces.first(where: { $0.postScriptName == postScriptName }) else { return postScriptName }
        return "\(family.name) · \(face.styleName)"
    }
}
