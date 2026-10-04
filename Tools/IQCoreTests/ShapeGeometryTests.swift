import XCTest
@testable import IQCore

/// Guards the visual vocabulary.
///
/// Every option a player can tap is drawn from `ShapeGeometry`. If a shape degenerates,
/// it renders as nothing — an option that looks like a blank tile and silently costs the
/// player the item. If a shape looks identical under rotation, the rotation and matrix
/// items built from it have no visible rule and no distinguishable answer. Neither failure
/// throws, crashes, or is caught by a "does it compile" check, so they are asserted here.
final class ShapeGeometryTests: XCTestCase {
    private let radius = 1.0

    func testEveryShapeProducesAClosedPolygon() {
        for shape in ShapeSpec.Shape.allCases {
            let vertices = ShapeGeometry.outline(for: shape, radius: self.radius)
            // Three is legitimate: the triangle is a real triangle, not a cut corner.
            XCTAssertGreaterThanOrEqual(vertices.count, 3, "\(shape) has too few vertices")
        }
    }

    func testEveryShapeHasAUsableArea() {
        for shape in ShapeSpec.Shape.allCases {
            let area = ShapeGeometry.area(of: ShapeGeometry.outline(for: shape, radius: self.radius))
            // A polygon that has collapsed to a line or a sliver is invisible in practice.
            XCTAssertGreaterThan(area, 0.20 * self.radius * self.radius,
                                 "\(shape) collapsed to area \(area)")
        }
    }

    func testEveryShapeFillsBothDimensionsOfItsBox() {
        for shape in ShapeSpec.Shape.allCases {
            guard let box = ShapeGeometry.boundingBox(
                of: ShapeGeometry.outline(for: shape, radius: self.radius)
            ) else { return XCTFail("\(shape) produced no bounding box") }

            let width = box.maxX - box.minX
            let height = box.maxY - box.minY
            // A bar is deliberately flat, hence the loose bound.
            XCTAssertGreaterThan(width, 0.15 * self.radius, "\(shape) is too narrow to see")
            XCTAssertGreaterThan(height, 0.15 * self.radius, "\(shape) is too flat to see")
            XCTAssertLessThanOrEqual(width, 2.1 * self.radius, "\(shape) overflows its box")
            XCTAssertLessThanOrEqual(height, 2.1 * self.radius, "\(shape) overflows its box")
        }
    }

    func testGeometryScalesWithRadius() {
        for shape in ShapeSpec.Shape.allCases {
            let small = ShapeGeometry.area(of: ShapeGeometry.outline(for: shape, radius: 0.5))
            let large = ShapeGeometry.area(of: ShapeGeometry.outline(for: shape, radius: 2.0))
            XCTAssertEqual(large / small, 16, accuracy: 0.6, "\(shape) is not scale-invariant")
        }
    }

    func testNoShapeIsDegenerateAtExtremeRadii() {
        for shape in ShapeSpec.Shape.allCases {
            for radius in [0.2, 1.0, 50.0, 500.0] {
                let area = ShapeGeometry.area(of: ShapeGeometry.outline(for: shape, radius: radius))
                XCTAssertGreaterThan(
                    area, 0.15 * radius * radius,
                    "\(shape) degenerates at radius \(radius)"
                )
            }
        }
    }

    func testCrescentIsActuallyACrescent() {
        // Two overlapping circles: the result must be meaningfully smaller than a full disc
        // yet comfortably larger than half of one.
        let fullDisc = Double.pi
        let area = ShapeGeometry.area(of: ShapeGeometry.outline(for: .crescent, radius: 1))
        XCTAssertLessThan(area, 0.72 * fullDisc, "the crescent swallowed the whole disc")
        XCTAssertGreaterThan(area, 0.30 * fullDisc, "the crescent is too thin to read as a shape")
    }

    // MARK: - Rotation and mirroring must be observable

    func testRotationSensitiveShapesLookDifferentAfterAQuarterTurn() {
        for shape in ShapeGeometry.rotationSensitive {
            let upright = ShapeGeometry.outline(for: shape, radius: 1)
            for turns in 1...3 {
                let turned = ShapeGeometry.outline(for: shape, radius: 1, quarterTurns: turns)
                XCTAssertNotEqual(
                    upright, turned,
                    "\(shape) looks identical after \(turns * 90)°, so a rotation item using it has no visible answer"
                )
            }
        }
    }

    func testRotationSensitiveListExcludesSymmetricShapes() {
        for excluded in [ShapeSpec.Shape.circle, .ring, .square, .cross] {
            XCTAssertFalse(
                ShapeGeometry.rotationSensitive.contains(excluded),
                "\(excluded) is rotationally symmetric and cannot carry a rotation rule"
            )
        }
    }

    func testHandedShapesLookDifferentWhenMirrored() {
        for shape in ShapeGeometry.handed {
            let original = ShapeGeometry.outline(for: shape, radius: 1)
            let mirrored = original.map { Vertex(x: -$0.x, y: $0.y) }
            XCTAssertNotEqual(
                original, mirrored,
                "\(shape) is left-right symmetric, so a mirror item using it has no correct answer"
            )
        }
    }

    func testHandedListExcludesSymmetricShapes() {
        for excluded in [ShapeSpec.Shape.circle, .ring, .square, .cross] {
            XCTAssertFalse(
                ShapeGeometry.handed.contains(excluded),
                "\(excluded) mirrors to itself"
            )
        }
    }

    // MARK: - The generators must respect those palettes

    func testRotationItemsOnlyUseRotationSensitiveShapes() {
        for seed in 0..<80 {
            var generator = SeededGenerator(seed: UInt64(seed &* 17 &+ 3))
            let puzzle = SpatialGenerator.make(kind: .rotation, theta: 3.0, generator: &generator, id: "rot")
            guard case .shape(let target) = puzzle.stimulus,
                  case .optionIndex(let answerIndex) = puzzle.answer,
                  case .shape(let answer) = puzzle.options[answerIndex].graphic else {
                return XCTFail("unexpected puzzle shape")
            }
            XCTAssertTrue(
                ShapeGeometry.rotationSensitive.contains(target.shape),
                "seed \(seed): rotation stimulus used \(target.shape)"
            )
            XCTAssertTrue(ShapeGeometry.rotationSensitive.contains(answer.shape), "seed \(seed)")
        }
    }

    func testMatrixItemsOnlyUseRotationSensitiveShapes() {
        for seed in 0..<80 {
            for theta in [1.8, 3.2, 4.6] {
                var generator = SeededGenerator(seed: UInt64(seed &* 31 &+ Int(theta)))
                let puzzle = MatrixGenerator.make(kind: .matrix, theta: theta, generator: &generator, id: "m")
                guard case .matrix(let spec) = puzzle.stimulus else { return XCTFail("wrong stimulus") }
                for cell in spec.cells.compactMap({ $0 }) {
                    XCTAssertTrue(
                        ShapeGeometry.rotationSensitive.contains(cell.shape),
                        "seed \(seed): matrix cell used \(cell.shape), whose rotation is invisible"
                    )
                }
            }
        }
    }

    func testMatrixRowsActuallyShowAChangingRotation() {
        // A matrix whose visible cells are all at the same angle has no rule to find.
        var unchanged = 0
        for seed in 0..<80 {
            var generator = SeededGenerator(seed: UInt64(seed &* 11 &+ 5))
            let puzzle = MatrixGenerator.make(kind: .matrix, theta: 3.2, generator: &generator, id: "m")
            guard case .matrix(let spec) = puzzle.stimulus else { continue }
            let rotations = Set(spec.cells.compactMap { $0?.rotation })
            if rotations.count < 2 { unchanged += 1 }
        }
        XCTAssertEqual(unchanged, 0, "a matrix with a single rotation across all cells is unsolvable")
    }

    func testSpatialCountUsesShapesVisibleInACluster() {
        for seed in 0..<60 {
            var generator = SeededGenerator(seed: UInt64(seed))
            let puzzle = SpatialGenerator.make(kind: .spatialCount, theta: 3.0, generator: &generator, id: "c")
            guard case .shape(let target) = puzzle.stimulus else { return XCTFail("wrong stimulus") }
            XCTAssertFalse(target.arrangement == .single)
            XCTAssertGreaterThanOrEqual(target.count, 4)
        }
    }
}