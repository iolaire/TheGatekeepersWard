// Gatekeeper's Ward menu bar app. All logic lives in the GatekeepersWard
// library so it can be unit tested; this file only starts it.
import GatekeepersWard

MainActor.assumeIsolated {
    GatekeepersWardApp.run()
}
