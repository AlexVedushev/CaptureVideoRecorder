//
//  PlayerView.swift
//  Record
//
//  Created by Alexey Vedushev on 13.05.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

class PlayerView: UIView {
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    // Override UIView property
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
