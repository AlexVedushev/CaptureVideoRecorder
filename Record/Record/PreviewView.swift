//
//  PreviewView.swift
//  Record
//
//  Created by Алексей Ведушев on 05.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

class PreviewView: UIView {
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }

    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
}

