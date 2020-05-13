import UIKit

import AVFoundation

class ViewController1: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self._setupCaptureSession()
                }
            }
        case .restricted:
            break
        case .denied:
            break
        case .authorized:
            _setupCaptureSession()
        @unknown default:
            fatalError()
        }
    }

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var assetWriter: AVAssetWriter?
    private var assetWriterInput: AVAssetWriterInput?
    private var adpater: AVAssetWriterInputPixelBufferAdaptor?
    private var filename = "file"
    private var _time: Double = 0
    
    private func _setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1920x1080

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input) else { return }

        session.beginConfiguration()
        session.addInput(input)
        session.commitConfiguration()

        let output = AVCaptureVideoDataOutput()
        guard session.canAddOutput(output) else { return }
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.yusuke024.video"))
        session.beginConfiguration()
        session.addOutput(output)
        session.commitConfiguration()

        DispatchQueue.main.async {
            let previewView = PreviewView()
            previewView.videoPreviewLayer.session = session
            previewView.frame = self.view.bounds
            previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.insertSubview(previewView, at: 0)
        }

        session.startRunning()
        videoOutput = output
        captureSession = session
    }

    private enum _CaptureState {
        case idle, start, capturing, end
    }
    private var _captureState = _CaptureState.idle
    @IBAction func capture(_ sender: Any) {
        switch _captureState {
        case .idle:
            _captureState = .start
        case .capturing:
            _captureState = .end
        default:
            break
        }
    }
}

extension ViewController1: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
        switch _captureState {
        case .start:
            // Set up recorder
            filename = UUID().uuidString
            let videoPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(filename).mov")
            let writer = try! AVAssetWriter(outputURL: videoPath, fileType: .mov)
            let settings = videoOutput!.recommendedVideoSettingsForAssetWriter(writingTo: .mov)
            let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings) 
            input.mediaTimeScale = CMTimeScale(bitPattern: 600)
            input.expectsMediaDataInRealTime = true
            input.transform = CGAffineTransform(rotationAngle: .pi/2)
            let adapter = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
            if writer.canAdd(input) {
                writer.add(input)
            }
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)
            assetWriter = writer
            assetWriterInput = input
            adpater = adapter
            _captureState = .capturing
            _time = timestamp
        case .capturing:
            if assetWriterInput?.isReadyForMoreMediaData == true {
                let time = CMTime(seconds: timestamp - _time, preferredTimescale: CMTimeScale(600))
                adpater?.append(CMSampleBufferGetImageBuffer(sampleBuffer)!, withPresentationTime: time)
            }
            break
        case .end:
            guard assetWriterInput?.isReadyForMoreMediaData == true, assetWriter!.status != .failed else { break }
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("\(filename).mov")
            assetWriterInput?.markAsFinished()
            assetWriter?.finishWriting { [weak self] in
                self?._captureState = .idle
                self?.assetWriter = nil
                self?.assetWriterInput = nil
                DispatchQueue.main.async {
                    let activity = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                    self?.present(activity, animated: true, completion: nil)
                }
            }
        default:
            break
        }
    }
}
