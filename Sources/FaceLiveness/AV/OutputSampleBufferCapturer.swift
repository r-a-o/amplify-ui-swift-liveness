//
// Copyright Amazon.com Inc. or its affiliates.
// All Rights Reserved.
//
// SPDX-License-Identifier: Apache-2.0
//

import AVFoundation
import CoreImage
import UIKit
import Photos

class OutputSampleBufferCapturer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let faceDetector: FaceDetector
    let videoChunker: VideoChunker
    private var hasSavedFrame = false

    init(faceDetector: FaceDetector, videoChunker: VideoChunker) {
        self.faceDetector = faceDetector
        self.videoChunker = videoChunker
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        videoChunker.consume(sampleBuffer)

        if !hasSavedFrame {
            saveFrame(sampleBuffer)
            hasSavedFrame = true
        }

        guard let imageBuffer = sampleBuffer.imageBuffer
        else { return }

        faceDetector.detectFaces(from: imageBuffer)
    }

    private func saveFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Error getting image buffer from sample buffer.")
            return
        }

        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("Error creating CGImage from CIImage.")
            return
        }

        let uiImage = UIImage(cgImage: cgImage)

        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Photo library access denied.")
                return
            }

            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAsset(from: uiImage)
            }, completionHandler: { success, error in
                if success {
                    print("Frame saved to photo library.")
                } else if let error = error {
                    print("Error saving frame to photo library: \(error.localizedDescription)")
                }
            })
        }
    }
}
