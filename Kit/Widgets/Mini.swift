//
//  Mini.swift
//  Kit
//
//  Created by Serhiy Mytrovtsiy on 10/04/2020.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2020 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

public class Mini: WidgetWrapper {
    private var labelState: Bool = true
    private var colorState: SColor = .monochrome
    private var alignmentState: String = "left"
    
    private var colors: [SColor] = SColor.allCases
    
    private var _value: Double = 0
    private var _pressureLevel: RAMPressure = .normal
    private var _colorZones: colorZones = (0.6, 0.8)
    private var _suffix: String = "%"
    
    private var defaultLabel: String
    private var _label: String
    
    private var width: CGFloat {
        (self.labelState ? 31 : 36) + (2*Constants.Widget.margin.x)
    }
    
    private var alignment: NSTextAlignment {
        if let alignmentPair = Alignments.first(where: { $0.key == self.alignmentState }) {
            return alignmentPair.additional as? NSTextAlignment ?? .left
        }
        return .left
    }
    
    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self._value = Double(value) ?? 0
                    }
                }
            }
            
            if let titleFromConfig = configuration["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
            if let unsupportedColors = configuration["Unsupported colors"] as? [String] {
                self.colors = self.colors.filter{ !unsupportedColors.contains($0.key) }
            }
            if let color = configuration["Color"] as? String {
                if let defaultColor = self.colors.first(where: { $0.key == color }) {
                    self.colorState = defaultColor
                }
            }
        }
        
        self.defaultLabel = widgetTitle
        self._label = widgetTitle
        super.init(.mini, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.colorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.alignmentState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_alignment", defaultValue: self.alignmentState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var value: Double = 0
        var pressureLevel: RAMPressure = .normal
        var colorZones: colorZones = (0.6, 0.8)
        var label: String = ""
        var suffix: String = ""
        self.queue.sync {
            value = self._value
            pressureLevel = self._pressureLevel
            colorZones = self._colorZones
            label = self._label
            suffix = self._suffix
        }
        
        let valueSize: CGFloat = self.labelState ? 12 : 14
        var origin: CGPoint = CGPoint(x: Constants.Widget.margin.x, y: (Constants.Widget.height-valueSize)/2)
        let style = NSMutableParagraphStyle()
        style.alignment = self.labelState ? self.alignment : .center
        
        if self.labelState {
            let style = NSMutableParagraphStyle()
            style.alignment = self.alignment
            
            let stringAttributes = [
                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .light),
                NSAttributedString.Key.foregroundColor: self.isDarkMode ? NSColor.white : NSColor.textColor,
                NSAttributedString.Key.paragraphStyle: style
            ]
            let rect = CGRect(x: origin.x, y: 12, width: self.width - (Constants.Widget.margin.x*2), height: 7)
            let str = NSAttributedString.init(string: label, attributes: stringAttributes)
            str.draw(with: rect)
            
            origin.y = 1
        }
        
        var color: NSColor = .controlAccentColor
        switch self.colorState {
        case .systemAccent: color = .controlAccentColor
        case .utilization: color = value.usageColor(zones: colorZones, reversed: self.title == "BAT")
        case .pressure: color = pressureLevel.pressureColor()
        case .monochrome: color = (self.isDarkMode ? NSColor.white : NSColor.black)
        default: color = self.colorState.additional as? NSColor ?? .controlAccentColor
        }
        
        let stringAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let rect = CGRect(x: origin.x, y: origin.y, width: self.width - (Constants.Widget.margin.x*2), height: valueSize+1)
        let str = NSAttributedString.init(string: "\(Int(value.rounded(toPlaces: 2) * 100))\(suffix)", attributes: stringAttributes)
        str.draw(with: rect)
        
        self.setWidth(self.width)
    }
    
    public func setValue(_ newValue: Double) {
        let updated = self.queue.sync { () -> Bool in
            guard self._value != newValue else { return false }
            self._value = newValue
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setPressure(_ newPressureLevel: RAMPressure) {
        let updated = self.queue.sync { () -> Bool in
            guard self._pressureLevel != newPressureLevel else { return false }
            self._pressureLevel = newPressureLevel
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setTitle(_ newTitle: String?) {
        var title = self.defaultLabel
        if let new = newTitle {
            title = new
        }
        let updated = self.queue.sync { () -> Bool in
            guard self._label != title else { return false }
            self._label = title
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setColorZones(_ newColorZones: colorZones) {
        let updated = self.queue.sync { () -> Bool in
            guard self._colorZones != newColorZones else { return false }
            self._colorZones = newColorZones
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    public func setSuffix(_ newSuffix: String) {
        let updated = self.queue.sync { () -> Bool in
            guard self._suffix != newSuffix else { return false }
            self._suffix = newSuffix
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Label"), component: self.switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Color"), component: self.colorSelectView(
                action: #selector(self.toggleColor),
                items: self.colors,
                selected: self.colorState.key
            )),
            PreferencesRow(localizedString("Alignment"), component: self.selectView(
                action: #selector(self.toggleAlignment),
                items: Alignments,
                selected: self.alignmentState
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.colorState = SColor.fromString(key, defaultValue: self.colorState)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState.key)
        self.display()
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        self.labelState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        self.display()
    }
    
    @objc private func toggleAlignment(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newAlignment = Alignments.first(where: { $0.key == key }) {
            self.alignmentState = newAlignment.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_alignment", value: key)
        self.display()
    }
}

// Mini-style widget: small label on top, free or used space in whole gigabytes below (e.g. "72GB").
public class SpaceWidget: WidgetWrapper {
    private var labelState: Bool = true
    private var colorState: SColor = .monochrome
    private var alignmentState: String = "left"
    
    private var colors: [SColor] = SColor.allCases.filter{ $0 != .utilization && $0 != .pressure && $0 != .cluster }
    
    private var _value: String = "0GB"
    private var defaultLabel: String
    private var _label: String
    
    private var alignment: NSTextAlignment {
        if let alignmentPair = Alignments.first(where: { $0.key == self.alignmentState }) {
            return alignmentPair.additional as? NSTextAlignment ?? .left
        }
        return .left
    }
    
    public init(_ type: widget_t, title: String, config: NSDictionary?, preview: Bool = false) {
        var widgetTitle: String = title
        if config != nil {
            var configuration = config!
            
            if preview {
                if let previewConfig = config!["Preview"] as? NSDictionary {
                    configuration = previewConfig
                    if let value = configuration["Value"] as? String {
                        self._value = value
                    }
                }
            }
            
            if let titleFromConfig = configuration["Title"] as? String {
                widgetTitle = titleFromConfig
            }
            if let label = configuration["Label"] as? Bool {
                self.labelState = label
            }
        }
        
        self.defaultLabel = widgetTitle
        self._label = widgetTitle
        super.init(type, title: widgetTitle, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: Constants.Widget.width + (2*Constants.Widget.margin.x),
            height: Constants.Widget.height - (2*Constants.Widget.margin.y)
        ))
        
        self.canDrawConcurrently = true
        
        if !preview {
            self.colorState = SColor.fromString(Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_color", defaultValue: self.colorState.key))
            self.labelState = Store.shared.bool(key: "\(self.title)_\(self.type.rawValue)_label", defaultValue: self.labelState)
            self.alignmentState = Store.shared.string(key: "\(self.title)_\(self.type.rawValue)_alignment", defaultValue: self.alignmentState)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        var value: String = ""
        var label: String = ""
        self.queue.sync {
            value = self._value
            label = self._label
        }
        
        let valueSize: CGFloat = self.labelState ? 12 : 14
        let style = NSMutableParagraphStyle()
        style.alignment = self.labelState ? self.alignment : .center
        
        var color: NSColor = .controlAccentColor
        switch self.colorState {
        case .systemAccent: color = .controlAccentColor
        case .monochrome: color = (self.isDarkMode ? NSColor.white : NSColor.black)
        default: color = self.colorState.additional as? NSColor ?? .controlAccentColor
        }
        
        let valueAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: valueSize, weight: .regular),
            NSAttributedString.Key.foregroundColor: color,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let valueStr = NSAttributedString.init(string: value, attributes: valueAttributes)
        let labelAttributes = [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 7, weight: .light),
            NSAttributedString.Key.foregroundColor: self.isDarkMode ? NSColor.white : NSColor.textColor,
            NSAttributedString.Key.paragraphStyle: style
        ]
        let labelStr = NSAttributedString.init(string: label, attributes: labelAttributes)
        let contentWidth = max(
            self.labelState ? 23 : 28,
            ceil(valueStr.size().width),
            self.labelState ? ceil(labelStr.size().width) : 0
        )
        let width = contentWidth + (2*Constants.Widget.margin.x)
        var originY: CGFloat = (Constants.Widget.height-valueSize)/2
        
        if self.labelState {
            labelStr.draw(with: CGRect(x: Constants.Widget.margin.x, y: 12, width: contentWidth, height: 7))
            originY = 1
        }
        
        valueStr.draw(with: CGRect(x: Constants.Widget.margin.x, y: originY, width: contentWidth, height: valueSize+1))
        
        self.setWidth(width)
    }
    
    // space in bytes; shown rounded to the nearest whole gigabyte
    public func setValue(_ bytes: Int64) {
        let gb = (Double(bytes) / 1_000_000_000).rounded()
        let newValue = gb >= 1000 ? String(format: "%.1fTB", gb / 1000) : "\(Int(gb))GB"
        let updated = self.queue.sync { () -> Bool in
            guard self._value != newValue else { return false }
            self._value = newValue
            return true
        }
        guard updated else { return }
        DispatchQueue.main.async(execute: {
            self.needsDisplay = true
        })
    }
    
    // MARK: - Settings
    
    public override func settings() -> NSView {
        let view = SettingsContainerView()
        
        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Label"), component: self.switchView(
                action: #selector(self.toggleLabel),
                state: self.labelState
            )),
            PreferencesRow(localizedString("Color"), component: self.colorSelectView(
                action: #selector(self.toggleColor),
                items: self.colors,
                selected: self.colorState.key
            )),
            PreferencesRow(localizedString("Alignment"), component: self.selectView(
                action: #selector(self.toggleAlignment),
                items: Alignments,
                selected: self.alignmentState
            ))
        ]))
        
        return view
    }
    
    @objc private func toggleColor(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.colorState = SColor.fromString(key, defaultValue: self.colorState)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_color", value: self.colorState.key)
        self.display()
    }
    
    @objc private func toggleLabel(_ sender: NSControl) {
        self.labelState = controlState(sender)
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_label", value: self.labelState)
        self.display()
    }
    
    @objc private func toggleAlignment(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        if let newAlignment = Alignments.first(where: { $0.key == key }) {
            self.alignmentState = newAlignment.key
        }
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_alignment", value: key)
        self.display()
    }
}
