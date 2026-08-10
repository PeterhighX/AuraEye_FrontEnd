import Foundation
import Photos
import UIKit
import UniformTypeIdentifiers

struct SelectedPhoto: Identifiable, @unchecked Sendable {
    let id: String
    let preview: UIImage
    let mimeType: String
    let byteSizeHint: Int?
    let loadOriginalData: @Sendable () async throws -> Data
}

protocol PhotoSource: Sendable {
    func loadPhotos() async throws -> [SelectedPhoto]
}

enum PhotoSourceError: LocalizedError, Equatable {
    case missingDemoManifest
    case invalidDemoManifest
    case missingDemoResource(String)
    case photoAccessDenied
    case photoAccessRestricted
    case photoUnavailable
    case unsupportedGalleryMode

    var errorDescription: String? {
        switch self {
        case .missingDemoManifest: return "演示相册资源尚未安装。"
        case .invalidDemoManifest: return "演示相册配置无效。"
        case .missingDemoResource: return "演示图片资源不完整。"
        case .photoAccessDenied: return "未获得照片访问权限，请前往系统设置授权。"
        case .photoAccessRestricted: return "当前设备限制了照片访问。"
        case .photoUnavailable: return "所选照片暂时无法读取。"
        case .unsupportedGalleryMode: return "相册模式配置无效，请联系服务端管理员。"
        }
    }
}

enum PhotoSourceFactory {
    static func make(
        features: AccountFeatures,
        bundle: Bundle = .main
    ) -> any PhotoSource {
        switch features.galleryMode {
        case .fixedDemo:
            return DemoBundlePhotoSource(bundle: bundle)
        case .authorizedLibrary:
            return AuthorizedPhotoKitSource()
        }
    }
}

private struct DemoGalleryManifest: Decodable {
    let version: String
    let items: [DemoGalleryManifestItem]
}

private struct DemoGalleryManifestItem: Decodable {
    let id: String
    let resource: String
    let title: String
}

final class DemoBundlePhotoSource: PhotoSource, @unchecked Sendable {
    private let bundle: Bundle
    private let resourceDirectoryURL: URL?

    init(bundle: Bundle = .main) {
        self.bundle = bundle
        self.resourceDirectoryURL = nil
    }

    init(resourceDirectoryURL: URL) {
        self.bundle = .main
        self.resourceDirectoryURL = resourceDirectoryURL
    }

    func loadPhotos() async throws -> [SelectedPhoto] {
        let manifestURL = resourceDirectoryURL?.appendingPathComponent("demo-gallery-manifest.json")
            ?? bundle.url(
                forResource: "demo-gallery-manifest",
                withExtension: "json",
                subdirectory: "DemoFixtures"
            )
        guard let manifestURL else {
            throw PhotoSourceError.missingDemoManifest
        }
        let manifest = try JSONDecoder().decode(
            DemoGalleryManifest.self,
            from: Data(contentsOf: manifestURL, options: [.mappedIfSafe])
        )
        guard manifest.items.count == 4,
              Set(manifest.items.map(\.id)).count == 4 else {
            throw PhotoSourceError.invalidDemoManifest
        }

        return try manifest.items.map { item in
            let resourceURL = manifestURL
                .deletingLastPathComponent()
                .appendingPathComponent(item.resource)
            guard FileManager.default.fileExists(atPath: resourceURL.path) else {
                throw PhotoSourceError.missingDemoResource(item.resource)
            }
            let previewData = try Data(contentsOf: resourceURL, options: [.mappedIfSafe])
            guard let preview = UIImage(data: previewData) else {
                throw PhotoSourceError.missingDemoResource(item.resource)
            }
            let values = try? resourceURL.resourceValues(forKeys: [.fileSizeKey])
            return SelectedPhoto(
                id: item.id,
                preview: preview,
                mimeType: "image/jpeg",
                byteSizeHint: values?.fileSize,
                loadOriginalData: {
                    try Task.checkCancellation()
                    return try Data(contentsOf: resourceURL, options: [.mappedIfSafe])
                }
            )
        }
    }
}

final class AuthorizedPhotoKitSource: PhotoSource, @unchecked Sendable {
    private let imageManager = PHCachingImageManager()

    func loadPhotos() async throws -> [SelectedPhoto] {
        let status = await requestAuthorizationIfNeeded()
        switch status {
        case .authorized, .limited:
            break
        case .denied:
            throw PhotoSourceError.photoAccessDenied
        case .restricted:
            throw PhotoSourceError.photoAccessRestricted
        case .notDetermined:
            throw PhotoSourceError.photoAccessDenied
        @unknown default:
            throw PhotoSourceError.photoAccessDenied
        }

        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)
        var photos: [SelectedPhoto] = []
        photos.reserveCapacity(assets.count)

        for index in 0..<assets.count {
            try Task.checkCancellation()
            let asset = assets.object(at: index)
            let preview = try await previewImage(for: asset)
            let localIdentifier = asset.localIdentifier
            let resource = Self.originalResource(for: asset)
            let mimeType = resource
                .flatMap { UTType($0.uniformTypeIdentifier)?.preferredMIMEType }
                ?? "application/octet-stream"
            photos.append(SelectedPhoto(
                id: localIdentifier,
                preview: preview,
                mimeType: mimeType,
                byteSizeHint: nil,
                loadOriginalData: {
                    try await Self.loadOriginalData(assetIdentifier: localIdentifier)
                }
            ))
        }
        imageManager.startCachingImages(
            for: (0..<assets.count).map { assets.object(at: $0) },
            targetSize: CGSize(width: 360, height: 360),
            contentMode: .aspectFill,
            options: nil
        )
        return photos
    }

    private func requestAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard current == .notDetermined else { return current }
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) {
                continuation.resume(returning: $0)
            }
        }
    }

    private func previewImage(for asset: PHAsset) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = true
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 360, height: 360),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) == true
                guard !degraded, !didResume else { return }
                didResume = true
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: PhotoSourceError.photoUnavailable)
                }
            }
        }
    }

    private static func originalResource(for asset: PHAsset) -> PHAssetResource? {
        PHAssetResource.assetResources(for: asset).first {
            $0.type == .fullSizePhoto || $0.type == .photo
        }
    }

    private static func loadOriginalData(assetIdentifier: String) async throws -> Data {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject,
              let resource = originalResource(for: asset) else {
            throw PhotoSourceError.photoUnavailable
        }
        let requestManager = PHAssetResourceManager.default()
        let requestOptions = PHAssetResourceRequestOptions()
        requestOptions.isNetworkAccessAllowed = true
        let request = PhotoResourceRequest()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let requestID = requestManager.requestData(
                    for: resource,
                    options: requestOptions,
                    dataReceivedHandler: { request.append($0) },
                    completionHandler: { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: request.data)
                        }
                    }
                )
                request.setRequestID(requestID)
            }
        } onCancel: {
            request.cancel(using: requestManager)
        }
    }
}

private final class PhotoResourceRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    private var requestID: PHAssetResourceDataRequestID?

    var data: Data {
        lock.withLock { storage }
    }

    func append(_ data: Data) {
        lock.withLock { storage.append(data) }
    }

    func setRequestID(_ requestID: PHAssetResourceDataRequestID) {
        lock.withLock { self.requestID = requestID }
    }

    func cancel(using manager: PHAssetResourceManager) {
        let id = lock.withLock { requestID }
        if let id { manager.cancelDataRequest(id) }
    }
}
