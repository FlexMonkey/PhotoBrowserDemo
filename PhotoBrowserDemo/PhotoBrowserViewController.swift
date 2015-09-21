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

class PhotoBrowserViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, PHPhotoLibraryChangeObserver
{
    let manager = PHImageManager.defaultManager()
    
    var longPressTarget: (cell: UICollectionViewCell, indexPath: NSIndexPath)?
    var collectionViewWidget: UICollectionView!
    var segmentedControl: UISegmentedControl!
    var photoBrowserSelectedSegmentIndex = 0

    var assetCollections: PHFetchResult!
    var segmentedControlItems = [String]()
    var contentOffsets = [CGPoint]()
    
    var uiCreated = false
    
    var delegate: PhotoBrowserDelegate?
    
    func launch(size size: CGSize, view: UIView)
    {
        preferredContentSize = size
        
        let popoverController = UIPopoverController(contentViewController: self)
        let popoverRect = view.frame.insetBy(dx: 0, dy: 0)
        
        popoverController.presentPopoverFromRect(popoverRect, inView: view, permittedArrowDirections: UIPopoverArrowDirection(), animated: true)
    }
    
    var assets: PHFetchResult!
    {
        didSet
        {
            if let _oldValue = oldValue
            {
                if _oldValue.count - assets.count == 1
                {
                    collectionViewWidget.deleteItemsAtIndexPaths([longPressTarget!.indexPath])
                    
                    collectionViewWidget.reloadData()
                }
                else if _oldValue.count != assets.count
                {
                    UIView.animateWithDuration(PhotoBrowserConstants.animationDuration, animations: { self.collectionViewWidget.alpha = 0}, completion: fadeOutComplete)
                }
                else
                {
                    collectionViewWidget.reloadData()
                }
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
            executeInMainQueue({ self.createUserInterface() })
        }
        else
        {
            executeInMainQueue({ self.dismissViewControllerAnimated(true, completion: nil) })
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
        
        view.addSubview(collectionViewWidget)
        
        view.addSubview(segmentedControl)
        
        segmentedControlChangeHandler()
        
        uiCreated = true
    }
    
    func photoLibraryDidChange(changeInstance: PHChange)
    {
        if let changeDetails = changeInstance.changeDetailsForFetchResult(assets) where assets != nil &&  uiCreated
        {            
            executeInMainQueue({ self.assets = changeDetails.fetchResultAfterChanges })
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
        if recognizer.state == UIGestureRecognizerState.Began
        {
            if let _longPressTarget = longPressTarget
            {
                let entity = assets[_longPressTarget.indexPath.row] as? PHAsset
                
                let contextMenuController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
                let toggleFavouriteAction = UIAlertAction(title: entity!.favorite ? "Remove Favourite" : "Make Favourite", style: UIAlertActionStyle.Default, handler: toggleFavourite)
                
                contextMenuController.addAction(toggleFavouriteAction)
                
                if let popoverPresentationController = contextMenuController.popoverPresentationController
                {
                    popoverPresentationController.permittedArrowDirections = [UIPopoverArrowDirection.Up, UIPopoverArrowDirection.Down]
                    popoverPresentationController.sourceRect = _longPressTarget.cell.frame.offsetBy(dx: collectionViewWidget.frame.origin.x, dy: collectionViewWidget.frame.origin.y - collectionViewWidget.contentOffset.y)
                    
                    popoverPresentationController.sourceView = view
                    
                    presentViewController(contextMenuController, animated: true, completion: nil)
                }
            }
        }
    }
    
    
    func toggleFavourite(value: UIAlertAction!) -> Void
    {
        if let _longPressTarget = longPressTarget, targetEntity = assets[_longPressTarget.indexPath.row] as? PHAsset
        {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let changeRequest = PHAssetChangeRequest(forAsset: targetEntity)
                changeRequest.favorite = !targetEntity.favorite
                }, completionHandler: nil)
        }
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
    
    func imageRequestResultHandler(image: UIImage?, properties: [NSObject: AnyObject]?) -> Void
    {
        if let delegate = delegate, image = image
        {
            delegate.photoBrowser(image)
        }
        
        dismissViewControllerAnimated(true, completion: nil)
    }
    
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return assets.count
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Cell", forIndexPath: indexPath) as! ImageItemRenderer
        
        let asset = assets[indexPath.row] as! PHAsset
        
        cell.asset = asset;
        
        return cell
    }
    
    override func viewDidLayoutSubviews()
    {
        if uiCreated
        {
            segmentedControl.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 40).insetBy(dx: 5, dy: 5)
            collectionViewWidget.frame = CGRect(x: 0, y: 40, width: view.frame.width, height: view.frame.height - 40)
        }
    }
    
    deinit
    {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    func executeInMainQueue(function: () -> Void)
    {
        dispatch_async(dispatch_get_main_queue(), function)
    }
}

struct PhotoBrowserConstants
{
    static let thumbnailSize = CGSize(width: 200, height: 200)
    static let animationDuration = 0.175
}
