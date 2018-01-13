//
//  ViewController.swift
//  BasicStreamingEngine
//
//  Created by Syed Haris Ali on 1/7/18.
//  Copyright © 2018 Ausome Apps LLC. All rights reserved.
//

import UIKit
import AVFoundation
import FileStreamer
import os.log

class ViewController: UIViewController {
    static let logger = OSLog(subsystem: "com.ausomeapps.fstreamer", category: "ViewController")

    struct TapReader {
        static let bufferSize: AVAudioFrameCount = 8192
        static let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                          sampleRate: 44100,
                                          channels: 2,
                                          interleaved: false)!
    }
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var currentTimeLabel: UILabel!
    @IBOutlet weak var durationTimeLabel: UILabel!
    @IBOutlet weak var progressSlider: UISlider!
    @IBOutlet weak var formatSegmentControl: UISegmentedControl!
    @IBOutlet weak var startDownloadButton: UIButton!
    @IBOutlet weak var downloadProgressLabel: UILabel!
    @IBOutlet weak var downloadProgressView: UIProgressView!
    
    lazy var timeFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()
    
    var parser: Parser?
    var reader: Reader?
    
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        /// Download
        let url = RemoteFileURL.faithfulDog.aac
        Downloader.shared.url = url
        Downloader.shared.delegate = self
     
        /// Parse
        do {
            self.parser = try Parser()
        } catch {
            os_log("Failed to create parser: %@", log: ViewController.logger, type: .error, error.localizedDescription)
        }
        
        /// Engine
        setupEngine()
    }
    
    func setupEngine() {
        /// Setup session
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(AVAudioSessionCategoryPlayback)
            try session.setActive(true)
        } catch {
            os_log("Failed to activate audio session: %@", log: ViewController.logger, type: .default, #function, #line, error.localizedDescription)
        }

        /// Make connections
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: TapReader.format)
        engine.prepare()
        
        /// Install tap
        playerNode.installTap(onBus: 0, bufferSize: TapReader.bufferSize/2, format: TapReader.format) {
            [weak self] (buffer, time) in

            guard let reader = self?.reader else {
                os_log("No reader yet...", log: ViewController.logger, type: .debug)
                return
            }

            guard let nextScheduledBuffer = reader.read(TapReader.bufferSize) else {
                os_log("No next scheduled buffer yet...", log: ViewController.logger, type: .debug)
                return
            }

            // This is copying the buffer internally in some kind of circular buffer
            self?.playerNode.scheduleBuffer(nextScheduledBuffer)
        }
    }
    
    @IBAction func changeFormat(_ sender: UISegmentedControl) {
        os_log("%@ - %d", log: ViewController.logger, type: .debug, #function, #line)
        
    }
    
    @IBAction func startDownload(_ sender: UIButton) {
        os_log("%@ - %d", log: ViewController.logger, type: .debug, #function, #line)

        Downloader.shared.start()
        
        startDownloadButton.setTitle("Downloading...", for: .normal)
        startDownloadButton.isEnabled = false
    }

    @IBAction func togglePlayback(_ sender: UIButton) {
        os_log("%@ - %d", log: ViewController.logger, type: .debug, #function, #line)
        
        if playerNode.isPlaying {
            playerNode.pause()
            engine.pause()
            playButton.setTitle("Play", for: .normal)
        } else {
            if !engine.isRunning {
                do {
                    try engine.start()
                } catch {
                    os_log("Failed to start engine: %@", log: ViewController.logger, type: .error, error.localizedDescription)
                }
            }
            playerNode.play()
            playButton.setTitle("Pause", for: .normal)
        }
    }
    
    @IBAction func seek(_ sender: UISlider) {
        os_log("%@ - %d [%.1f]", log: ViewController.logger, type: .debug, #function, #line, progressSlider.value)
        
        let isPlaying = playerNode.isPlaying
        
        guard let parser = parser, let reader = reader else {
            return
        }
        
        let frameOffset = AVAudioFrameCount(round(progressSlider.value))
        
        guard let packetOffset = parser.packetOffset(forFrame: frameOffset) else {
            return
        }
        
        playerNode.stop()
        
        reader.currentPacket = packetOffset
        
        if isPlaying {
            playerNode.play()
        }
    }
    
}

