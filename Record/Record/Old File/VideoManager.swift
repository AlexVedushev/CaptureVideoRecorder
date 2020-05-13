//
//  VideoManager.swift
//  Record
//
//  Created by Алексей Ведушев on 05.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVFoundation


class VideoManager: NSObject {
    
    var captureSession: AVCaptureSession!
    fileprivate var videoOutput: AVCaptureVideoDataOutput!
    fileprivate var audioOutput: AVCaptureAudioDataOutput!
    private var assetWriter: AVAssetWriter?
    private var assetVideoWriterInput: AVAssetWriterInput?
    private var assertAudioWriterInput: AVAssetWriterInput?
    private var adpater: AVAssetWriterInputPixelBufferAdaptor?
    
    private var captureState = CaptureState.idle
    private var _time: Double = 0
    var fileName: String = "file"
    
    var videoFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(fileName).mov")
    }
    
    func setup() {
        requestAutorizstionStatus {[weak self] (granted) in
            guard let self = self, granted else { return }
            self.setupCaptureSession()
        }
    }
    
    func capture() {
        switch captureState {
        case .idle:
            captureState = .start
        case .capturing:
            captureState = .end
        default:
            break
        }
    }
    
    private func requestAutorizstionStatus(completion: @escaping (Bool) -> Void) {
        requestAutorisationStatus(for: .video) {[weak self] (granted) in
            self?.requestAutorisationStatus(for: .audio, completion: completion)
        }
    }
    
    private func requestAutorisationStatus(for type: AVMediaType, completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            completion(true)
        @unknown default:
            fatalError()
        }
        completion(false)
    }
    
    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        guard
            let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
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
        guard session.canAddOutput(videoOutput),
            session.canAddOutput(audioOutput) else {
                return
        }
        let queue = DispatchQueue(label: "com.yusuke024.video")
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        session.beginConfiguration()
        session.addOutput(videoOutput)
        session.addOutput(audioOutput)
        session.commitConfiguration()
        self.captureSession = session
//        DispatchQueue.main.async {
//            let previewView = PreviewView()
//            previewView.videoPreviewLayer.session = session
//            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
//        }

        session.startRunning()
        self.videoOutput = videoOutput
        self.audioOutput = audioOutput
        captureSession = session
    }
    
    private enum CaptureState {
        case idle, start, capturing, end
    }
}

extension VideoManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        switch captureState {
        case .start:
            // Set up recorder
            let videoPath = videoFileURL
            let writer = try! AVAssetWriter(outputURL: videoPath, fileType: .mov)
            let videoInputSettings = videoOutput!.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
            let assertVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
            assertVideoInput.mediaTimeScale = CMTimeScale(bitPattern: 600)
            assertVideoInput.expectsMediaDataInRealTime = true
            assertVideoInput.transform = CGAffineTransform(rotationAngle: .pi/2)
            let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assertVideoInput, sourcePixelBufferAttributes: nil)
            
            if writer.canAdd(assertVideoInput) {
                writer.add(assertVideoInput)
            }
            guard let audioInputSettings = audioOutput.recommendedAudioSettingsForAssetWriter(writingTo: .mov) as? [String : Any] else { return }
            let assertAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioInputSettings)
            assertAudioInput.expectsMediaDataInRealTime = true
            
            if writer.canAdd(assertAudioInput) {
                writer.add(assertAudioInput)
            }
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            assetWriter = writer
            assetVideoWriterInput = assertVideoInput
            assertAudioWriterInput = assertAudioInput
            adpater = adapter
            captureState = .capturing
            _time = timestamp
        case .capturing:
            if output == videoOutput, assetVideoWriterInput?.isReadyForMoreMediaData == true {
                let time = CMTime(seconds: timestamp - _time, preferredTimescale: CMTimeScale(600))
                let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
                guard let resPixelBuffer = drawOverlay(pixelBuffer: pixelBuffer) else { return }
                adpater?.append(resPixelBuffer, withPresentationTime: time)
            } else if output == audioOutput, assetVideoWriterInput?.isReadyForMoreMediaData == true {
                assertAudioWriterInput?.append(sampleBuffer)
            }
            break
        case .end:
            guard assetVideoWriterInput?.isReadyForMoreMediaData == true, assetWriter!.status != .failed else { break }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(fileName).mov")
            assetVideoWriterInput?.markAsFinished()
            assetWriter?.finishWriting { [weak self] in
                self?.captureState = .idle
                self?.assetWriter = nil
                self?.assetVideoWriterInput = nil

//                DispatchQueue.main.async {
//                    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
//                    self?.present(activity, animated: true, completion: nil)
//                }
            }
        default:
            break
        }
    }
    
    func drawOverlay(pixelBuffer: CVImageBuffer) -> CVPixelBuffer? {
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: pixelBuffer,
                                                        attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as! [CIImageOption: Any]
        let source = CIImage(cvImageBuffer: pixelBuffer, options: attachments)
        let watermarkFilter = CIFilter(name: "CISourceOverCompositing")!
        watermarkFilter.setValue(source, forKey: "inputBackgroundImage")
        let face = #imageLiteral(resourceName: "face-imaged").cgImage!
        let ciImage = CIImage(cgImage: face)
        watermarkFilter.setValue(ciImage, forKey: "inputImage")
        
        guard let resCIImage = watermarkFilter.outputImage else {
            return nil
        }
        let resImage = UIImage(ciImage: resCIImage)
        return buffer(from: resImage)
    }
    
    func buffer(from image: UIImage) -> CVPixelBuffer? {
      let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
      var pixelBuffer : CVPixelBuffer?
      let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
      guard (status == kCVReturnSuccess) else {
        return nil
      }

      CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

      context?.translateBy(x: 0, y: image.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)

      UIGraphicsPushContext(context!)
      image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

      return pixelBuffer
    }
}
