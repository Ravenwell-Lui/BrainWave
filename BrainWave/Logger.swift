//
//  Logger.swift
//  BrainWave
//
//  Created by Ravenwell on 2024/11/18.
//

import Foundation
import Combine

class Logger: ObservableObject {
    static let shared = Logger()
    
    @Published var logMessages: [String] = []
    
    private init() {}
    
    func log(_ message: String) {
        DispatchQueue.main.async {
            self.logMessages.append(message)
            print(message) // Print to console for debugging
        }
    }
}
