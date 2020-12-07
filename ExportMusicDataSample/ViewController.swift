//
//  ViewController.swift
//  ExportMusicDataSample
//
//  Created by 鶴本賢太朗 on 2020/12/01.
//

import UIKit
import MediaPlayer

class ViewController: UIViewController {
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var exportedNumberLabel: UILabel!
    @IBOutlet weak var allExportNumberLabel: UILabel!
    @IBOutlet weak var failureLabel: UILabel!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.failureLabel.text = "Music data export failure list\n"
        MPMediaLibrary.requestAuthorization { (status) in
            
        }
    }
    
    @IBAction func tapButton(_ sender: Any) {
        let predicate: MPMediaPropertyPredicate = MPMediaPropertyPredicate(value: MPMediaType.music.rawValue, forProperty: "mediaType", comparisonType: .contains)
        let mediaItems: [MPMediaItem]? = MPMediaQuery(filterPredicates: [predicate]).items
        if let mediaItems: [MPMediaItem] = mediaItems {
            self.exportButton.isEnabled = false
            self.indicator.startAnimating()
            self.allExportNumberLabel.text = "\(mediaItems.count)"
            self.allExport(mediaItems: mediaItems) {
                self.exportButton.isEnabled = true
                self.indicator.stopAnimating()
                print("All complete export")
            }
        }
        else {
            print("Can not export")
        }
    }
    
    /// Export all music data
    /// - Parameters:
    ///   - mediaItems: mediaItems
    ///   - onComplete: Called when export is finished. (if contain failure. write error log)
    private func allExport(mediaItems: [MPMediaItem], onComplete: @escaping () -> Void) {
        let dispatchSemaphore: DispatchSemaphore = DispatchSemaphore(value: 0)
        let dispatchQueue: DispatchQueue = DispatchQueue(label: "export music data task")
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            var isContainFailure: Bool = false
            for media in mediaItems.enumerated() {
                self.export(media.element.assetURL!, onSuccess: {
                    print("\(media.offset) complete")
                    dispatchSemaphore.signal()
                    DispatchQueue.main.async {
                        self.exportedNumberLabel.text = "\(media.offset+1)"
                    }
                }, onError: { (error) in
                    isContainFailure = true
                    print(error ?? "error")
                    dispatchSemaphore.signal()
                    DispatchQueue.main.async {
                        self.failureLabel.text! += "・" + media.element.fullName + "\n"
                    }
                })
                dispatchSemaphore.wait()
            }
            DispatchQueue.main.async {
                if isContainFailure {
                    self.writeErrorLog(log: self.failureLabel.text!)
                }
                onComplete()
            }
        }
    }
    
    /// Export music data
    /// The file name of the exported music data will be UUID().uuidString
    /// - Parameters:
    ///   - assetURL: Music data file url
    ///   - onSuccess: Called when music data is successfully exported
    ///   - onError: Called when music data is failure exported
    private func export(_ assetURL: URL, onSuccess: @escaping () -> Void, onError: @escaping (_ error: Error?) -> Void) {
        let asset = AVURLAsset(url: assetURL)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            onError(nil)
            return
        }
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() + "/Documents/")
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        exporter.outputURL = fileURL
        exporter.outputFileType = .m4a
        
        exporter.exportAsynchronously {
            if exporter.status == .completed {
                onSuccess()
            } else {
                onError(exporter.error)
            }
        }
    }
    
    /// Write export error log
    /// - Parameter log: error log content
    func writeErrorLog(log: String) {
        if FileManager.default.createFile(atPath: NSHomeDirectory() + "/Documents/" + "/error_log.txt", contents: log.data(using: .utf8), attributes: nil) {
            print("complete write error log")
        }
        else {
            print("fail write error log")
        }
    }
}

extension MPMediaItem {
    var fullName: String {
        let albumname = (albumTitle ?? "no album")
        let artist = (self.artist ?? "no artist")
        let title = (self.title ?? "no title")
        let name =  "\(albumname)_\(artist)_\(title)"
        return name
    }
}
