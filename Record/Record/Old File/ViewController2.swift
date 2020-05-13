//
//  ViewController2.swift
//  Record
//
//  Created by Алексей Ведушев on 05.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

class ViewController2: UIViewController {

    @IBOutlet weak var previewView: PreviewView!
    
    let videomManager = VideoManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        videomManager.setup()
    }
    
    @IBAction func setupManagerTouched(_ sender: Any) {
        previewView.videoPreviewLayer.session = videomManager.captureSession
    }
    
    @IBAction func captureTouched(_ sender: Any) {
        videomManager.capture()
    }
    
    @IBAction func showVideoTouched(_ sender: Any) {
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: videomManager.videoFileURL)
        present(vc, animated: true, completion: nil)
    }
}
