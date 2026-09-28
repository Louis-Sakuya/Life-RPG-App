import PhotosUI
import SwiftUI
import UIKit

enum AvatarCatalog {
    static let presets = [
        "person.crop.circle.fill",
        "person.fill",
        "figure.walk",
        "figure.run",
        "shield.lefthalf.filled",
        "crown.fill",
        "sparkles",
        "wand.and.stars",
        "flame.fill",
        "bolt.fill",
        "leaf.fill",
        "moon.stars.fill",
        "sun.max.fill",
        "book.fill",
        "hare.fill",
        "tortoise.fill",
        "cat.fill",
        "bird.fill",
        "pawprint.fill",
        "star.fill",
        "heart.fill",
        "gamecontroller.fill",
        "paintpalette.fill",
        "hammer.fill"
    ]
}

enum AvatarImage {
    static let maxDimension: CGFloat = 512

    static func prepared(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return prepared(from: image)
    }

    static func prepared(from image: UIImage) -> Data? {
        squared(image, maxDimension: maxDimension).jpegData(compressionQuality: 0.82)
    }

    private static func squared(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        let upright = image.imageOrientation == .up
            ? image
            : UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }

        let size = upright.size
        guard size.width > 0, size.height > 0 else { return upright }

        let side = min(size.width, size.height)
        let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side) / 2)
        let cropRect = CGRect(origin: origin, size: CGSize(width: side, height: side))
        let outputSide = min(maxDimension, side)
        let outputSize = CGSize(width: outputSide, height: outputSide)

        return UIGraphicsImageRenderer(size: outputSize, format: format).image { _ in
            upright.draw(in: CGRect(
                x: -cropRect.origin.x * (outputSide / side),
                y: -cropRect.origin.y * (outputSide / side),
                width: size.width * (outputSide / side),
                height: size.height * (outputSide / side)
            ))
        }
    }
}

struct AvatarView: View {
    var symbol: String
    var imageData: Data?
    var size: CGFloat
    var showsEditBadge: Bool = false

    @Environment(\.palette) private var palette

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Circle()
                    .fill(palette.gradient)
                    .frame(width: size, height: size)
                if let data = imageData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size - 4, height: size - 4)
                        .clipShape(Circle())
                } else {
                    Image(systemName: symbol)
                        .font(.system(size: max(16, size * 0.42), weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            if showsEditBadge {
                Image(systemName: "pencil.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, palette.accent)
                    .font(.system(size: max(18, size * 0.34)))
                    .offset(x: 2, y: 2)
            }
        }
        .frame(width: size, height: size)
    }
}

struct AvatarPicker: View {
    @Binding var symbol: String
    @Binding var imageData: Data?
    var previewSize: CGFloat = 108

    @Environment(\.palette) private var palette
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPresentingCamera = false

    private var canUseCamera: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    var body: some View {
        VStack(spacing: 18) {
            AvatarView(symbol: symbol, imageData: imageData, size: previewSize)

            HStack(spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    pickerChip(icon: "photo.on.rectangle.angled", title: L10n.t("avatar.photo"), highlighted: imageData != nil)
                }
                .buttonStyle(.plain)

                if canUseCamera {
                    Button {
                        isPresentingCamera = true
                    } label: {
                        pickerChip(icon: "camera.fill", title: L10n.t("avatar.camera"), highlighted: false)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.t("avatar.presets"))
                    .font(.subheadline.weight(.semibold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(AvatarCatalog.presets, id: \.self) { name in
                        Button {
                            symbol = name
                            imageData = nil
                            pickerItem = nil
                        } label: {
                            Image(systemName: name)
                                .font(.system(size: 18))
                                .frame(width: 42, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(isPresetSelected(name) ? palette.accent.opacity(0.22) : Color.primary.opacity(0.06))
                                )
                                .foregroundStyle(isPresetSelected(name) ? palette.accent : Color.primary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(name)
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let prepared = AvatarImage.prepared(from: data) {
                    await MainActor.run {
                        imageData = prepared
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $isPresentingCamera) {
            CameraPicker(isPresented: $isPresentingCamera) { image in
                imageData = AvatarImage.prepared(from: image)
            }
            .ignoresSafeArea()
        }
    }

    private func isPresetSelected(_ name: String) -> Bool {
        imageData == nil && symbol == name
    }

    private func pickerChip(icon: String, title: String, highlighted: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            Capsule().fill(highlighted ? palette.accent.opacity(0.18) : Color.primary.opacity(0.06))
        )
        .foregroundStyle(highlighted ? palette.accent : Color.primary)
    }
}

struct AvatarEditorSheet: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var symbol: String
    @State private var imageData: Data?

    init(player: Player) {
        _symbol = State(initialValue: player.avatarSymbol)
        _imageData = State(initialValue: player.avatarImageData)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                AvatarPicker(symbol: $symbol, imageData: $imageData)
                    .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(L10n.t("avatar.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.t("common.save")) {
                        store.updateAvatar(symbol: symbol, imageData: imageData)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        context.coordinator.onCapture = onCapture
        context.coordinator.onDismiss = { isPresented = false }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onCapture: onCapture,
            onDismiss: { isPresented = false }
        )
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onCapture: (UIImage) -> Void
        var onDismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage {
                onCapture(image)
            }
            onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }
    }
}
