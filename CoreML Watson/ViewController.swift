//
//  ViewController.swift
//  CoreML Watson
//
//  Created by Rodolphe DUPUY on 05/10/2020.
//  Copyright © 2020 Rodolphe DUPUY. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var cameraVue: UIView!
    @IBOutlet weak var rotationBouton: UIButton!
    @IBOutlet weak var holderVue: UIView!
    @IBOutlet weak var resultatLabel: UILabel!
    
    let mediaType = AVMediaType.video
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var position = AVCaptureDevice.Position.back
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Vérifier authorisation
        verifierAutorisationEtLancerCamera()
    }
    
    func verifierAutorisationEtLancerCamera() {
        let autorisation = AVCaptureDevice.authorizationStatus(for: mediaType)
        switch autorisation {
        case .authorized: miseEnPlaceCamera()
        case .denied: print("L'utilisateur a refusé l'accès à la caméra")
        case .restricted: print("L'utilisation de la camera est restreint")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: mediaType) { (success) in
                DispatchQueue.main.async {
                    self.verifierAutorisationEtLancerCamera()
                }
            }
        default: break
        }
    }
    
    func miseEnPlaceCamera() {
        previewLayer?.removeFromSuperlayer()
        
        session = AVCaptureSession()
        guard session != nil else { return }
        guard let appareilPhoto = AVCaptureDevice.default(AVCaptureDevice.DeviceType.builtInWideAngleCamera, for: mediaType, position: position) else { return }
        do {
            let input =  try AVCaptureDeviceInput(device: appareilPhoto)
            if session!.canAddInput(input) {
                session!.addInput(input)
            }
            
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            output.alwaysDiscardsLateVideoFrames = true
            if session!.canAddOutput(output) {
                session!.addOutput(output)
            }
            
            previewLayer = AVCaptureVideoPreviewLayer(session: session!)
            previewLayer?.frame = cameraVue.bounds
            previewLayer?.connection?.videoOrientation = .portrait
            previewLayer?.videoGravity = .resizeAspect
            
            guard previewLayer != nil else { return }
            cameraVue.layer.addSublayer(previewLayer!)
            
            let queue = DispatchQueue(label: "videoqueue")
            output.setSampleBufferDelegate(self, queue: queue)
            session!.startRunning()
            
        } catch {
            print(error.localizedDescription)
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixel = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let copie = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate) else { return }
        let ciImage = CIImage(cvImageBuffer: pixel, options: convertToOptionalCIImageOptionDictionary(copie as? [String: Any]))
        if position == .front {
            self.choisirActionAEffectuer(ciImage: ciImage.oriented(forExifOrientation: Int32(UIImage.Orientation.leftMirrored.rawValue)))
            // Image a utiliser avec Vision
        } else {
            self.choisirActionAEffectuer(ciImage: ciImage.oriented(forExifOrientation: Int32(UIImage.Orientation.downMirrored.rawValue)))
        }
    }
    
    func choisirActionAEffectuer(ciImage: CIImage) {
        do  {
            let config = MLModelConfiguration()
            let model = try VNCoreMLModel(for: DefaultCustomModel_1168905109(configuration: config).model)
            let requete = VNCoreMLRequest(model: model, completionHandler: reponse)
            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            try handler.perform([requete])
        } catch {
            print(error.localizedDescription)
        }
        
    }
    
    func reponse(_ requete: VNRequest, _ error: Error?) {
        if let resultats = requete.results as? [VNClassificationObservation], resultats.count > 0 {
            let bonResultat = resultats[0]
            let attributed = NSMutableAttributedString(string: bonResultat.identifier + " - ", attributes: [.font: UIFont.boldSystemFont(ofSize: 20), .foregroundColor: UIColor.red])
            attributed.append(NSAttributedString(string: String(bonResultat.confidence * 100) + "%", attributes: [.font: UIFont.italicSystemFont(ofSize: 20), .foregroundColor: UIColor.blue]))
            DispatchQueue.main.async {
                self.resultatLabel.attributedText = attributed
            }
        } else {
            DispatchQueue.main.async {
                self.resultatLabel.text = "Nous n'avons rien reconnu pour le moment"
            }
        }
    }
    
    @IBAction func rotationAction(_ sender: Any) {
        session?.stopRunning()
        switch position {
        case .back: position = .front
        case .front: position = .back
        case .unspecified: position = .back
        default: break
        }
        verifierAutorisationEtLancerCamera()
    }
    
    
}


// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalCIImageOptionDictionary(_ input: [String: Any]?) -> [CIImageOption: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (CIImageOption(rawValue: key), value)})
}
