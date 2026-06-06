import Foundation

enum Difficulty: String, Codable, CaseIterable {
    case easy, medium, hard, expert, whiz

    var label: String {
        switch self {
        case .easy:   return "Easy"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        case .expert: return "Expert"
        case .whiz:   return "Premium"
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
    /// Stored as a Double so Whiz (scientific) problems can have non-integer answers.
    /// Integer problems use the `Int` convenience initializer below.
    let answer: Double

    init(expression: String, answer: Double) {
        self.expression = expression
        self.answer = answer
    }

    init(expression: String, answer: Int) {
        self.expression = expression
        self.answer = Double(answer)
    }

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
            return generateWhiz()
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

    // MARK: - Whiz (scientific) generators

    private enum WhizKind: CaseIterable {
        case squareRoot, cubeRoot, log10, naturalLog, sine, cosine, tangent
        case piMultiple, circleArea, hypotenuse, exponential
    }

    /// Random scientific-style problem with a non-integer (decimal) answer.
    /// Answers are checked to two decimal places, so a digits + decimal keypad suffices.
    static func generateWhiz() -> MathProblem {
        var rng = SystemRandomNumberGenerator()
        return generateWhiz(using: &rng)
    }

    /// RNG-injectable variant so tests can drive deterministic problems.
    static func generateWhiz<R: RandomNumberGenerator>(using rng: inout R) -> MathProblem {
        switch WhizKind.allCases.randomElement(using: &rng)! {
        case .squareRoot:  return whizSquareRoot(Int.random(in: 2...150, using: &rng))
        case .cubeRoot:    return whizCubeRoot(Int.random(in: 2...300, using: &rng))
        case .log10:       return whizLog10(Int.random(in: 2...9999, using: &rng))
        case .naturalLog:  return whizNaturalLog(Int.random(in: 2...200, using: &rng))
        case .sine:        return whizSine(Int.random(in: 1...89, using: &rng))
        case .cosine:      return whizCosine(Int.random(in: 1...89, using: &rng))
        case .tangent:     return whizTangent(Int.random(in: 1...80, using: &rng))
        case .piMultiple:  return whizPiMultiple(Int.random(in: 2...50, using: &rng))
        case .circleArea:  return whizCircleArea(Int.random(in: 2...25, using: &rng))
        case .hypotenuse:  return whizHypotenuse(Int.random(in: 2...60, using: &rng),
                                                 Int.random(in: 2...60, using: &rng))
        case .exponential: return whizExp(Int.random(in: 1...9, using: &rng))
        }
    }

    // Each helper is a pure function of its operands so it can be unit-tested directly.

    static func whizSquareRoot(_ n: Int) -> MathProblem {
        MathProblem(expression: "√\(n) = ?", answer: Double(n).squareRoot())
    }

    static func whizCubeRoot(_ n: Int) -> MathProblem {
        MathProblem(expression: "∛\(n) = ?", answer: cbrt(Double(n)))
    }

    static func whizLog10(_ n: Int) -> MathProblem {
        MathProblem(expression: "log \(n) = ?", answer: Foundation.log10(Double(n)))
    }

    static func whizNaturalLog(_ n: Int) -> MathProblem {
        MathProblem(expression: "ln \(n) = ?", answer: Foundation.log(Double(n)))
    }

    static func whizSine(_ degrees: Int) -> MathProblem {
        MathProblem(expression: "sin \(degrees)° = ?", answer: Foundation.sin(radians(degrees)))
    }

    static func whizCosine(_ degrees: Int) -> MathProblem {
        MathProblem(expression: "cos \(degrees)° = ?", answer: Foundation.cos(radians(degrees)))
    }

    static func whizTangent(_ degrees: Int) -> MathProblem {
        MathProblem(expression: "tan \(degrees)° = ?", answer: Foundation.tan(radians(degrees)))
    }

    static func whizPiMultiple(_ k: Int) -> MathProblem {
        MathProblem(expression: "\(k)π = ?", answer: Double(k) * .pi)
    }

    static func whizCircleArea(_ r: Int) -> MathProblem {
        MathProblem(expression: "π × \(r)² = ?", answer: .pi * Double(r) * Double(r))
    }

    static func whizHypotenuse(_ a: Int, _ b: Int) -> MathProblem {
        MathProblem(expression: "√(\(a)² + \(b)²) = ?",
                    answer: Double(a * a + b * b).squareRoot())
    }

    static func whizExp(_ n: Int) -> MathProblem {
        MathProblem(expression: "e^\(n) = ?", answer: Foundation.exp(Double(n)))
    }

    private static func radians(_ degrees: Int) -> Double {
        Double(degrees) * .pi / 180
    }
}
