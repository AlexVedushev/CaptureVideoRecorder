//
//  ViewController.swift
//  Record
//
//  Created by Алексей Ведушев on 03.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var recorderView: RecorderView!
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recorderView.setupCamera()
        recorderView.setupWriter()
    }

    @IBAction func startRunningTouched(_ sender: Any) {
        recorderView.start()
    }
    
    @IBAction func stopRunningTouched(_ sender: Any) {
        recorderView.stop()
    }
    
    @IBAction func showplayer(_ sender: Any) {
        let vc = AVPlayerViewController()
        vc.player = AVPlayer(url: recorderView.outputURL)
        present(vc, animated: true) {
            vc.player?.play()
        }
    }
}

