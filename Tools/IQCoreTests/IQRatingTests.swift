import XCTest
@testable import IQCore

/// Verifies the mathematical backbone of the report: that the θ → IQ → percentile
/// mapping behaves the way the UI claims it does, and that confidence intervals widen
/// when they should.
final class IQRatingTests: XCTestCase {
    func testMeanThetaMapsToIQ100() {
        XCTAssertEqual(IQRating.iq(forTheta: IQRating.meanTheta), 100, accuracy: 0.0001)
    }

    func testMeanThetaMapsToFiftiethPercentile() {
        XCTAssertEqual(IQRating.percentile(forTheta: IQRating.meanTheta), 50, accuracy: 0.01)
    }

    func testOneSigmaAboveMeanIsIQ115And84thPercentile() {
        let theta = IQRating.meanTheta + IQRating.thetaSigma
        XCTAssertEqual(IQRating.iq(forTheta: theta), 115, accuracy: 0.0001)
        // The cumulative percentile at +1σ is ~84%. (68% is the area *between* the mean
        // and +1σ, which is a different quantity and a classic place to go wrong.)
        XCTAssertEqual(IQRating.percentile(forTheta: theta), 84.13, accuracy: 0.05)
    }

    func testIQAndThetaRoundTrip() {
        for iq in stride(from: 70.0, through: 145.0, by: 5.0) {
            XCTAssertEqual(IQRating.iq(forTheta: IQRating.theta(forIQ: iq)), iq, accuracy: 0.0001)
        }
    }

    func testPercentileIsMonotonicInTheta() {
        var previous = -1.0
        for step in 0...40 {
            let percentile = IQRating.percentile(forTheta: 1.0 + Double(step) * 0.1)
            XCTAssertGreaterThan(percentile, previous)
            previous = percentile
        }
    }

    // MARK: - Item scoring

    func testWrongAnswerScoresZero() {
        XCTAssertEqual(
            IQRating.itemScore(theta: 4, correct: false, elapsed: 1, timeLimit: 30, hintsUsed: 0), 0
        )
    }

    func testFastUnsolvedHintScoreBeatsSlowAnswer() {
        let fast = IQRating.itemScore(theta: 4, correct: true, elapsed: 6, timeLimit: 30, hintsUsed: 0)
        let slowWithHints = IQRating.itemScore(theta: 4, correct: true, elapsed: 27, timeLimit: 30, hintsUsed: 2)
        XCTAssertGreaterThan(fast, slowWithHints)
    }

    func testHintsReduceScore() {
        let none = IQRating.itemScore(theta: 3, correct: true, elapsed: 10, timeLimit: 30, hintsUsed: 0)
        let one = IQRating.itemScore(theta: 3, correct: true, elapsed: 10, timeLimit: 30, hintsUsed: 1)
        let two = IQRating.itemScore(theta: 3, correct: true, elapsed: 10, timeLimit: 30, hintsUsed: 2)
        XCTAssertGreaterThan(none, one)
        XCTAssertGreaterThan(one, two)
    }

    func testItemScoreIsClampedToZeroAtTheBottom() {
        let score = IQRating.itemScore(theta: 1, correct: true, elapsed: 300, timeLimit: 10, hintsUsed: 4)
        XCTAssertEqual(score, 0, accuracy: 0.0001)
    }

    func testItemScoreIsClampedToSixAtTheTop() {
        let score = IQRating.itemScore(theta: 6, correct: true, elapsed: 0, timeLimit: 30, hintsUsed: 0)
        XCTAssertEqual(score, 6, accuracy: 0.0001)
    }

    // MARK: - Confidence intervals

    func testMoreItemsProduceANarrowerInterval() {
        let few = IQRating.confidenceInterval(theta: 3, itemCount: 12, dispersion: 0.5)
        let many = IQRating.confidenceInterval(theta: 3, itemCount: 120, dispersion: 0.5)
        XCTAssertLessThan(many.high - many.low, few.high - few.low)
    }

    func testInconsistentPerformanceWidensTheInterval() {
        let consistent = IQRating.confidenceInterval(theta: 3, itemCount: 60, dispersion: 0.2)
        let erratic = IQRating.confidenceInterval(theta: 3, itemCount: 60, dispersion: 2.0)
        XCTAssertGreaterThan(erratic.high - erratic.low, consistent.high - consistent.low)
    }

    func testIntervalIsCentredOnTheEstimate() {
        let interval = IQRating.confidenceInterval(theta: 3.4, itemCount: 40, dispersion: 0.8)
        let estimate = IQRating.iq(forTheta: 3.4)
        let midpoint = (interval.low + interval.high) / 2
        XCTAssertEqual(midpoint, estimate, accuracy: 0.001)
    }

    // MARK: - Bands

    func testBandBoundaries() {
        XCTAssertEqual(IQBand.band(for: 55), .veryLow)
        XCTAssertEqual(IQBand.band(for: 70), .low)
        XCTAssertEqual(IQBand.band(for: 85), .average)
        XCTAssertEqual(IQBand.band(for: 115), .high)
        XCTAssertEqual(IQBand.band(for: 130), .veryHigh)
    }

    func testBandIsWithheldWhenTheIntervalStraddlesABoundary() {
        // Estimate 100 sits inside `average`, but the interval crosses into `high`.
        XCTAssertNil(IQRating.confidentBand(estimate: 100, low: 96, high: 118))
    }

    func testBandIsClaimedWhenTheIntervalFitsInside() {
        XCTAssertEqual(IQRating.confidentBand(estimate: 100, low: 96, high: 108), .average)
    }

    // MARK: - Statistics

    func testStandardDeviation() {
        XCTAssertEqual(IQRating.standardDeviation([2, 2, 2, 2]), 0, accuracy: 0.0001)
        XCTAssertEqual(IQRating.standardDeviation([2, 4, 4, 4, 5, 5, 7, 9]), 2, accuracy: 0.0001)
        XCTAssertEqual(IQRating.standardDeviation([5]), 0, accuracy: 0.0001)
    }

    func testNormalCDFAnchors() {
        XCTAssertEqual(MathKit.normalCDF(0), 0.5, accuracy: 1e-6)
        XCTAssertEqual(MathKit.normalCDF(1.96), 0.975, accuracy: 1e-3)
        XCTAssertEqual(MathKit.normalCDF(-1.96), 0.025, accuracy: 1e-3)
    }
}