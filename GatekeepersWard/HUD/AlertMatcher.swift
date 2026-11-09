import CoreGraphics
import Foundation

/// One entry from the window server list, reduced to the fields the Ward reads.
///
/// `kCGWindowName` is deliberately not read, because it requires Screen Recording
/// permission on recent macOS versions.
struct WindowInfo: Equatable {
    /// The owning process name (`kCGWindowOwnerName`), if present.
    var ownerName: String?
    /// The window layer (`kCGWindowLayer`), if present.
    var layer: Int?
    /// The window bounds in CG global coordinates (`kCGWindowBounds`), if present and valid.
    var bounds: CGRect?

    /// Creates a window entry from explicit field values.
    init(ownerName: String? = nil, layer: Int? = nil, bounds: CGRect? = nil) {
        self.ownerName = ownerName
        self.layer = layer
        self.bounds = bounds
    }

    /// Creates a window entry from a `CGWindowListCopyWindowInfo` dictionary.
    ///
    /// Uses optional casts only; missing or malformed fields become `nil`.
    /// - Parameter dictionary: One element of the window server list.
    init(dictionary: [String: Any]) {
        self.ownerName = dictionary[kCGWindowOwnerName as String] as? String
        self.layer = dictionary[kCGWindowLayer as String] as? Int
        if let boundsDict = dictionary[kCGWindowBounds as String] as? NSDictionary {
            self.bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        } else {
            self.bounds = nil
        }
    }
}

/// Picks the TCC alert out of a list of window server entries.
enum AlertMatcher {
    /// Returns the CG bounds of the first window that matches the alert description.
    ///
    /// A window matches when its owner name and layer equal the given values and its
    /// bounds are present with positive width and height. The window list is ordered
    /// front to back, so the first match is the frontmost.
    /// - Parameters:
    ///   - windows: Window entries in window-list order.
    ///   - ownerName: The expected owner name of the TCC alert.
    ///   - layer: The expected window layer of the TCC alert.
    /// - Returns: The matching bounds, or `nil` when no entry qualifies.
    static func match(_ windows: [WindowInfo], ownerName: String, layer: Int) -> CGRect? {
        for window in windows {
            guard window.ownerName == ownerName,
                  window.layer == layer,
                  let bounds = window.bounds,
                  bounds.width > 0, bounds.height > 0 else { continue }
            return bounds
        }
        return nil
    }
}
