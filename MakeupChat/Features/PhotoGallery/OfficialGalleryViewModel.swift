import Foundation
import Observation

enum OfficialGalleryLoadState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed(String)
}

@Observable
@MainActor
final class OfficialGalleryViewModel {
    private(set) var photos: [SelectedPhoto] = []
    private(set) var loadState: OfficialGalleryLoadState = .idle
    private(set) var isLoadingSelection = false
    private(set) var selectionErrorMessage: String?
    var selectedPhotoID: String?

    let galleryMode: GalleryMode
    private let source: any PhotoSource

    init(features: AccountFeatures, bundle: Bundle = .main) {
        galleryMode = features.galleryMode
        source = PhotoSourceFactory.make(features: features, bundle: bundle)
    }

    init(source: any PhotoSource, galleryMode: GalleryMode) {
        self.source = source
        self.galleryMode = galleryMode
    }

    func load() async {
        loadState = .loading
        selectionErrorMessage = nil
        do {
            photos = try await source.loadPhotos()
            loadState = photos.isEmpty ? .empty : .loaded
        } catch is CancellationError {
            loadState = .idle
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    func select(_ photo: SelectedPhoto) {
        selectedPhotoID = photo.id
        selectionErrorMessage = nil
    }

    func loadSelectedPhoto() async -> VisionImageInput? {
        guard !isLoadingSelection,
              let selectedPhotoID,
              let photo = photos.first(where: { $0.id == selectedPhotoID }) else {
            return nil
        }
        isLoadingSelection = true
        selectionErrorMessage = nil
        defer { isLoadingSelection = false }
        do {
            let data = try await photo.loadOriginalData()
            try Task.checkCancellation()
            return try VisionImageInput(photoData: data, contentType: photo.mimeType)
        } catch is CancellationError {
            return nil
        } catch {
            selectionErrorMessage = error.localizedDescription
            return nil
        }
    }
}
