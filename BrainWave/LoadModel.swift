//
//  LoadModel.swift
//  BrainWave
//
//  Created by Ravenwell on 2024/11/18.
//

import Vision
import CoreML
import Cocoa
import CoreVideo
import CoreImage
import CoreGraphics

class GetResult: ObservableObject {
    private var undrawImage: NSImage?
    private var modifiedImage: NSImage?
    private var requests = [VNRequest]()
    private var selectedModels: [VNCoreMLModel] = []

    // 选择多个模型并加载
    func chooseModelsAndCache(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.allowedFileTypes = ["mlmodelc"]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        panel.begin { response in
            if response == .OK {
                self.selectedModels.removeAll()
                for url in panel.urls {
                    do {
                        let model = try VNCoreMLModel(for: MLModel(contentsOf: url))
                        self.selectedModels.append(model)
                    } catch {
                        Logger.shared.log("Failed to load model from \(url): \(error)")
                        completion("Failed to load one or more models")
                        return
                    }
                }
                if self.selectedModels.isEmpty {
                    completion("No models were selected")
                } else {
                    completion("Successfully loaded \(self.selectedModels.count) models")
                }
            } else {
                completion("Model selection was cancelled")
            }
        }
    }

    func runInference(on image: NSImage, completion: @escaping (NSImage?) -> Void) {
        if selectedModels.isEmpty {
            Logger.shared.log("No models are loaded")
            completion(nil)
            return
        }

        var combinedImage = image.copy() as! NSImage
        let dispatchGroup = DispatchGroup()

        for model in selectedModels {
            dispatchGroup.enter()
            setupVision(with: model) { resultImage in
                if let resultImage = resultImage {
                    combinedImage = self.mergeImages(baseImage: combinedImage, overlayImage: resultImage)
                }
                dispatchGroup.leave()
            }

            if let pixelBuffer = nsImageToCVPixelBuffer(nsImage: image) {
                undrawImage = combinedImage // 更新为当前合并后的图像
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

                do {
                    try imageRequestHandler.perform(self.requests)
                } catch {
                    Logger.shared.log("Request failed: \(error)")
                    dispatchGroup.leave()
                }
            } else {
                Logger.shared.log("PixelBuffer conversion failed")
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            completion(combinedImage)
        }
    }

    private func setupVision(with model: VNCoreMLModel, completion: @escaping (NSImage?) -> Void) {
        let objectRecognition = VNCoreMLRequest(model: model) { [weak self] request, error in
            if let results = request.results as? [VNRecognizedObjectObservation], let self = self {
                var modifiedImage = self.undrawImage?.copy() as? NSImage

                for observation in results {
                    let boundingBox = [
                        observation.boundingBox.origin.x,
                        observation.boundingBox.origin.y,
                        observation.boundingBox.size.width,
                        observation.boundingBox.size.height
                    ]
                    let confidence = observation.confidence
                    let label = observation.labels.first?.identifier ?? "Unknown"
                    Logger.shared.log("Label: \(label), Confidence: \(confidence)")

                    modifiedImage = self.drawBoundingBox(
                        image: modifiedImage!,
                        boundingBox: boundingBox,
                        confidence: CGFloat(confidence),
                        label: label
                    )
                }
                completion(modifiedImage)
            } else {
                completion(nil)
            }
        }

        self.requests = [objectRecognition]
    }


    private func drawBoundingBox(image: NSImage, boundingBox: [CGFloat], confidence: CGFloat, label: String) -> NSImage {
        let width = image.size.width
        let height = image.size.height

        let x = boundingBox[0] * width
        let y = boundingBox[1] * height
        let boxWidth = boundingBox[2] * width
        let boxHeight = boundingBox[3] * height

        let newImage = image.copy() as! NSImage
        newImage.lockFocus()

        let path = NSBezierPath(rect: CGRect(x: x, y: y, width: boxWidth, height: boxHeight))
        NSColor.red.setStroke()
        path.lineWidth = 3
        path.stroke()

        let text = "\(label): \(String(format: "%.2f", confidence))"
        let textRect = CGRect(x: x, y: y + boxHeight, width: 150, height: 40)
        text.draw(in: textRect, withAttributes: [.font: NSFont.systemFont(ofSize: 30), .foregroundColor: NSColor.red])

        newImage.unlockFocus()

        return newImage
    }

    private func mergeImages(baseImage: NSImage, overlayImage: NSImage) -> NSImage {
        let mergedImage = baseImage.copy() as! NSImage
        mergedImage.lockFocus()
        overlayImage.draw(in: NSRect(origin: .zero, size: baseImage.size), from: NSRect(origin: .zero, size: overlayImage.size), operation: .sourceOver, fraction: 1.0)
        mergedImage.unlockFocus()
        return mergedImage
    }

    func nsImageToCVPixelBuffer(nsImage: NSImage) -> CVPixelBuffer? {
        guard let cgImage = nsImageToCGImage(nsImage: nsImage) else {
            return nil
        }
        return cgImageToCVPixelBuffer(cgImage: cgImage)
    }

    func nsImageToCGImage(nsImage: NSImage) -> CGImage? {
        guard let tiffData = nsImage.tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return imageRep.cgImage
    }

    func cgImageToCVPixelBuffer(cgImage: CGImage) -> CVPixelBuffer? {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        var pixelBuffer: CVPixelBuffer?

        // Create a pixel buffer with the specified dimensions
        let options: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, .readOnly)

        // Create a context to draw the CGImage into the pixel buffer
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue
        )

        context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))

        CVPixelBufferUnlockBaseAddress(buffer, .readOnly)

        return buffer
    }
}
