import XCTest
@testable import AlarmedByMath

final class MathProblemTests: XCTestCase {

    // MARK: - Expression format

    func testExpressionIsNonEmpty() {
        for difficulty in [Difficulty.easy, .medium, .hard] {
            let problem = MathProblem.generate(difficulty: difficulty)
            XCTAssertFalse(problem.expression.isEmpty)
        }
    }

    func testExpressionContainsOperator() {
        for _ in 0..<30 {
            let problem = MathProblem.generate(difficulty: .medium)
            let hasOp = problem.expression.contains("+")
                     || problem.expression.contains("−")
                     || problem.expression.contains("×")
            XCTAssertTrue(hasOp, "Expression '\(problem.expression)' contains no operator")
        }
    }

    func testExpressionEndsWithQuestionMark() {
        for _ in 0..<20 {
            let problem = MathProblem.generate()
            XCTAssertTrue(
                problem.expression.hasSuffix("= ?"),
                "Expression '\(problem.expression)' should end with '= ?'"
            )
        }
    }

    // MARK: - Answer correctness

    func testAdditionAnswerIsCorrect() {
        // Easy problems are always additions in range 1…20.
        for _ in 0..<50 {
            let problem = MathProblem.generate(difficulty: .easy)
            XCTAssertTrue(problem.answer >= 2)
            XCTAssertTrue(problem.answer <= 40)
        }
    }

    func testAnswerIsNonNegative() {
        // Subtraction problems always subtract the smaller from the larger.
        for _ in 0..<50 {
            let problem = MathProblem.generate(difficulty: .medium)
            XCTAssertGreaterThanOrEqual(problem.answer, 0)
        }
    }

    func testHardAnswerBounds() {
        // Hard addition: up to 999 + 999 = 1998. Hard multiplication: up to 25 * 25 = 625.
        for _ in 0..<50 {
            let problem = MathProblem.generate(difficulty: .hard)
            XCTAssertGreaterThanOrEqual(problem.answer, 0)
            XCTAssertLessThanOrEqual(problem.answer, 1998)
        }
    }

    func testEffectiveDifficultyFallsBackWhenWhizLocked() {
        XCTAssertEqual(
            Difficulty.effective(.whiz, whizUnlocked: false),
            .expert
        )
    }

    func testEffectiveDifficultyPreservesWhizWhenUnlocked() {
        XCTAssertEqual(
            Difficulty.effective(.whiz, whizUnlocked: true),
            .whiz
        )
    }

    // MARK: - Whiz (scientific) generators

    func testIntConvenienceInitializerStoresDouble() {
        let problem = MathProblem(expression: "2 + 3 = ?", answer: 5)
        XCTAssertEqual(problem.answer, 5.0, accuracy: 1e-12)
    }

    func testWhizHelpersProduceExpectedExpressionsAndAnswers() {
        assertWhiz(MathProblem.whizSquareRoot(50), "√50 = ?", 50.0.squareRoot())
        assertWhiz(MathProblem.whizCubeRoot(100), "∛100 = ?", cbrt(100.0))
        assertWhiz(MathProblem.whizLog10(1000), "log 1000 = ?", 3.0)
        assertWhiz(MathProblem.whizNaturalLog(10), "ln 10 = ?", log(10.0))
        assertWhiz(MathProblem.whizSine(30), "sin 30° = ?", 0.5)
        assertWhiz(MathProblem.whizCosine(60), "cos 60° = ?", 0.5)
        assertWhiz(MathProblem.whizTangent(45), "tan 45° = ?", 1.0)
        assertWhiz(MathProblem.whizPiMultiple(2), "2π = ?", 2.0 * .pi)
        assertWhiz(MathProblem.whizCircleArea(5), "π × 5² = ?", .pi * 25.0)
        assertWhiz(MathProblem.whizHypotenuse(3, 4), "√(3² + 4²) = ?", 5.0)
        assertWhiz(MathProblem.whizExp(2), "e^2 = ?", exp(2.0))
    }

    func testWhizProblemsAreFiniteBoundedAndWellFormed() {
        var rng = SeededGenerator(seed: 0xA11CE)
        for _ in 0..<500 {
            let problem = MathProblem.generateWhiz(using: &rng)
            XCTAssertTrue(problem.answer.isFinite, "Answer not finite for '\(problem.expression)'")
            XCTAssertLessThan(abs(problem.answer), 100_000,
                              "Answer out of typeable bounds for '\(problem.expression)'")
            XCTAssertTrue(problem.expression.hasSuffix("= ?"),
                          "Expression '\(problem.expression)' should end with '= ?'")
        }
    }

    func testWhizGenerationIsDeterministicForSeed() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        for _ in 0..<25 {
            let p1 = MathProblem.generateWhiz(using: &a)
            let p2 = MathProblem.generateWhiz(using: &b)
            XCTAssertEqual(p1.expression, p2.expression)
            XCTAssertEqual(p1.answer, p2.answer, accuracy: 1e-12)
        }
    }

    // MARK: - Helpers

    private func assertWhiz(
        _ problem: MathProblem,
        _ expectedExpression: String,
        _ expectedAnswer: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(problem.expression, expectedExpression, file: file, line: line)
        XCTAssertEqual(problem.answer, expectedAnswer, accuracy: 1e-9, file: file, line: line)
    }
}

/// Deterministic RNG (SplitMix64) so Whiz generation can be tested reproducibly.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { self.state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
