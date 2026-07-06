//
//  WhatsNewConfig.swift
//  Ice
//

import DragonKit

/// App-owned "What's New" content for Ice 2, rendered by DragonKit's ``WhatsNewPane``.
///
/// Only the app's own content lives here — the layout is owned by DragonKit. The version is
/// single-sourced from the bundle (``Constants/versionString``, i.e. `CFBundleShortVersionString`)
/// so it always matches About and the update checker; update the `date` and `sections` per release.
enum WhatsNewConfig {
    static var content: WhatsNewContent {
        WhatsNewContent(
            version: Constants.versionString,
            date: "2026-07-06",
            summary: "This release continues the push to keep Ice 2 idle and easy on your battery.",
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    "Stopped a perpetual one-second permission poll that churned CPU while idle.",
                    "Made menu bar item polling event-driven so it no longer wakes the app on a timer.",
                    "The Menu Bar Appearance editor is now built only when you open it, not at launch.",
                    "Closed Settings and Permissions windows no longer re-render in the background.",
                ]),
            ]
        )
    }
}
