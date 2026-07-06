//
//  SettingsNavigationIdentifier.swift
//  Ice
//

/// The navigation identifier type for the "Settings" interface.
enum SettingsNavigationIdentifier: String, NavigationIdentifier {
    case general = "General"
    case appearance = "Appearance"
    case hotkeys = "Hotkeys"
    case updates = "Updates"
    case advanced = "Advanced"
    case permissions = "Permissions"
    case backup = "Backup & Restore"
    case whatsNew = "What's New"
    case about = "About"

    var iconResource: IconResource {
        switch self {
        case .general: .systemSymbol("gearshape")
        case .appearance: .systemSymbol("paintpalette")
        case .hotkeys: .systemSymbol("keyboard")
        case .updates: .systemSymbol("arrow.triangle.2.circlepath")
        case .advanced: .systemSymbol("gearshape.2")
        case .permissions: .systemSymbol("lock.shield")
        case .backup: .systemSymbol("externaldrive.badge.timemachine")
        case .whatsNew: .systemSymbol("sparkles")
        case .about: .assetCatalog(.iceCubeStroke)
        }
    }
}
