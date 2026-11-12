import AppKit
import CoreImage
import UniformTypeIdentifiers

struct QR {
    let size: Int
    let cells: [Bool]
    static func make(_ text: String) throws -> QR {
        let link = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: link), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty, !link.contains(where: { $0.isWhitespace }) else { throw Failure.message("Enter a complete https:// or http:// link.") }
        guard link.utf8.count <= 2000 else { throw Failure.message("Use a link under 2,000 UTF-8 bytes.") }
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(Data(link.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { throw Failure.message("Could not generate this QR code.") }
        let n = Int(output.extent.width)
        var pixels = [UInt8](repeating: 0, count: n * n * 4)
        CIContext().render(output, toBitmap: &pixels, rowBytes: n * 4, bounds: output.extent, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        // Read module rows, crop the built-in border, and add a four-module quiet zone.
        var dark = [(Int, Int)]()
        for y in 0..<n { for x in 0..<n { if pixels[(y * n + x) * 4] < 128 { dark.append((x, y)) } } }
        guard let minX = dark.map({ $0.0 }).min(), let maxX = dark.map({ $0.0 }).max(), let minY = dark.map({ $0.1 }).min(), let maxY = dark.map({ $0.1 }).max() else { throw Failure.message("Empty QR code.") }
        let size = max(maxX - minX, maxY - minY) + 9
        var cells = [Bool](repeating: false, count: size * size)
        for (x, y) in dark { cells[(y - minY + 4) * size + x - minX + 4] = true }
        return QR(size: size, cells: cells)
    }
    func svg(hex: String) -> String {
        var path = ""
        for y in 0..<size { for x in 0..<size where cells[y * size + x] { path += "M\(x) \(y)h1v1h-1z" } }
        return "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(size) \(size)\" shape-rendering=\"crispEdges\"><path fill=\"\(hex)\" d=\"\(path)\"/></svg>\n"
    }
}
enum Failure: LocalizedError { case message(String); var errorDescription: String? { if case let .message(text) = self { return text }; return nil } }
func parseColor(_ hex: String) -> NSColor? {
    guard hex.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil, let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
    return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
}
func colorHex(_ color: NSColor) -> String {
    let c = color.usingColorSpace(.sRGB) ?? .black
    return String(format: "#%02x%02x%02x", Int((c.redComponent * 255).rounded()), Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
}
final class DropView: NSView {
    var onLink: ((String) -> Void)?
    override init(frame: NSRect) { super.init(frame: frame); registerForDraggedTypes([.URL, .string]) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func droppedLink(_ pasteboard: NSPasteboard) -> String? {
        let text = pasteboard.string(forType: .URL) ?? pasteboard.string(forType: .string)
        guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines), let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil else { return nil }
        return value
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { droppedLink(sender.draggingPasteboard) == nil ? [] : .copy }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let value = droppedLink(sender.draggingPasteboard) else { return false }
        onLink?(value); return true
    }
}
final class Preview: NSView, NSDraggingSource {
    var onError: ((String) -> Void)?
    private var dragStarted = false
    override func mouseDown(with event: NSEvent) { dragStarted = false }
    override func mouseDragged(with event: NSEvent) {
        guard !dragStarted, let qr = qr else { return }
        do {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("QRStudio-Exports").appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let file = directory.appendingPathComponent("qr-code.svg")
            try qr.svg(hex: colorHex(ink)).write(to: file, atomically: true, encoding: .utf8)
            let item = NSDraggingItem(pasteboardWriter: file as NSURL)
            let image = NSImage(size: bounds.size)
            image.lockFocus(); ink.setFill()
            let unit = bounds.width / CGFloat(qr.size)
            for y in 0..<qr.size { for x in 0..<qr.size where qr.cells[y * qr.size + x] { NSRect(x: CGFloat(x) * unit, y: CGFloat(qr.size - 1 - y) * unit, width: unit, height: unit).fill() } }
            image.unlockFocus()
            item.setDraggingFrame(bounds, contents: image)
            dragStarted = true
            beginDraggingSession(with: [item], event: event, source: self)
        } catch { onError?("Could not drag SVG: \(error.localizedDescription)") }
    }
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    var qr: QR? { didSet { needsDisplay = true } }
    var ink = parseColor("#182c38")! { didSet { needsDisplay = true } }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        NSColor(white: 0.92, alpha: 1).setFill()
        for y in stride(from: 0, to: Int(bounds.height), by: 10) { for x in stride(from: 0, to: Int(bounds.width), by: 10) where (x / 10 + y / 10) % 2 == 0 { NSRect(x: x, y: y, width: 10, height: 10).fill() } }
        if let qr = qr {
            NSGraphicsContext.current?.shouldAntialias = false
            ink.setFill()
            let unit = bounds.width / CGFloat(qr.size)
            for y in 0..<qr.size { for x in 0..<qr.size where qr.cells[y * qr.size + x] { NSRect(x: CGFloat(x) * unit, y: CGFloat(y) * unit, width: unit, height: unit).fill() } }
        } else {
            let text = "Your QR code goes here" as NSString
            text.draw(at: NSPoint(x: 38, y: 111), withAttributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.darkGray])
        }
    }
}
final class Controller: NSViewController, NSTextFieldDelegate {
    let link = NSTextField(), hex = NSTextField(string: "#182c38"), well = NSColorWell()
    let preview = Preview(), status = NSTextField(wrappingLabelWithString: "Links stay on your Mac. No server required.")
    let download = NSButton(title: "Download SVG…", target: nil, action: nil)
    override func loadView() {
        let dropView = DropView(frame: NSRect(x: 0, y: 0, width: 370, height: 650))
        dropView.onLink = { [weak self] value in self?.link.stringValue = value; self?.generateQR() }
        view = dropView
        preview.onError = { [weak self] message in self?.status.stringValue = message }
        func label(_ text: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat = 12) { let l = NSTextField(labelWithString: text); l.font = .systemFont(ofSize: size); l.frame = NSRect(x: x, y: y, width: 326, height: 22); view.addSubview(l) }
        label("◈  QR STUDIO", 22, 608, 20)
        label("Drop a link here. Drag your QR out as SVG.", 22, 580)
        label("Where should it go?", 22, 548)
        link.frame = NSRect(x: 22, y: 514, width: 326, height: 28); link.placeholderString = "https://example.com"; link.delegate = self; link.setAccessibilityLabel("Link"); view.addSubview(link)
        label("Foreground color", 22, 481)
        well.frame = NSRect(x: 22, y: 445, width: 48, height: 30); well.color = parseColor(hex.stringValue)!; well.target = self; well.action = #selector(colorChanged); view.addSubview(well)
        hex.frame = NSRect(x: 82, y: 447, width: 142, height: 26); hex.delegate = self; hex.setAccessibilityLabel("Hex foreground color"); view.addSubview(hex)
        label("Dark colors scan best on light surfaces.", 22, 416, 11)
        let generate = NSButton(title: "Generate QR code", target: self, action: #selector(generateQR)); generate.bezelStyle = .rounded; generate.frame = NSRect(x: 18, y: 375, width: 334, height: 34); generate.keyEquivalent = "\r"; view.addSubview(generate)
        preview.frame = NSRect(x: 65, y: 127, width: 240, height: 240); preview.setAccessibilityLabel("QR code preview on transparency checkerboard"); view.addSubview(preview)
        label("Transparent SVG · Drag preview to export", 58, 101, 11)
        download.frame = NSRect(x: 18, y: 62, width: 334, height: 34); download.bezelStyle = .rounded; download.target = self; download.action = #selector(save); download.isEnabled = false; view.addSubview(download)
        status.frame = NSRect(x: 22, y: 13, width: 270, height: 42); status.font = .systemFont(ofSize: 10); status.textColor = .secondaryLabelColor; view.addSubview(status)
        let quit = NSButton(title: "Quit", target: NSApp, action: #selector(NSApplication.terminate(_:))); quit.bezelStyle = .inline; quit.frame = NSRect(x: 300, y: 22, width: 48, height: 24); view.addSubview(quit)
        NSColorPanel.shared.showsAlpha = false
    }
    func controlTextDidChange(_ obj: Notification) {
        if let field = obj.object as? NSTextField, field === hex, let color = parseColor(hex.stringValue) { well.color = color }
        invalidate()
    }
    func invalidate() { preview.qr = nil; download.isEnabled = false; status.stringValue = "Generate again to apply your changes." }
    @objc func colorChanged() { hex.stringValue = colorHex(well.color); invalidate() }
    @objc func generateQR() {
        do {
            guard let color = parseColor(hex.stringValue) else { throw Failure.message("Enter a six-digit color, such as #182c38.") }
            preview.qr = try QR.make(link.stringValue); preview.ink = color; download.isEnabled = true
            status.stringValue = "Ready. Test on the final background before sharing."
        } catch { preview.qr = nil; download.isEnabled = false; status.stringValue = error.localizedDescription }
    }
    @objc func save() {
        guard let qr = preview.qr else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.svg]; panel.nameFieldStringValue = "qr-code.svg"; panel.canCreateDirectories = true
        NSApp.activate(ignoringOtherApps: true)
        if panel.runModal() == .OK, let url = panel.url {
            do { try qr.svg(hex: colorHex(preview.ink)).write(to: url, atomically: true, encoding: .utf8); status.stringValue = "Saved \(url.lastPathComponent)." }
            catch { status.stringValue = "Save failed: \(error.localizedDescription)" }
        }
    }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    let popover = NSPopover()
    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "qrcode", accessibilityDescription: "QR Studio")
        item.button?.toolTip = "QR Studio — create a transparent SVG"
        item.button?.target = self; item.button?.action = #selector(toggle)
        popover.contentViewController = Controller(); popover.behavior = .applicationDefined
        toggle()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { if !popover.isShown { toggle() }; return true }
    @objc func toggle() {
        if popover.isShown { popover.close(); NSColorPanel.shared.orderOut(nil) }
        else if let button = item.button { popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY); NSApp.activate(ignoringOtherApps: true); popover.contentViewController?.view.window?.makeKey() }
    }
}
if CommandLine.arguments.contains("--self-test") {
    do {
        let qr = try QR.make("https://example.com/qr?a=1&b=two")
        let svg = qr.svg(hex: "#573a8c")
        assert(svg.contains("fill=\"#573a8c\"")); assert(!svg.contains("<image")); assert(!svg.contains("<rect"))
        for y in 0..<qr.size { for x in 0..<qr.size where x < 4 || y < 4 || x >= qr.size - 4 || y >= qr.size - 4 { assert(!qr.cells[y * qr.size + x]) } }
        // Render exported matrix independently and decode with Apple's QR detector.
        let scale = 8, width = qr.size * scale
        var data = [UInt8](repeating: 255, count: width * width * 4)
        for y in 0..<width { for x in 0..<width where qr.cells[(y / scale) * qr.size + x / scale] { let i = (y * width + x) * 4; data[i] = 0; data[i+1] = 0; data[i+2] = 0 } }
        let image = CIImage(bitmapData: Data(data), bytesPerRow: width * 4, size: CGSize(width: width, height: width), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        let detector = CIDetector(ofType: CIDetectorTypeQRCode, context: CIContext(), options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])!
        let decoded = detector.features(in: image).compactMap { ($0 as? CIQRCodeFeature)?.messageString }
        guard decoded.contains("https://example.com/qr?a=1&b=two") else { throw Failure.message("QR decode failed: \(decoded)") }
        for bad in ["", "example.com", "javascript:alert(1)", "https://example.com/" + String(repeating: "a", count: 2000)] { do { _ = try QR.make(bad); fatalError("Accepted invalid URL") } catch {} }
        assert(parseColor("#abc") == nil); assert(parseColor("#123456") != nil)
        if let index = CommandLine.arguments.firstIndex(of: "--export-test"), CommandLine.arguments.count > index + 1 { try svg.write(toFile: CommandLine.arguments[index + 1], atomically: true, encoding: .utf8) }
        print("PASS: QR decoding, transparent vector export, quiet zone, input validation.")
    } catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
} else {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let delegate = AppDelegate(); app.delegate = delegate; app.run()
}
