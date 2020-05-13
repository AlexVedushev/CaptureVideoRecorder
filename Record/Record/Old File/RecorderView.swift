//
//  RecordView.swift
//  Record
//
//  Created by Алексей Ведушев on 03.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import AVFoundation
import ImageIO
import UIKit

class RecorderView: UIView {
    fileprivate(set) lazy var isRecording = false
    fileprivate var videoWriter: AVAssetWriter!
    fileprivate var videoWriterInput: AVAssetWriterInput!
    fileprivate var audioWriterInput: AVAssetWriterInput!
    fileprivate var sessionAtSourceTime: CMTime?

    fileprivate lazy var cameraSession = AVCaptureSession()
    fileprivate lazy var videoDataOutput = AVCaptureVideoDataOutput()
    fileprivate lazy var audioDataOutput = AVCaptureAudioDataOutput()
    
    fileprivate var videoWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor!
    fileprivate lazy var sDeviceRgbColorSpace = CGColorSpaceCreateDeviceRGB()
    fileprivate lazy var bitmapInfo = CGBitmapInfo.byteOrder32Little
                                                .union(CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue))

    fileprivate weak var previewLayer: AVCaptureVideoPreviewLayer?

    fileprivate lazy var faceDetector = CIDetector(ofType: CIDetectorTypeFace,
                                                   context: nil,
                                                   options: [
                                                       CIDetectorAccuracy: CIDetectorAccuracyHigh,
                                                       CIDetectorTracking: true,
    ])!

    override func layoutSubviews() {
        super.layoutSubviews()
//        previewLayer?.frame = frame
    }

    var outputURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("output.mov")
    }

    var observer: NSKeyValueObservation!
    
    func setupWriter() {
        
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try! FileManager.default.removeItem(at: outputURL)
        }
        let url = outputURL
        do {
            videoWriter = try AVAssetWriter(url: url, fileType: AVFileType.mov)
        } catch {
            debugPrint(error.localizedDescription)
        }
        videoWriter.shouldOptimizeForNetworkUse = true
        
//        videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoWidthKey: NSNumber(value: 720),
//            AVVideoHeightKey: NSNumber(value: 1280),
//            AVVideoCompressionPropertiesKey: [
//                AVVideoAverageBitRateKey: 2300000,
//            ],
//        ])
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoDataOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov))
        videoWriterInput.expectsMediaDataInRealTime = true
        videoWriterInput.mediaTimeScale = CMTimeScale(bitPattern: 600)
        videoWriter.movieFragmentInterval = CMTime.invalid
        videoWriterInput.transform = CGAffineTransform(rotationAngle: .pi/2)
        
        audioWriterInput = AVAssetWriterInput(mediaType: AVMediaType.audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: 64000,
        ])
//        audioWriterInput.expectsMediaDataInRealTime = true
//
//        if videoWriter.canAdd(audioWriterInput) {
//            videoWriter.add(audioWriterInput)
//        }
        videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: nil)
//        videoWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput,
//                                                                                  sourcePixelBufferAttributes: [
//                                                                                      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
//                                                                                      kCVPixelBufferWidthKey as String: 720,
//                                                                                      kCVPixelBufferHeightKey as String: 1280,
//                                                                                      kCVPixelFormatOpenGLESCompatibility as String: kCFBooleanTrue!,
//        ])
    }

    func setupCamera() {
        // The size of output video will be 720x1280
        cameraSession.sessionPreset = AVCaptureSession.Preset.hd1280x720

        // Setup your camera
        // Detect which type of camera should be used via `isUsingFrontFacingCamera`
        let captureDevice: AVCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)!

        // Setup your microphone
        let audioDevice = AVCaptureDevice.default(.builtInMicrophone, for: .audio, position: .unspecified)!

        do {
            cameraSession.beginConfiguration()

            // Add camera to your session
            let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
            
            if cameraSession.canAddInput(deviceInput) {
                cameraSession.addInput(deviceInput)
            }

            // Add microphone to your session
//            let audioInput = try AVCaptureDeviceInput(device: audioDevice)
//            if cameraSession.canAddInput(audioInput) {
//                cameraSession.addInput(audioInput)
//            }

            // Now we should define your output data
            let queue = DispatchQueue(label: "com.hilaoinc.hilao.queue.record-video.data-output")

            // Define your video output
            videoDataOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            ]
            videoDataOutput.alwaysDiscardsLateVideoFrames = true

            if cameraSession.canAddOutput(videoDataOutput) {
                videoDataOutput.setSampleBufferDelegate(self, queue: queue)
                cameraSession.addOutput(videoDataOutput)
            }

            // Define your audio output
//            if cameraSession.canAddOutput(audioDataOutput) {
//                audioDataOutput.setSampleBufferDelegate(self, queue: queue)
//                cameraSession.addOutput(audioDataOutput)
//            }

            cameraSession.commitConfiguration()

            // Present the preview of video
//            let previewLayer = AVCaptureVideoPreviewLayer(session: cameraSession)
//            previewLayer.bounds = bounds
//            previewLayer.videoGravity = .resizeAspectFill
//            layer.addSublayer(previewLayer)
//            self.previewLayer = previewLayer

            cameraSession.startRunning()
        } catch let error {
            debugPrint(error.localizedDescription)
        }
    }
    
}

extension RecorderView: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        let writable = canWrite()

        if writable,
            sessionAtSourceTime == nil {
            // Start writing
//            sessionAtSourceTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            sessionAtSourceTime = CMTime.zero
            videoWriter.startSession(atSourceTime: sessionAtSourceTime!)
        }

        if output === videoDataOutput {
            // Your old code when make the overlay here
            if videoWriterInput != nil,
                videoWriterInput.isReadyForMoreMediaData {
                // Write video buffer
//                let resSampleBuffer = drawOverlay(sampleBuffer: sampleBuffer)
                videoWriterInput.append(sampleBuffer)
//                let time = CMTime(seconds: timestamp - _time, preferredTimescale: CMTimeScale(600))
//                videoWriterInputPixelBufferAdaptor.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: timestamp)
                print("video sample")
//                videoWriterInput.append(resSampleBuffer)
            }
        } //else if writable,
//            output == audioDataOutput,
//            audioWriterInput.isReadyForMoreMediaData {
//            // Write audio buffer
//            audioWriterInput.append(sampleBuffer)
//        }
    }
}

extension RecorderView {
    func drawOverlay(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault,
                                                        target: pixelBuffer,
                                                        attachmentMode: CMAttachmentMode(kCMAttachmentMode_ShouldPropagate)) as! [CIImageOption: Any]
        let source = CIImage(cvImageBuffer: pixelBuffer, options: attachments)
        let watermarkFilter = CIFilter(name: "CISourceOverCompositing")!
        watermarkFilter.setValue(source, forKey: "inputBackgroundImage")
        let face = #imageLiteral(resourceName: "face-imaged").cgImage!
        let ciImage = CIImage(cgImage: face)
        watermarkFilter.setValue(ciImage, forKey: "inputImage")
        let resImage = watermarkFilter.outputImage!
        let image = UIImage(ciImage: resImage)
        return image.CMSampleBuffer
    }
}

extension RecorderView {
    fileprivate func canWrite() -> Bool {
        return isRecording
            && videoWriter != nil
            && videoWriter.status == .writing
    }
}

extension RecorderView {
    func start() {
        guard !isRecording else { return }
        isRecording = true
        sessionAtSourceTime = nil

        if videoWriter.status != .writing {
            let canStarted = videoWriter.startWriting()
            print("videoWriter can started = \(canStarted)")
            videoWriter.startSession(atSourceTime: .zero)
        }
        
//        videoWriterInput.requestMediaDataWhenReady(on: DispatchQueue(label: "dfas")) {
//            print("adasd")
//        }
    }
}

extension RecorderView {
    func stop() {
        guard isRecording else { return }
        isRecording = false
//        cameraSession.stopRunning()
        
        videoWriter.finishWriting { [weak self] in
            self?.sessionAtSourceTime = nil
            guard let url = self?.videoWriter.outputURL else { return }
            let asset = AVURLAsset(url: url)
            let fileExist = FileManager.default.fileExists(atPath: url.path)
            let attr = try! FileManager.default.attributesOfItem(atPath: url.path)
            print(attr[.size])
            // Do whatever you want with your asset here
        }
    }
}

extension RecorderView {
    func pause() {
        isRecording = false
    }

    func resume() {
        isRecording = true
    }
}

extension UIImage {
    var cvPixelBuffer: CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [NSObject: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: false,
            kCVPixelBufferCGBitmapContextCompatibilityKey: false,
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(size.width),
                                         Int(size.height),
                                         kCVPixelFormatType_32BGRA,
                                         options as CFDictionary,
                                         &pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer!,
                                     CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData,
                                width: Int(size.width),
                                height: Int(size.height),
                                bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!),
                                space: rgbColorSpace,
                                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue)
        context?.draw(cgImage!, in: CGRect(origin: .zero, size: size))
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        return pixelBuffer
    }

    var CMSampleBuffer: CMSampleBuffer {
        let pixelBuffer = cvPixelBuffer
        var newSampleBuffer: CMSampleBuffer?
        var timimgInfo: CMSampleTimingInfo = CMSampleTimingInfo.invalid
        var videoInfo: CMVideoFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil, imageBuffer: pixelBuffer!, formatDescriptionOut: &videoInfo)
        CMSampleBufferCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                           imageBuffer: pixelBuffer!,
                                           dataReady: true,
                                           makeDataReadyCallback: nil,
                                           refcon: nil,
                                           formatDescription: videoInfo!,
                                           sampleTiming: &timimgInfo,
                                           sampleBufferOut: &newSampleBuffer)
        return newSampleBuffer!
    }
}


//func captureOutput(_ captureOutput: AVCaptureOutput!,
//                   didOutputSampleBuffer sampleBuffer: CMSampleBuffer!,
//                   from connection: AVCaptureConnection!) {
//  //...
//
//  if captureOutput == videoDataOutput {
//      //...
//
//      //We don't write directly to `videoWriterInput`, will write to `videoWriterInputPixelBufferAdaptor`
//      //if videoWriterInput.isReadyForMoreMediaData {
//      // //Write video buffer
//      //  videoWriterInput.append(sampleBuffer)
//      //}
//      if writable {
//          autoreleasepool { //Make sure `CVPixelBuffer` will release after used
//          //Lock `pixelBuffer` before working on it
//          CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
//
//          //Deep copy buffer pixel to avoid memory leak
//          var renderedOutputPixelBuffer: CVPixelBuffer? = nil
//          let options = [
//              kCVPixelBufferCGImageCompatibilityKey as String: true,
//              kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
//          ] as CFDictionary
//          let status = CVPixelBufferCreate(kCFAllocatorDefault,
//                                           CVPixelBufferGetWidth(pixelBuffer),
//                                           CVPixelBufferGetHeight(pixelBuffer),
//                                           kCVPixelFormatType_32BGRA, options,
//                                           &renderedOutputPixelBuffer)
//          guard status == kCVReturnSuccess else { return }
//
//          CVPixelBufferLockBaseAddress(renderedOutputPixelBuffer!,
//                                       CVPixelBufferLockFlags(rawValue: 0))
//
//          let renderedOutputPixelBufferBaseAddress = CVPixelBufferGetBaseAddress(renderedOutputPixelBuffer!)
//
//          memcpy(renderedOutputPixelBufferBaseAddress,
//                 CVPixelBufferGetBaseAddress(pixelBuffer),
//                 CVPixelBufferGetHeight(pixelBuffer) * CVPixelBufferGetBytesPerRow(pixelBuffer))
//
//          //Lock the copy of pixel buffer when working on ti
//          CVPixelBufferLockBaseAddress(renderedOutputPixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
//          if !features.isEmpty {
//              //Create context base on copied buffer
//              let context = CGContext(data: renderedOutputPixelBufferBaseAddress,
//                                      width: CVPixelBufferGetWidth(renderedOutputPixelBuffer!),
//                                      height: CVPixelBufferGetHeight(renderedOutputPixelBuffer!),
//                                      bitsPerComponent: 8,
//                                      bytesPerRow: CVPixelBufferGetBytesPerRow(renderedOutputPixelBuffer!),
//                                      space: sDeviceRgbColorSpace,
//                                      bitmapInfo: bitmapInfo.rawValue)
//
//              for feature in features {
//                  //Draw mask image
//                  let faceImage = UIImage("face-image")!
//                  context?.draw(faceImage.cgImage!, in: feature.bounds)
//              }
//          }
//
//          //Make sure adaptor and writer able to write
//          if videoWriterInputPixelBufferAdaptor.assetWriterInput.isReadyForMoreMediaData,
//              canWrite() {
//              //Write down to adator instead of `videoWriterInput`
//              videoWriterInputPixelBufferAdaptor.append(renderedOutputPixelBuffer!, withPresentationTime: timestamp)
//          }
//
//          //Unlock buffers after processed on them
//          CVPixelBufferUnlockBaseAddress(renderedOutputPixelBuffer!,
//                                         CVPixelBufferLockFlags(rawValue: 0))
//          CVPixelBufferUnlockBaseAddress(pixelBuffer,
//                                         CVPixelBufferLockFlags(rawValue: 0))
//      }
//  } else if writable,
//      captureOutput == audioDataOutput,
//      audioWriterInput.isReadyForMoreMediaData {
//      //Write audio buffer
//      audioWriterInput.append(sampleBuffer)
//  }
//}
