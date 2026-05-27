import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var preferences: PreferencesService

    public init() { }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            SettingsSection("Workflow") {
                ToggleRow("Auto convert on drop", isOn: $preferences.autoConvertOnDrop)
                ToggleRow("Copy SVG after conversion", isOn: $preferences.copyAfterConversion)
                ToggleRow("Save next to original", isOn: $preferences.saveNextToOriginal)
            }

            SettingsSection("Defaults") {
                DefaultRow("Mode") {
                    Picker("Mode", selection: $preferences.defaultSettings.mode) {
                        ForEach(ConversionMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                }

                DefaultRow("Quality") {
                    Picker("Quality", selection: $preferences.defaultSettings.quality) {
                        ForEach(ConversionQuality.allCases) { quality in
                            Text(quality.title).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                }

                DefaultRow("Fill") {
                    Picker("Fill", selection: $preferences.defaultSettings.fillMode) {
                        ForEach(FillMode.allCases) { fill in
                            Text(fill.title).tag(fill)
                        }
                    }
                    .pickerStyle(.menu)
                }

                DefaultRow("Filename suffix") {
                    TextField(".vector", text: $preferences.defaultSettings.outputFilenameSuffix)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 38)
        .padding(.bottom, 24)
        .frame(width: 460, height: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.title2.weight(.semibold))

            Text("Defaults and workflow for local SVG conversion.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.44))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
                    }
            }
        }
    }
}

private struct ToggleRow: View {
    var title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.callout)

            Spacer()

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(height: 34)
    }
}

private struct DefaultRow<Control: View>: View {
    var title: String
    @ViewBuilder var control: Control

    init(_ title: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)

            Spacer()

            control
                .labelsHidden()
                .controlSize(.regular)
                .frame(width: 190)
        }
        .frame(height: 38)
    }
}
