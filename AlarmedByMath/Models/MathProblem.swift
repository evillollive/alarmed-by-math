import Foundation

enum Difficulty: String, Codable, CaseIterable {
    case easy, medium, hard, expert, whiz

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        case .expert: return "Expert"
        case .whiz:   return "Whiz"
        }
    }
}

extension Difficulty {
    static func effective(_ selected: Difficulty, whizUnlocked: Bool) -> Difficulty {
        guard selected == .whiz, !whizUnlocked else { return selected }
        return .expert
    }
}

struct MathProblem {
    let expression: String
    let answer: Int

    /// Generate a random arithmetic problem at the requested difficulty.
    static func generate(difficulty: Difficulty = .medium) -> MathProblem {
        switch difficulty {
        case .easy:
            return generateAddition(range: 1...20)
        case .medium:
            switch Int.random(in: 0...2) {
            case 0:  return generateAddition(range: 10...99)
            case 1:  return generateSubtraction(range: 10...99)
            default: return generateMultiplication(range: 2...12)
            }
        case .hard:
            switch Int.random(in: 0...2) {
            case 0:  return generateAddition(range: 100...999)
            case 1:  return generateSubtraction(range: 100...999)
            default: return generateMultiplication(range: 10...25)
            }
        case .expert:
            switch Int.random(in: 0...2) {
            case 0:  return generateSignedSubtraction()
            case 1:  return generateAlgebra()
            default: return generateFraction()
            }
        case .whiz:
            // Whiz tier coming soon, falls back to Expert in the meantime
            return generate(difficulty: .expert)
        }
    }

    // MARK: - Private generators

    private static func generateAddition(range: ClosedRange<Int>) -> MathProblem {
        let a = Int.random(in: range)
        let b = Int.random(in: range)
        return MathProblem(expression: "\(a) + \(b) = ?", answer: a + b)
    }

    private static func generateSubtraction(range: ClosedRange<Int>) -> MathProblem {
        let a = Int.random(in: range)
        let b = Int.random(in: range)
        let larger  = max(a, b)
        let smaller = min(a, b)
        return MathProblem(expression: "\(larger) − \(smaller) = ?", answer: larger - smaller)
    }

    private static func generateMultiplication(range: ClosedRange<Int>) -> MathProblem {
        let a = Int.random(in: range)
        let b = Int.random(in: range)
        return MathProblem(expression: "\(a) × \(b) = ?", answer: a * b)
    }

    // MARK: - Expert generators

    /// Subtraction where the result can be negative (e.g. "14 − 37 = ?").
    private static func generateSignedSubtraction() -> MathProblem {
        let a = Int.random(in: 10...99)
        let b = Int.random(in: 10...99)
        // Occasionally ensure a negative result for variety
        let (left, right) = Bool.random() ? (a, b) : (b, a)
        return MathProblem(expression: "\(left) − \(right) = ?", answer: left - right)
    }

    /// Linear equation: ax + b = c, solve for x. Answer is an integer.
    private static func generateAlgebra() -> MathProblem {
        let x = Int.random(in: -9...15)         // the answer
        let a = Int.random(in: 2...9)            // coefficient (always >= 2)
        let b = Int.random(in: -20...20)         // constant term
        let c = a * x + b                         // right-hand side

        let aStr = a == 1 ? "x" : "\(a)x"
        let expr: String
        if b > 0 {
            expr = "\(aStr) + \(b) = \(c)"
        } else if b < 0 {
            expr = "\(aStr) − \(-b) = \(c)"
        } else {
            expr = "\(aStr) = \(c)"
        }
        return MathProblem(expression: expr, answer: x)
    }

    /// Fraction multiplication with an integer answer (e.g. "(3/4) × 20 = ?").
    private static func generateFraction() -> MathProblem {
        let denominator = [2, 3, 4, 5].randomElement()!
        let numerator   = Int.random(in: 1...(denominator - 1))
        let multiplier  = Int.random(in: 2...10)
        let whole       = denominator * multiplier          // divisible by denominator
        let result      = (numerator * whole) / denominator // always integer
        return MathProblem(expression: "(\(numerator)/\(denominator)) × \(whole) = ?", answer: result)
    }
}
