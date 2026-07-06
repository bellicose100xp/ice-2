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
            summary: "Layout gets its own spot in Settings, plus a first-launch crash fix and a new What's New tab.",
            sections: [
                ChangeSection(kind: .fixed, entries: [
                    "Fixed a crash that could happen on first launch, before Accessibility was granted.",
                ]),
                ChangeSection(kind: .changed, entries: [
                    "Moved the menu bar Layout editor out of Appearance into its own Settings tab, right after Appearance.",
                    "Refreshed the About and Permissions screens and corrected the Settings sidebar text size.",
                ]),
                ChangeSection(kind: .added, entries: [
                    "Added this What's New tab so you can see what changed in each version.",
                ]),
            ]
        )
    }
}
