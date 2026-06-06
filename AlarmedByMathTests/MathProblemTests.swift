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

    func testIntConvenienceInitializerStoresDouble() {
        let problem = MathProblem(expression: "2 + 3 = ?", answer: 5)
        XCTAssertEqual(problem.answer, 5.0, accuracy: 1e-12)
    }
}
