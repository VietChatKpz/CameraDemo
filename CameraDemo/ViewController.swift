//
//  ViewController.swift
//  CameraDemo
//
//  Created by Nguyễn Đình Việt on 27/06/2022.
//

import UIKit
import AVFoundation
import Photos


class ViewController: UIViewController {
    
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var flashMode = AVCaptureDevice.FlashMode.off
    var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    var previewLayer: AVCaptureVideoPreviewLayer?
    @IBOutlet weak var blackView: UIView!
    
    @IBOutlet weak var flashButto: UIButton!
    @IBOutlet weak var squareView: UIView!
    @IBOutlet weak var viewCamera: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureCameraController()
        
        UIView.animateKeyframes(withDuration: 5, delay: 0, options: [.autoreverse, .repeat]) {
            self.blackView.transform = CGAffineTransform(translationX: 0, y: self.squareView.bounds.height-self.blackView.bounds.height)
            //self.blackView.alpha = 0
        }completion: { _ in
            self.blackView.transform = CGAffineTransform.identity
        }

    }
    
    
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {
     
        func createCaptureSession() {
            
            self.captureSession = AVCaptureSession()
            
        }
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            let cameras = (session.devices.compactMap { $0 })
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                
                if camera.position == .back {
                    self.rearCamera = camera
                    
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
            
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
            
            else { throw CameraControllerError.noCamerasAvailable }
        }
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecType.jpeg])], completionHandler: nil)
            
            if captureSession.canAddOutput(self.photoOutput!) { captureSession.addOutput(self.photoOutput!) }
            
            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
            
            catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
    
    func switchCameras() throws {
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        func switchToFrontCamera() throws {
            guard let inputs = captureSession.inputs as? [AVCaptureInput], let rearCameraInput = self.rearCameraInput, inputs.contains(rearCameraInput),
                  let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            
            if captureSession.canAddInput(self.frontCameraInput!) {
                captureSession.addInput(self.frontCameraInput!)
                
                self.currentCameraPosition = .front
            }
            
            else { throw CameraControllerError.invalidOperation }
        }
        
        func switchToRearCamera() throws {
            guard let inputs = captureSession.inputs as? [AVCaptureInput], let frontCameraInput = self.frontCameraInput, inputs.contains(frontCameraInput),
                  let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(self.rearCameraInput!) {
                captureSession.addInput(self.rearCameraInput!)
                
                self.currentCameraPosition = .rear
            }
            
            else { throw CameraControllerError.invalidOperation }
        }
        
        switch currentCameraPosition {
        case .front:
            try switchToRearCamera()
            
        case .rear:
            try switchToFrontCamera()
        }
        
        captureSession.commitConfiguration()
        
    }
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.previewLayer?.connection?.videoOrientation = .portrait
        self.previewLayer?.frame = view.frame
        self.previewLayer?.frame = CGRect( x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height )
        view.layer.insertSublayer(self.previewLayer!, at: 0)
        
    }
    
    func configureCameraController() {
        self.prepare {(error) in
            if let error = error {
                print(error)
            }
            
            try? self.displayPreview(on: self.viewCamera)
        }
    }
    
    func captureImage(completion: @escaping (UIImage?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
    
    @IBAction func flashOnPress(_ sender: Any) {
        if self.flashMode == .on {
            self.flashMode = .off
            flashButto.setImage(UIImage(named: "Frame-1"), for: .normal)
        }
        
        else {
            self.flashMode = .on
            flashButto.setImage(UIImage(named: "Flash"), for: .normal)
        }
    }
    
    @IBAction func cameraOnPress(_ sender: Any) {
        self.captureImage {(image, error) in
            guard let image = image else {
                print(error ?? "Image capture error")
                return
            }
            let alert = UIAlertController(title: "Thông báo", message: "Bạn có muốn lưu ảnh không?", preferredStyle: UIAlertController.Style.alert)
            self.captureSession?.stopRunning()
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { action in
                try? PHPhotoLibrary.shared().performChangesAndWait {
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }
                self.captureSession?.startRunning()
            }))
            alert.addAction(UIAlertAction(title: "Hủy", style: UIAlertAction.Style.cancel, handler: {_ in
                self.captureSession?.startRunning()
            }))
            
            self.present(alert, animated: true, completion: nil)
            
            
        }
    }
    @IBAction func switchOnPress(_ sender: Any) {
        do {
            try self.switchCameras()
        }
        
        catch {
            print(error)
        }
        
        switch self.currentCameraPosition {
        case .some(.front):
            return
            
        case .some(.rear):
            return
            
        case .none:
            return
        }

    }
    
}


extension ViewController {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Swift.Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        
        else if let imageData = photo.fileDataRepresentation(),
                let image = UIImage(data: imageData) {
            
            self.photoCaptureCompletionBlock?(image, nil)
        }
        
        else {
            self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown)
        }
    }
}


