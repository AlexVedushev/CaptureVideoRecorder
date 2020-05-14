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
    private var player: AVPlayer?

    // Key-value observing context
    private var playerItemContext = 0
    private var itemStatusObserver: NSKeyValueObservation?
    
    deinit {
        itemStatusObserver = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadPlayerItem()
    }
    
    @IBAction func playPauseTouched(_ sender: Any) {
        if playPauseButton.isSelected {
            player?.play()
        } else {
            player?.pause()
        }
        playPauseButton.isSelected = !playPauseButton.isSelected
    }
    
    // MARK: - Private
    
    fileprivate func loadPlayerItem() {
        guard let url = videoURL else {
            return
        }
        let playerItem = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: playerItem)
        self.player = player
        previewView.player = player
        
        itemStatusObserver = playerItem.observe(\.status, options: [.old, .new], changeHandler: {[weak self] (item, _) in
            guard let self = self else { return }
            print(item.status.rawValue)
            
            switch item.status {
            case .readyToPlay:
                self.player?.play()
            default:
                break
            }
        })
    }
}
