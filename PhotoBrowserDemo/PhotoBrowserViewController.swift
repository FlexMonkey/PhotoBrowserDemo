//
//  PhotoBrowserViewController.swift
//  Nodality
//
//  Created by Simon Gladman on Feb 8, 2015
//  Copyright (c) 2015 Simon Gladman. All rights reserved.
//
//  Thanks to http://www.shinobicontrols.com/blog/posts/2014/08/22/ios8-day-by-day-day-20-photos-framework


import UIKit
import Photos

class PhotoBrowserViewController: UIViewController
{
    let manager = PHImageManager.defaultManager()
    
    var longPressTarget: (cell: UICollectionViewCell, indexPath: NSIndexPath)?
    var collectionViewWidget: UICollectionView!
    var segmentedControl: UISegmentedControl!
    let blurOverlay = UIVisualEffectView(effect: UIBlurEffect())
    let background = UIView(frame: CGRectZero)
    
    var photoBrowserSelectedSegmentIndex = 0

    var assetCollections: PHFetchResult!
    var segmentedControlItems = [String]()
    var contentOffsets = [CGPoint]()
    
    var uiCreated = false
    
    weak var delegate: PhotoBrowserDelegate?
    
    func launch()
    {
        if let viewController = UIApplication.sharedApplication().keyWindow!.rootViewController
        {
            modalPresentationStyle = UIModalPresentationStyle.OverFullScreen
            modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
            
            viewController.presentViewController(self, animated: true, completion: nil)
        }
    }
    
    var assets: PHFetchResult!
    {
        didSet
        {
            guard let oldValue = oldValue else
            {
                return
            }
            
            if oldValue.count - assets.count == 1
            {
                collectionViewWidget.deleteItemsAtIndexPaths([longPressTarget!.indexPath])
                
                collectionViewWidget.reloadData()
            }
            else if oldValue.count != assets.count
            {
                UIView.animateWithDuration(PhotoBrowserConstants.animationDuration, animations: { self.collectionViewWidget.alpha = 0}, completion: fadeOutComplete)
            }
            else
            {
                collectionViewWidget.reloadData()
            }
        }
    }
    
    func fadeOutComplete(value: Bool)
    {
        collectionViewWidget.reloadData()
        collectionViewWidget.contentOffset = contentOffsets[segmentedControl.selectedSegmentIndex]
        UIView.animateWithDuration(PhotoBrowserConstants.animationDuration, animations: { self.collectionViewWidget.alpha = 1.0 })
    }
        
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
        
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized
        {
            createUserInterface()
        }
        else
        {
            PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
        }
    }
    
    func requestAuthorizationHandler(status: PHAuthorizationStatus)
    {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized
        {
            PhotoBrowserViewController.executeInMainQueue({ self.createUserInterface() })
        }
        else
        {
            PhotoBrowserViewController.executeInMainQueue({ self.dismissViewControllerAnimated(true, completion: nil) })
        }
    }
    
    func createUserInterface()
    {
        assetCollections = PHAssetCollection.fetchAssetCollectionsWithType(PHAssetCollectionType.SmartAlbum, subtype: PHAssetCollectionSubtype.AlbumRegular, options: nil)
        
        segmentedControlItems = [String]()
        
        for var i = 0 ; i < assetCollections.count ; i++
        {
            let assetCollection = assetCollections[i] as? PHAssetCollection
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.Image.rawValue)
            
            let assetsInCollection  = PHAsset.fetchAssetsInAssetCollection(assetCollection!, options: fetchOptions)
            
            if assetsInCollection.count > 0 || assetCollection?.localizedTitle == "Favorites"
            {
                if let localizedTitle = assetCollection?.localizedTitle
                {
                    segmentedControlItems.append(localizedTitle)
                    
                    contentOffsets.append(CGPoint(x: 0, y: 0))
                }
            }
        }
        
        segmentedControlItems = segmentedControlItems.sort { $0 < $1 }
        
        segmentedControl = UISegmentedControl(items: segmentedControlItems)
        segmentedControl.selectedSegmentIndex = photoBrowserSelectedSegmentIndex
        segmentedControl.addTarget(self, action: "segmentedControlChangeHandler", forControlEvents: UIControlEvents.ValueChanged)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .Vertical
        layout.itemSize = PhotoBrowserConstants.thumbnailSize
        layout.minimumLineSpacing = 30
        layout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        
        collectionViewWidget = UICollectionView(frame: CGRectZero, collectionViewLayout: layout)
        
        collectionViewWidget.backgroundColor = UIColor.clearColor()
        
        collectionViewWidget.delegate = self
        collectionViewWidget.dataSource = self
        collectionViewWidget.registerClass(ImageItemRenderer.self, forCellWithReuseIdentifier: "Cell")
        collectionViewWidget.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        
        let longPress = UILongPressGestureRecognizer(target: self, action: "longPressHandler:")
        collectionViewWidget.addGestureRecognizer(longPress)
        
        background.layer.borderColor = UIColor.darkGrayColor().CGColor
        background.layer.borderWidth = 1
        background.layer.cornerRadius = 5
        background.layer.masksToBounds = true
        
        view.addSubview(background)
        
        background.addSubview(blurOverlay)
        background.addSubview(collectionViewWidget)
        background.addSubview(segmentedControl)
        
        view.backgroundColor = UIColor(white: 0.5, alpha: 0.5)
        
        segmentedControlChangeHandler()
        
        uiCreated = true
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?)
    {
        super.touchesBegan(touches, withEvent: event)
        
        if let locationInView = touches.first?.locationInView(view) where
            !background.frame.contains(locationInView)
        {
            dismissViewControllerAnimated(true, completion: nil)
        }
    }
    
    func segmentedControlChangeHandler()
    {
        contentOffsets[photoBrowserSelectedSegmentIndex] = collectionViewWidget.contentOffset
        
        photoBrowserSelectedSegmentIndex = segmentedControl.selectedSegmentIndex
        
        let options = PHFetchOptions()
        options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
        options.predicate =  NSPredicate(format: "mediaType = %i", PHAssetMediaType.Image.rawValue)
        
        for var i = 0; i < assetCollections.count; i++
        {
            if segmentedControlItems[photoBrowserSelectedSegmentIndex] == assetCollections[i].localizedTitle
            {
                if let assetCollection = assetCollections[i] as? PHAssetCollection
                {
                    assets = PHAsset.fetchAssetsInAssetCollection(assetCollection, options: options)
                    
                    return
                }
            }
        }
    }
    
    func longPressHandler(recognizer: UILongPressGestureRecognizer)
    {
        guard let longPressTarget = longPressTarget,
            entity = assets[longPressTarget.indexPath.row] as? PHAsset where
            recognizer.state == UIGestureRecognizerState.Began else
        {
            return
        }
        
        let contextMenuController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        let toggleFavouriteAction = UIAlertAction(title: entity.favorite ? "Remove Favourite" : "Make Favourite", style: UIAlertActionStyle.Default, handler: toggleFavourite)
        
        contextMenuController.addAction(toggleFavouriteAction)
        
        if let popoverPresentationController = contextMenuController.popoverPresentationController
        {
            popoverPresentationController.permittedArrowDirections = [ UIPopoverArrowDirection.Down]
            popoverPresentationController.sourceRect = CGRect(origin: recognizer.locationInView(self.view), size: CGSize(width: 0, height: 0))
            
            popoverPresentationController.sourceView = view
            
            presentViewController(contextMenuController, animated: true, completion: nil)
        }
    }
    
    func toggleFavourite(value: UIAlertAction!) -> Void
    {
        if let _longPressTarget = longPressTarget, targetEntity = assets[_longPressTarget.indexPath.row] as? PHAsset
        {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges(
                {
                    let changeRequest = PHAssetChangeRequest(forAsset: targetEntity)
                    changeRequest.favorite = !targetEntity.favorite
                },
                completionHandler: nil)
        }
    }
    
    func imageRequestResultHandler(image: UIImage?, properties: [NSObject: AnyObject]?) -> Void
    {
        if let delegate = delegate, image = image
        {
            delegate.photoBrowser(image)
        }
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    override func viewDidLayoutSubviews()
    {
        if uiCreated
        {
            background.frame = view.frame.insetBy(dx: 50, dy: 50)
            blurOverlay.frame = CGRect(x: 0, y: 0, width: background.frame.width, height: background.frame.height)
            
            segmentedControl.frame = CGRect(x: 0, y: 0, width: background.frame.width, height: 40).insetBy(dx: 5, dy: 5)
            collectionViewWidget.frame = CGRect(x: 0, y: 40, width: background.frame.width, height: background.frame.height - 40)
        }
    }
    
    deinit
    {
        print("deinit MIAN")
        
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    static func executeInMainQueue(function: () -> Void)
    {
        dispatch_async(dispatch_get_main_queue(), function)
    }
}

// MARK: PHPhotoLibraryChangeObserver

extension PhotoBrowserViewController: PHPhotoLibraryChangeObserver
{
    func photoLibraryDidChange(changeInstance: PHChange)
    {
        guard let assets = assets else
        {
            return
        }
        
        if let changeDetails = changeInstance.changeDetailsForFetchResult(assets) where uiCreated
        {
            PhotoBrowserViewController.executeInMainQueue{ self.assets = changeDetails.fetchResultAfterChanges }
        }
    }
}

// MARK: UICollectionViewDataSource

extension PhotoBrowserViewController: UICollectionViewDataSource
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return assets.count
    }
}

// MARK: UICollectionViewDelegate

extension PhotoBrowserViewController: UICollectionViewDelegate
{
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! ImageItemRenderer
        
        let asset = assets[indexPath.row] as! PHAsset
        
        cell.asset = asset;
        
        return cell
    }
    
    func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath)
    {
        longPressTarget = (cell: self.collectionView(collectionViewWidget, cellForItemAtIndexPath: indexPath), indexPath: indexPath)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        if let selectedAsset = assets[indexPath.row] as? PHAsset
        {
            let targetSize = CGSize(width: selectedAsset.pixelWidth, height: selectedAsset.pixelHeight)
            let deliveryOptions = PHImageRequestOptionsDeliveryMode.HighQualityFormat
            let requestOptions = PHImageRequestOptions()
            
            requestOptions.deliveryMode = deliveryOptions
            
            manager.requestImageForAsset(selectedAsset, targetSize: targetSize, contentMode: PHImageContentMode.AspectFill, options: requestOptions, resultHandler: imageRequestResultHandler)
        }
    }
}

struct PhotoBrowserConstants
{
    static let thumbnailSize = CGSize(width: 150, height: 150)
    static let animationDuration = 0.175
}
