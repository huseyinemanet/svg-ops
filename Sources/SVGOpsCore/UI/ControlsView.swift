import SwiftUI

struct ControlsView: View {
    @Binding var settings: ConversionSettings
    var isConverting: Bool
    var binaryWarning: String?
    var convertAction: () -> Void

    private let labelWidth: CGFloat = 72
    private let leftControlWidth: CGFloat = 390
    private let fillSegmentWidth: CGFloat = 292
    private let customFillWidth: CGFloat = 86
    private let rightControlWidth: CGFloat = 300

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("Mode")
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: .leading)

                        Picker("Mode", selection: $settings.mode) {
                            ForEach(ConversionMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: leftControlWidth)
                    }

                    HStack(spacing: 12) {
                        Text("Fill")
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: .leading)

                        if settings.mode.requiresPotrace {
                            HStack(spacing: 12) {
                                Picker("Fill", selection: $settings.fillMode) {
                                    ForEach(FillMode.allCases) { fill in
                                        Text(fill.title).tag(fill)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(width: fillSegmentWidth)

                                Group {
                                    if settings.fillMode == .custom {
                                        ColorPicker(
                                            "Custom fill",
                                            selection: customFillColor,
                                            supportsOpacity: false
                                        )
                                        .labelsHidden()
                                    } else {
                                        Spacer(minLength: 0)
                                    }
                                }
                                .frame(width: customFillWidth, height: 22)
                            }
                            .frame(width: leftControlWidth, alignment: .leading)
                        } else {
                            Text("Preserved from image")
                                .foregroundStyle(.secondary)
                                .frame(width: leftControlWidth, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Text("Quality")
                            .foregroundStyle(.secondary)
                            .frame(width: labelWidth, alignment: .leading)

                        Picker("Quality", selection: $settings.quality) {
                            ForEach(ConversionQuality.allCases) { quality in
                                Text(quality.title).tag(quality)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: rightControlWidth)
                    }

                    HStack(spacing: 12) {
                        Spacer(minLength: 0)
                            .frame(width: labelWidth)

                        Button(action: convertAction) {
                            Text(isConverting ? "Converting..." : "Convert to SVG")
                                .frame(maxWidth: .infinity)
                        }
                        .frame(width: rightControlWidth)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(isConverting)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let binaryWarning {
                Label(binaryWarning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.44))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                }
        }
    }

    private var customFillColor: Binding<Color> {
        Binding {
            Color(hex: settings.customFillHex) ?? .black
        } set: { color in
            settings.customFillHex = color.hexString
        }
    }
}

private extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") {
            value.removeFirst()
        }

        guard value.count == 6,
              let number = Int(value, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((number >> 16) & 0xff) / 255,
            green: Double((number >> 8) & 0xff) / 255,
            blue: Double(number & 0xff) / 255
        )
    }

    var hexString: String {
        let color = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
