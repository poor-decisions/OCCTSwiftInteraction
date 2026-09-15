import OCCTSwiftViewport
import Testing
import simd

@testable import OCCTSwiftCADKit

/// Regression coverage for the `.constant(bodies)` binding bug (fixed by mirroring `bodies`
/// into `@State liveBodies` and rebinding through `$liveBodies`, keyed off `bodiesIdentity`).
///
/// `bodiesIdentity` is what tells `.onChange(of:)` in `CADViewportView.body` that `liveBodies`
/// needs to be refreshed. If it ever stops changing for a case that matters (a body added,
/// removed, or rebuilt in place), `liveBodies` goes stale again and the original bug comes
/// back in a different shape, so this suite pins exactly those cases.
@Suite("CADViewportView bodies identity")
struct CADViewportViewBindingIdentityTests {
    private func body(id: String) -> _ViewportBody {
        _ViewportBody(
            id: id,
            vertexData: [0, 0, 0, 0, 1, 0],
            indices: [0],
            edges: [],
            color: SIMD4<Float>(1, 1, 1, 1)
        )
    }

    @MainActor
    @Test("a body being added changes the identity key")
    func additionChangesIdentity() {
        let before = [body(id: "model")]
        let after = before + [body(id: "selection_highlight_face")]

        #expect(
            CADViewportView.bodiesIdentity(for: before)
                != CADViewportView.bodiesIdentity(for: after))
    }

    @MainActor
    @Test("a body being removed changes the identity key")
    func removalChangesIdentity() {
        let before = [body(id: "model"), body(id: "selection_highlight_face")]
        let after = [body(id: "model")]

        #expect(
            CADViewportView.bodiesIdentity(for: before)
                != CADViewportView.bodiesIdentity(for: after))
    }

    @MainActor
    @Test("a body rebuilt in place (same id, new generation) changes the identity key")
    func inPlaceRebuildChangesIdentity() {
        let original = body(id: "model")
        let rebuilt = body(id: "model")

        #expect(original.generation != rebuilt.generation)
        #expect(
            CADViewportView.bodiesIdentity(for: [original])
                != CADViewportView.bodiesIdentity(for: [rebuilt]))
    }

    @MainActor
    @Test("the same body list produces the same identity key every time")
    func stableForUnchangedBodies() {
        let bodies = [body(id: "model"), body(id: "fixture")]

        #expect(
            CADViewportView.bodiesIdentity(for: bodies)
                == CADViewportView.bodiesIdentity(for: bodies))
    }
}
