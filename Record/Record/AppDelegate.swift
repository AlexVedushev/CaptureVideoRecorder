//
//  AppDelegate.swift
//  Record
//
//  Created by Алексей Ведушев on 03.04.2020.
//  Copyright © 2020 Алексей Ведушев. All rights reserved.
//

import UIKit
import AVKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAudioSession()
        return true
    }


    fileprivate func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            let options: AVAudioSession.CategoryOptions = [.mixWithOthers, .defaultToSpeaker, .allowBluetooth]
            try audioSession.setCategory(.playAndRecord,
                                         mode: .default,
                                         options: options)
            try audioSession.setActive(true, options: [])
        } catch {
            
        }
    }
}

