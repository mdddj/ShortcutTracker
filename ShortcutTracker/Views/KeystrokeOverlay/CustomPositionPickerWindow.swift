import AppKit
import SwiftUI

/// A draggable window for picking custom overlay position
class CustomPositionPickerWindow: NSWindow {
    var onSavePosition: ((CGFloat, CGFloat) -> Void)?
    var onCancelPicker: (() -> Void)?
    
    init(initialX: CGFloat, initialY: CGFloat) {
        super.init(
            contentRect: NSRect(x: initialX, y: initialY, width: 400, height: 160),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isMovableByWindowBackground = true
        hasShadow = true
        
        // Position window
        setFrameOrigin(NSPoint(x: initialX, y: initialY))
    }
    
    func setupContent() {
        let contentView = CustomPositionPickerView(
            onSave: { [weak self] in
                self?.saveAndClose()
            },
            onCancel: { [weak self] in
                self?.cancelAndClose()
            }
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
    }
    
    private func saveAndClose() {
        let x = frame.origin.x
        let y = frame.origin.y
        orderOut(nil)
        onSavePosition?(x, y)
    }
    
    private func cancelAndClose() {
        orderOut(nil)
        onCancelPicker?()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// SwiftUI view for the position picker content
struct CustomPositionPickerView: View {
    let onSave: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        ZStack {
            // Dashed border background
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 3, dash: [10, 5]))
                .foregroundColor(.accentColor)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                )
            
            VStack(spacing: 12) {
                Text("拖动此框到目标位置")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Drag to desired position")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
                
                HStack(spacing: 16) {
                    Button(action: onCancel) {
                        Text("取消")
                            .frame(width: 80)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    
                    Button(action: onSave) {
                        Text("保存位置")
                            .frame(width: 80)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.top, 8)
            }
            .padding()
        }
        .frame(width: 400, height: 160)
    }
}

/// Controller for showing the position picker
class CustomPositionPickerController {
    static let shared = CustomPositionPickerController()
    
    private var pickerWindow: CustomPositionPickerWindow?
    
    func showPicker(initialX: CGFloat, initialY: CGFloat, onSave: @escaping (CGFloat, CGFloat) -> Void) {
        // Close existing picker if any
        pickerWindow?.orderOut(nil)
        pickerWindow = nil
        
        let window = CustomPositionPickerWindow(initialX: initialX, initialY: initialY)
        
        window.onSavePosition = { [weak self] x, y in
            DispatchQueue.main.async {
                onSave(x, y)
                self?.pickerWindow = nil
            }
        }
        
        window.onCancelPicker = { [weak self] in
            DispatchQueue.main.async {
                self?.pickerWindow = nil
            }
        }
        
        window.setupContent()
        pickerWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
