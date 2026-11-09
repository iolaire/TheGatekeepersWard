#!/usr/bin/env swift
// Dev helper: dump on-screen windows (owner name, layer, bounds).
// Used to record the empirical TCC alert window owner and layer.
// Deliberately never reads kCGWindowName, which would require
// Screen Recording permission.
//
// Usage: swift scripts/dump_window_list.swift [ownerSubstring]

import CoreGraphics
import Foundation

let filter = CommandLine.arguments.dropFirst().first?.lowercased()
let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]

guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
    print("CGWindowListCopyWindowInfo returned nil")
    exit(1)
}

let os = ProcessInfo.processInfo.operatingSystemVersionString
print("macOS \(os)")
print("owner\tlayer\tbounds(CG, top-left origin)")

for info in list {
    let owner = info[kCGWindowOwnerName as String] as? String ?? "?"
    if let filter, !owner.lowercased().contains(filter) { continue }
    let layer = info[kCGWindowLayer as String] as? Int ?? 0
    var boundsText = "?"
    if let dict = info[kCGWindowBounds as String] as? NSDictionary,
       let rect = CGRect(dictionaryRepresentation: dict) {
        boundsText = "x=\(Int(rect.minX)) y=\(Int(rect.minY)) w=\(Int(rect.width)) h=\(Int(rect.height))"
    }
    print("\(owner)\t\(layer)\t\(boundsText)")
}
