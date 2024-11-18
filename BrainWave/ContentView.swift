//
//  ContentView.swift
//  BrainWave
//
//  Created by Ravenwell on 2024/11/18.
//

import SwiftUI
import Cocoa
import CoreML
import CoreImage
import Vision

struct ContentView: View {
    @State private var image: NSImage?
    @State private var loadimg = GetImage()
    @State private var loadmodel = GetResult()
    @StateObject private var logger = Logger.shared
    @State private var isDarkMode = false // 控制深夜模式的状态

    var body: some View {
        VStack {
            HStack(spacing: 20) {
                // Left Section (Image display)
                VStack(spacing: 15) {
                    Text("Result Image")
                        .font(.title)
                        .foregroundColor(isDarkMode ? .white : .black)
                        .padding(.top, 10)
                    
                    Divider()
                    
                    Group {
                        if let image = image {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 640, height: 640)
                                .cornerRadius(12)
                                .shadow(radius: 10)
                        } else {
                            Text("Loading image...")
                                .font(.title3)
                                .foregroundColor(isDarkMode ? .gray : .black)
                        }
                    }
                    .padding(15)
                    .background(isDarkMode ? Color.gray.opacity(0.4) : Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                }
                .frame(width: 650)
                .padding()

                Divider()

                // Center Section (Buttons)
                VStack(spacing: 30) {
                    Button(action: {
                        loadimg.loadImage { real in
                            if let real = real {
                                image = real
                                Logger.shared.log("Image loaded successfully at \(Date())")
                            } else {
                                Logger.shared.log("Image loading failed at \(Date())")
                            }
                        }
                    }) {
                        Text("Select Image")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isDarkMode ? Color.blue.opacity(0.8) : Color.blue)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }

                    Button(action: {
                        $loadmodel.wrappedValue.chooseModelsAndCache { result in
                            Logger.shared.log(result)
                        }
                    }) {
                        Text("Select Models")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isDarkMode ? Color.green.opacity(0.8) : Color.green)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }

                    Button(action: {
                        guard let selectedImage = image else {
                            Logger.shared.log("No image selected for inference at \(Date())")
                            return
                        }
                        loadmodel.runInference(on: selectedImage) { modifiedImage in
                            if let resultImage = modifiedImage {
                                self.image = resultImage
                                Logger.shared.log("Inference completed successfully at \(Date())")
                            } else {
                                Logger.shared.log("Inference failed at \(Date())")
                            }
                        }
                    }) {
                        Text("Run Inference")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isDarkMode ? Color.purple.opacity(0.8) : Color.purple)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                    }
                }
                .frame(width: 200)
                .padding()

                Divider()

                // Right Section (Logs)
                VStack(spacing: 15) {
                    Image(systemName: "terminal.fill") // 选择一个合适的图标
                        .font(.title) // 设置图标的大小
                        .foregroundColor(isDarkMode ? .white : .blue) // 图标的颜色
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(Logger.shared.logMessages, id: \.self) { message in
                                Text(message)
                                    .font(.body)
                                    .foregroundColor(isDarkMode ? .white : .blue)
                            }
                        }
                    }
                    .frame(width: 300, height: 600)
                    .padding(10)
                    .background(isDarkMode ? Color.gray.opacity(0.6) : Color.white)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                    .border(isDarkMode ? Color.white.opacity(0.5) : Color.gray, width: 1)

                    HStack {
                        Spacer()
                        Button(action: {
                            Logger.shared.logMessages.removeAll()
                        }) {
                            Text("Clear Logs")
                                .font(.title3)
                                .foregroundColor(isDarkMode ? .red : .red)
                                .padding()
                                .background(isDarkMode ? Color.white : Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }
                    }
                    .padding(.top, 10)
                }
                .frame(width: 300)
                .padding()
            }
            .padding()
            .background(isDarkMode ? Color.black : Color.gray.opacity(0.1))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            // 设置工具栏按钮来切换深夜模式
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    isDarkMode.toggle() // 切换深夜模式
                }) {
                    Text(isDarkMode ? "Switch to Light Mode" : "Switch to Dark Mode")
                        .foregroundColor(isDarkMode ? .white : .blue)
                }
            }
        }
    }
}
