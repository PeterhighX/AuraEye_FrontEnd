import Foundation
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "AvatarAI" asset catalog image resource.
    static let avatarAI = DeveloperToolsSupport.ImageResource(name: "AvatarAI", bundle: resourceBundle)

    /// The "AvatarAI2" asset catalog image resource.
    static let avatarAI2 = DeveloperToolsSupport.ImageResource(name: "AvatarAI2", bundle: resourceBundle)

    /// The "AvatarUser" asset catalog image resource.
    static let avatarUser = DeveloperToolsSupport.ImageResource(name: "AvatarUser", bundle: resourceBundle)

    /// The "AvatarUserMsg" asset catalog image resource.
    static let avatarUserMsg = DeveloperToolsSupport.ImageResource(name: "AvatarUserMsg", bundle: resourceBundle)

    /// The "ParkPhoto" asset catalog image resource.
    static let parkPhoto = DeveloperToolsSupport.ImageResource(name: "ParkPhoto", bundle: resourceBundle)

}

