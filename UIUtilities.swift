//
//  Copyright (c) 2018 Google Inc.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//

//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AVFoundation
import UIKit

import FirebaseMLVision


/// Defines UI-related utilitiy methods for vision detection.
public class UIUtilities {

  // MARK: - Public
    
  public static func addCircle( atPoint point: CGPoint, to view: UIView, color: UIColor, radius: CGFloat )
  {
        let divisor: CGFloat = 2.0
        let xCoord = point.x - radius / divisor
        let yCoord = point.y - radius / divisor
        let circleRect = CGRect(x: xCoord, y: yCoord, width: radius, height: radius)
        let circleView = UIView(frame: circleRect)
        circleView.layer.cornerRadius = radius / divisor
        circleView.alpha = Constants.circleViewAlpha
        circleView.backgroundColor = color
        view.addSubview(circleView)
  }
    
  public static func addRectangle(_ rectangle: CGRect, to view: UIView, color: UIColor)
  {
        let rectangleView = UIView(frame: rectangle)
        rectangleView.layer.cornerRadius = Constants.rectangleViewCornerRadius
        rectangleView.alpha = Constants.rectangleViewAlpha
        rectangleView.backgroundColor = color
        view.addSubview(rectangleView)
  }
    
    public static func fillColorOnShape(withPoints pointsArray: [CGPoint], to view: UIView, color: UIColor, makeupType: String)
    {
        let path = UIBezierPath()
        
        path.lineCapStyle = .round
        for i in 0 ..< pointsArray.count
        {
            let point = pointsArray[i]  // else { return }
            
          //  print("pointttttttttt", point.x, point.y)
            
            if i == 0
            {
                path.move(to: CGPoint(x: point.x, y: point.y))
            }
            else
            {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            
            if i == pointsArray.count - 1
            {
                path.close()
            }
        }
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.fillColor = color.cgColor
        
        if makeupType == "EyeShadow"
        {
            shapeLayer.shadowPath = path.cgPath
            shapeLayer.shadowColor = color.cgColor
            shapeLayer.shadowOffset = CGSize(width: 1, height: 2)
            shapeLayer.shadowOpacity = 0.8
            shapeLayer.shadowRadius = 10
            
            shapeLayer.strokeColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.0).cgColor
            shapeLayer.fillColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.0).cgColor
        }
        
        if makeupType != "Blush"
        {
            view.layer.addSublayer(shapeLayer)
        }
        
        if makeupType == "Blush"
        {
            let point1 = pointsArray[0]
            let point2 = pointsArray[1]
            let point3 = pointsArray[2]
            
            let xPoint = ( point1.x + point2.x + point3.x)/3
            let yPoint = ( point1.y + point2.y + point3.y)/3

            let totalDistance = CGPointDistance(from: point1, to: point2)

            print("pointt is :", xPoint, yPoint, totalDistance)

            let cx = (point1.x + point2.x + point3.x) / 3
            let cy = (point1.y + point2.y + point3.y) / 3
            
            let a = lineDistance(point1: pointsArray[0], point2: pointsArray[1])
            let b = lineDistance(point1: pointsArray[1], point2: pointsArray[2])
            let c = lineDistance(point1: pointsArray[2], point2: pointsArray[0])
            
            let p = (a + b + c)/2
            
            let area = b / 2 * (point2.y - point1.y)
            
            var r = (2 * area) / p
            r=r/2;
            
            print("Radius is :", r)
            
            if (r>0) {
                
                let shape = UIBezierPath(arcCenter: CGPoint(x: cx, y: cy), radius: r-15, startAngle: CGFloat(0), endAngle: CGFloat.pi * 2, clockwise: true)
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = shape.cgPath
                shapeLayer.shadowPath = shape.cgPath
                shapeLayer.shadowColor = color.cgColor
                shapeLayer.shadowOffset = CGSize(width: 1, height: 2)
                shapeLayer.shadowOpacity = 0.8
                shapeLayer.shadowRadius = 10
                
                shapeLayer.fillColor = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.0).cgColor
                view.layer.addSublayer(shapeLayer)
            }
        }
    }
    
    public static func lineDistance(point1: CGPoint, point2: CGPoint) -> CGFloat
    {
        var xs = 0.0
        var ys = 0.0

        xs = Double(point2.x - point1.x)
        xs = xs * xs;

        ys = Double(point2.y - point1.y)
        ys = ys * ys;

        return CGFloat(sqrt(xs + ys));
    }
    
    public static func CGPointDistanceSquared(from: CGPoint, to: CGPoint) -> CGFloat {
        return (from.x - to.x) * (from.x - to.x) + (from.y - to.y) * (from.y - to.y)
    }

    public static func CGPointDistance(from: CGPoint, to: CGPoint) -> CGFloat {
        return sqrt(CGPointDistanceSquared(from: from, to: to))
    }
    
   public static func createRoundedTriangle(width: CGFloat, height: CGFloat, radius: CGFloat) -> CGPath {
        let point1 = CGPoint(x: -width / 2, y: height / 2)
        let point2 = CGPoint(x: 0, y: -height / 2)
        let point3 = CGPoint(x: width / 2, y: height / 2)

        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addArc(tangent1End: point1, tangent2End: point2, radius: radius)
        path.addArc(tangent1End: point2, tangent2End: point3, radius: radius)
        path.addArc(tangent1End: point3, tangent2End: point1, radius: radius)
        path.closeSubpath()

        return path
    }
    
    public static func drawLineAboveEye(withPoints pointsArray: [CGPoint], to view: UIView, color: UIColor)
    {
        let path = UIBezierPath()
        
        for i in 0 ..< pointsArray.count
        {
            let point = pointsArray[i]  // else { return }
            
        //    print("pointttttttttt", point.x, point.y)
            
            if i == 0
            {
                path.move(to: CGPoint(x: point.x, y: point.y))
            }
            else
            {
                path.addLine(to: CGPoint(x: point.x, y: point.y))
            }
            
            if i == pointsArray.count - 1
            {
               // path.close()
            }
        }
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = color.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2
        view.layer.addSublayer(shapeLayer)
    }
  
    public static func addShape(withPoints points: [NSValue]?, to view: UIView, color: UIColor)
    {
      guard let points = points else { return }
      let path = UIBezierPath()
      for (index, value) in points.enumerated()
      {
        let point = value.cgPointValue
        if index == 0 {
          path.move(to: point)
        } else {
          path.addLine(to: point)
        }
        if index == points.count - 1 {
          path.close()
        }
      }
      let shapeLayer = CAShapeLayer()
      shapeLayer.path = path.cgPath
      shapeLayer.fillColor = color.cgColor
      let rect = CGRect(x: 0, y: 0, width: view.frame.size.width, height: view.frame.size.height)
      let shapeView = UIView(frame: rect)
      shapeView.alpha = Constants.shapeViewAlpha
      shapeView.layer.addSublayer(shapeLayer)
      view.addSubview(shapeView)
    }
    
  public static func imageOrientation(
    fromDevicePosition devicePosition: AVCaptureDevice.Position = .back
    ) -> UIImage.Orientation {
    var deviceOrientation = UIDevice.current.orientation
    if deviceOrientation == .faceDown || deviceOrientation == .faceUp ||
      deviceOrientation == .unknown {
      deviceOrientation = currentUIOrientation()
    }
    switch deviceOrientation {
    case .portrait:
      return devicePosition == .front ? .leftMirrored : .right
    case .landscapeLeft:
      return devicePosition == .front ? .downMirrored : .up
    case .portraitUpsideDown:
      return devicePosition == .front ? .rightMirrored : .left
    case .landscapeRight:
      return devicePosition == .front ? .upMirrored : .down
    case .faceDown, .faceUp, .unknown:
      return .up
    @unknown default:
      return .up
    }
    
  }
  
    
  public static func visionImageOrientation(
    from imageOrientation: UIImage.Orientation
    ) -> VisionDetectorImageOrientation {
    switch imageOrientation {
    case .up:
      return .topLeft
    case .down:
      return .bottomRight
    case .left:
      return .leftBottom
    case .right:
      return .rightTop
    case .upMirrored:
      return .topRight
    case .downMirrored:
      return .bottomLeft
    case .leftMirrored:
      return .leftTop
    case .rightMirrored:
      return .rightBottom
    @unknown default:
      return .topLeft
    }
  }

  // MARK: - Private

  private static func currentUIOrientation() -> UIDeviceOrientation {
    let deviceOrientation = { () -> UIDeviceOrientation in
      switch UIApplication.shared.statusBarOrientation {
      case .landscapeLeft:
        return .landscapeRight
      case .landscapeRight:
        return .landscapeLeft
      case .portraitUpsideDown:
        return .portraitUpsideDown
      case .portrait, .unknown:
        return .portrait
      @unknown default:
        return .portrait
      }
    }
    guard Thread.isMainThread else {
      var currentOrientation: UIDeviceOrientation = .portrait
      DispatchQueue.main.sync {
        currentOrientation = deviceOrientation()
      }
      return currentOrientation
    }
    return deviceOrientation()
  }
}

// MARK: - Constants

private enum Constants {
  static let circleViewAlpha: CGFloat = 0.7
  static let rectangleViewAlpha: CGFloat = 0.3
    static let shapeViewAlpha: CGFloat = 0.3
  static let rectangleViewCornerRadius: CGFloat = 10.0
}
