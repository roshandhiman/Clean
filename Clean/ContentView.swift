import SwiftUI
import AppKit

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct WindowSetup: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { configure(view.window) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { configure(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func configure(_ window: NSWindow?) {
        guard let window else { return }
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.hasShadow = true
    }
}

func sizeText(_ bytes: Int64) -> String {
    if bytes == 0 { return "-" }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

struct ChipView: View {
    let title: String
    let size: Int64
    let color: Color
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.65)
                Text(sizeText(size))
                    .font(.system(size: 12, weight: .semibold))
            }
            .frame(width: 80, height: 44)
            .background(
                on ? color.opacity(0.5) : Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? color : Color.white.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(size == 0)
        .opacity(size == 0 ? 0.35 : 1)
    }
}

struct RowView: View {
    let item: AppItem
    @ObservedObject var model: CleanerModel

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 44, height: 44)
            Text(item.name)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 10)
            ChipView(title: "App", size: item.appSize, color: .blue, on: model.isOn(item.id, .app)) {
                model.toggle(item.id, .app)
            }
            ChipView(title: "Cache", size: item.cacheSize, color: .orange, on: model.isOn(item.id, .cache)) {
                model.toggle(item.id, .cache)
            }
            ChipView(title: "Data", size: item.dataSize, color: .purple, on: model.isOn(item.id, .data)) {
                model.toggle(item.id, .data)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct ContentView: View {
    @StateObject private var model = CleanerModel()
    @State private var confirm = false

    var body: some View {
        ZStack {
            ZStack {
                GlassBackground()
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.clear, Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()

            VStack(spacing: 14) {
                header
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(model.visible) { item in
                            RowView(item: item, model: model)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 4)
                }
                .overlay {
                    if model.visible.isEmpty {
                        empty
                    }
                }
                footer
            }
            .padding(.top, 34)
        }
        .frame(minWidth: 680, minHeight: 480)
        .preferredColorScheme(.dark)
        .background(WindowSetup())
        .onAppear { model.scan() }
        .confirmationDialog("Move to Trash?", isPresented: $confirm) {
            Button("Move to Trash", role: .destructive) {
                model.deleteSelected()
            }
        } message: {
            Text("\(model.selectedCount) item(s), \(sizeText(model.selectedSize)) will be moved to the Trash.")
        }
    }

    var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $model.search)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.08), in: Capsule())

            if model.scanning {
                ProgressView()
                    .controlSize(.small)
            }

            Button(action: { model.scan() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(model.scanning || model.deleting)
        }
        .padding(.horizontal, 22)
    }

    var empty: some View {
        VStack(spacing: 8) {
            if model.scanning {
                Text("Scanning apps…")
            } else {
                Text("No apps found")
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }

    var footer: some View {
        HStack(spacing: 12) {
            if model.deleting {
                ProgressView()
                    .controlSize(.small)
            } else if model.selectedCount > 0 {
                Text(sizeText(model.selectedSize))
                    .font(.system(size: 15, weight: .semibold))
            }
            if model.failed > 0 {
                Text("\(model.failed) failed")
                    .font(.system(size: 12))
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button(action: { confirm = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash")
                    Text("Delete")
                }
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.red.opacity(model.selectedCount == 0 ? 0.25 : 0.85), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(model.selectedCount == 0 || model.deleting)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }
}

#Preview {
    ContentView()
}
