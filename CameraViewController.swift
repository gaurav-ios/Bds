//
//  CameraViewController.swift
//  BoddyShopMakeup
//
//  Created by Raksha Saini on 25/01/20.
//  Copyright © 2020 . All rights reserved.
//

import AVFoundation
import CoreVideo
import Vision
import Firebase


//@objc(CameraViewController)
class CameraViewController: UIViewController, UITextFieldDelegate
{
  private let detectors: [Detector] = [
    .onDeviceFace,
  ]

  private var currentDetector: Detector = .onDeviceFace
  private var isUsingFrontCamera = true
  private var previewLayer: AVCaptureVideoPreviewLayer!
  private lazy var captureSession = AVCaptureSession()
  private lazy var sessionQueue = DispatchQueue(label: Constant.sessionQueueLabel)
  private lazy var vision = Vision.vision()
  private var lastFrame: CMSampleBuffer?
  private lazy var modelManager = ModelManager.modelManager()
  @IBOutlet var downloadProgressView: UIProgressView!

  private lazy var previewOverlayView: UIImageView = {

    precondition(isViewLoaded)
    let previewOverlayView = UIImageView(frame: .zero)
    previewOverlayView.contentMode = UIView.ContentMode.scaleAspectFill
    previewOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return previewOverlayView
  }()

  private lazy var annotationOverlayView: UIView = {
    precondition(isViewLoaded)
    let annotationOverlayView = UIView(frame: .zero)
    annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return annotationOverlayView
  }()
    
    var cameraView: UIView!
    
    var selectedMakeupType : String = ""
    var selectedColorValue : UIColor = UIColor.clear

      
    var arrPointsEyeBrowLeft = [CGPoint]()
    var arrPointsEyeBrowRight = [CGPoint]()
    var arrPointsLipsTop = [CGPoint]()
    var arrPointsLipsBottom = [CGPoint]()
      
    var arrPointsEyeShadowLeft = [CGPoint]()
    var arrPointsEyeShadowRight = [CGPoint]()
      
    var arrPointsEyeLeft = [CGPoint]()
    var arrPointsEyeRight = [CGPoint]()
    var arrPointsFace = [CGPoint]()
      
    var upperTopFirstPoint : CGPoint!
    var upperTopLastPoint : CGPoint!
    var upperBottomFirstPoint : CGPoint!
    var upperBottomLastPoint : CGPoint!
      
    var arrPointsNoswBottom = [CGPoint]()
      
    var arrPointsBlushLeft = [CGPoint]()
    var arrPointsBlushRight = [CGPoint]()
    

  override func viewDidLoad() {
    super.viewDidLoad()

    cameraView = UIView()
    cameraView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
    self.view.addSubview(cameraView)
    
    
    previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
    setUpPreviewOverlayView()
    setUpAnnotationOverlayView()
    setUpCaptureSessionOutput()
    setUpCaptureSessionInput()
  }
      
    @IBAction func btnBackClicked(_ sender: UIButton)
    {
        self.navigationController?.popViewController(animated: true)
    }
    
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    startSession()
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    stopSession()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    previewLayer.frame = cameraView.frame
  }

  // MARK: - IBActions

  @IBAction func selectDetector(_ sender: Any) {
    presentDetectorsAlertController()
  }

  @IBAction func switchCamera(_ sender: Any) {
    isUsingFrontCamera = !isUsingFrontCamera
    removeDetectionAnnotations()
    setUpCaptureSessionInput()
  }

  private func detectFacesOnDevice(in image: VisionImage, width: CGFloat, height: CGFloat) {
    let options = VisionFaceDetectorOptions()

    // When performing latency tests to determine ideal detection settings,
    // run the app in 'release' mode to get accurate performance metrics
    options.landmarkMode = .none
    options.contourMode = .all
    options.classificationMode = .none

    options.performanceMode = .fast
    let faceDetector = vision.faceDetector(options: options)

    var detectedFaces: [VisionFace]? = nil
    do {
      detectedFaces = try faceDetector.results(in: image)
    } catch let error {
      print("Failed to detect faces with error: \(error.localizedDescription).")
    }
    guard let faces = detectedFaces, !faces.isEmpty else {
      print("On-Device face detector returned no results.")
      DispatchQueue.main.sync {
        self.updatePreviewOverlayView()
        self.removeDetectionAnnotations()
      }
      return
    }

   DispatchQueue.main.sync
   {
      self.updatePreviewOverlayView()
      self.removeDetectionAnnotations()
      for face in faces {
        let normalizedRect = CGRect(
          x: face.frame.origin.x / width,
          y: face.frame.origin.y / height,
          width: face.frame.size.width / width,
          height: face.frame.size.height / height
        )
                
        self.addContours(for: face, width: width, height: height, selectedMakeup: selectedMakeupType, selectedColor: selectedColorValue)
      }
    }
  }

  private func setUpCaptureSessionOutput() {
    sessionQueue.async {
      self.captureSession.beginConfiguration()
      // When performing latency tests to determine ideal capture settings,
      // run the app in 'release' mode to get accurate performance metrics
      self.captureSession.sessionPreset = AVCaptureSession.Preset.medium

      let output = AVCaptureVideoDataOutput()
      output.videoSettings = [
        (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA,
      ]
      let outputQueue = DispatchQueue(label: Constant.videoDataOutputQueueLabel)
      output.setSampleBufferDelegate(self, queue: outputQueue)
      guard self.captureSession.canAddOutput(output) else {
        print("Failed to add capture session output.")
        return
      }
      self.captureSession.addOutput(output)
      self.captureSession.commitConfiguration()
    }
  }

  private func setUpCaptureSessionInput() {
    sessionQueue.async {
      let cameraPosition: AVCaptureDevice.Position = self.isUsingFrontCamera ? .front : .back
      guard let device = self.captureDevice(forPosition: cameraPosition) else {
        print("Failed to get capture device for camera position: \(cameraPosition)")
        return
      }
      do {
        self.captureSession.beginConfiguration()
        let currentInputs = self.captureSession.inputs
        for input in currentInputs {
          self.captureSession.removeInput(input)
        }

        let input = try AVCaptureDeviceInput(device: device)
        guard self.captureSession.canAddInput(input) else {
          print("Failed to add capture session input.")
          return
        }
        self.captureSession.addInput(input)
        self.captureSession.commitConfiguration()
      } catch {
        print("Failed to create capture device input: \(error.localizedDescription)")
      }
    }
  }

  private func startSession() {
    sessionQueue.async {
      self.captureSession.startRunning()
    }
  }

  private func stopSession() {
    sessionQueue.async {
      self.captureSession.stopRunning()
    }
  }

  private func setUpPreviewOverlayView() {
    cameraView.addSubview(previewOverlayView)
    NSLayoutConstraint.activate([
      previewOverlayView.centerXAnchor.constraint(equalTo: cameraView.centerXAnchor),
      previewOverlayView.centerYAnchor.constraint(equalTo: cameraView.centerYAnchor),
      previewOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
      previewOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),

    ])
  }

  private func setUpAnnotationOverlayView() {
    cameraView.addSubview(annotationOverlayView)
    NSLayoutConstraint.activate([
      annotationOverlayView.topAnchor.constraint(equalTo: cameraView.topAnchor),
      annotationOverlayView.leadingAnchor.constraint(equalTo: cameraView.leadingAnchor),
      annotationOverlayView.trailingAnchor.constraint(equalTo: cameraView.trailingAnchor),
      annotationOverlayView.bottomAnchor.constraint(equalTo: cameraView.bottomAnchor),
    ])
  }

  private func captureDevice(forPosition position: AVCaptureDevice.Position) -> AVCaptureDevice? {
    if #available(iOS 10.0, *) {
      let discoverySession = AVCaptureDevice.DiscoverySession(
        deviceTypes: [.builtInWideAngleCamera],
        mediaType: .video,
        position: .unspecified
      )
      return discoverySession.devices.first { $0.position == position }
    }
    return nil
  }

  private func presentDetectorsAlertController() {
    let alertController = UIAlertController(
      title: Constant.alertControllerTitle,
      message: Constant.alertControllerMessage,
      preferredStyle: .alert
    )
    detectors.forEach { detectorType in
      let action = UIAlertAction(title: detectorType.rawValue, style: .default) {
        [unowned self] (action) in
        guard let value = action.title else { return }
        guard let detector = Detector(rawValue: value) else { return }
        self.currentDetector = detector
        self.removeDetectionAnnotations()
      }
      if detectorType.rawValue == currentDetector.rawValue { action.isEnabled = false }
      alertController.addAction(action)
    }
    alertController.addAction(UIAlertAction(title: Constant.cancelActionTitleText, style: .cancel))
    present(alertController, animated: true)
  }

  private func updatePreviewOverlayView() {
    guard let lastFrame = lastFrame,
      let imageBuffer = CMSampleBufferGetImageBuffer(lastFrame)
    else {
      return
    }
    let ciImage = CIImage(cvPixelBuffer: imageBuffer)
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
      return
    }
    let rotatedImage = UIImage(cgImage: cgImage, scale: Constant.originalScale, orientation: .right)
    if isUsingFrontCamera {
      guard let rotatedCGImage = rotatedImage.cgImage else {
        return
      }
      let mirroredImage = UIImage(
        cgImage: rotatedCGImage, scale: Constant.originalScale, orientation: .leftMirrored)
      previewOverlayView.image = mirroredImage
    } else {
      previewOverlayView.image = rotatedImage
    }
  }

  private func convertedPoints(
    from points: [NSValue]?,
    width: CGFloat,
    height: CGFloat
  ) -> [NSValue]? {
    return points?.map {
      let cgPointValue = $0.cgPointValue
      let normalizedPoint = CGPoint(x: cgPointValue.x / width, y: cgPointValue.y / height)
      let cgPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
      let value = NSValue(cgPoint: cgPoint)
      return value
    }
  }

  private func normalizedPoint(fromVisionPoint point: VisionPoint,width: CGFloat,height: CGFloat) -> CGPoint
  {
    let cgPoint = CGPoint(x: CGFloat(point.x.floatValue), y: CGFloat(point.y.floatValue))
    var normalizedPoint = CGPoint(x: cgPoint.x / width, y: cgPoint.y / height)
    normalizedPoint = previewLayer.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
    return normalizedPoint
  }

  // face contor detection //
    private func addContours(for face: VisionFace, width: CGFloat, height: CGFloat, selectedMakeup: String, selectedColor: UIColor)
  {
    if selectedMakeup == "Foundation"
    {
        // Face
        if let faceContour = face.contour(ofType: .face)
        {
          for point in faceContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
            arrPointsFace.append(cgPoint)
          }
            
            UIUtilities.fillColorOnShape(withPoints: arrPointsFace, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        }
    }
    else if selectedMakeup == "Lips"
    {
        // Lips
        if let topUpperLipContour = face.contour(ofType: .upperLipTop)
        {
          for point in topUpperLipContour.points
          {
             let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrPointsLipsTop.append(cgPoint)
          }
            
            upperTopFirstPoint = arrPointsLipsTop.first
            upperTopLastPoint = arrPointsLipsTop.last
        }
        
        if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom)
        {
            var arrTemp = [CGPoint]()
            
          for point in bottomUpperLipContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
            arrTemp.append(cgPoint)
          }
            
            for item in arrTemp.reversed()
            {
                arrPointsLipsTop.append(item)
            }
                    
            upperBottomFirstPoint = arrTemp.first
            upperBottomLastPoint = arrTemp.last
        }
        
        if let bottomLowerLipContour = face.contour(ofType: .lowerLipBottom)
        {
            var arrTemp = [CGPoint]()
            
          for point in bottomLowerLipContour.points
          {
              let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
              arrTemp.append(cgPoint)
          }
            
            arrPointsLipsTop.append(upperTopFirstPoint)
            
            for item in arrTemp.reversed()
            {
                arrPointsLipsTop.append(item)
            }
        }
        
        if let topLowerLipContour = face.contour(ofType: .lowerLipTop)
        {
            
            arrPointsLipsTop.append(upperTopLastPoint)
            arrPointsLipsTop.append(upperBottomLastPoint)
            
            for point in topLowerLipContour.points
            {
                let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
                arrPointsLipsTop.append(cgPoint)
            }
            
            arrPointsLipsTop.append(upperBottomFirstPoint)
            
            UIUtilities.fillColorOnShape(withPoints: arrPointsLipsTop, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        }
    }
    else if selectedMakeup == "EyeBrow"
    {
        // Left Eyebrows
        if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop)
        {
          for point in topLeftEyebrowContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
          
            arrPointsEyeBrowLeft.append(cgPoint)
          }
        }
        
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom)
        {
          var arrTemp = [CGPoint]()
            
          for point in bottomLeftEyebrowContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
           
            arrTemp.append(cgPoint)
          }
            
            for item in arrTemp.reversed()
            {
                arrPointsEyeBrowLeft.append(item)
            }
            
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeBrowLeft, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        }
        
        // Right Eyebrows
        if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop)
        {
          for point in topRightEyebrowContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
            arrPointsEyeBrowRight.append(cgPoint)
          }
        }
        
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom)
        {
            var arrTemp = [CGPoint]()
            
          for point in bottomRightEyebrowContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
            arrTemp.append(cgPoint)
          }
            
            for item in arrTemp.reversed()
            {
                arrPointsEyeBrowRight.append(item)
            }
                
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeBrowRight, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        }
    }
    else if selectedMakeup == "EyeShadow"
    {
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom)
        {
          var arrTemp = [CGPoint]()
            
          for point in bottomLeftEyebrowContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
             
             // Left eyes bottom points for eyeshadow
             arrPointsEyeShadowLeft.append(cgPoint)
          }
        }
        
        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye)
        {
            var arrTemp = [CGPoint]()
            
          for point in leftEyeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
                    
            for item in halfElements.reversed()
            {
                // Left eyeshadow points //
                arrPointsEyeShadowLeft.append(item)
            }
                        
            // Left eyeshadow color filling //
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeShadowLeft, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        }
        
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom)
        {
            var arrTemp = [CGPoint]()
            
          for point in bottomRightEyebrowContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
            arrTemp.append(cgPoint)
            
            // Right eyes bottom points for eyeshadow
            arrPointsEyeShadowRight.append(cgPoint)
          }
        }
        
        if let rightEyeContour = face.contour(ofType: .rightEye)
        {
            var arrTemp = [CGPoint]()
            
          for point in rightEyeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
                        
            for item in halfElements
            {
                // Right eyeshadow points //
                arrPointsEyeShadowRight.append(item)
            }
            
            // Right eyeshadow color filling //
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeShadowRight, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        }
    }
    else if selectedMakeup == "EyeLiner"
    {
        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye)
        {
            var arrTemp = [CGPoint]()
            
          for point in leftEyeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
            
            for item in halfElements
            {
                arrPointsEyeLeft.append(item)
            }
                                
            UIUtilities.drawLineAboveEye(withPoints: arrPointsEyeLeft, to: annotationOverlayView, color: selectedColor)
        }
        
        if let rightEyeContour = face.contour(ofType: .rightEye)
        {
            var arrTemp = [CGPoint]()
            
          for point in rightEyeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
            
            for item in halfElements
            {
                arrPointsEyeRight.append(item)
            }
            
            UIUtilities.drawLineAboveEye(withPoints: arrPointsEyeRight, to: annotationOverlayView, color: selectedColor)
        }
    }
    else if selectedMakeup == "Blush"
    {
        // Face
        if let faceContour = face.contour(ofType: .face)
        {
          for point in faceContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrPointsFace.append(cgPoint)
          }
            
            arrPointsBlushRight.append(arrPointsFace[7])
            arrPointsBlushRight.append(arrPointsFace[12])
                        
            arrPointsBlushLeft.append(arrPointsFace[29])
            arrPointsBlushLeft.append(arrPointsFace[24])
        }
        
        
        // Eyes
        if let leftEyeContour = face.contour(ofType: .leftEye)
        {
            var arrTemp = [CGPoint]()
            
          for point in leftEyeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
            
            for item in halfElements
            {
                arrPointsEyeLeft.append(item)
            }
        }
        
        if let rightEyeContour = face.contour(ofType: .rightEye)
        {
            var arrTemp = [CGPoint]()
            
          for point in rightEyeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
            
            for item in halfElements
            {
                arrPointsEyeRight.append(item)
            }
        }
        
        // Nose
        if let noseBridgeContour = face.contour(ofType: .noseBridge)
        {
            var arrTemp = [CGPoint]()
            
          for point in noseBridgeContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrTemp.append(cgPoint)
          }
            
            let point1 = arrTemp[0]
            let point2 = arrTemp[1]
            
            let xPoint = ( point1.x + point2.x )/2
            let yPoint = ( point1.y + point2.y )/2
            
            arrPointsBlushRight.append(CGPoint(x: xPoint, y: yPoint))
            
            arrPointsBlushLeft.append(CGPoint(x: xPoint, y: yPoint))
        }
        
        if let noseBottomContour = face.contour(ofType: .noseBottom)
        {
          for point in noseBottomContour.points
          {
            let cgPoint = normalizedPoint(fromVisionPoint: point, width: width, height: height)
             arrPointsNoswBottom.append(cgPoint)
          }
        }
        
        UIUtilities.fillColorOnShape(withPoints: arrPointsBlushRight, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
        
        UIUtilities.fillColorOnShape(withPoints: arrPointsBlushLeft, to: annotationOverlayView, color: selectedColor, makeupType: selectedMakeup)
    }
  }
    
    // Removes the detection annotations from the annotation overlay view.
    private func removeDetectionAnnotations()
    {
        if let layers = annotationOverlayView.layer.sublayers {

          for (index, _) in layers.enumerated() {

                 annotationOverlayView.layer.sublayers?[0].removeFromSuperlayer()
            }
        }
      
      arrPointsEyeBrowLeft.removeAll()
      arrPointsEyeBrowRight.removeAll()
      arrPointsLipsTop.removeAll()
      arrPointsLipsBottom.removeAll()
      arrPointsEyeShadowLeft.removeAll()
      arrPointsEyeShadowRight.removeAll()
      arrPointsEyeBrowLeft.removeAll()
      arrPointsEyeBrowLeft.removeAll()
      
      arrPointsEyeLeft.removeAll()
      arrPointsEyeRight.removeAll()
      arrPointsFace.removeAll()
      arrPointsNoswBottom.removeAll()
      arrPointsBlushLeft.removeAll()
      arrPointsBlushRight.removeAll()
      
      upperTopFirstPoint = nil
      upperTopLastPoint = nil
      upperBottomFirstPoint = nil
      upperBottomLastPoint = nil
    }
}

// MARK: AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      print("Failed to get image buffer from sample buffer.")
      return
    }
    lastFrame = sampleBuffer
    let visionImage = VisionImage(buffer: sampleBuffer)
    let metadata = VisionImageMetadata()
    let orientation = UIUtilities.imageOrientation(
      fromDevicePosition: isUsingFrontCamera ? .front : .back
    )

    let visionOrientation = UIUtilities.visionImageOrientation(from: orientation)
    metadata.orientation = visionOrientation
    visionImage.metadata = metadata
    let imageWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
    let imageHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))
   
    switch currentDetector {
    
    case .onDeviceFace:
      detectFacesOnDevice(in: visionImage, width: imageWidth, height: imageHeight)
    }
  }
}

public enum Detector: String {
  case onDeviceFace = "On-Device Face Detection"
}

private enum Constant {
  static let alertControllerTitle = "Vision Detectors"
  static let alertControllerMessage = "Select a detector"
  static let cancelActionTitleText = "Cancel"
  static let videoDataOutputQueueLabel = "com.google.firebaseml.visiondetector.VideoDataOutputQueue"
  static let sessionQueueLabel = "com.google.firebaseml.visiondetector.SessionQueue"
  static let noResultsMessage = "No Results"
  static let remoteAutoMLModelName = "remote_automl_model"
  static let localModelManifestFileName = "automl_labeler_manifest"
  static let autoMLManifestFileType = "json"
  static let labelConfidenceThreshold: Float = 0.75
  static let smallDotRadius: CGFloat = 4.0
  static let originalScale: CGFloat = 1.0
  static let padding: CGFloat = 10.0
  static let resultsLabelHeight: CGFloat = 200.0
  static let resultsLabelLines = 5
}
