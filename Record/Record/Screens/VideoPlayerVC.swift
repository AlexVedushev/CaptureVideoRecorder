//
//  VideoPlayerVC.swift
//  Record
//
//  Created by Alexey Vedushev on 13.05.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

extension VideoPlayerVC {
    static func build(videoURL: URL) {
        
    }
}

class VideoPlayerVC: UIViewController {

    @IBOutlet weak var previewView: PlayerView!
    @IBOutlet weak var playPauseButton: UIButton!
    
    var videoURL: URL?
    var playerItem: AVPlayerItem?
    var player: AVPlayer?
    
    // Key-value observing context
    private var playerItemContext = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard let url = videoURL else {
            return
        }
        playerItem = AVPlayerItem(url: url)
        playerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: &playerItemContext)
    }
    
    override func observeValue(forKeyPath keyPath: String?,
                                     of object: Any?,
                                     change: [NSKeyValueChangeKey : Any]?,
                                     context: UnsafeMutableRawPointer?) {
        guard context == &playerItemContext else {
            super.observeValue(forKeyPath: keyPath,
                               of: object,
                               change: change,
                               context: context)
            return
        }
        
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
            if let statusNumber = change?[.newKey] as? NSNumber {
                status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
            } else {
                status = .unknown
            }

            // Switch over status value
            switch status {
            case .readyToPlay:
                guard let playerItem = playerItem else { return }
                let player = AVPlayer(playerItem: playerItem)
                self.player = player
                previewView.player = player
            default:
                break
            }
        }
    }
    
    @IBAction func playPauseTouched(_ sender: Any) {
        if playPauseButton.isSelected {
            player?.play()
        } else {
            player?.pause()
        }
        playPauseButton.isSelected = !playPauseButton.isSelected
    }
}
