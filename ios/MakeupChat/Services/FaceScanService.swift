import Foundation
import UIKit

enum FaceScanService {
    static func savePortrait(_ image: UIImage) throws -> String {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("portraits", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let fileName = "user_portrait_\(Int(Date().timeIntervalSince1970)).jpg"
        let destination = directory.appendingPathComponent(fileName)

        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw FaceScanError.encodingFailed
        }
        try data.write(to: destination)
        return destination.path
    }
}

enum FaceScanError: Error {
    case encodingFailed
}
