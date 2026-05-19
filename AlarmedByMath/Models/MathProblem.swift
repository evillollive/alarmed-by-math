import Foundation

enum Difficulty {
    case easy, medium, hard
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
}
