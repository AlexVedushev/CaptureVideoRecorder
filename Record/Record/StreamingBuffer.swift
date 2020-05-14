//
//  VideoBuffer.swift
//  Record
//
//  Created by Alexey Vedushev on 14.05.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import Foundation
import AVKit

class StreamingBuffer {
    private var sampleArray = [StreamingSample]()
    
    private let queue = DispatchQueue(label: "VideoBuffer")
    
    var isNextSound: Bool? {
        sampleArray.first?.isSound
    }
    
    func appendSample(isSound: Bool, sample: CMSampleBuffer) {
        sampleArray.append(StreamingSample(isSound: isSound, sample: sample))
    }
    
    func getNextSample() -> CMSampleBuffer? {
        sampleArray.removeFirst().sample
    }
    
    struct StreamingSample {
        var isSound: Bool
        var sample: CMSampleBuffer
    }
}


