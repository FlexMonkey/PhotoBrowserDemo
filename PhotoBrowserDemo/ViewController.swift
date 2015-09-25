//
//  ViewController.swift
//  PhotoBrowserDemo
//
//  Created by Simon Gladman on 08/01/2015.
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//

import UIKit

class ViewController: UIViewController, PhotoBrowserDelegate
{
    let photoBrowser = PhotoBrowser(returnImageSize: CGSize(width: 640, height: 640))
    let launchBrowserButton = UIButton()
    let imageView: UIImageView = UIImageView(frame: CGRectZero)

    override func viewDidLoad()
    {
        super.viewDidLoad()

        view.backgroundColor = UIColor.blackColor()
        
        launchBrowserButton.setTitle("Launch Photo Browser", forState: UIControlState.Normal)
        launchBrowserButton.addTarget(self, action: "launchPhotoBrowser", forControlEvents: UIControlEvents.TouchDown)
        
        imageView.layer.borderColor = UIColor.whiteColor().CGColor
        imageView.layer.borderWidth = 2
        
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        view.addSubview(imageView)
        view.addSubview(launchBrowserButton)
    }

    func launchPhotoBrowser()
    {
        photoBrowser.delegate = self
        
        photoBrowser.launch()
    }
    
    func photoBrowserDidSelectImage(image: UIImage, localIdentifier: String)
    {
        imageView.image = image
    }

    override func viewDidLayoutSubviews()
    {
        let topMargin = topLayoutGuide.length
        let imageViewSide = min(view.frame.width, view.frame.height - topMargin) - 75
 
        imageView.frame = CGRect(x: view.frame.width / 2 - imageViewSide / 2,
            y: view.frame.height / 2 - imageViewSide / 2,
            width: imageViewSide,
            height: imageViewSide)
        
        launchBrowserButton.frame = CGRect(x: 0, y: view.frame.height - 40, width: view.frame.width, height: 40)
    }


}

