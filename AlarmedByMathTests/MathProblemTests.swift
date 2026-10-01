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

final class MathAnswerTests: XCTestCase {
    func testIntegerAndNegativeAnswersUseTheSameRules() {
        let problem = MathProblem(expression: "2 - 5 = ?", answer: -3)
        XCTAssertEqual(problem.evaluateAnswer("-3"), .correct)
        XCTAssertEqual(problem.evaluateAnswer("-3."), .correct)
        XCTAssertEqual(problem.evaluateAnswer("3"), .incorrect)
        XCTAssertEqual(MathProblem(expression: "0", answer: 0).evaluateAnswer("-0"), .correct)
    }

    func testDecimalAnswersRoundToTwoPlaces() {
        let problem = MathProblem(expression: "Scientific problem", answer: 1.234)
        XCTAssertEqual(problem.evaluateAnswer("1.23"), .correct)
        XCTAssertEqual(problem.evaluateAnswer("1.234"), .correct)
        XCTAssertEqual(problem.evaluateAnswer("1.24"), .incorrect)
        XCTAssertEqual(MathProblem(expression: "Half", answer: -1.125).evaluateAnswer("-1.13"), .correct)
        XCTAssertEqual(MathProblem(expression: "Half", answer: -1.125).evaluateAnswer("-1.12"), .incorrect)
    }

    func testInvalidAndNonFiniteInputCannotCompleteAProblem() {
        let problem = MathProblem(expression: "2 + 3 = ?", answer: 5)
        for input in ["", "-", ".", "-.", "abc", "1..2", "nan", "inf", "-inf", "1e309", "1e308"] {
            XCTAssertEqual(problem.evaluateAnswer(input), .invalid, input)
        }
        XCTAssertEqual(problem.evaluateAnswer("999999"), .incorrect)
    }
}

final class MathPracticeSessionTests: XCTestCase {
    private func session(count: Int = 2) -> MathPracticeSession {
        MathPracticeSession(difficulty: .easy, problemCount: count, whizUnlocked: false) { _ in
            MathProblem(expression: "2 + 3 = ?", answer: 5)
        }
    }

    func testSetupClampsCountAndRespectsEntitlement() {
        var generatedDifficulty: Difficulty?
        let locked = MathPracticeSession(difficulty: .whiz, problemCount: 99, whizUnlocked: false) {
            generatedDifficulty = $0
            return MathProblem(expression: "Preview", answer: 1)
        }
        XCTAssertEqual(locked.difficulty, .expert)
        XCTAssertEqual(generatedDifficulty, .expert)
        XCTAssertEqual(locked.problemCount, 10)
        XCTAssertEqual(session(count: 0).problemCount, 1)
        let unlocked = MathPracticeSession(difficulty: .whiz, problemCount: 1, whizUnlocked: true) { _ in
            MathProblem(expression: "Scientific preview", answer: 1.25)
        }
        XCTAssertEqual(unlocked.difficulty, .whiz)
    }

    func testInvalidInputPreservesProblemAndProgress() {
        var run = session()
        run.submit()
        XCTAssertEqual(run.phase, .answering)
        XCTAssertEqual(run.solvedCount, 0)
        XCTAssertEqual(run.problem.expression, "2 + 3 = ?")
        XCTAssertEqual(run.feedback, "Enter a number before checking your answer.")
    }

    func testWrongAnswerWaitsForExplicitRetry() {
        var run = session()
        run.input = "4"
        run.submit()
        XCTAssertEqual(run.phase, .incorrect)
        XCTAssertEqual(run.problemNumber, 1)
        XCTAssertEqual(run.solvedCount, 0)
        run.input = "5"
        run.submit()
        XCTAssertEqual(run.phase, .incorrect)
        XCTAssertEqual(run.solvedCount, 0)
        run.nextProblem()
        XCTAssertEqual(run.phase, .answering)
        XCTAssertEqual(run.input, "")
        XCTAssertEqual(run.problemNumber, 1)
    }

    func testCorrectAnswersRequireNextAndCompleteAtConfiguredCount() {
        var run = session()
        run.input = "5"
        run.submit()
        XCTAssertEqual(run.phase, .correct)
        XCTAssertEqual(run.solvedCount, 1)
        XCTAssertEqual(run.problemNumber, 1)
        run.submit()
        XCTAssertEqual(run.solvedCount, 1)
        run.nextProblem()
        XCTAssertEqual(run.problemNumber, 2)
        XCTAssertEqual(run.input, "")
        run.input = "5"
        run.submit()
        XCTAssertEqual(run.phase, .completed)
        XCTAssertEqual(run.solvedCount, 2)
        XCTAssertEqual(run.problemNumber, 2)
        run.submit()
        run.nextProblem()
        XCTAssertEqual(run.phase, .completed)
        XCTAssertEqual(run.solvedCount, 2)
    }

    func testEachRetryGeneratesAProblemWithCapturedDifficulty() {
        var generated: [Difficulty] = []
        var run = MathPracticeSession(difficulty: .hard, problemCount: 2, whizUnlocked: false) {
            generated.append($0)
            return MathProblem(expression: "Question \(generated.count)", answer: generated.count)
        }
        run.input = "0"
        run.submit()
        run.nextProblem()
        XCTAssertEqual(run.problem.expression, "Question 2")
        XCTAssertEqual(generated, [.hard, .hard])
    }

    func testPracticeLeavesActiveAlarmAndPersistenceUntouched() throws {
        let statsData = UserDefaults.standard.data(forKey: "app_stats_v1")
        let alarmData = UserDefaults.standard.data(forKey: "saved_alarms")
        let stats = StatsStore.shared.stats
        let scheduler = AlarmScheduler()
        let id = UUID().uuidString
        defer {
            scheduler.dismiss()
            AlarmGate.forget(id)
        }
        scheduler.startRinging(alarmID: id, volume: 0, preview: true)
        var run = session(count: 1)
        run.input = "5"
        run.submit()
        XCTAssertEqual(run.phase, .completed)
        XCTAssertEqual(scheduler.activeAlarmID, id)
        XCTAssertTrue(scheduler.isRinging)
        XCTAssertFalse(AlarmGate.isSolved(id))
        XCTAssertTrue(AlarmGate.reringIDs(id).isEmpty)
        XCTAssertEqual(UserDefaults.standard.data(forKey: "app_stats_v1"), statsData)
        XCTAssertEqual(UserDefaults.standard.data(forKey: "saved_alarms"), alarmData)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        XCTAssertEqual(try encoder.encode(StatsStore.shared.stats), try encoder.encode(stats))
    }
}
