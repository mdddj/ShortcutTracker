import SwiftUI
import AppKit

/// A button that captures keyboard shortcuts when clicked.
/// Uses a sheet with a dedicated capture view for reliable key capture.
struct KeyCaptureField: View {
    @Binding var keys: String
    let placeholder: String
    
    @State private var showCaptureSheet = false
    
    var body: some View {
        HStack {
            Text(keys.isEmpty ? placeholder : keys)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(keys.isEmpty ? .secondary : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            if !keys.isEmpty {
                Button {
                    keys = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Button("Record") {
                showCaptureSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showCaptureSheet) {
            KeyCaptureSheet(keys: $keys, isPresented: $showCaptureSheet)
        }
    }
}

/// Sheet view for capturing keyboard shortcuts
struct KeyCaptureSheet: View {
    @Binding var keys: String
    @Binding var isPresented: Bool
    
    @State private var capturedKeys = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Press a keyboard shortcut")
                .font(.headline)
            
            Text(capturedKeys.isEmpty ? "Waiting for input..." : capturedKeys)
                .font(.system(size: 32, weight: .medium, design: .monospaced))
                .foregroundStyle(capturedKeys.isEmpty ? .secondary : .primary)
                .frame(height: 50)
            
            Text("Press Escape to cancel")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Use This Shortcut") {
                    keys = capturedKeys
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(capturedKeys.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 350)
        .background(KeyCaptureNSViewWrapper(capturedKeys: $capturedKeys, onEscape: {
            isPresented = false
        }))
    }
}

/// NSViewRepresentable wrapper for key capture
struct KeyCaptureNSViewWrapper: NSViewRepresentable {
    @Binding var capturedKeys: String
    let onEscape: () -> Void
    
    func makeNSView(context: Context) -> KeyCaptureNSView {
        let view = KeyCaptureNSView()
        view.onKeyCapture = { keys in
            capturedKeys = keys
        }
        view.onEscape = onEscape
        return view
    }
    
    func updateNSView(_ nsView: KeyCaptureNSView, context: Context) {
        // Make sure the view can receive key events
        DispatchQueue.main.async {
            nsView.window?.makeFirstResponder(nsView)
        }
    }
}

/// Custom NSView that captures keyboard events
class KeyCaptureNSView: NSView {
    var onKeyCapture: ((String) -> Void)?
    var onEscape: (() -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    override var canBecomeKeyView: Bool { true }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    
    override func keyDown(with event: NSEvent) {
        // Check for Escape key
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        
        let keys = buildKeyString(from: event)
        if !keys.isEmpty {
            onKeyCapture?(keys)
        }
    }
    
    private func buildKeyString(from event: NSEvent) -> String {
        var parts: [String] = []
        let flags = event.modifierFlags
        
        // Add modifier keys in standard order
        if flags.contains(.control) {
            parts.append("⌃")
        }
        if flags.contains(.option) {
            parts.append("⌥")
        }
        if flags.contains(.shift) {
            parts.append("⇧")
        }
        if flags.contains(.command) {
            parts.append("⌘")
        }
        
        // Add the main key
        if let key = keyString(for: event.keyCode, with: event.charactersIgnoringModifiers) {
            parts.append(key)
        }
        
        return parts.joined()
    }
    
    private func keyString(for keyCode: UInt16, with characters: String?) -> String? {
        // Special keys mapping
        let specialKeys: [UInt16: String] = [
            36: "↩",    // Return
            48: "⇥",    // Tab
            49: "Space", // Space
            51: "⌫",    // Delete
            117: "⌦",   // Forward Delete
            123: "←",   // Left Arrow
            124: "→",   // Right Arrow
            125: "↓",   // Down Arrow
            126: "↑",   // Up Arrow
            115: "↖",   // Home
            119: "↘",   // End
            116: "⇞",   // Page Up
            121: "⇟",   // Page Down
            // Function keys
            122: "F1", 120: "F2", 99: "F3", 118: "F4",
            96: "F5", 97: "F6", 98: "F7", 100: "F8",
            101: "F9", 109: "F10", 103: "F11", 111: "F12"
        ]
        
        if let special = specialKeys[keyCode] {
            return special
        }
        
        // Use the character if available
        if let char = characters?.uppercased(), !char.isEmpty {
            return char
        }
        
        return nil
    }
}

#Preview {
    VStack {
        KeyCaptureField(keys: .constant(""), placeholder: "Click Record to capture...")
        KeyCaptureField(keys: .constant("⌘S"), placeholder: "Click Record to capture...")
    }
    .padding()
    .frame(width: 350)
}
