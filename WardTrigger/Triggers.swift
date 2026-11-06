import AVFoundation
import Contacts
import Foundation

/// Triggers the `kTCCServiceSystemPolicyDocumentsFolder` TCC dialog by
/// attempting a read-only listing of `~/Documents` via FileManager and
/// checking it for the `.ward_canary` canary file.
///
/// The access is strictly read-only: nothing is created or modified, and the
/// canary file (created once by the developer) is only read. Directory
/// enumeration is the operation `tccd` gates for folder services — a plain
/// `stat` of a path inside the folder is not intercepted. Outcomes:
/// - Access already granted → prints the "previously granted" message.
/// - TCC denial error (the user denied the prompt) → prints that the prompt
///   should have appeared.
/// - Any other file-system error → prints the localized description.
///
/// All messages go to stdout; this function never exits the process.
func triggerDocuments() {
    let documentsPath = NSHomeDirectory() + "/Documents"
    do {
        // Read-only probe: enumerating the folder makes `tccd` evaluate the
        // Documents Folder entitlement when it has not been decided yet.
        _ = try FileManager.default.contentsOfDirectory(atPath: documentsPath)
        print("[WardTrigger] Documents access already granted — no prompt will appear.")
    } catch {
        let nsError = error as NSError
        let isPermissionDenial = nsError.domain == NSCocoaErrorDomain
            && (nsError.code == NSFileReadNoPermissionError
                || nsError.code == NSFileWriteNoPermissionError)
        if isPermissionDenial {
            print("[WardTrigger] Documents access denied by TCC — the permission prompt should have appeared.")
        } else {
            print("[WardTrigger] File system error: \(error.localizedDescription)")
        }
    }
}

/// Triggers the `kTCCServiceAddressBook` TCC dialog via
/// `CNContactStore.requestAccess(for: .contacts)`.
///
/// Uses a `DispatchSemaphore` to keep the process alive until the async TCC
/// callback fires — intentional for a CLI with no `RunLoop`. The callback
/// prints any framework error, then the grant/denial outcome, then signals.
func triggerContacts() {
    let store = CNContactStore()
    let semaphore = DispatchSemaphore(value: 0)
    store.requestAccess(for: .contacts) { granted, error in
        if let error {
            print("[WardTrigger] CNContactStore error: \(error.localizedDescription)")
        }
        print(granted
            ? "[WardTrigger] Contacts access granted."
            : "[WardTrigger] Contacts access denied.")
        semaphore.signal()
    }
    semaphore.wait()
}

/// Triggers the `kTCCServiceMicrophone` TCC dialog via
/// `AVCaptureDevice.requestAccess(for: .audio)`.
///
/// Uses the same `DispatchSemaphore` pattern as `triggerContacts()` to keep
/// the process alive until the async callback fires. The callback prints the
/// grant/denial outcome, then signals.
func triggerMicrophone() {
    let semaphore = DispatchSemaphore(value: 0)
    AVCaptureDevice.requestAccess(for: .audio) { granted in
        print(granted
            ? "[WardTrigger] Microphone access granted."
            : "[WardTrigger] Microphone access denied.")
        semaphore.signal()
    }
    semaphore.wait()
}
