import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        if let session {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspect
            previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
            view.layer = previewLayer
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let previewLayer = nsView.layer as? AVCaptureVideoPreviewLayer else {
            if let session {
                let newLayer = AVCaptureVideoPreviewLayer(session: session)
                newLayer.videoGravity = .resizeAspect
                newLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
                nsView.layer = newLayer
            }
            return
        }

        if let session, previewLayer.session !== session {
            previewLayer.session = session
        }
    }
}
