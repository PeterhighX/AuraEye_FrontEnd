import XCTest
@testable import MakeupChat

final class PhotoSourceRoutingTests: XCTestCase {
    func testGalleryModeDecodesOnlyFrozenServerValues() throws {
        let fixed = try JSONDecoder().decode(
            AccountFeatures.self,
            from: Data(#"{"gallery_mode":"fixed_demo","use_demo_assets":true,"allow_live_recognition_seed":false}"#.utf8)
        )
        let authorized = try JSONDecoder().decode(
            AccountFeatures.self,
            from: Data(#"{"gallery_mode":"authorized_library","use_demo_assets":false,"allow_live_recognition_seed":false}"#.utf8)
        )

        XCTAssertEqual(fixed.galleryMode, .fixedDemo)
        XCTAssertEqual(authorized.galleryMode, .authorizedLibrary)
        XCTAssertFalse(fixed.galleryMode.allowsCameraCapture)
        XCTAssertTrue(authorized.galleryMode.allowsCameraCapture)
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                AccountFeatures.self,
                from: Data(#"{"gallery_mode":"username_demo","use_demo_assets":true,"allow_live_recognition_seed":false}"#.utf8)
            )
        )
    }

    func testPhotoSourceFactoryUsesOnlyGalleryMode() {
        let fixed = AccountFeatures(
            galleryMode: .fixedDemo,
            useDemoAssets: false,
            allowLiveRecognitionSeed: true
        )
        let authorized = AccountFeatures(
            galleryMode: .authorizedLibrary,
            useDemoAssets: true,
            allowLiveRecognitionSeed: true
        )

        XCTAssertTrue(PhotoSourceFactory.make(features: fixed) is DemoBundlePhotoSource)
        XCTAssertTrue(PhotoSourceFactory.make(features: authorized) is AuthorizedPhotoKitSource)
    }
}
