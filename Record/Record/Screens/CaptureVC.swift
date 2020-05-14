//
//  CaptureVC.swift
//  Record
//
//  Created by Алексей Ведушев on 07.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

class CaptureVC: UIViewController {
    
    @IBOutlet weak var startStopRecord: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var imageView: UIImageView!
    
    private let captureService: ICaptureService = CaptureService()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        captureService.setup()
        captureService.setupDelegate(self)
        captureService.overlayImage = #imageLiteral(resourceName: "virus")
    }
    
    // MARK: - Action

    @IBAction func startStopTouched(_ sender: Any) {
        guard let button = sender as? UIButton else { return }
        
        if button.isSelected {
            captureService.stopWriting()
        } else {
            captureService.startWriting()
        }
        button.isSelected = !button.isSelected
    }
    
    @IBAction func playVideo(_ sender: Any) {
        openPlayer(captureService.videoFileURL)
    }
}

extension CaptureVC {
    func openPlayer(_ videoURL: URL) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        guard let vc = storyboard.instantiateViewController(withIdentifier: "VideoPlayerVC") as? VideoPlayerVC else {
            return
        }
        vc.videoURL = videoURL
        show(vc, sender: self)
    }
}

extension CaptureVC: CaptureServiceDelegate {
    func imageStream(_ image: UIImage) {
        imageView.image = image
    }
    
    func finishWriting(_ fileURL: URL) {
        
    }
    
}
