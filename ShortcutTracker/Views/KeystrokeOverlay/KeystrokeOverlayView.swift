import SwiftUI

/// View for displaying keystrokes in the overlay.
struct KeystrokeOverlayView: View {
    @ObservedObject var controller: KeystrokeOverlayController

    private var alignment: Alignment {
        switch controller.position {
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        }
    }

    private var horizontalAlignment: HorizontalAlignment {
        switch controller.position {
        case .bottomLeft, .topLeft: return .leading
        case .bottomRight, .topRight: return .trailing
        }
    }

    private var insertionEdge: Edge {
        switch controller.position {
        case .bottomLeft, .bottomRight: return .bottom
        case .topLeft, .topRight: return .top
        }
    }

    private var shouldReverse: Bool {
        switch controller.position {
        case .bottomLeft, .bottomRight: return true
        case .topLeft, .topRight: return false
        }
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: 8) {
            let items = shouldReverse ? Array(controller.keystrokes.reversed()) : controller.keystrokes
            ForEach(items) { keystroke in
                KeystrokeItemView(keystroke: keystroke, controller: controller)
                    .transition(.asymmetric(
                        insertion: .move(edge: insertionEdge).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .id(keystroke.id)
            }
        }
        .frame(width: 380, height: 150, alignment: alignment)
        .padding(10)
    }
}

// MARK: - Keystroke Item View

struct KeystrokeItemView: View {
    let keystroke: KeystrokeItem
    @ObservedObject var controller: KeystrokeOverlayController

    var body: some View {
        HStack(spacing: 8) {
            Text(keystroke.keys)
                .font(controller.currentFont)
                .foregroundColor(Color(controller.textColor))

            if let title = keystroke.matchedTitle {
                Text("→")
                    .font(.system(size: controller.fontSize * 0.7))
                    .foregroundColor(Color(controller.textColor).opacity(0.7))
                Text(title)
                    .font(.system(size: controller.fontSize * 0.7, weight: .medium))
                    .foregroundColor(Color.yellow)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: controller.cornerRadius)
                .fill(Color(controller.backgroundColor).opacity(controller.backgroundOpacity))
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    KeystrokeOverlayView(controller: KeystrokeOverlayController.shared)
}
