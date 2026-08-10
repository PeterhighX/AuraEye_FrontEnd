import UIKit
import XCTest
@testable import MakeupChat

final class DemoBundlePhotoSourceTests: XCTestCase {
    func testLoadsExactlyFourJPEGsAndReturnsUnchangedOriginalBytes() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("demo-fixtures-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let names = ["tool.jpg", "eyeliner.jpg", "portrait.jpg", "eyeshadow.jpg"]
        var originals: [String: Data] = [:]
        for (index, name) in names.enumerated() {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2))
            let image = renderer.image { context in
                UIColor(white: CGFloat(index + 1) / 5, alpha: 1).setFill()
                context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
            }
            let data = try XCTUnwrap(image.jpegData(compressionQuality: 1))
            try data.write(to: directory.appendingPathComponent(name))
            originals[name] = data
        }
        let items = names.enumerated().map {
            ["id": "fixture-\($0.offset)", "resource": $0.element, "title": "Fixture"]
        }
        let manifest = try JSONSerialization.data(withJSONObject: ["version": "1", "items": items])
        try manifest.write(to: directory.appendingPathComponent("demo-gallery-manifest.json"))

        let photos = try await DemoBundlePhotoSource(resourceDirectoryURL: directory).loadPhotos()

        XCTAssertEqual(photos.count, 4)
        for (photo, name) in zip(photos, names) {
            XCTAssertEqual(photo.mimeType, "image/jpeg")
            let loadedData = try await photo.loadOriginalData()
            XCTAssertEqual(loadedData, originals[name])
        }
    }
}
