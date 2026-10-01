import SwiftUI
import AudioToolbox

// MARK: - Theme palette

struct ThemeSwatch: Equatable {
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    private var linearRed: Double { Self.linearize(red) }
    private var linearGreen: Double { Self.linearize(green) }
    private var linearBlue: Double { Self.linearize(blue) }

    var relativeLuminance: Double {
        (0.2126 * linearRed) + (0.7152 * linearGreen) + (0.0722 * linearBlue)
    }

    func contrastRatio(with other: ThemeSwatch) -> Double {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func linearize(_ value: Double) -> Double {
        if value <= 0.03928 {
            return value / 12.92
        }
        return pow((value + 0.055) / 1.055, 2.4)
    }
}

struct ThemeColors {
    let boardSwatch:       ThemeSwatch
    let boardDarkSwatch:   ThemeSwatch
    let chalkSwatch:       ThemeSwatch
    let chalkFadedSwatch:  ThemeSwatch
    let chalkYellowSwatch: ThemeSwatch
    let chalkRedSwatch:    ThemeSwatch
    let chalkBlueSwatch:   ThemeSwatch
    let fontDesign:        Font.Design

    var board: Color { boardSwatch.color }
    var boardDark: Color { boardDarkSwatch.color }
    var chalk: Color { chalkSwatch.color }
    var chalkFaded: Color { chalkFadedSwatch.color }
    var chalkYellow: Color { chalkYellowSwatch.color }
    var chalkRed: Color { chalkRedSwatch.color }
    var chalkBlue: Color { chalkBlueSwatch.color }
}

// MARK: - App themes

enum AppTheme: String, CaseIterable, Codable {
    case chalk
    case whiteboard
    case retro
    case neon
    case bubblegum
    case bluebird
    case dark
    case highContrast

    var label: String {
        switch self {
        case .chalk:        return "Chalkboard"
        case .whiteboard:   return "Whiteboard"
        case .retro:        return "Retro LCD"
        case .neon:         return "Neon"
        case .bubblegum:    return "Bubblegum"
        case .bluebird:     return "Bluebird"
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
                boardSwatch:       ThemeSwatch(red: 0.06, green: 0.17, blue: 0.14),
                boardDarkSwatch:   ThemeSwatch(red: 0.04, green: 0.12, blue: 0.10),
                chalkSwatch:       ThemeSwatch(red: 0.96, green: 0.94, blue: 0.85),
                chalkFadedSwatch:  ThemeSwatch(red: 0.70, green: 0.76, blue: 0.68),
                chalkYellowSwatch: ThemeSwatch(red: 0.97, green: 0.81, blue: 0.39),
                chalkRedSwatch:    ThemeSwatch(red: 0.99, green: 0.60, blue: 0.48),
                chalkBlueSwatch:   ThemeSwatch(red: 0.63, green: 0.82, blue: 0.81),
                fontDesign:        .rounded
            )
        case .whiteboard:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.98, green: 0.98, blue: 0.97),
                boardDarkSwatch:   ThemeSwatch(red: 0.90, green: 0.91, blue: 0.92),
                chalkSwatch:       ThemeSwatch(red: 0.11, green: 0.11, blue: 0.13),
                chalkFadedSwatch:  ThemeSwatch(red: 0.35, green: 0.37, blue: 0.40),
                chalkYellowSwatch: ThemeSwatch(red: 0.55, green: 0.33, blue: 0.02),
                chalkRedSwatch:    ThemeSwatch(red: 0.69, green: 0.14, blue: 0.14),
                chalkBlueSwatch:   ThemeSwatch(red: 0.08, green: 0.31, blue: 0.65),
                fontDesign:        .default
            )
        case .retro:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.04, green: 0.07, blue: 0.04),
                boardDarkSwatch:   ThemeSwatch(red: 0.02, green: 0.04, blue: 0.02),
                chalkSwatch:       ThemeSwatch(red: 0.71, green: 1.00, blue: 0.66),
                chalkFadedSwatch:  ThemeSwatch(red: 0.47, green: 0.76, blue: 0.43),
                chalkYellowSwatch: ThemeSwatch(red: 0.98, green: 0.86, blue: 0.30),
                chalkRedSwatch:    ThemeSwatch(red: 1.00, green: 0.48, blue: 0.34),
                chalkBlueSwatch:   ThemeSwatch(red: 0.47, green: 0.92, blue: 1.00),
                fontDesign:        .monospaced
            )
        case .neon:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.14, green: 0.05, blue: 0.24),
                boardDarkSwatch:   ThemeSwatch(red: 0.07, green: 0.02, blue: 0.13),
                chalkSwatch:       ThemeSwatch(red: 0.96, green: 0.93, blue: 1.00),
                chalkFadedSwatch:  ThemeSwatch(red: 0.74, green: 0.68, blue: 0.86),
                chalkYellowSwatch: ThemeSwatch(red: 0.93, green: 0.76, blue: 1.00),
                chalkRedSwatch:    ThemeSwatch(red: 1.00, green: 0.46, blue: 0.70),
                chalkBlueSwatch:   ThemeSwatch(red: 0.40, green: 1.00, blue: 0.73),
                fontDesign:        .monospaced
            )
        case .bubblegum:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.20, green: 0.08, blue: 0.18),
                boardDarkSwatch:   ThemeSwatch(red: 0.12, green: 0.04, blue: 0.11),
                chalkSwatch:       ThemeSwatch(red: 1.00, green: 0.95, blue: 0.99),
                chalkFadedSwatch:  ThemeSwatch(red: 0.82, green: 0.69, blue: 0.79),
                chalkYellowSwatch: ThemeSwatch(red: 1.00, green: 0.79, blue: 0.40),
                chalkRedSwatch:    ThemeSwatch(red: 1.00, green: 0.47, blue: 0.73),
                chalkBlueSwatch:   ThemeSwatch(red: 0.48, green: 0.78, blue: 1.00),
                fontDesign:        .rounded
            )
        case .bluebird:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.06, green: 0.19, blue: 0.33),
                boardDarkSwatch:   ThemeSwatch(red: 0.03, green: 0.12, blue: 0.23),
                chalkSwatch:       ThemeSwatch(red: 0.94, green: 0.98, blue: 1.00),
                chalkFadedSwatch:  ThemeSwatch(red: 0.68, green: 0.79, blue: 0.89),
                chalkYellowSwatch: ThemeSwatch(red: 1.00, green: 0.87, blue: 0.40),
                chalkRedSwatch:    ThemeSwatch(red: 1.00, green: 0.56, blue: 0.51),
                chalkBlueSwatch:   ThemeSwatch(red: 0.45, green: 0.82, blue: 1.00),
                fontDesign:        .rounded
            )
        case .dark:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.12, green: 0.14, blue: 0.18),
                boardDarkSwatch:   ThemeSwatch(red: 0.07, green: 0.08, blue: 0.11),
                chalkSwatch:       ThemeSwatch(red: 0.95, green: 0.96, blue: 1.00),
                chalkFadedSwatch:  ThemeSwatch(red: 0.67, green: 0.72, blue: 0.80),
                chalkYellowSwatch: ThemeSwatch(red: 1.00, green: 0.82, blue: 0.32),
                chalkRedSwatch:    ThemeSwatch(red: 1.00, green: 0.49, blue: 0.52),
                chalkBlueSwatch:   ThemeSwatch(red: 0.48, green: 0.73, blue: 1.00),
                fontDesign:        .default
            )
        case .highContrast:
            return ThemeColors(
                boardSwatch:       ThemeSwatch(red: 0.00, green: 0.00, blue: 0.00),
                boardDarkSwatch:   ThemeSwatch(red: 0.03, green: 0.03, blue: 0.03),
                chalkSwatch:       ThemeSwatch(red: 1.00, green: 1.00, blue: 1.00),
                chalkFadedSwatch:  ThemeSwatch(red: 0.85, green: 0.85, blue: 0.85),
                chalkYellowSwatch: ThemeSwatch(red: 1.00, green: 0.92, blue: 0.18),
                chalkRedSwatch:    ThemeSwatch(red: 1.00, green: 0.35, blue: 0.35),
                chalkBlueSwatch:   ThemeSwatch(red: 0.33, green: 0.86, blue: 1.00),
                fontDesign:        .rounded
            )
        }
    }
}

// MARK: - Alarm sounds

enum AlarmSound: String, CaseIterable, Codable {
    case chime
    case daybreak
    case glasshouse
    case clockwork
    case bell
    case buzzOnly
    case rollCall
    case ratchet

    enum Family: String, CaseIterable {
        case melodic = "Melodic"
        case insistent = "Insistent"
    }

    var label: String {
        switch self {
        case .chime:    return "Chime"
        case .daybreak: return "Daybreak"
        case .glasshouse: return "Glasshouse"
        case .clockwork: return "Clockwork"
        case .bell:     return "Bell"
        case .buzzOnly: return "Buzz"
        case .rollCall: return "Roll Call"
        case .ratchet:  return "Ratchet"
        }
    }

    var detail: String {
        switch self {
        case .chime: return "The familiar chime, unchanged."
        case .daybreak: return "Warm mallets over a rounded low accompaniment."
        case .glasshouse: return "A low opening note and a clear, short melody."
        case .clockwork: return "Dry ticks under a repeating mallet pattern."
        case .bell: return "Deep, closely spaced double-strikes."
        case .buzzOnly: return "A low buzz with long calls and shorter pairs."
        case .rollCall: return "Varied call-and-response with ringing tails."
        case .ratchet: return "Mechanical bursts with low body and sharp attacks."
        }
    }

    var family: Family {
        switch self {
        case .chime, .daybreak, .glasshouse, .clockwork: return .melodic
        case .bell, .buzzOnly, .rollCall, .ratchet: return .insistent
        }
    }

    static func fromStoredValue(_ value: String) -> AlarmSound? {
        value == "classic" ? .rollCall : AlarmSound(rawValue: value)
    }

    /// Bundled looping tone (< 30s) used for the real alarm: AlarmKit, the
    /// notification sound, and the in-app player all reference this by name.
    var fileName: String { "\(resource.name).\(resource.ext)" }

    /// Resource lookup parts for `Bundle.main.url(forResource:withExtension:)`.
    var resource: (name: String, ext: String) {
        switch self {
        case .chime:    return ("chime", "caf")
        case .daybreak: return ("daybreak", "caf")
        case .glasshouse: return ("glasshouse", "caf")
        case .clockwork: return ("clockwork", "caf")
        case .bell:     return ("bell_v2", "caf")
        case .buzzOnly: return ("buzz_v2", "caf")
        case .rollCall: return ("roll_call", "caf")
        case .ratchet:  return ("ratchet", "caf")
        }
    }

    /// Whether this sound should also drive the vibration motor in-app.
    var vibrates: Bool { self == .buzzOnly }

    var systemSoundID: SystemSoundID {
        switch self {
        case .chime, .daybreak: return SystemSoundID(1005)
        case .bell, .glasshouse: return SystemSoundID(1013)
        case .clockwork, .buzzOnly, .rollCall, .ratchet: return SystemSoundID(1007)
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

enum AppTypography {
    static var body: Font { .system(.body, design: Theme.fontDesign) }
    static var emphasis: Font { body.weight(.semibold) }
    static var title: Font { .system(.title2, design: Theme.fontDesign).weight(.semibold) }
    static var display: Font { .system(.largeTitle, design: Theme.fontDesign).weight(.semibold) }
}

struct ChalkboardBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            Theme.board
            if !reduceTransparency {
                Canvas { context, size in
                    var lines = Path()
                    for y in stride(from: CGFloat(32), to: size.height, by: 32) {
                        lines.move(to: CGPoint(x: 0, y: y))
                        lines.addLine(to: CGPoint(x: size.width, y: y))
                    }
                    context.stroke(lines, with: .color(Theme.chalk.opacity(0.035)), lineWidth: 0.5)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// A clock whose hands form the two sides of a right-angle proof.
struct ChalkClockMark: View {
    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            ZStack {
                Circle()
                    .fill(Theme.boardDark)
                Circle()
                    .strokeBorder(Theme.chalk, lineWidth: side * 0.016)
                    .padding(side * 0.045)
                ForEach(0..<12, id: \.self) { tick in
                    Capsule()
                        .fill(tick.isMultiple(of: 3) ? Theme.chalkYellow : Theme.chalkFaded)
                        .frame(width: side * 0.016, height: side * (tick.isMultiple(of: 3) ? 0.075 : 0.04))
                        .offset(y: -side * 0.37)
                        .rotationEffect(.degrees(Double(tick) * 30))
                }
                Path { path in
                    path.move(to: CGPoint(x: side * 0.29, y: side * 0.5))
                    path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.5))
                    path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.22))
                }
                .stroke(Theme.chalkYellow, style: StrokeStyle(lineWidth: side * 0.035, lineCap: .round, lineJoin: .round))
                Path { path in
                    path.move(to: CGPoint(x: side * 0.29, y: side * 0.5))
                    path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.22))
                    path.move(to: CGPoint(x: side * 0.435, y: side * 0.5))
                    path.addLine(to: CGPoint(x: side * 0.435, y: side * 0.435))
                    path.addLine(to: CGPoint(x: side * 0.5, y: side * 0.435))
                }
                .stroke(Theme.chalkFaded, style: StrokeStyle(lineWidth: side * 0.008, dash: [side * 0.022, side * 0.018]))
                Circle()
                    .fill(Theme.chalkYellow)
                    .frame(width: side * 0.065, height: side * 0.065)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}
