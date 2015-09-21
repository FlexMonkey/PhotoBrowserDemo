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

    let imageView: UIImageView = UIImageView(frame: CGRectZero)
    let launchBrowserButton: UIButton = UIButton(frame: CGRectZero)
    
    override func viewDidLoad()
    {
        super.viewDidLoad()

        view.backgroundColor = UIColor.darkGrayColor()
        
        launchBrowserButton.setTitle("Launch Photo Browser", forState: UIControlState.Normal)
        launchBrowserButton.addTarget(self, action: "launchPhotoBrowser", forControlEvents: UIControlEvents.TouchDown)
        
        imageView.contentMode = UIViewContentMode.ScaleAspectFit
        
        view.addSubview(imageView)
        view.addSubview(launchBrowserButton)
    }

    func launchPhotoBrowser()
    {
        let photoBrowserViewController = PhotoBrowserViewController()
        
        photoBrowserViewController.delegate = self
        
        photoBrowserViewController.launch()
    }
    
    func photoBrowser(didSelectImage: UIImage)
    {
        imageView.image = didSelectImage
    }
    
    override func viewDidLayoutSubviews()
    {
        
        imageView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height).insetBy(dx: 50, dy: 50)
        
        launchBrowserButton.frame = CGRect(x: 0, y: view.frame.height - 40, width: view.frame.width, height: 40)
        
    }


}

