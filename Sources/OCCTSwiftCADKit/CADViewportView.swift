import OCCTSwift
import OCCTSwiftTools
import OCCTSwiftViewport
import SwiftUI

/// SwiftUI wrapper around the Metal viewport, with a selection-info banner
/// and display-mode controls.
///
/// Bind to a `CADViewportService` for the standard pattern:
///
/// ```swift
/// @State private var viewport = CADViewportService()
///
/// var body: some View {
///     CADViewportView(
///         bodies: viewport.bodies,
///         controller: viewport.controller,
///         selection: viewport.selection,
///         onClearSelection: { viewport.clearSelection() }
///     )
/// }
/// ```
public struct CADViewportView: View {
    public let bodies: [_ViewportBody]
    @ObservedObject public var controller: _ViewportController
    public var selection: [PickedEntity]
    public var onClearSelection: (() -> Void)?

    /// A real, live-updating mirror of `bodies`.
    ///
    /// `_MetalViewportView`'s `ViewportRenderer` captures the `Binding` it's
    /// given exactly once, into a stored property, at construction (it's
    /// only ever constructed once itself, guarded by `renderer == nil` in
    /// `onAppear`) and reads through that same captured reference on every
    /// frame after. Handing it `.constant(bodies)` (the previous
    /// implementation) meant that captured reference's getter permanently
    /// returned whatever `bodies` happened to be on the very first render:
    /// structurally, no update after that (a selection highlight appearing,
    /// any later body change) could ever reach the renderer, not just
    /// "sometimes didn't." `$liveBodies` is a genuine `Binding` backed by
    /// persistent `@State`, so the renderer's one-time-captured reference
    /// keeps reading the current value correctly.
    @State private var liveBodies: [_ViewportBody] = []

    /// Changes whenever the body *set* changes: which bodies exist (`id`)
    /// and whether any single one was rebuilt in place (`generation`, a
    /// monotonic per-body counter). `_ViewportBody` doesn't conform to
    /// `Equatable`, so `[_ViewportBody]` can't be either, and this is what
    /// `.onChange` keys off instead of the array directly.
    private var bodiesIdentity: String {
        Self.bodiesIdentity(for: bodies)
    }

    /// The pure key-derivation behind `bodiesIdentity`, pulled out as a
    /// static function so it's testable without constructing a live view
    /// (which needs a real `_ViewportController`). This is the contract
    /// `.onChange(of:)` in `body` relies on to know when `liveBodies` needs
    /// to be refreshed: if two body sets are meaningfully different (a body
    /// added, removed, or rebuilt in place) but happen to produce the same
    /// key here, `liveBodies` silently goes stale again, the same failure
    /// mode `.constant(bodies)` had.
    static func bodiesIdentity(for bodies: [_ViewportBody]) -> String {
        bodies.map { "\($0.id):\($0.generation)" }.joined(separator: ",")
    }

    public init(
        bodies: [_ViewportBody],
        controller: _ViewportController,
        selection: [PickedEntity] = [],
        onClearSelection: (() -> Void)? = nil
    ) {
        self.bodies = bodies
        self.controller = controller
        self.selection = selection
        self.onClearSelection = onClearSelection
    }

    public var body: some View {
        GeometryReader { proxy in
            _MetalViewportView(controller: controller, bodies: $liveBodies)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .onAppear { liveBodies = bodies }
        .onChange(of: bodiesIdentity) { liveBodies = bodies }
        .overlay(alignment: .top) {
            if selection.count == 1, let entity = selection.first {
                selectionLabel(entity)
                    .padding(8)
            } else if selection.count > 1 {
                selectionSummaryLabel(count: selection.count)
                    .padding(8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            viewportControls
                .padding(8)
        }
    }

    private func selectionSummaryLabel(count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checklist")
            Text("\(count) selected")
                .font(.caption)
            Button {
                onClearSelection?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func selectionLabel(_ entity: PickedEntity) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconName(for: entity))
                .foregroundStyle(iconColor(for: entity))
            Text(description(for: entity))
                .font(.caption)
            Button {
                onClearSelection?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func iconName(for entity: PickedEntity) -> String {
        switch entity {
        case .face(let info): return info.isHorizontal ? "square.fill" : "rectangle.portrait.fill"
        case .edge: return "line.diagonal"
        case .vertex: return "circle.fill"
        }
    }

    /// Matches the highlight color `CADViewportService` draws in the 3D scene for each kind.
    private func iconColor(for entity: PickedEntity) -> SwiftUI.Color {
        switch entity {
        case .face: return .yellow
        case .edge: return .cyan
        case .vertex: return .pink
        }
    }

    private func description(for entity: PickedEntity) -> String {
        switch entity {
        case .face(let info): return info.description
        case .edge(let info): return info.description
        case .vertex(let info): return info.description
        }
    }

    private var viewportControls: some View {
        HStack(spacing: 4) {
            Button {
                controller.displayMode = .shaded
            } label: {
                Image(systemName: "cube.fill")
                    .foregroundStyle(controller.displayMode == .shaded ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                controller.displayMode = .shadedWithEdges
            } label: {
                Image(systemName: "cube.transparent")
                    .foregroundStyle(
                        controller.displayMode == .shadedWithEdges ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                controller.displayMode = .wireframe
            } label: {
                Image(systemName: "square.dashed")
                    .foregroundStyle(controller.displayMode == .wireframe ? .blue : .secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16)

            Button {
                controller.goToStandardView(.isometricFrontRight)
            } label: {
                Image(systemName: "rotate.3d")
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
