//
//  CaptureService.swift
//  Record
//
//  Created by Алексей Ведушев on 07.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import Foundation
import AVKit
import CoreMedia

public protocol ICaptureService: class {
    var captureSession: AVCaptureSession! { get }
    var videoFileURL: URL { get }
    var overlayImage: UIImage? { get set }
    
    func requestAutorizstionStatus(completion: @escaping (Bool) -> Void)
    func setup()
    func setupDelegate(_ delegate: CaptureServiceDelegate)
    
    func startWriting()
    func stopWriting()
}

public protocol CaptureServiceDelegate: class {
    func imageStream(_ image: UIImage)
    func finishWriting(_ fileURL: URL)
}

public class CaptureService: NSObject, ICaptureService {
    public var captureSession: AVCaptureSession!
    public weak var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var videoOutput: AVCaptureVideoDataOutput!
    private var audioOutput: AVCaptureAudioDataOutput!
    private var assetWriter: AVAssetWriter?
    private var assetVideoWriterInput: AVAssetWriterInput?
    private var assertAudioWriterInput: AVAssetWriterInput?
    private var adapter: AVAssetWriterInputPixelBufferAdaptor?
    
    private var captureState = CaptureState.idle
    private var _time: Double = 0
    private var fileName: String = "INCOHEARENTvideo.mov"
    private var isNextAudioFrame: Bool = false
    
    public var videoFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
    
    public var overlayImage: UIImage?
    
    public weak var delegate: CaptureServiceDelegate?
    
    public func setupDelegate(_ delegate: CaptureServiceDelegate) {
        self.delegate = delegate
    }
    
    public func requestAutorizstionStatus(completion: @escaping (Bool) -> Void) {
        requestAutorisationStatus(for: .video) {[weak self] (granted) in
            guard granted else {
                completion(granted)
                return
            }
            self?.requestAutorisationStatus(for: .audio, completion: { (granted) in
                completion(granted)
            })
        }
    }
    
    private func requestAutorisationStatus(for type: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: type) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: type) { granted in
                completion(granted)
            }
            return
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            completion(true)
            return
        @unknown default:
            fatalError()
        }
        completion(false)
    }
    
    public func setup() {
        try? FileManager.default.removeItem(at: videoFileURL)
        
        guard captureSession == nil else { return }
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        guard
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
            let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified),
            let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
            let audioInput = try? AVCaptureDeviceInput(device: audioDevice),
            session.canAddInput(videoInput) && session.canAddInput(audioInput) else { return }
        session.beginConfiguration()
        session.addInput(videoInput)
        session.addInput(audioInput)
        session.commitConfiguration()

        let videoOutput = AVCaptureVideoDataOutput()
        let audioOutput = AVCaptureAudioDataOutput()

        guard
            session.canAddOutput(videoOutput),
            session.canAddOutput(audioOutput) else { return }
        let queue = DispatchQueue(label: "com.yusuke024.video")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        session.beginConfiguration()
        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
        session.commitConfiguration()
        session.startRunning()
        
        self.captureSession = session
        self.videoOutput = videoOutput
        self.audioOutput = audioOutput
        captureSession = session
    }
    
    public func startWriting() {
        guard captureState == .idle else { return }
        print("🎥 Start writing")
        try? FileManager.default.removeItem(at: videoFileURL)
        captureState = .start
    }
    
    public func stopWriting() {
        guard captureState == .capturing else { return }
        captureState = .end
    }
    
    private func drawOverlay(pixelBuffer: CVImageBuffer) -> CVPixelBuffer? {
        let attachmentMode = CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: pixelBuffer,
                                                        attachmentMode: attachmentMode) as! [CIImageOption: Any]
        let source = CIImage(cvImageBuffer: pixelBuffer, options: attachments)
        guard let watermarkFilter = CIFilter(name: "CISourceOverCompositing") else { return nil }
        watermarkFilter.setValue(source, forKey: "inputBackgroundImage")
        
        guard let overlayImage = overlayImage else { return nil }
        let inputImage = CIImage(image: overlayImage)
        watermarkFilter.setValue(inputImage, forKey: "inputImage")
        
        guard let resCIImage = watermarkFilter.outputImage else {
            return nil
        }
        let resImage = UIImage(ciImage: resCIImage)
        return buffer(from: resImage)
    }
    
    private func buffer(from image: UIImage) -> CVPixelBuffer? {
      let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                   kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
      var pixelBuffer : CVPixelBuffer?
      let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(image.size.width),
                                       Int(image.size.height),
                                       kCVPixelFormatType_32ARGB,
                                       attrs, &pixelBuffer)
      guard status == kCVReturnSuccess else {
        return nil
      }

      CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData,
                              width: Int(image.size.width),
                              height: Int(image.size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                              space: rgbColorSpace,
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

      context?.translateBy(x: 0, y: image.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)

      UIGraphicsPushContext(context!)
      image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

      return pixelBuffer
    }
    
    private func setupWriter(sourceTime: CMTime) {
        guard let writer = try? AVAssetWriter(outputURL: videoFileURL, fileType: .mov),
            let videoInputSettings = videoOutput?.recommendedVideoSettingsForAssetWriter(writingTo: .mov) else {
            return
        }
        
        let assertVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        assertVideoInput.expectsMediaDataInRealTime = true
        assertVideoInput.transform = CGAffineTransform(rotationAngle: .pi / 2)
        let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assertVideoInput,
                                                           sourcePixelBufferAttributes: videoInputSettings)
        
        if writer.canAdd(assertVideoInput) {
            writer.add(assertVideoInput)
        }
        guard let audioInputSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String : Any] else {
            return
        }
        let assertAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioInputSettings)
        assertAudioInput.expectsMediaDataInRealTime = true
        
        guard writer.canApply(outputSettings: audioInputSettings, forMediaType: .audio),
            writer.canAdd(assertAudioInput) else {
            return
        }
        writer.add(assertAudioInput)
        assertAudioWriterInput = assertAudioInput
        writer.startWriting()
        writer.startSession(atSourceTime: sourceTime)
        assetWriter = writer
        assetVideoWriterInput = assertVideoInput
        
        self.adapter = adapter
    }
    
    fileprivate func convert(_ pixelBuffer: CVImageBuffer) -> UIImage {
        let attachmentMode = CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: pixelBuffer,
                                                        attachmentMode: attachmentMode) as! [CIImageOption: Any]
        let source = CIImage(cvImageBuffer: pixelBuffer, options: attachments)
        let image = UIImage(ciImage: source)
        return image
    }
    
    fileprivate func setupVideoOrientation(_ connection: AVCaptureConnection) {
        guard connection.isVideoOrientationSupported else { return }
        switch UIDevice.current.orientation {
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
        case .portrait:
            connection.videoOrientation = .portrait
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            connection.videoOrientation = .portrait
        }
    }
    
    private enum CaptureState {
        case idle, start, capturing, end
    }
}

extension CaptureService: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        setupVideoOrientation(connection)
        
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        switch captureState {
        case .start:
            setupWriter(sourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            captureState = .capturing
            _time = timestamp
        case .capturing:
            appendSampleBufer(timestamp: timestamp, sampleBuffer: sampleBuffer, output: output)
        case .end:
            guard assetVideoWriterInput?.isReadyForMoreMediaData == true,
                assertAudioWriterInput?.isReadyForMoreMediaData == true,
                assetWriter?.status != .failed else {
                    break
            }
            assetVideoWriterInput?.markAsFinished()
            assertAudioWriterInput?.markAsFinished()
            let url = videoFileURL
            
            assetWriter?.finishWriting { [weak self] in
                self?.captureState = .idle
                self?.assetWriter = nil
                self?.assetVideoWriterInput = nil
                self?.assertAudioWriterInput = nil
                self?.captureSession.stopRunning()

                DispatchQueue.main.async {[weak self] in
                    self?.delegate?.finishWriting(url)
                }
            }
        default:
            break
        }
    }
    
    func appendSampleBufer(timestamp: Double, sampleBuffer: CMSampleBuffer, output: AVCaptureOutput) {
        if output == audioOutput {
            isNextAudioFrame = true
        }
        if output == videoOutput,
            assetVideoWriterInput?.isReadyForMoreMediaData == true,
            !isNextAudioFrame {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)

                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    return
                }
                if let resPixelBuffer = drawOverlay(pixelBuffer: pixelBuffer) {
                    adapter?.append(resPixelBuffer, withPresentationTime: time)
                    let image = convert(resPixelBuffer)
                    
                    DispatchQueue.main.async {[weak self] in
                        self?.delegate?.imageStream(image)
                    }
                } else {
                    adapter?.append(pixelBuffer, withPresentationTime: time)
                }
            isNextAudioFrame = true
        } else if output == audioOutput,
            assertAudioWriterInput?.isReadyForMoreMediaData == true {
                assertAudioWriterInput?.append(sampleBuffer)
                isNextAudioFrame = false
        }
    }
}
