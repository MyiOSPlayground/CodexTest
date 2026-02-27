import CoreGraphics
import SwiftUI

struct FractalZoomToyView: View {
    let onBackToMainMenu: () -> Void

    @StateObject private var renderer = FractalRendererModel()

    @State private var mode: FractalMode = .mandelbrot
    @State private var center = SIMD2<Double>(-0.62, 0.0)
    @State private var span: Double = 3.2
    @State private var juliaConstant = SIMD2<Double>(-0.8, 0.156)
    @State private var maxIterations: Double = 180
    @State private var colorShift: Double = 0.08

    @State private var dragStartCenter: SIMD2<Double>?
    @State private var pinchStartSpan: Double?
    @State private var canvasSize: CGSize = .zero

    private let minSpan = 0.0000005
    private let maxSpan = 6.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.08),
                    Color(red: 0.03, green: 0.05, blue: 0.12),
                    Color(red: 0.07, green: 0.03, blue: 0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            GeometryReader { geometry in
                ZStack {
                    if let image = renderer.image {
                        Image(decorative: image, scale: 1.0)
                            .resizable()
                            .interpolation(.none)
                            .antialiased(false)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .contentShape(Rectangle())
                .simultaneousGesture(dragGesture(size: geometry.size))
                .simultaneousGesture(magnificationGesture())
                .simultaneousGesture(
                    SpatialTapGesture()
                        .onEnded { value in
                            handleTap(at: value.location, in: geometry.size)
                        }
                )
                .highPriorityGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            resetView()
                        }
                )
                .onAppear {
                    canvasSize = geometry.size
                    requestRender(interactive: false)
                }
                .onChange(of: geometry.size) { _, newSize in
                    canvasSize = newSize
                    requestRender(interactive: false)
                }
            }

            hud
        }
        .onChange(of: mode) { _, _ in
            requestRender(interactive: false)
        }
        .onChange(of: maxIterations) { _, _ in
            requestRender(interactive: false)
        }
        .onChange(of: colorShift) { _, _ in
            requestRender(interactive: false)
        }
        .frame(minWidth: 760, minHeight: 820)
    }

    private var hud: some View {
        VStack {
            HStack {
                Button("메인 메뉴") {
                    onBackToMainMenu()
                }
                .buttonStyle(FractalHudButtonStyle())

                Spacer()

                Text("FRACTAL ZOOM VIEWER")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.black.opacity(0.34), in: Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Spacer()

            VStack(spacing: 8) {
                Picker("Mode", selection: $mode) {
                    ForEach(FractalMode.allCases) { fractalMode in
                        Text(fractalMode.rawValue).tag(fractalMode)
                    }
                }
                .pickerStyle(.segmented)

                FractalControlRow(
                    title: "반복 횟수",
                    valueText: "\(Int(maxIterations))",
                    value: $maxIterations,
                    range: 60...420
                )
                FractalControlRow(
                    title: "컬러 시프트",
                    valueText: String(format: "%.2f", colorShift),
                    value: $colorShift,
                    range: 0...1
                )

                HStack {
                    Text("중심: \(format(center.x)), \(format(center.y))")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.8))
                    Spacer()
                    Text("줌: \(String(format: "%.2fx", 3.2 / max(span, minSpan)))")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.85, green: 0.95, blue: 1.0))
                }

                HStack {
                    Text("드래그 이동 / 핀치 줌 / 더블클릭 리셋")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.66))
                    Spacer()
                    Button("초기화") {
                        resetView()
                    }
                    .buttonStyle(FractalHudButtonStyle())
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.17), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartCenter == nil {
                    dragStartCenter = center
                }
                guard let start = dragStartCenter else { return }

                let aspect = Double(size.height / max(size.width, 1))
                let dx = Double(value.translation.width / size.width) * span
                let dy = Double(value.translation.height / size.height) * span * aspect

                center = SIMD2<Double>(start.x - dx, start.y - dy)
                requestRender(interactive: true)
            }
            .onEnded { _ in
                dragStartCenter = nil
                requestRender(interactive: false)
            }
    }

    private func magnificationGesture() -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if pinchStartSpan == nil {
                    pinchStartSpan = span
                }
                guard let start = pinchStartSpan else { return }

                let next = start / max(0.01, Double(value))
                span = min(max(next, minSpan), maxSpan)
                requestRender(interactive: true)
            }
            .onEnded { _ in
                pinchStartSpan = nil
                requestRender(interactive: false)
            }
    }

    private func handleTap(at location: CGPoint, in size: CGSize) {
        let complex = complexCoordinate(for: location, in: size)
        if mode == .mandelbrot {
            juliaConstant = complex
        } else {
            center = complex
        }
        requestRender(interactive: false)
    }

    private func complexCoordinate(for location: CGPoint, in size: CGSize) -> SIMD2<Double> {
        let width = max(1.0, Double(size.width))
        let height = max(1.0, Double(size.height))
        let nx = Double(location.x) / width - 0.5
        let ny = Double(location.y) / height - 0.5
        let aspect = height / width

        return SIMD2<Double>(
            center.x + nx * span,
            center.y + ny * span * aspect
        )
    }

    private func requestRender(interactive: Bool) {
        renderer.requestRender(
            mode: mode,
            center: center,
            span: span,
            juliaConstant: juliaConstant,
            maxIterations: Int(maxIterations),
            colorShift: colorShift,
            size: canvasSize,
            interactive: interactive
        )
    }

    private func resetView() {
        if mode == .mandelbrot {
            center = SIMD2<Double>(-0.62, 0.0)
            span = 3.2
        } else {
            center = SIMD2<Double>(0.0, 0.0)
            span = 3.2
        }
        requestRender(interactive: false)
    }

    private func format(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}

private enum FractalMode: String, CaseIterable, Identifiable {
    case mandelbrot = "만델브로"
    case julia = "줄리아"

    var id: String { rawValue }
}

private final class FractalRendererModel: ObservableObject {
    @Published var image: CGImage?

    private let queue = DispatchQueue(label: "fractal-render-queue", qos: .userInitiated)
    private var requestToken: Int = 0

    func requestRender(
        mode: FractalMode,
        center: SIMD2<Double>,
        span: Double,
        juliaConstant: SIMD2<Double>,
        maxIterations: Int,
        colorShift: Double,
        size: CGSize,
        interactive: Bool
    ) {
        guard size.width > 4, size.height > 4 else { return }

        requestToken += 1
        let token = requestToken

        let sampleScale = interactive ? 0.45 : 0.82
        let pixelWidth = max(240, Int(size.width * sampleScale))
        let pixelHeight = max(180, Int(size.height * sampleScale))
        let iterations = max(40, Int(Double(maxIterations) * (interactive ? 0.65 : 1.0)))

        queue.async {
            let rendered = Self.makeImage(
                width: pixelWidth,
                height: pixelHeight,
                mode: mode,
                center: center,
                span: span,
                juliaConstant: juliaConstant,
                maxIterations: iterations,
                colorShift: colorShift
            )

            DispatchQueue.main.async {
                guard token == self.requestToken else { return }
                self.image = rendered
            }
        }
    }

    private static func makeImage(
        width: Int,
        height: Int,
        mode: FractalMode,
        center: SIMD2<Double>,
        span: Double,
        juliaConstant: SIMD2<Double>,
        maxIterations: Int,
        colorShift: Double
    ) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let aspect = Double(height) / Double(width)

        for y in 0..<height {
            let imag = center.y + (Double(y) / Double(height) - 0.5) * span * aspect
            for x in 0..<width {
                let real = center.x + (Double(x) / Double(width) - 0.5) * span

                let cReal: Double
                let cImag: Double
                var zReal: Double
                var zImag: Double

                switch mode {
                case .mandelbrot:
                    cReal = real
                    cImag = imag
                    zReal = 0
                    zImag = 0
                case .julia:
                    cReal = juliaConstant.x
                    cImag = juliaConstant.y
                    zReal = real
                    zImag = imag
                }

                var iteration = 0
                while iteration < maxIterations {
                    let zr2 = zReal * zReal
                    let zi2 = zImag * zImag
                    if zr2 + zi2 > 4 { break }

                    let nextReal = zr2 - zi2 + cReal
                    let nextImag = 2 * zReal * zImag + cImag
                    zReal = nextReal
                    zImag = nextImag
                    iteration += 1
                }

                let offset = (y * width + x) * 4
                if iteration == maxIterations {
                    bytes[offset] = 4
                    bytes[offset + 1] = 6
                    bytes[offset + 2] = 14
                    bytes[offset + 3] = 255
                    continue
                }

                let magnitude = max(1.000_000_1, sqrt(zReal * zReal + zImag * zImag))
                let smooth = Double(iteration) + 1.0 - log2(log2(magnitude))
                let normalized = max(0, min(1, smooth / Double(maxIterations)))

                let hue = fmod(0.58 + colorShift + normalized * 0.92, 1.0)
                let saturation = 0.78 + normalized * 0.2
                let brightness = 0.2 + pow(normalized, 0.44) * 0.95
                let rgb = hsvToRGB(h: hue, s: saturation, v: brightness)

                bytes[offset] = UInt8(max(0, min(255, Int(rgb.r * 255))))
                bytes[offset + 1] = UInt8(max(0, min(255, Int(rgb.g * 255))))
                bytes[offset + 2] = UInt8(max(0, min(255, Int(rgb.b * 255))))
                bytes[offset + 3] = 255
            }
        }

        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func hsvToRGB(h: Double, s: Double, v: Double) -> (r: Double, g: Double, b: Double) {
        let clampedS = max(0, min(1, s))
        let clampedV = max(0, min(1, v))
        let hh = (h - floor(h)) * 6
        let i = Int(hh) % 6
        let f = hh - Double(i)
        let p = clampedV * (1 - clampedS)
        let q = clampedV * (1 - f * clampedS)
        let t = clampedV * (1 - (1 - f) * clampedS)

        switch i {
        case 0: return (clampedV, t, p)
        case 1: return (q, clampedV, p)
        case 2: return (p, clampedV, t)
        case 3: return (p, q, clampedV)
        case 4: return (t, p, clampedV)
        default: return (clampedV, p, q)
        }
    }
}

private struct FractalHudButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.25, green: 0.24, blue: 0.42)
                    .opacity(configuration.isPressed ? 0.84 : 0.63),
                in: RoundedRectangle(cornerRadius: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct FractalControlRow: View {
    let title: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                Spacer()
                Text(valueText)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color(red: 0.87, green: 0.92, blue: 1.0))
            }
            Slider(value: $value, in: range)
                .tint(Color(red: 0.66, green: 0.92, blue: 1.0))
        }
    }
}

struct FractalZoomToyView_Previews: PreviewProvider {
    static var previews: some View {
        FractalZoomToyView(onBackToMainMenu: {})
    }
}
