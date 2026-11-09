import AVFoundation
import EventKit
import Foundation
import Photos

/// Triggers the `kTCCServiceCalendar` TCC dialog via EventKit.
///
/// Uses `requestFullAccessToEvents` on macOS 14+ and the legacy
/// `requestAccess(to: .event)` before that. A `DispatchSemaphore` keeps the
/// process alive until the callback fires.
func triggerCalendar() {
    let store = EKEventStore()
    let semaphore = DispatchSemaphore(value: 0)
    let completion: (Bool, Error?) -> Void = { granted, error in
        if let error {
            print("[WardTrigger] EKEventStore error: \(error.localizedDescription)")
        }
        print(granted
            ? "[WardTrigger] Calendar access granted."
            : "[WardTrigger] Calendar access denied.")
        semaphore.signal()
    }
    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents(completion: completion)
    } else {
        store.requestAccess(to: .event, completion: completion)
    }
    semaphore.wait()
}

/// Triggers the `kTCCServiceReminders` TCC dialog via EventKit.
///
/// Uses `requestFullAccessToReminders` on macOS 14+ and the legacy
/// `requestAccess(to: .reminder)` before that.
func triggerReminders() {
    let store = EKEventStore()
    let semaphore = DispatchSemaphore(value: 0)
    let completion: (Bool, Error?) -> Void = { granted, error in
        if let error {
            print("[WardTrigger] EKEventStore error: \(error.localizedDescription)")
        }
        print(granted
            ? "[WardTrigger] Reminders access granted."
            : "[WardTrigger] Reminders access denied.")
        semaphore.signal()
    }
    if #available(macOS 14.0, *) {
        store.requestFullAccessToReminders(completion: completion)
    } else {
        store.requestAccess(to: .reminder, completion: completion)
    }
    semaphore.wait()
}

/// Triggers the `kTCCServiceCamera` TCC dialog via
/// `AVCaptureDevice.requestAccess(for: .video)`.
func triggerCamera() {
    let semaphore = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: .video) { granted in
        print(granted
            ? "[WardTrigger] Camera access granted."
            : "[WardTrigger] Camera access denied.")
        semaphore.signal()
    }
    semaphore.wait()
}

/// Triggers the `kTCCServicePhotos` TCC dialog via
/// `PHPhotoLibrary.requestAuthorization(for: .readWrite)`.
func triggerPhotos() {
    let semaphore = DispatchSemaphore(value: 0)
    PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
        switch status {
        case .authorized:
            print("[WardTrigger] Photos access granted.")
        case .limited:
            print("[WardTrigger] Photos access granted (limited selection).")
        default:
            print("[WardTrigger] Photos access denied.")
        }
        semaphore.signal()
    }
    semaphore.wait()
}
