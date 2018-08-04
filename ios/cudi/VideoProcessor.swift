import UIKit
import AssetsLibrary
import AVFoundation
import Photos
import SpriteKit
import MobileCoreServices
import MediaWatermark
import AVFoundation


class VideoProcessor: NSObject {
    func processVideo(sourceURL: URL, duration: Float, withWaterMark: Bool) {
        if(withWaterMark){
         return self.processVideo(url: sourceURL, duration: duration)
        }
        self.trimVideo(sourceURL: sourceURL, duration: duration)
    }
    
    private func processVideo(url: URL, duration: Float) {
        if let item = MediaItem(url: url) {
            let logoImage = UIImage(named: "watermark@2x.png")
            
            let firstElement = MediaElement(image: logoImage!)
            firstElement.frame = CGRect(x: 20, y: 100, width: 100, height: (800 * 100 / 650))
            
            item.add(elements: [firstElement])
            
            let mediaProcessor = MediaProcessor()
            mediaProcessor.processElements(item: item) { [weak self] (result, error) in
                DispatchQueue.main.async {
                    print("done with watermark")
                    self?.trimVideo(sourceURL: result.processedUrl!, duration: duration)
                }
            }
        }
    }
    
    private func sendUpdate(message: String){
        let dict:[String: String] = ["message": message]
        NotificationCenter.default.post(name: Notification.Name("VideoStatusUpdate"), object: nil, userInfo: dict)
    }
    
    private func trimVideo(sourceURL: URL, duration: Float) {
        let fileManager = FileManager.default
        let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let asset = AVAsset(url: sourceURL)
        let length = Float(asset.duration.value) / Float(asset.duration.timescale)
        let count = Int(ceil(length / duration))
        let timestamp = NSDate().timeIntervalSince1970
        
        for i in 1...count {
            self.sendUpdate(message: "processing\ncutting \(i) of \(count)")
            let startTime = Double(i-1) * Double(duration)
            let endTime = Double(i) * Double(duration)
            
            var outputURL = documentDirectory.appendingPathComponent("output")
            do {
                try fileManager.createDirectory(at: outputURL, withIntermediateDirectories: true, attributes: nil)
                outputURL = outputURL.appendingPathComponent("\(sourceURL.lastPathComponent)-\(timestamp)-\(i).mp4")
            }catch let error {
                print(error)
            }
            
            //Remove existing file
            try? fileManager.removeItem(at: outputURL)
            
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { return }
            exportSession.outputURL = outputURL
            exportSession.outputFileType = AVFileTypeMPEG4

            let timeRange = CMTimeRange(start: CMTime(seconds: startTime, preferredTimescale: 1000),
                                        end: CMTime(seconds: endTime, preferredTimescale: 1000))

            let metaItem = AVMutableMetadataItem()   // Creation Date
            metaItem.keySpace = AVMetadataKeySpaceCommon // AVMetadataKeySpace.common;
            metaItem.key = AVMetadataCommonKeyCreationDate as (NSCopying & NSObjectProtocol)?;
            metaItem.value = NSDate() as (NSCopying & NSObjectProtocol)?
            exportSession.metadata = [metaItem]

            exportSession.timeRange = timeRange
            exportSession.exportAsynchronously {
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                }) { saved, error in
                }
            }
        }
        self.sendUpdate(message: "done")
    }
}
