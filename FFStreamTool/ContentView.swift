//
//  ContentView.swift
//  FFStreamTool
//
//  Created by YuXiaofei on 2020/6/7.
//  Copyright © 2020 YuXiaofei. All rights reserved.
//


import SwiftUI
import Foundation
import CommonCrypto
import os


extension String {
    var sha256: String {
        let data = Data(self.utf8)
        let hash = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}


struct ProgressBar: View {
    @Binding var value: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: geometry.size.width , height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color.gray)

                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color.green)
                    .animation(.linear)
            }.cornerRadius(45.0)
        }
    }
}


struct ContentView: View, DropDelegate {

    let AudioModes = ["压制音频", "无音频流", "拷贝音频"]
    let AudioBitRates = ["64k", "96k", "128k", "160k", "192k", "256k", "320k"]
    let OutputFormats = ["flv", "mp4", "mkv", "mov", "avi", "f4v", "m4v"]
    let VideoCRFRange = 15.0 ... 40.0
    let VideoCRFStep = 0.1

    @State var inputPath = "可以把文件拖拽到这里"

    @State var videoCRF: Double
    @State var keepOriginalSize: Bool
    @State var width: UInt32
    @State var height: UInt32

    @State var audioMode: String
    @State var audioBitRate: String

    @State var outputPath = ""
    @State var outputFormat: String

    @State var showingAlert = false
    @State var warningMessage = ""

    let LicenseMinLength = 8
    let LicenseMaxLength = 16
    @State var licenseChecking = false
    @State var usedLicenses: [String] = []
    @State var currentLicense = ""
    @State var licenseState = "授权"
    @State var licenseUseLimit = 0
    @State var licenseUseCount = 0

    @State var helpQuerying = false
    @State var helpContentCreated = false
    @State var helpLines:[String] = []
    let HelpContent = """
Step 1: Drag video file to the left area
Setp 2: Select audio mode and its bitrate
Step 3: Select width, height
Step 4: Select quality and target format of the video
Step 5: Click Process
"""

    @State var progressValue: Float = 0.0
    let InitialTime = "00:00:00.00"
    let DurationPattern = #"(?:(Duration: ))(\d{2}:)(\d{2}:)(\d{2}.)(\d{2})"#
    let ProcessetTimePattern = #"(?:(time=))(\d{2}:)(\d{2}:)(\d{2}.)(\d{2})"#
    @State var duration = "00:00:00.00"
    @State var processedTime = "00:00:00.00"


    func performDrop(info: DropInfo) -> Bool {
        os_log("performDrop ->")
        guard let itemProvider = info.itemProviders(for: [(kUTTypeFileURL as String)]).first else { return false }

        itemProvider.loadItem(forTypeIdentifier: (kUTTypeFileURL as String), options: nil) {item, error in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            print(url)
            self.inputPath = url.path
            self.outputPath = url.deletingLastPathComponent().path
            self.duration = self.InitialTime
            self.processedTime = self.InitialTime
            self.progressValue = 0
        }
        os_log("<- performDrop")
        return true
    }

    func CheckLiense(input: String) -> Bool {
        os_log("CheckLiense ->")
        if input.isEmpty { return false }
        if input.count < LicenseMinLength || input.count > LicenseMaxLength { return false }
        if usedLicenses.count == 0 {
            if let used = UserDefaults.standard.stringArray(forKey: "usedLicenses") {
                usedLicenses = used
            }
        }
//        var data = ""
        for i in 1...10 {
            let license = String(i).sha256
//            licenseUseLimit = i * i * 1
//            data.append(license)
//            data.append("\n")
            if license.contains(input) == false {
                continue
            }
            if usedLicenses.contains(input) == false {
                licenseUseLimit = 500
                os_log("<- CheckLiense true")
                return true
            }
        }

//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        let url = paths[0].appendingPathComponent("message2.txt")
//        do {
//            try data.write(to: url, atomically: true, encoding: .utf8)
//        } catch {
//            print(error.localizedDescription)
//        }

        os_log("<- CheckLiense false")
        return false
    }

    func checkOperation() -> Bool {
        os_log("checkOperation ->")
        // Check arguments
        let fileManger = FileManager.default
        if !fileManger.fileExists(atPath: inputPath)
        {
            showingAlert = true
            warningMessage = "请选择视频文件！"
            os_log("<- checkOperation no input file")
            return false
        }
        if !fileManger.fileExists(atPath: outputPath)
        {
            showingAlert = true
            warningMessage = "请选择输出路径！"
            os_log("<- checkOperation no output path")
            return false
        }

        // Check license
        if licenseState != "已授权" {
            if let state = UserDefaults.standard.string(forKey: "licenseState") {
                self.licenseState = state
            }
            if licenseState != "已授权" {
                showingAlert = true
                warningMessage = "请输入使用码！"
                os_log("<- checkOperation no license")
                return false
            }
        }

        let res = CheckLicenseLimt()
        os_log("<- checkOperation")
        return res
    }

    func CheckLicenseLimt() -> Bool {
        os_log("CheckLicenseLimt enter ->")
        if licenseUseLimit == 0 {
            licenseUseLimit = UserDefaults.standard.integer(forKey: "licenseUseLimit")
        }
        if licenseUseCount == 0 {
            licenseUseCount = UserDefaults.standard.integer(forKey: "licenseUseCount")
        }
        if (licenseUseCount > licenseUseLimit)
        {
            warningMessage = "使用已超\(self.licenseUseLimit)次，请更新使用码！"

            licenseState = "授权"
            UserDefaults.standard.set(licenseState, forKey: "licenseState")
            licenseUseCount = 0
            UserDefaults.standard.set(licenseUseCount, forKey: "licenseUseCount")
            licenseUseLimit = 0
            UserDefaults.standard.set(licenseUseLimit, forKey: "licenseUseLimit")

            if usedLicenses.count == 0 {
                if let used = UserDefaults.standard.stringArray(forKey: "usedLicenses") {
                    usedLicenses = used
                }
            }
            if currentLicense.isEmpty {
                if let current = UserDefaults.standard.string(forKey: "userLicense") {
                    currentLicense = current
                }
            }
            usedLicenses.append(currentLicense)
            UserDefaults.standard.set(usedLicenses, forKey: "usedLicenses")

            showingAlert = true
            os_log("<- CheckLicenseLimt false")
            return false
        }
        os_log("<- CheckLicenseLimt true")
        return true
    }

    func updateProgressValue(duration: String, time: String) -> Float {
        let arr0 = duration.components(separatedBy: ":")
        if (arr0.count != 3) { return 0 }
        let arr1 = time.components(separatedBy: ":")
        if (arr1.count != 3) { return 0 }
        var total: Float = 0
        if let hh = Float(arr0[0]),
            let mm = Float(arr0[1]),
            let ss = Float(arr0[2]) {
            total = hh * 3600 + mm * 60 + ss
        }
        if total.isZero { return 0 }
        var processed: Float = 0
        if let h = Float(arr1[0]),
            let m = Float(arr1[1]),
            let s = Float(arr1[2]) {
            processed = h * 3600 + m * 60 + s
        }
        return processed / total
    }


    var body: some View {
        HStack {
            VStack {
                Text("输入文件").frame(maxWidth: 191, maxHeight: 50)
                Text(inputPath)
                    .frame(maxWidth: 191, maxHeight: 197)
                    .onDrop(of: [(kUTTypeFileURL as String)], delegate: self)
                VStack {
                    Text("\(processedTime) / \(duration)").frame(minWidth: 191, maxHeight: 10)
                    ProgressBar(value: $progressValue).frame(height: 10)
                }.frame(maxWidth: 191, maxHeight: 50)

            }.frame(maxWidth:191, maxHeight: 287)

            VStack {
                TextField("输出地址", text: $outputPath,
                    onEditingChanged: {
                        _ in print("changed")
                        print(self.outputPath)
                    },
                    onCommit: {
                        print(self.outputPath)
                    }
                ).frame(maxWidth: 348, maxHeight: 50)

                HStack {
                    HStack {
                        Text("宽度")
                            .frame(maxWidth: 48, maxHeight: 33)
                        TextField("Width", value: $width, formatter: NumberFormatter())
                            .frame(maxWidth: 86, maxHeight: 50)
                            .disabled(keepOriginalSize)
                    }.frame(maxWidth: 140, maxHeight: 50)

                    HStack {
                        Text("音频模式").frame(maxWidth: 104, maxHeight: 33)
                        MenuButton(audioMode) {
                            ForEach(AudioModes, id: \.self) {
                                item in Button(item, action: {self.audioMode = item})
                            }
                        }.frame(maxWidth: 90, maxHeight: 50)
                    }
                }

                HStack {
                    HStack {
                        Text("高度")
                            .frame(maxWidth: 48, maxHeight: 33)
                        TextField("Height", value: $height, formatter: NumberFormatter())
                            .frame(maxWidth: 86, maxHeight: 50)
                            .disabled(keepOriginalSize)
                    }.frame(maxWidth: 140, maxHeight: 50)

                    HStack {
                        Text("音频码率").frame(maxWidth: 104, maxHeight: 33)
                        MenuButton(audioBitRate) {
                            ForEach(AudioBitRates, id: \.self) {
                                item in Button(item, action: {self.audioBitRate = item})
                            }
                        }.frame(maxWidth: 90, maxHeight: 50)
                    }
                }

                HStack {
                    HStack {
                        Toggle(isOn: $keepOriginalSize) {
                            Text("保留原始尺寸")
                        }.frame(maxWidth: 140, maxHeight: 33)
                    }

                    HStack {
                        Text("输出格式").frame(maxWidth: 104, maxHeight: 33)
                        MenuButton(outputFormat) {
                            ForEach(OutputFormats, id: \.self) {
                                item in Button(item, action: {self.outputFormat = item})
                            }
                        }.frame(maxWidth: 90, maxHeight: 50)
                    }
                }

                HStack {
                    Text("视频质量")
                        .frame(maxWidth: 124, maxHeight: 33)

                    Stepper(value: $videoCRF, in: VideoCRFRange, step: VideoCRFStep) {
                        Text("\(videoCRF, specifier: "%0.1f")")
                        }.frame(maxWidth: 104, maxHeight: 50)

                    Button(action: {
                        os_log("authenticate ->")
                        if self.licenseState != "已授权" {
                            if let state = UserDefaults.standard.string(forKey: "licenseState") {
                                self.licenseState = state
                            }
                        }
                        self.licenseChecking = true
                        os_log("<- authenticate")
                    }) {
                        Text("授权使用")
                            .frame(maxWidth: 180, maxHeight: 50)
                    }.popover(isPresented: $licenseChecking, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                        VStack {
                            HStack {
                                SecureField("输入使用码，即可永久使用", text: self.$currentLicense).frame(maxWidth:200, maxHeight: 50)
                                Button(action:{
                                    os_log("license ->")
                                    if self.licenseState == "已授权" {
                                        os_log("<- license: licensed")
                                        return
                                    }
                                    if self.CheckLiense(input: self.currentLicense)
                                    {
                                        self.licenseState = "已授权"
                                        UserDefaults.standard.set(self.currentLicense, forKey: "userLicense")
                                        UserDefaults.standard.set(self.licenseState, forKey: "licenseState")
                                        UserDefaults.standard.set(self.licenseUseLimit, forKey: "licenseUseLimit")
                                        os_log("<- license: succeeded")
                                        return
                                    }
                                    os_log("<- license: failed")
                                }) {
                                    Text(self.licenseState)
                                }
                            }
                            Text("lamontyu@gmail.com")
                            }.padding(.all)
                    }
                }
            }

            VStack {
                Button(action: {
                    let dialog = NSOpenPanel();
                    dialog.title = "Choose single directory | Our Code World";
                    dialog.showsResizeIndicator = true;
                    dialog.showsHiddenFiles = false;
                    dialog.canChooseFiles = false;
                    dialog.canChooseDirectories = true;

                    if (dialog.runModal() ==  NSApplication.ModalResponse.OK) {
                        let result = dialog.url
                        if (result != nil) {
                            self.outputPath = result!.path
                        }
                    } else {
                        return
                    }
                }) {
                    Text("输出地址")
                }.frame(maxWidth: 132, maxHeight: 50)

                Button(action: {
                    os_log("Process ->")
                    if !self.checkOperation() {
                        os_log("<- Process failed")
                        return
                    }

                    os_log("Process: Create task")
                    let group = DispatchGroup()
                    let task = Process()
                    let executableURL = URL(fileURLWithPath: "/bin/sh")
                    task.executableURL = executableURL
                    let outPipe = Pipe()
                    let errorPipe = Pipe()

                    os_log("Process: Set standardError readabilityHandler")
                    group.enter()
                    errorPipe.fileHandleForReading.readabilityHandler = {
                        stdErrorFileHandle in
                        if let line = String(data: stdErrorFileHandle.availableData, encoding: .utf8) {
                            if line.isEmpty {
                                self.processedTime = self.duration
                                errorPipe.fileHandleForReading.readabilityHandler = nil
                                group.leave()
                            }
                            var pattern = self.ProcessetTimePattern
                            if (self.duration == "00:00:00.00") {
                                pattern = self.DurationPattern
                            }
                            if let range = line.range(of: pattern, options: .regularExpression) {
                                if (pattern == self.DurationPattern)
                                {
                                    self.duration = String(line[range].dropFirst(10))
                                } else {
                                    self.processedTime = String(line[range].dropFirst(5))
                                }
                                let percent = self.updateProgressValue(duration: self.duration, time: self.processedTime)
                                if !percent.isZero {
                                    self.progressValue = percent
                                }
                            }
                        } else {
                            print("Failed to read standardError data: \(stdErrorFileHandle.availableData)")
                            os_log("Failed to read standardError data")
                            group.leave()
                        }
                    }
                    task.standardOutput = outPipe
                    task.standardError = errorPipe

                    os_log("Process: Construct audio options")
                    var audioOption = "-c:a copy"
                    if (self.audioMode == "无音频流")
                    {
                        audioOption = "-an"
                    }
                    if (self.audioMode == "压制音频")
                    {
                        audioOption = "-b:a " + self.audioBitRate
                    }

                    os_log("Process: Construct video size options")
                    var videoSizeOption = ""
                    if (!self.keepOriginalSize)
                    {
                        videoSizeOption = String(format: "-s %04dx%04d", arguments: [self.width, self.height])
                    }

                    os_log("Process: Construct output file path")
                    let fileURL = URL(fileURLWithPath: self.inputPath)
                    let fileName = fileURL.lastPathComponent
                    let fileExtension = fileURL.pathExtension
                    var name = fileName.dropLast(fileExtension.count + 1)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyyMMdd_hhmmss"
                    name = name + "_" + formatter.string(from: Date())
                    let output = URL(fileURLWithPath: self.outputPath).appendingPathComponent(String(name)).path + "." + self.outputFormat

                    os_log("Process: Construct ffmpeg commnad")
                    guard let ffmpegPath = Bundle.main.path(forResource: "ffmpeg", ofType: "") else { return }
                    let command_format = " '%@' -i '%@' %@ -c:v libx264 -crf %.1f %@ '%@' "
                    let ffmpeg_command = String(format: command_format, arguments:[ffmpegPath, self.inputPath, audioOption, self.videoCRF, videoSizeOption, output])
                    let args = ["-c", ffmpeg_command]
                    task.arguments = args
                    task.terminationHandler = {
                        _ in
                        os_log("Process: task termination")
                    }
                    try! task.run()
                    task.waitUntilExit()

                    os_log("Process: task run complete!")
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let es = String(decoding: outData, as: UTF8.self)
                    print("execution out data: \(es)")
                    if self.licenseUseCount == 0 {
                        self.licenseUseCount = UserDefaults.standard.integer(forKey: "licenseUseCount")
                    }
                    self.licenseUseCount = self.licenseUseCount + 1
                    UserDefaults.standard.set(self.licenseUseCount, forKey: "licenseUseCount")
                    os_log("<- Process")
                }) {
                    Text("压制").frame(maxWidth: 50, maxHeight: 80)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.blue))
                }
                .buttonStyle(PlainButtonStyle())
                .alert(isPresented: $showingAlert) {
                    Alert(title: Text("提示"), message: Text(warningMessage), dismissButton: .default(Text("Got it!")))
                }.frame(maxWidth: 132, maxHeight: 187)

                Button(action: {
                    self.helpQuerying = true
                    if !self.helpContentCreated {
                        self.HelpContent.enumerateLines {
                            line, _ in self.helpLines.append(line)
                        }
                        self.helpContentCreated = true
                    }
                }) {
                    Text("使用帮助")
                }.popover(isPresented: $helpQuerying, attachmentAnchor: .point(.bottom), arrowEdge: .bottom) {
                    VStack(alignment: .leading) {
                        ForEach(self.helpLines, id: \.self) {
                            helpLine in Text(helpLine)
                        }
                    }.padding(.all)
                }.frame(maxWidth: 132, maxHeight: 50)

            }.frame(maxWidth: 132, maxHeight: 287)

        }.frame(maxWidth: 720, maxHeight: 400)
        .padding()
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(videoCRF: 23.0, keepOriginalSize: true, width: 1280, height: 720, audioMode: "压制音频", audioBitRate: "128k", outputFormat: "mp4").frame(minWidth: 720, maxWidth: .infinity, minHeight: 405, maxHeight: .infinity)
    }
}
