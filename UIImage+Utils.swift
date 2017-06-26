//
//  UIImage+Utils.swift
//  SharedTasks
//
//  Created by David Spector on 6/26/17.
//  Copyright © 2017 Realm. All rights reserved.
//

import Foundation
import UIKit

extension UIImage {
    /// resize image to fit current frame
    ///
    /// - Parameters:
    ///   - sourceSize: source imagesize
    ///   - destRect: the cgSize of the desination
    /// - Returns: return
    func AspectScaleFit( sourceSize : CGSize,  destRect : CGRect) -> CGFloat  {
        let destSize = destRect.size
        let  scaleW = destSize.width / sourceSize.width
        let scaleH = destSize.height / sourceSize.height
        return fmin(scaleW, scaleH)
    }
    
    /// resize the current iage
    ///
    /// - Parameter targetSize: the target size as a cgSize
    /// - Returns: a new UIImage
    func resizeImage(targetSize: CGSize) -> UIImage {
        let size = self.size
        
        let widthRatio  = targetSize.width  / self.size.width
        let heightRatio = targetSize.height / self.size.height
        
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width:size.width * heightRatio, height:size.height * heightRatio)
        } else {
            newSize = CGSize(width:size.width * widthRatio,  height:size.height * widthRatio)
        }
        
        let rect = CGRect(x:0, y:0, width: newSize.width, height: newSize.height)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        self.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
}
