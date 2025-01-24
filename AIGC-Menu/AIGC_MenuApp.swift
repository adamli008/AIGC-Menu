//
//  AIGC_MenuApp.swift
//  AIGC-Menu
//
//  Created by adam li on 2024/12/27.
//

import SwiftUI
import AppleScriptObjC

@main
struct AIGC_MenuApp: App {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            // 添加默认的 File 菜单
            CommandGroup(after: .appInfo) { }
            
            // Settings 菜单移到 File 后面
            CommandMenu("Settings") {
                Menu("功能选择") {
                    ForEach(1...6, id: \.self) { index in
                        let isEnabled = settingsManager.enabledTasks.contains(index)
                        Button(action: {
                            settingsManager.toggleTask(index)
                            // 强制刷新整个窗口
                            NSApp.keyWindow?.contentView?.setNeedsDisplay(NSApp.keyWindow?.contentView?.bounds ?? .zero)
                        }) {
                            HStack {
                                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                                    .frame(width: 20)
                                    .foregroundColor(isEnabled ? .blue : .gray)
                                    .id("menu-item-\(index)-\(isEnabled)")
                                
                                if let image = NSImage(named: "icon\(index)") {
                                    let thumbnail = createThumbnail(from: image, size: NSSize(width: 20, height: 20))
                                    Image(nsImage: thumbnail)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                        .cornerRadius(2)
                                }
                                
                                if let iconName = getIconName(for: index) {
                                    Text(iconName)
                                }
                            }
                        }
                        .keyboardShortcut(KeyEquivalent(Character(String(index))), modifiers: .command)
                    }
                }
                
                Divider()
                
                Menu("设置壁纸") {
                    ForEach(1...20, id: \.self) { index in
                        Button(action: {
                            setWallpaperFromAssets(imageName: "AIGC\(index)")
                        }) {
                            HStack {
                                if let image = NSImage(named: "AIGC\(index)") {
                                    let thumbnail = createThumbnail(from: image, size: NSSize(width: 200, height: 120))
                                    Image(nsImage: thumbnail)
                                        .resizable()
                                        .frame(width: 200, height: 120)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .keyboardShortcut("W", modifiers: .command)
                
                Button("恢复默认壁纸") {
                    setWallpaperFromAssets(imageName: "AIGC5")
                }
                .keyboardShortcut("R", modifiers: .command)
            }
        }
    }
    
    // 创建缩略图函数
    private func createThumbnail(from image: NSImage, size: NSSize) -> NSImage {
        let thumbnail = NSImage(size: size)
        thumbnail.lockFocus()
        
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .sourceOver,
                  fraction: 1.0)
        
        thumbnail.unlockFocus()
        return thumbnail
    }
    
    // 从 Assets 设置壁纸
    private func setWallpaperFromAssets(imageName: String) {
        guard let image = NSImage(named: imageName) else {
            showAlert(message: "无法加载图片", informative: "未找到指定的图片资源")
            return
        }
        
        // 只更新程序壁纸设置
        WallpaperManager.shared.currentWallpaper = imageName
    }
    
    // 显示警告对话框
    private func showAlert(message: String, informative: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informative
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    // 添加一个辅助函数来获取图标名称
    private func getIconName(for index: Int) -> String? {
        let iconNames = [
            1: "Xcode",
            2: "MLX Fine Tuning",
            3: "LMStudio",
            4: "LangChain Chatchat",
            5: "Comfyui",
            6: "ASITOP"
        ]
        return iconNames[index]
    }
}

// 创建一个观察对象来管理壁纸
class WallpaperManager: ObservableObject {
    @Published var currentWallpaper: String = "AIGC5"
    @Published var textColor: Color = .white
    
    static let shared = WallpaperManager()
    
    private init() {
        updateTextColor()
    }
    
    func updateTextColor() {
        guard let image = NSImage(named: currentWallpaper) else { return }
        
        // 获取图片上部区域的亮度
        let headerArea = getHeaderAreaBrightness(from: image)
        // 根据亮度决定文字颜色
        textColor = headerArea > 0.5 ? .black : .white
    }
    
    private func getHeaderAreaBrightness(from image: NSImage) -> CGFloat {
        let size = image.size
        let headerRect = NSRect(x: 0, y: size.height * 0.6,  // 只分析上部 40% 的区域
                              width: size.width, height: size.height * 0.4)
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let context = CGContext(data: nil,
                                    width: Int(size.width),
                                    height: Int(size.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: 0,
                                    space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return 0
        }
        
        context.draw(cgImage, in: NSRect(origin: .zero, size: size))
        
        guard let data = context.data else { return 0 }
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        
        var totalBrightness: CGFloat = 0
        var pixelCount: Int = 0
        
        let bytesPerRow = context.bytesPerRow
        let startY = Int(headerRect.origin.y)
        let endY = Int(headerRect.origin.y + headerRect.height)
        
        for y in startY..<endY {
            for x in 0..<Int(headerRect.width) {
                let offset = y * bytesPerRow + x * 4
                let red = CGFloat(pixels[offset]) / 255.0
                let green = CGFloat(pixels[offset + 1]) / 255.0
                let blue = CGFloat(pixels[offset + 2]) / 255.0
                
                // 使用感知亮度公式
                let brightness = (0.299 * red + 0.587 * green + 0.114 * blue)
                totalBrightness += brightness
                pixelCount += 1
            }
        }
        
        return pixelCount > 0 ? totalBrightness / CGFloat(pixelCount) : 0
    }
}
