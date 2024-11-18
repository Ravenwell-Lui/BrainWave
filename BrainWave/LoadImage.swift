//
//  LoadImage.swift
//  BrainWave
//
//  Created by Ravenwell on 2024/11/18.
//

import Foundation
import Cocoa
import CoreML
import Vision

class GetImage {
    var real: NSImage?
    var loaded = false

    func loadImage(completion: @escaping (NSImage?) -> Void){
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.allowsMultipleSelection = false
        openPanel.begin { (result) in
            if result == .OK {
                if let url = openPanel.url {
                    self.loadImage(from: url, completion: completion)
                    print(url)
                }
            }
        }
    }

    func loadImage(from url: URL, completion: @escaping (NSImage?) -> Void) {
        do {
            let imageData = try Data(contentsOf: url)
            let image = NSImage(data: imageData)
            image?.size = NSSize(width: 1280, height: 1280)
            DispatchQueue.main.async {
                self.real = image
                self.loaded = true
                completion(image)
            }
        } catch {
            print("Error loading image: \(error)")
            completion(nil)
        }
    }
}
