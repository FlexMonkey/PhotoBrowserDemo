//
//  ImageItemRenderer.swift
//  PHImageManagerTwitterDemo
//
//  Created by Simon Gladman on 31/12/2014.
//  Copyright (c) 2014 Simon Gladman. All rights reserved.
//

import UIKit
import Photos

class ImageItemRenderer: UICollectionViewCell, PHPhotoLibraryChangeObserver
{
    let label = UILabel(frame: CGRectZero)
    let imageView = UIImageView(frame: CGRectZero)
    let blurOverlay = UIVisualEffectView(effect: UIBlurEffect())
    
    let manager = PHImageManager.defaultManager()
    let deliveryOptions = PHImageRequestOptionsDeliveryMode.Opportunistic
    let requestOptions = PHImageRequestOptions()
    
    let priority = DISPATCH_QUEUE_PRIORITY_DEFAULT
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        requestOptions.deliveryMode = deliveryOptions
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.Exact
        
        contentView.layer.cornerRadius = 5
        contentView.layer.masksToBounds = true
        
        label.numberOfLines = 0
  
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = NSTextAlignment.Center
        
        contentView.addSubview(imageView)
        contentView.addSubview(blurOverlay)
        contentView.addSubview(label)
        
        layer.borderColor = UIColor.darkGrayColor().CGColor
        layer.borderWidth = 1
        layer.cornerRadius = 5
        
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
    }
    
    override func layoutSubviews()
    {
        imageView.frame = bounds
        
        let labelFrame = CGRect(x: 0, y: frame.height - 20, width: frame.width, height: 20)
        
        blurOverlay.frame = labelFrame
        label.frame = labelFrame
    }
    
    deinit
    {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    var asset: PHAsset?
    {
        didSet
        {
            if let asset = asset
            {
                dispatch_async(dispatch_get_global_queue(priority, 0))
                {
                    self.setLabel()
                    self.manager.requestImageForAsset(asset,
                        targetSize: self.frame.size,
                        contentMode: PHImageContentMode.AspectFill,
                        options: self.requestOptions,
                        resultHandler: self.requestResultHandler)
                }
            }
        }
    }
    
    func setLabel()
    {
        if let asset = asset, creationDate = asset.creationDate
        {
            let text = (asset.favorite ? "★ " : "") + NSDateFormatter.localizedStringFromDate(creationDate, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.NoStyle)
            
            PhotoBrowser.executeInMainQueue({self.label.text = text})
        }
    }
    
    func photoLibraryDidChange(changeInstance: PHChange)
    {
        dispatch_async(dispatch_get_main_queue(), { self.setLabel() })
    }

    func requestResultHandler (image: UIImage?, properties: [NSObject: AnyObject]?) -> Void
    {
        PhotoBrowser.executeInMainQueue({self.imageView.image = image})
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
}

