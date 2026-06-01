import SwiftUI
import AudioToolbox

// MARK: - Theme palette

struct ThemeColors {
    let board:       Color
    let boardDark:   Color
    let chalk:       Color
    let chalkFaded:  Color
    let chalkYellow: Color
    let chalkRed:    Color
    let chalkBlue:   Color
    let fontDesign:  Font.Design
}

// MARK: - App themes

enum AppTheme: String, CaseIterable, Codable {
    case chalk
    case whiteboard
    case retro
    case neon
    case dark
    case highContrast

    var label: String {
        switch self {
        case .chalk:        return "Chalkboard"
        case .whiteboard:   return "Whiteboard"
        case .retro:        return "Retro LCD"
        case .neon:         return "Neon"
        case .dark:         return "Dark"
        case .highContrast: return "High Contrast"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .whiteboard: return .light
        default:          return .dark
        }
    }

    var colors: ThemeColors {
        switch self {
        case .chalk:
            return ThemeColors(
                board:       Color(red: 0.16, green: 0.30, blue: 0.20),
                boardDark:   Color(red: 0.10, green: 0.20, blue: 0.13),
                chalk:       Color(red: 0.96, green: 0.96, blue: 0.92),
                chalkFaded:  Color(red: 0.96, green: 0.96, blue: 0.92).opacity(0.55),
                chalkYellow: Color(red: 0.99, green: 0.89, blue: 0.38),
                chalkRed:    Color(red: 0.93, green: 0.38, blue: 0.38),
                chalkBlue:   Color(red: 0.50, green: 0.76, blue: 0.95),
                fontDesign:  .rounded
            )
        case .whiteboard:
            return ThemeColors(
                board:       Color(red: 0.96, green: 0.96, blue: 0.96),
                boardDark:   Color(red: 0.87, green: 0.87, blue: 0.89),
                chalk:       Color(red: 0.10, green: 0.10, blue: 0.12),
                chalkFaded:  Color(red: 0.10, green: 0.10, blue: 0.12).opacity(0.45),
                chalkYellow: Color(red: 0.82, green: 0.50, blue: 0.02),
                chalkRed:    Color(red: 0.80, green: 0.15, blue: 0.15),
                chalkBlue:   Color(red: 0.14, green: 0.40, blue: 0.78),
                fontDesign:  .default
            )
        case .retro:
            return ThemeColors(
                board:       Color(red: 0.05, green: 0.07, blue: 0.05),
                boardDark:   Color(red: 0.02, green: 0.03, blue: 0.02),
                chalk:       Color(red: 0.20, green: 0.90, blue: 0.20),
                chalkFaded:  Color(red: 0.20, green: 0.90, blue: 0.20).opacity(0.45),
                chalkYellow: Color(red: 0.95, green: 0.75, blue: 0.10),
                chalkRed:    Color(red: 0.90, green: 0.20, blue: 0.10),
                chalkBlue:   Color(red: 0.20, green: 0.80, blue: 0.95),
                fontDesign:  .monospaced
            )
        case .neon:
            return ThemeColors(
                board:       Color(red: 0.14, green: 0.05, blue: 0.24),
                boardDark:   Color(red: 0.07, green: 0.02, blue: 0.13),
                chalk:       Color(red: 0.96, green: 0.93, blue: 1.00),
                chalkFaded:  Color(red: 0.96, green: 0.93, blue: 1.00).opacity(0.50),
                chalkYellow: Color(red: 0.80, green: 0.62, blue: 1.00),
                chalkRed:    Color(red: 1.00, green: 0.18, blue: 0.58),
                chalkBlue:   Color(red: 0.15, green: 1.00, blue: 0.52),
                fontDesign:  .monospaced
            )
        case .dark:
            return ThemeColors(
                board:       Color(red: 0.11, green: 0.11, blue: 0.13),
                boardDark:   Color(red: 0.06, green: 0.06, blue: 0.08),
                chalk:       Color(red: 0.93, green: 0.93, blue: 0.95),
                chalkFaded:  Color(red: 0.93, green: 0.93, blue: 0.95).opacity(0.50),
                chalkYellow: Color(red: 1.00, green: 0.75, blue: 0.00),
                chalkRed:    Color(red: 1.00, green: 0.30, blue: 0.30),
                chalkBlue:   Color(red: 0.25, green: 0.65, blue: 1.00),
                fontDesign:  .default
            )
        case .highContrast:
            return ThemeColors(
                board:       Color(red: 0.00, green: 0.00, blue: 0.00),
                boardDark:   Color(red: 0.05, green: 0.05, blue: 0.05),
                chalk:       Color(red: 1.00, green: 1.00, blue: 1.00),
                chalkFaded:  Color(red: 0.75, green: 0.75, blue: 0.75),
                chalkYellow: Color(red: 1.00, green: 0.88, blue: 0.00),
                chalkRed:    Color(red: 1.00, green: 0.22, blue: 0.22),
                chalkBlue:   Color(red: 0.00, green: 0.65, blue: 1.00),
                fontDesign:  .rounded
            )
        }
    }
}

// MARK: - Alarm sounds

enum AlarmSound: String, CaseIterable, Codable {
    case chime
    case classic
    case bell
    case buzzOnly

    var label: String {
        switch self {
        case .chime:    return "Chime"
        case .classic:  return "Classic"
        case .bell:     return "Bell"
        case .buzzOnly: return "Buzz"
        }
    }

    /// Bundled looping tone (< 30s) used for the real alarm: AlarmKit, the
    /// notification sound, and the in-app player all reference this by name.
    var fileName: String { "\(resource.name).\(resource.ext)" }

    /// Resource lookup parts for `Bundle.main.url(forResource:withExtension:)`.
    var resource: (name: String, ext: String) {
        switch self {
        case .chime:    return ("chime", "caf")
        case .classic:  return ("classic", "caf")
        case .bell:     return ("bell", "caf")
        case .buzzOnly: return ("buzz", "caf")
        }
    }

    /// Whether this sound should also drive the vibration motor in-app.
    var vibrates: Bool { self == .buzzOnly }

    var systemSoundID: SystemSoundID {
        switch self {
        case .chime:    return SystemSoundID(1005)
        case .classic:  return SystemSoundID(1007)
        case .bell:     return SystemSoundID(1013)
        case .buzzOnly: return kSystemSoundID_Vibrate
        }
    }
}

// MARK: - Theme accessor (delegates to SettingsStore.shared)

enum Theme {
    private static var c: ThemeColors { SettingsStore.shared.activeTheme.colors }

    static var board:       Color       { c.board }
    static var boardDark:   Color       { c.boardDark }
    static var chalk:       Color       { c.chalk }
    static var chalkFaded:  Color       { c.chalkFaded }
    static var chalkYellow: Color       { c.chalkYellow }
    static var chalkRed:    Color       { c.chalkRed }
    static var chalkBlue:   Color       { c.chalkBlue }
    static var fontDesign:  Font.Design { c.fontDesign }
}
