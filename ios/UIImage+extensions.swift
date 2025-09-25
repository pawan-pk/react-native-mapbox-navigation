import UIKit
extension UIImage {
  func withRounded(radius: CGFloat, borderWidth: CGFloat = 0, borderColor: UIColor = UIColor.white) -> UIImage {
      let targetSize = CGSize(width: 20, height: 20)
      let rect = CGRect(origin: .zero, size: targetSize)

      UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
      let context = UIGraphicsGetCurrentContext()

      let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
      path.addClip()

      // Compute aspect-fit size
      let aspectWidth = targetSize.width / size.width
      let aspectHeight = targetSize.height / size.height
      let scaleFactor = max(aspectWidth, aspectHeight)

      let scaledWidth = size.width * scaleFactor
      let scaledHeight = size.height * scaleFactor

      // Center the image in the target rect
      let x = (targetSize.width - scaledWidth) / 2
      let y = (targetSize.height - scaledHeight) / 2
      let drawRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)

      self.draw(in: drawRect)

      if borderWidth > 0 {
        borderColor.setStroke()
        path.lineWidth = borderWidth
        path.stroke()
      }

      let processedImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      return processedImage ?? self
    }
}
