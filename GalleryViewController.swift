//
//  ViewController.swift
//  BoddyShopMakeup
//
//  Created by Raksha Saini on 25/01/20.
//  Copyright © 2020. All rights reserved.
//

import Firebase
import AVFoundation
import Vision

class GalleryViewController: UIViewController, UITextFieldDelegate, AVCaptureVideoDataOutputSampleBufferDelegate
{
  var imgUsed: UIImage!
        
  var imageView: UIImageView!
    
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
    
  /// An overlay view that displays detection annotations.
  private lazy var annotationOverlayView: UIView = {
    precondition(isViewLoaded)
    let annotationOverlayView = UIView(frame: .zero)
    annotationOverlayView.translatesAutoresizingMaskIntoConstraints = false
    return annotationOverlayView
  }()

  private lazy var resultsAlertController: UIAlertController = {
    let alertController = UIAlertController(title: "Detection Results",
                                            message: nil,
                                            preferredStyle: .actionSheet)
    alertController.addAction(UIAlertAction(title: "OK", style: .destructive) { _ in
      alertController.dismiss(animated: true, completion: nil)
    })
    return alertController
  }()

  private lazy var vision = Vision.vision()
  private lazy var textRecognizer = vision.onDeviceTextRecognizer()
  private lazy var cloudDocumentTextRecognizer = vision.cloudDocumentTextRecognizer()
  private lazy var faceDetectorOption: VisionFaceDetectorOptions = {
    let option = VisionFaceDetectorOptions()
    option.contourMode = .all
    option.performanceMode = .fast
    return option
  }()
  private lazy var faceDetector = vision.faceDetector(options: faceDetectorOption)

    
  private lazy var labels: [String] = {
    let encoding = String.Encoding.utf8.rawValue
    guard let labelsFilePath = Bundle.main.path(
      forResource: Constants.labelsFilename,
      ofType: Constants.labelsExtension)
      else {
        print("Failed to get the labels file path.")
        return []
    }
    let contents = try! NSString(contentsOfFile: labelsFilePath, encoding: encoding)
    return contents.components(separatedBy: Constants.labelsSeparator)
  }()

  private lazy var outputDimensions = [
    Constants.dimensionBatchSize,
    NSNumber(value: labels.count),
    ]

  let shapeLayer = CAShapeLayer()
    
  let faceDetection = VNDetectFaceRectanglesRequest()
  let faceLandmarks = VNDetectFaceLandmarksRequest()
  let faceLandmarksDetectionRequest = VNSequenceRequestHandler()
  let faceDetectionRequest = VNSequenceRequestHandler()
    
  override func viewDidLoad()
  {
    super.viewDidLoad()

    imageView = UIImageView()
    imageView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: self.view.frame.height)
    imageView.contentMode = .scaleAspectFit
    self.view.addSubview(imageView)
        
    imageView.addSubview(annotationOverlayView)
    
    NSLayoutConstraint.activate([
        annotationOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
        annotationOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
        annotationOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
        annotationOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
    ])
  }

  func initializeCameraSession() {
        
        //1:  Create a new AV Session
        let avSession = AVCaptureSession()
        // Get camera devices
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front).devices
        
        //2:  Select a capture device
        do {
            if let captureDevice = devices.first {
                let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
                avSession.addInput(captureDeviceInput)
            }
        } catch {
            print(error.localizedDescription)
        }
        
        //3:  Show output on a preview layer
        let captureOutput = AVCaptureVideoDataOutput()
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        avSession.addOutput(captureOutput)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: avSession)
        previewLayer.frame = view.frame
        shapeLayer.frame = view.frame
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: -1))
        
        view.layer.addSublayer(previewLayer)
        view.layer.addSublayer(shapeLayer)
        avSession.startRunning()
    }
    
   // Delegate
   func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
       
       let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
       
    let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate)
    let ciImage = CIImage(cvImageBuffer: pixelBuffer!, options: attachments as? [CIImageOption : Any])
       
    let ciImageWithOrientation = ciImage.oriented(forExifOrientation: Int32(UIImage.Orientation.leftMirrored.rawValue))
       
       detectFace(on: ciImageWithOrientation)
       
   }

   func detectFace(on image: CIImage) {
       try? faceDetectionRequest.perform([faceDetection], on: image)
       if let results = faceDetection.results as? [VNFaceObservation] {
           if !results.isEmpty {
               faceLandmarks.inputFaceObservations = results
             //  detectLandmarks(on: image)
               
            
            let img = UIImage(ciImage: image)
            
            runFaceContourDetection(with: img, makeupType: selectedMakeupType, selectedColorCode: selectedColorValue)
            
               DispatchQueue.main.async {
                   self.shapeLayer.sublayers?.removeAll()
               }
           }
       }
   }
    
    
  func detectLandmarks(on image: CIImage) {
        try? faceLandmarksDetectionRequest.perform([faceLandmarks], on: image)
        if let landmarksResults = faceLandmarks.results as? [VNFaceObservation] {
            for observation in landmarksResults {
                DispatchQueue.main.async {
                    if let boundingBox = self.faceLandmarks.inputFaceObservations?.first?.boundingBox {
                     //   let faceBoundingBox = boundingBox.scaled(to: self.view.bounds.size)

                        
                     //   let leftEyeImageName = "lens"
                     //   let leftEye = observation.landmarks?.leftEye
                    //    self.convertPointsForFace(leftEye, faceBoundingBox, imgName: leftEyeImageName)
                        
                    //    let rightEyeImageName = "lens"
                    //    let rightEye = observation.landmarks?.rightEye
                    //    self.convertPointsForFace(rightEye, faceBoundingBox, imgName: rightEyeImageName)

                    }
                }
            }
        }
    }
    
    
  func convertPointsForFace(_ landmark: VNFaceLandmarkRegion2D?, _ boundingBox: CGRect, imgName : String) {
        if let points = landmark?.normalizedPoints {
            let faceLandmarkPoints = points.map { (point: CGPoint) -> (x: CGFloat, y: CGFloat) in
                let pointX = point.x * boundingBox.width + boundingBox.origin.x
                let pointY = point.y * boundingBox.height + boundingBox.origin.y
                
                return (x: pointX, y: pointY)
            }
            
            DispatchQueue.main.async {
                self.draw(points: faceLandmarkPoints, imgName : imgName)
            }
        }
        
    }
    
    func draw(points: [(x: CGFloat, y: CGFloat)], imgName : String) {
        let newLayer = CAShapeLayer()
        
        
        let path = UIBezierPath()
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for i in 0..<points.count - 1 {
            let point = CGPoint(x: points[i].x, y: points[i].y)
            path.addLine(to: point)
            path.move(to: point)
        }
        
        newLayer.path = path.cgPath
        
        var imageView : UIImageView

        
        imageView  = UIImageView(frame:(newLayer.path?.boundingBox)!)
        imageView.image = UIImage(named:imgName)
        self.shapeLayer.addSublayer(imageView.layer)
    }
    
    
    func convert(_ points: UnsafePointer<vector_float2>, with count: Int) -> [(x: CGFloat, y: CGFloat)] {
        var convertedPoints = [(x: CGFloat, y: CGFloat)]()
        for i in 0...count {
            convertedPoints.append((CGFloat(points[i].x), CGFloat(points[i].y)))
        }
        
        return convertedPoints
    }
    
  @IBAction func btnBackClicked(_ sender: UIButton)
  {
      self.navigationController?.popViewController(animated: true)
  }
    
  // 1
  func runFaceContourDetection(with image: UIImage, makeupType: String, selectedColorCode : UIColor)
  {
        let visionImage = VisionImage(image: image)
        faceDetector.process(visionImage) { features, error in
            self.processResult(from: features, error: error, makeupType: makeupType, selectedColorRGB: selectedColorCode)
    }
  }

  // 2
  func processResult(from faces: [VisionFace]?, error: Error?, makeupType: String, selectedColorRGB : UIColor)
  {
    removeDetectionAnnotations()
    
    guard let faces = faces else {
      return
    }

    for feature in faces {
      let transform = self.transformMatrix()
              
        self.addContours(forFace: feature, transform: transform, makeupType: makeupType, selectedColorCode: selectedColorRGB)
    }
  }

  //    Add Face Contours    //
  private func addContours(forFace face: VisionFace, transform: CGAffineTransform, makeupType: String, selectedColorCode : UIColor)
  {
    if makeupType == "Foundation"
    {
        // Face
        if let faceContour = face.contour(ofType: .face)
        {
            for point in faceContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrPointsFace.append(transformedPoint)
            }
            
            UIUtilities.fillColorOnShape(withPoints: arrPointsFace, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        }
    }
    else if makeupType == "Lips"
    {
        // Lips Top //
        if let topUpperLipContour = face.contour(ofType: .upperLipTop)
        {
            for point in topUpperLipContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrPointsLipsTop.append(transformedPoint)
            }
            
            upperTopFirstPoint = arrPointsLipsTop.first
            upperTopLastPoint = arrPointsLipsTop.last
        }
        
        if let bottomUpperLipContour = face.contour(ofType: .upperLipBottom)
        {
            var arrTemp = [CGPoint]()
            
            for point in bottomUpperLipContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
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
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
                        
            arrPointsLipsTop.append(upperTopFirstPoint)
            
            for item in arrTemp.reversed()
            {
                arrPointsLipsTop.append(item)
            }
        }
        
        // Lips Bottom //
        if let topLowerLipContour = face.contour(ofType: .lowerLipTop)
        {
            arrPointsLipsTop.append(upperTopLastPoint)
            arrPointsLipsTop.append(upperBottomLastPoint)
            
            for point in topLowerLipContour.points
            {
                // drawPoint(point, in: .red, transform: transform)
                
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrPointsLipsTop.append(transformedPoint)
            }
                  
            arrPointsLipsTop.append(upperBottomFirstPoint)
            
            UIUtilities.fillColorOnShape(withPoints: arrPointsLipsTop, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        }
    }
    else if makeupType == "EyeBrow"
    {
        // Left Eyebrows //
        if let topLeftEyebrowContour = face.contour(ofType: .leftEyebrowTop)
        {
           for point in topLeftEyebrowContour.points
           {
              let pointValue : VisionPoint = point
              let transformedPoint = pointFrom(pointValue).applying(transform);
              arrPointsEyeBrowLeft.append(transformedPoint)
          }
        }
        
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom)
        {
            var arrTemp = [CGPoint]()
            
            for point in bottomLeftEyebrowContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
            
            for item in arrTemp.reversed()
            {
                arrPointsEyeBrowLeft.append(item)
            }
            
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeBrowLeft, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        }
        
        // Right Eyebrows //
        if let topRightEyebrowContour = face.contour(ofType: .rightEyebrowTop)
        {
           for point in topRightEyebrowContour.points
           {
               let pointValue : VisionPoint = point
               let transformedPoint = pointFrom(pointValue).applying(transform);
               arrPointsEyeBrowRight.append(transformedPoint)
           }
        }
        
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom)
        {
            var arrTemp = [CGPoint]()
            
            for point in bottomRightEyebrowContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
                
            for item in arrTemp.reversed()
            {
                arrPointsEyeBrowRight.append(item)
            }
                
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeBrowRight, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        }
    }
    else if makeupType == "EyeShadow"
    {
        if let bottomLeftEyebrowContour = face.contour(ofType: .leftEyebrowBottom)
        {
            var arrTemp = [CGPoint]()
            
            for point in bottomLeftEyebrowContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
                
                // Left eyes bottom points for eyeshadow
                arrPointsEyeShadowLeft.append(transformedPoint)
            }
        }
        
        if let leftEyeContour = face.contour(ofType: .leftEye)
        {
            var arrTemp = [CGPoint]()
            
            for point in leftEyeContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
                    
            for item in halfElements.reversed()
            {
                // Left eyeshadow points //
                arrPointsEyeShadowLeft.append(item)
            }
                        
            // Left eyeshadow color filling //
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeShadowLeft, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        }
        
        if let bottomRightEyebrowContour = face.contour(ofType: .rightEyebrowBottom)
        {
            var arrTemp = [CGPoint]()
            
            for point in bottomRightEyebrowContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
                
                // Right eyes bottom points for eyeshadow
                arrPointsEyeShadowRight.append(transformedPoint)
            }
        }
        
        if let rightEyeContour = face.contour(ofType: .rightEye)
        {
            var arrTemp = [CGPoint]()
            
            for point in rightEyeContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
                        
            for item in halfElements
            {
                // Right eyeshadow points //
                arrPointsEyeShadowRight.append(item)
            }
            
            // Right eyeshadow color filling //
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeShadowRight, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        }
    }
    else if makeupType == "EyeLiner"
    {
        if let leftEyeContour = face.contour(ofType: .leftEye)
        {
            var arrTemp = [CGPoint]()
            
            for point in leftEyeContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
            
            for item in halfElements
            {
                arrPointsEyeLeft.append(item)
            }
                                
            UIUtilities.drawLineAboveEye(withPoints: arrPointsEyeLeft, to: annotationOverlayView, color: selectedColorCode)
        }
        
        if let rightEyeContour = face.contour(ofType: .rightEye)
        {
            var arrTemp = [CGPoint]()
            
            for point in rightEyeContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
            }
            
            let halfElements = arrTemp.prefix(arrTemp.count/2)
            
            for item in halfElements
            {
                arrPointsEyeRight.append(item)
            }
            
            UIUtilities.drawLineAboveEye(withPoints: arrPointsEyeRight, to: annotationOverlayView, color: selectedColorCode)
        }
    }
    else if makeupType == "Blush"
    {
        // Face
        if let faceContour = face.contour(ofType: .face)
        {
            for point in faceContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrPointsFace.append(transformedPoint)
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
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
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
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
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
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrTemp.append(transformedPoint)
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
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrPointsNoswBottom.append(transformedPoint)
            }
        }
        
        // Lips Top //
        if let topUpperLipContour = face.contour(ofType: .upperLipTop)
        {
            for point in topUpperLipContour.points
            {
                let pointValue : VisionPoint = point
                let transformedPoint = pointFrom(pointValue).applying(transform);
                arrPointsLipsTop.append(transformedPoint)
            }
        }
        
        UIUtilities.fillColorOnShape(withPoints: arrPointsBlushRight, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
        
        UIUtilities.fillColorOnShape(withPoints: arrPointsBlushLeft, to: annotationOverlayView, color: selectedColorCode, makeupType: makeupType)
    }
  }
    
    
  func updateSelectedColor(selectedColor : UIColor, makeupType : String)
  {
        if let layers = annotationOverlayView.layer.sublayers {

          for (index, _) in layers.enumerated() {

                 annotationOverlayView.layer.sublayers?[0].removeFromSuperlayer()
            }
        }
        
       if makeupType == "Foundation"
       {
            UIUtilities.fillColorOnShape(withPoints: arrPointsFace, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
       }
       else if makeupType == "Lips"
       {
            UIUtilities.fillColorOnShape(withPoints: arrPointsLipsTop, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
       }
       else if makeupType == "EyeBrow"
       {
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeBrowLeft, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeBrowRight, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
       }
       else if makeupType == "EyeShadow"
       {
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeShadowLeft, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
            UIUtilities.fillColorOnShape(withPoints: arrPointsEyeShadowRight, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
       }
       else if makeupType == "EyeLiner"
       {
            UIUtilities.drawLineAboveEye(withPoints: arrPointsEyeLeft, to: annotationOverlayView, color: selectedColor)
            UIUtilities.drawLineAboveEye(withPoints: arrPointsEyeRight, to: annotationOverlayView, color: selectedColor)
       }
       else if makeupType == "Blush"
       {
            UIUtilities.fillColorOnShape(withPoints: arrPointsBlushRight, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
           
            UIUtilities.fillColorOnShape(withPoints: arrPointsBlushLeft, to: annotationOverlayView, color: selectedColor, makeupType: makeupType)
       }
  }
    
  private func scaledImageData(
    from image: UIImage,
    componentsCount: Int = Constants.dimensionComponents.intValue
    ) -> Data? {
    let imageWidth = Constants.dimensionImageWidth.doubleValue
    let imageHeight = Constants.dimensionImageHeight.doubleValue
    let imageSize = CGSize(width: imageWidth, height: imageHeight)
    guard let scaledImageData = image.scaledImageData(
      with: imageSize,
      componentsCount: componentsCount,
      batchSize: Constants.dimensionBatchSize.intValue)
      else {
        print("Failed to scale image to size: \(imageSize).")
        return nil
    }
    return scaledImageData
  }

  private func drawFrame(_ frame: CGRect, in color: UIColor, transform: CGAffineTransform) {
    let transformedRect = frame.applying(transform)
    UIUtilities.addRectangle(
      transformedRect,
      to: self.annotationOverlayView,
      color: color
    )
  }
    
  private func pointFrom(_ visionPoint: VisionPoint) -> CGPoint
  {
       return CGPoint(x: CGFloat(visionPoint.x.floatValue), y: CGFloat(visionPoint.y.floatValue))
  }

  private func transformMatrix() -> CGAffineTransform {
    guard let image = imageView.image else { return CGAffineTransform() }
    let imageViewWidth = imageView.frame.size.width
    let imageViewHeight = imageView.frame.size.height
    let imageWidth = image.size.width
    let imageHeight = image.size.height

    let imageViewAspectRatio = imageViewWidth / imageViewHeight
    let imageAspectRatio = imageWidth / imageHeight
    let scale = (imageViewAspectRatio > imageAspectRatio) ?
      imageViewHeight / imageHeight :
      imageViewWidth / imageWidth

    // Image view's `contentMode` is `scaleAspectFit`, which scales the image to fit the size of the
    // image view by maintaining the aspect ratio. Multiple by `scale` to get image's original size.
    let scaledImageWidth = imageWidth * scale
    let scaledImageHeight = imageHeight * scale
    let xValue = (imageViewWidth - scaledImageWidth) / CGFloat(2.0)
    let yValue = (imageViewHeight - scaledImageHeight) / CGFloat(2.0)

    var transform = CGAffineTransform.identity.translatedBy(x: xValue, y: yValue)
    transform = transform.scaledBy(x: scale, y: scale)
    return transform
  }

  /// Removes the detection annotations from the annotation overlay view.
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
    
// MARK: - Fileprivate

fileprivate enum Constants {
  static let lineWidth: CGFloat = 3.0
  static let lineColor = UIColor.yellow.cgColor
  static let fillColor = UIColor.clear.cgColor
  static let smallDotRadius: CGFloat = 5.0
  static let largeDotRadius: CGFloat = 10.0
  static let detectionNoResultsMessage = "No results returned."
  static let failedToDetectObjectsMessage = "Failed to detect objects in image."
  static let labelsFilename = "labels"
  static let labelsExtension = "txt"
  static let labelsSeparator = "\n"
  static let modelExtension = "tflite"
  static let dimensionBatchSize: NSNumber = 1
  static let dimensionImageWidth: NSNumber = 224
  static let dimensionImageHeight: NSNumber = 224
  static let dimensionComponents: NSNumber = 3
  static let modelInputIndex: UInt = 0
  static let maxRGBValue: Float32 = 255.0
  static let topResultsCount: Int = 5
  static let inputDimensions = [
    dimensionBatchSize,
    dimensionImageWidth,
    dimensionImageHeight,
    dimensionComponents,
    ]
}

struct ImageDisplay {
  let file: String
  let name: String
}

extension CGRect {
    func scaled(to size: CGSize) -> CGRect {
        return CGRect(
            x: self.origin.x * size.width,
            y: self.origin.y * size.height,
            width: self.size.width * size.width,
            height: self.size.height * size.height
        )
    }
}
