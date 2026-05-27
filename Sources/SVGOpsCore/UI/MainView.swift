import SwiftUI
import UniformTypeIdentifiers

public struct MainView: View {
    @EnvironmentObject private var preferences: PreferencesService
    @StateObject private var viewModel: MainViewModel

    public init() {
        _viewModel = StateObject(wrappedValue: MainViewModel(settings: .defaults))
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if viewModel.originalURL == nil {
                    DropZoneView(
                        isTargeted: viewModel.isDropTargeted,
                        chooseAction: { viewModel.chooseFile(preferences: preferences) }
                    )
                } else {
                    VStack(spacing: 16) {
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(viewModel.originalURL?.lastPathComponent ?? "Image")
                                    .font(.title3.weight(.semibold))
                                    .lineLimit(1)
                                    .truncationMode(.middle)

                                Text("Drop another PNG, JPG, or WEBP anywhere in this window to replace it")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button {
                                viewModel.chooseFile(preferences: preferences)
                            } label: {
                                Label("New Image...", systemImage: "plus")
                            }
                            .disabled(viewModel.isConverting)
                            .buttonStyle(.bordered)

                            Button {
                                viewModel.clear()
                            } label: {
                                Text("Clear")
                            }
                            .disabled(viewModel.isConverting)
                            .buttonStyle(.bordered)
                        }

                        HStack(spacing: 16) {
                            PreviewPane(
                                title: "Original Image",
                                imageURL: viewModel.originalURL,
                                svg: nil,
                                placeholder: ""
                            )

                            PreviewPane(
                                title: "SVG Preview",
                                imageURL: nil,
                                svg: viewModel.result?.svg,
                                placeholder: "Ready to convert",
                                hidesSVGContent: viewModel.isDropTargeted
                            )
                        }

                        ControlsView(
                            settings: $viewModel.settings,
                            isConverting: viewModel.isConverting,
                            binaryWarning: viewModel.binaryWarning,
                            convertAction: { viewModel.convert(preferences: preferences) }
                        )

                        ResultActionsView(
                            result: viewModel.result,
                            copied: viewModel.copied,
                            copyAction: viewModel.copySVG,
                            saveAction: viewModel.saveSVG,
                            revealAction: viewModel.revealInFinder
                        )

                        StatusBarView(message: viewModel.statusMessage, isConverting: viewModel.isConverting)
                    }
                    .padding(.horizontal, 34)
                    .padding(.top, 34)
                    .padding(.bottom, 24)
                }
            }

            if viewModel.originalURL != nil, viewModel.isDropTargeted {
                DropReplaceOverlay()
                    .padding(34)
                    .zIndex(1000)
                    .transaction { transaction in
                        transaction.disablesAnimations = true
                    }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("SVG Ops")
        .onAppear {
            viewModel.settings = preferences.defaultSettings
        }
        .onChange(of: viewModel.settings) { _ in
            preferences.updateLastUsedSettings(viewModel.settings)
            viewModel.settingsDidChange(preferences: preferences)
        }
        .onOpenURL { url in
            viewModel.load(url: url, preferences: preferences)
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDropTargeted) { providers in
            guard let provider = providers.first else { return false }
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url: URL?
                if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else if let itemURL = item as? URL {
                    url = itemURL
                } else {
                    url = nil
                }

                if let url {
                    Task { @MainActor in
                        viewModel.load(url: url, preferences: preferences)
                    }
                }
            }
            return true
        }
    }
}

private struct DropReplaceOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.08), radius: 24, y: 10)

            VStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                Text("Drop to replace image")
                    .font(.title3.weight(.semibold))

                Text("PNG, JPG, or WEBP")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
