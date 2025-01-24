//
//  ContentView.swift
//  AIGC-Menu
//
//  Created by adam li on 2024/12/27.
//

import SwiftUI
import AppleScriptObjC
import AppKit

// 创建一个工具类
class RosettaHelper {
    static func checkRosetta() -> Bool {
        // 检查是否安装了 Rosetta 2
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/arch")
        process.arguments = ["-x86_64", "true"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    static func installRosetta() {
        // 安装 Rosetta 2
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/softwareupdate")
        process.arguments = ["--install-rosetta", "--agree-to-license"]
        
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("安装 Rosetta 2 时发生错误：\(error.localizedDescription)")
        }
    }
}

struct AppButton: View {
    let title: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            Text(title)
                .frame(width: 80)
                .padding(.vertical, 8)
                .background(
                    Group {
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.blue.opacity(isPressed ? 0.6 : 0.7),
                                Color.blue.opacity(isPressed ? 0.4 : 0.5)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .cornerRadius(8)
                .shadow(
                    color: Color.black.opacity(0.2),
                    radius: isPressed ? 2 : 4,
                    x: 0,
                    y: isPressed ? 1 : 2
                )
                .offset(y: isPressed ? 1 : 0)
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AppItem: View {
    let iconName: String
    let index: Int
    
    func runShellScript(number: Int) {
        // 检查 Rosetta 2
        if !RosettaHelper.checkRosetta() {
            let alert = NSAlert()
            alert.messageText = "需要安装 Rosetta 2"
            alert.informativeText = "要运行此应用程序需要安装 Rosetta 2，是否现在安装？"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "安装")
            alert.addButton(withTitle: "取消")
            
            if alert.runModal() == .alertFirstButtonReturn {
                RosettaHelper.installRosetta()
            } else {
                return
            }
        }
        
        let fileManager = FileManager.default
        
        // 获取应用程序的 Bundle 路径
        let bundlePath = Bundle.main.bundlePath
        if FileManager.default.fileExists(atPath: bundlePath) {
            // 构建脚本文件路径
            let scriptPath = "\(bundlePath)/Contents/Resources/Task\(number).app"
            
            if fileManager.fileExists(atPath: scriptPath) {
                let scriptURL = URL(fileURLWithPath: scriptPath)
                
                if NSWorkspace.shared.open(scriptURL) {
                    print("成功启动脚本: Task\(number).app")
                } else {
                    print("启动脚本失败")
                    let alert = NSAlert()
                    alert.messageText = "启动脚本失败"
                    alert.informativeText = "无法打开指定的应用程序"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "确定")
                    alert.runModal()
                }
            } else {
                print("脚本不存在: \(scriptPath)")
                let alert = NSAlert()
                alert.messageText = "脚本不存在"
                alert.informativeText = "请确保脚本文件已正确放置在应用程序包内"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "确定")
                alert.runModal()
            }
        } else {
            print("无法获取应用程序路径")
            return
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 45, height: 45)
            
            AppButton(title: "启动") {
                runShellScript(number: index)
            }
            .frame(width: 80)
            .cornerRadius(8)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(width: 200)
        .background(Color(white: 0.9))
        .cornerRadius(10)
    }
}

struct ButtonBackgroundStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.blue.opacity(0.3))
            .cornerRadius(8)
    }
}

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @StateObject private var wallpaperManager = WallpaperManager.shared
    @StateObject private var settingsManager = SettingsManager.shared
    
    func openApp() {
        // 使用 NSWorkspace 打开应用
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "你的应用Bundle ID") {
            NSWorkspace.shared.openApplication(at: url, 
                                            configuration: NSWorkspace.OpenConfiguration(),
                                            completionHandler: nil)
        }
    }
    
    var body: some View {
        ZStack {
            Image(wallpaperManager.currentWallpaper)
                .resizable()
                .scaledToFill()
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                // 添加标题背景蒙布
                VStack(spacing: 5) {
                    Text("欢迎进入AIGC世界")
                        .font(.custom("PingFangHK-Regular", size: 50))
                        .foregroundColor(wallpaperManager.textColor)
                    
                    Rectangle()
                        .frame(width: 400, height: 2)
                        .foregroundColor(wallpaperManager.textColor)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 40)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.2))
                        .blur(radius: 3)
                )
                .padding(.top, 60)
                
                Text("请确保AIGC卷标的U盘已经插入Mac后，再安装")
                    .font(.system(size: 26))
                    .foregroundColor(wallpaperManager.textColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.black.opacity(0.2))
                            .blur(radius: 2)
                    )
                
                Text("                       ")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                
                Text("                       ")
                    .font(.system(size: 26))
                    .foregroundColor(.white)
                    
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(200), spacing: 100),
                        GridItem(.fixed(200), spacing: 100),
                        GridItem(.fixed(200), spacing: 100)
                    ],
                    spacing: 80,
                    content: {
                        ForEach(Array(SettingsManager.shared.enabledTasks).sorted(), id: \.self) { index in
                            AppItem(iconName: "icon\(index)", index: index)
                        }
                    }
                )
                .padding(.horizontal, 100)
                
                Spacer()
                    .frame(height: 60)
            }
        }
    }
}

#Preview {
    ContentView()
}
