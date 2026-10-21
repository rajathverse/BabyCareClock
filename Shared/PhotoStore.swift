import UIKit

/// The baby's photo, stored once as a small JPEG in the shared container so the app,
/// widget and Keychain backup can all use it.
enum PhotoStore {
    private static let fileName = "baby-photo.jpg"
    /// Widgets reject large images, so the photo is kept well under their limit.
    private static let maxPixelSize: CGFloat = 700

    static var url: URL { AppGroup.directory.appendingPathComponent(fileName) }

    static func load() -> UIImage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    @discardableResult
    static func save(_ image: UIImage) -> UIImage? {
        let resized = downscaled(image)
        guard let data = resized.jpegData(compressionQuality: 0.82) else { return nil }
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return resized
        } catch {
            print("Unable to save photo: \(error.localizedDescription)")
            return nil
        }
    }

    static func delete() {
        try? FileManager.default.removeItem(at: url)
    }

    private static func downscaled(_ image: UIImage) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        let scale = longest > maxPixelSize ? maxPixelSize / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
