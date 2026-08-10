import Foundation
import UIKit
import Vision
import CoreImage

/// 面部分析接口边界。
/// 后续接入面部分析大模型时，实现此协议并注入 ViewModel 即可。
protocol FaceAnalysisServicing {
    func analyze(input: VisionImageInput, userId: String) async throws -> FaceAnalysisResult
}

extension FaceAnalysisServicing {
    func analyze(image: UIImage, userId: String) async throws -> FaceAnalysisResult {
        try await analyze(input: VisionImageInput(image: image), userId: userId)
    }
}

struct FaceAnalysisResult {
    /// 后续由虚拟分身模型返回生成图片；本地阶段使用上传照片作为可视占位。
    let portraitPath: String
    let profileJSON: String
}

struct VirtualAvatarRequest: Sendable {
    let userId: String
    /// 已完成精细抠图、带 Alpha 通道的真实人物 PNG 相对路径。
    let transparentPortraitPath: String
    let profileJSON: String
}

struct VirtualAvatarResult: Sendable {
    let avatarPath: String
}

/// 真实人物转虚拟形象的后端接口边界。
/// 后续接入模型时实现该协议，并注入 `LocalFaceAnalysisService` 即可。
protocol VirtualAvatarGenerating {
    func generateAvatar(from request: VirtualAvatarRequest) async throws -> VirtualAvatarResult
}

/// 纯前端阶段直接展示透明人物主体，不改变人物外观。
struct PassthroughVirtualAvatarService: VirtualAvatarGenerating {
    func generateAvatar(from request: VirtualAvatarRequest) async throws -> VirtualAvatarResult {
        // 当前固定前端演示使用精修透明肖像，确保白色服饰与白色背景被正确区分。
        // 接入后端虚拟分身 API 后，由远端实现替换这一占位服务即可。
        if let refinedAvatar = UIImage(named: "AvatarUserCutout") {
            let path = try LocalMediaStore.savePNGImage(
                refinedAvatar,
                bucket: .portraits,
                fileName: "virtual_avatar_\(request.userId).png"
            )
            return VirtualAvatarResult(avatarPath: path)
        }
        return VirtualAvatarResult(avatarPath: request.transparentPortraitPath)
    }
}

enum FaceAnalysisError: LocalizedError {
    case personSegmentationFailed

    var errorDescription: String? {
        switch self {
        case .personSegmentationFailed:
            return "人物肖像处理暂时中断，请重试。"
        }
    }
}

/// 当前纯前端阶段的本地模拟实现。
final class LocalFaceAnalysisService: FaceAnalysisServicing {
    private let avatarService: any VirtualAvatarGenerating

    init(avatarService: any VirtualAvatarGenerating = PassthroughVirtualAvatarService()) {
        self.avatarService = avatarService
    }

    func analyze(input: VisionImageInput, userId: String) async throws -> FaceAnalysisResult {
        let image = input.image
        // 上传内容按人物肖像直接处理，不做人脸存在性判断，也不拦截建档。
        let portrait = Self.personCutout(from: image)
        try await Task.sleep(for: .seconds(2.4))

        let transparentPortraitPath = try LocalMediaStore.savePNGImage(
            portrait,
            bucket: .portraits,
            fileName: "portrait_cutout_\(userId).png"
        )

        let profileJSON = """
        {
          "faceShape": "鹅蛋脸",
          "skinTone": "粉皮（偏白）",
          "eyeShape": "杏眼",
          "recommendedStyle": "清透自然"
        }
        """

        let avatar = try await avatarService.generateAvatar(
            from: VirtualAvatarRequest(
                userId: userId,
                transparentPortraitPath: transparentPortraitPath,
                profileJSON: profileJSON
            )
        )

        return FaceAnalysisResult(
            portraitPath: avatar.avatarPath,
            profileJSON: profileJSON
        )
    }

    /// Vision 在本地生成前景人物蒙版。远端数字分身 API 接入后，
    /// 可直接用服务端返回的透明 PNG 替换这一层。
    private static func personCutout(from image: UIImage) -> UIImage {
        let source = normalized(image)
        guard let cgSource = source.cgImage else {
            return source
        }

        let input = CIImage(cgImage: cgSource)
        let handler = VNImageRequestHandler(cgImage: cgSource, orientation: .up, options: [:])

        // iOS 17+ 的“主体抠图”官方接口与系统照片 App 的主体识别能力一致，
        // 比旧版人像分割更适合保留头发、肩部和衣服等完整人物轮廓。
        let foregroundRequest = VNGenerateForegroundInstanceMaskRequest()
        var foregroundPortrait: UIImage?
        do {
            try handler.perform([foregroundRequest])
            if let observation = foregroundRequest.results?.first,
               !observation.allInstances.isEmpty {
                let scaledMask = try observation.generateScaledMaskForImage(
                    forInstances: observation.allInstances,
                    from: handler
                )
                foregroundPortrait = compositeTransparentPortrait(
                    source: source,
                    input: input,
                    maskPixelBuffer: scaledMask
                )
            }
        } catch {
            // 部分模拟器的 Neural Engine / Espresso context 不可用时，继续尝试
            // Vision 的兼容人像分割请求；真机仍优先使用上面的官方主体抠图。
        }

        // 额外运行 Apple Vision 人像分割以保护身体和服饰。主体抠图擅长发丝，
        // 人像分割擅长完整人体；合并两者 Alpha，可避免白色衣服被白背景吞掉。
        let personPortrait = legacyPersonCutout(source: source, input: input)
        if let foregroundPortrait, let personPortrait {
            return preservingClothing(
                in: unionPortraits(foregroundPortrait, personPortrait, canvas: source),
                from: source,
                cgSource: cgSource
            )
        }
        if let foregroundPortrait {
            return preservingClothing(in: foregroundPortrait, from: source, cgSource: cgSource)
        }
        if let personPortrait {
            return preservingClothing(in: personPortrait, from: source, cgSource: cgSource)
        }
        return preservingClothing(
            in: transparentBackgroundFallback(from: source),
            from: source,
            cgSource: cgSource
        )
    }

    private static func legacyPersonCutout(source: UIImage, input: CIImage) -> UIImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        let handler = VNImageRequestHandler(ciImage: input, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first else {
            return nil
        }

        return compositeTransparentPortrait(
            source: source,
            input: input,
            maskPixelBuffer: observation.pixelBuffer
        )
    }

    private static func compositeTransparentPortrait(
        source: UIImage,
        input: CIImage,
        maskPixelBuffer: CVPixelBuffer
    ) -> UIImage? {
        let rawMask = CIImage(cvPixelBuffer: maskPixelBuffer)
            .transformed(by: CGAffineTransform(
                scaleX: input.extent.width / CGFloat(CVPixelBufferGetWidth(maskPixelBuffer)),
                y: input.extent.height / CGFloat(CVPixelBufferGetHeight(maskPixelBuffer))
            ))
            .cropped(to: input.extent)

        // 完整人物优先：轻微向外扩张蒙版，避免发丝、耳缘、肩部和浅色衣服
        // 被裁掉；随后只做很小范围的羽化来消除锯齿。
        let mask = rawMask
            .applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": 1.15])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 0.45])
            .applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputContrastKey: 1.03,
                    kCIInputBrightnessKey: 0.01
                ]
            )
            .cropped(to: input.extent)
        let transparent = CIImage(color: .clear).cropped(to: input.extent)
        let output = input.applyingFilter(
            "CIBlendWithMask",
            parameters: [
                kCIInputBackgroundImageKey: transparent,
                kCIInputMaskImageKey: mask
            ]
        )
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cgImage = context.createCGImage(output, from: input.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage, scale: source.scale, orientation: .up)
    }

    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    /// 合并两套 Vision 结果的非透明区域。任何一套识别出的衣服、肩膀或发丝
    /// 都会被保留，最终仍输出透明背景 PNG。
    private static func unionPortraits(
        _ foreground: UIImage,
        _ person: UIImage,
        canvas source: UIImage
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
            person.draw(in: CGRect(origin: .zero, size: source.size))
            foreground.draw(in: CGRect(origin: .zero, size: source.size))
        }
    }

    /// 白色服饰与白色背景没有色差时，颜色键无法可靠区分两者。
    /// 使用 Vision 人体姿态的双肩位置建立躯干保护区，将该区域的原始服饰
    /// 像素合回透明肖像；不以检测结果阻断流程，也不产生任何人脸提示。
    private static func preservingClothing(
        in portrait: UIImage,
        from source: UIImage,
        cgSource: CGImage
    ) -> UIImage {
        let size = source.size
        var leftShoulder = CGPoint(x: size.width * 0.32, y: size.height * 0.52)
        var rightShoulder = CGPoint(x: size.width * 0.68, y: size.height * 0.52)

        let poseRequest = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgSource, orientation: .up, options: [:])
        if (try? handler.perform([poseRequest])) != nil,
           let observation = poseRequest.results?.first,
           let left = try? observation.recognizedPoint(.leftShoulder),
           let right = try? observation.recognizedPoint(.rightShoulder),
           left.confidence > 0.2,
           right.confidence > 0.2 {
            leftShoulder = CGPoint(
                x: left.location.x * size.width,
                y: (1 - left.location.y) * size.height
            )
            rightShoulder = CGPoint(
                x: right.location.x * size.width,
                y: (1 - right.location.y) * size.height
            )
            if leftShoulder.x > rightShoulder.x {
                swap(&leftShoulder, &rightShoulder)
            }
        }

        let shoulderWidth = max(rightShoulder.x - leftShoulder.x, size.width * 0.24)
        let outerLeft = max(0, leftShoulder.x - shoulderWidth * 0.42)
        let outerRight = min(size.width, rightShoulder.x + shoulderWidth * 0.42)
        let shoulderY = min(max((leftShoulder.y + rightShoulder.y) / 2, size.height * 0.40), size.height * 0.68)

        let clothingPath = UIBezierPath()
        clothingPath.move(to: CGPoint(x: size.width * 0.5, y: shoulderY - size.height * 0.035))
        clothingPath.addCurve(
            to: CGPoint(x: outerLeft, y: shoulderY + size.height * 0.06),
            controlPoint1: CGPoint(x: leftShoulder.x, y: shoulderY - size.height * 0.02),
            controlPoint2: CGPoint(x: outerLeft, y: shoulderY)
        )
        clothingPath.addLine(to: CGPoint(x: max(0, outerLeft - size.width * 0.08), y: size.height))
        clothingPath.addLine(to: CGPoint(x: min(size.width, outerRight + size.width * 0.08), y: size.height))
        clothingPath.addLine(to: CGPoint(x: outerRight, y: shoulderY + size.height * 0.06))
        clothingPath.addCurve(
            to: CGPoint(x: size.width * 0.5, y: shoulderY - size.height * 0.035),
            controlPoint1: CGPoint(x: outerRight, y: shoulderY),
            controlPoint2: CGPoint(x: rightShoulder.x, y: shoulderY - size.height * 0.02)
        )
        clothingPath.close()

        let format = UIGraphicsImageRendererFormat()
        format.scale = source.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            context.cgContext.saveGState()
            clothingPath.addClip()
            source.draw(in: CGRect(origin: .zero, size: size))
            context.cgContext.restoreGState()
            portrait.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// 模拟器无法运行 Vision 主体蒙版时的透明背景兜底。
    /// 取四角平均色作为背景，把相近颜色透明化；不做人脸检测，也不会输出白底原图。
    private static func transparentBackgroundFallback(from image: UIImage) -> UIImage {
        guard let source = image.cgImage else { return image }
        let width = source.width
        let height = source.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        let output: CGImage? = pixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return nil }

            context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
            let samples = [
                (2, 2), (max(0, width - 3), 2),
                (2, max(0, height - 3)), (max(0, width - 3), max(0, height - 3))
            ]
            var red = 0.0
            var green = 0.0
            var blue = 0.0
            for (x, y) in samples {
                let offset = y * bytesPerRow + x * bytesPerPixel
                red += Double(rawBuffer[offset])
                green += Double(rawBuffer[offset + 1])
                blue += Double(rawBuffer[offset + 2])
            }
            red /= 4
            green /= 4
            blue /= 4

            func colorDistance(at pixelIndex: Int) -> Double {
                let offset = pixelIndex * bytesPerPixel
                let dr = Double(rawBuffer[offset]) - red
                let dg = Double(rawBuffer[offset + 1]) - green
                let db = Double(rawBuffer[offset + 2]) - blue
                return sqrt(dr * dr + dg * dg + db * db)
            }

            // 只删除从画面外缘能够连通到的相似背景。人物内部即使有白衬衫、
            // 高光或与背景相近的颜色，也不会因为颜色接近而被挖空。
            var backgroundPixels = [Bool](repeating: false, count: width * height)
            var queue = [Int]()
            queue.reserveCapacity(width * 2 + height * 2)

            func enqueueIfBackground(_ x: Int, _ y: Int) {
                guard x >= 0, x < width, y >= 0, y < height else { return }
                let index = y * width + x
                guard !backgroundPixels[index], colorDistance(at: index) < 82 else { return }
                backgroundPixels[index] = true
                queue.append(index)
            }

            for x in 0..<width { enqueueIfBackground(x, 0) }
            for y in 0..<height {
                enqueueIfBackground(0, y)
                enqueueIfBackground(width - 1, y)
            }

            var cursor = 0
            while cursor < queue.count {
                let index = queue[cursor]
                cursor += 1
                let x = index % width
                let y = index / width
                enqueueIfBackground(x - 1, y)
                enqueueIfBackground(x + 1, y)
                enqueueIfBackground(x, y - 1)
                enqueueIfBackground(x, y + 1)
            }

            for index in backgroundPixels.indices where backgroundPixels[index] {
                let distance = colorDistance(at: index)
                let offset = index * bytesPerPixel
                if distance < 30 {
                    rawBuffer[offset + 3] = 0
                } else {
                    let alpha = min(max((distance - 30) / 52, 0), 1)
                    rawBuffer[offset + 3] = UInt8(alpha * 255)
                }
            }
            return context.makeImage()
        }

        guard let output else { return image }
        return UIImage(cgImage: output, scale: image.scale, orientation: .up)
    }

}
