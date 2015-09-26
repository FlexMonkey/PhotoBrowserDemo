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

class PhotoBrowser: UIViewController
{
    let manager = PHImageManager.defaultManager()
    let requestOptions = PHImageRequestOptions()

    var touchedCell: (cell: UICollectionViewCell, indexPath: NSIndexPath)?
    var collectionViewWidget: UICollectionView!
    var segmentedControl: UISegmentedControl!
    let blurOverlay = UIVisualEffectView(effect: UIBlurEffect())
    let background = UIView(frame: CGRectZero)
    let activityIndicator = ActivityIndicator()
    
    var photoBrowserSelectedSegmentIndex = 0

    var assetCollections: PHFetchResult!
    var segmentedControlItems = [String]()
    var contentOffsets = [CGPoint]()
    
    var selectedAsset: PHAsset?
    var uiCreated = false
    
    var returnImageSize = CGSize(width: 100, height: 100)
    
    weak var delegate: PhotoBrowserDelegate?
    
    required init(returnImageSize: CGSize)
    {
        super.init(nibName: nil, bundle: nil)
        
        self.returnImageSize = returnImageSize
        
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.HighQualityFormat
        requestOptions.resizeMode = PHImageRequestOptionsResizeMode.Exact
        requestOptions.networkAccessAllowed = true
        requestOptions.progressHandler = {
            (value: Double, _: NSError?, _ : UnsafeMutablePointer<ObjCBool>, _ : [NSObject : AnyObject]?) in
            self.activityIndicator.updateProgress(value)
        }
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    func launch()
    {
        if let viewController = UIApplication.sharedApplication().keyWindow!.rootViewController
        {
            modalPresentationStyle = UIModalPresentationStyle.OverFullScreen
            modalTransitionStyle = UIModalTransitionStyle.CrossDissolve
            
            viewController.presentViewController(self, animated: true, completion: nil)
            
            activityIndicator.stopAnimating()
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
                collectionViewWidget.deleteItemsAtIndexPaths([touchedCell!.indexPath])
                
                collectionViewWidget.reloadData()
            }
            else if oldValue.count != assets.count
            {
                UIView.animateWithDuration(PhotoBrowserConstants.animationDuration,
                    animations:
                    {
                        self.collectionViewWidget.alpha = 0
                    },
                    completion:
                    {
                        (value: Bool) in
                        self.collectionViewWidget.reloadData()
                        self.collectionViewWidget.contentOffset = self.contentOffsets[self.segmentedControl.selectedSegmentIndex]
                        UIView.animateWithDuration(PhotoBrowserConstants.animationDuration, animations: { self.collectionViewWidget.alpha = 1.0 })
                    })
            }
            else
            {
                collectionViewWidget.reloadData()
            }
        }
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
            PhotoBrowser.executeInMainQueue({ self.createUserInterface() })
        }
        else
        {
            PhotoBrowser.executeInMainQueue({ self.dismissViewControllerAnimated(true, completion: nil) })
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
   
    if UIApplication.sharedApplication().keyWindow?.traitCollection.forceTouchCapability == UIForceTouchCapability.Available
    {
        registerForPreviewingWithDelegate(self, sourceView: view)
    }
    else
    {
        let longPress = UILongPressGestureRecognizer(target: self, action: "longPressHandler:")
        collectionViewWidget.addGestureRecognizer(longPress)
    }
            
        background.layer.borderColor = UIColor.darkGrayColor().CGColor
        background.layer.borderWidth = 1
        background.layer.cornerRadius = 5
        background.layer.masksToBounds = true
        
        view.addSubview(background)
        
        background.addSubview(blurOverlay)
        background.addSubview(collectionViewWidget)
        background.addSubview(segmentedControl)
        
        view.backgroundColor = UIColor(white: 0.15, alpha: 0.85)
        
        activityIndicator.frame = CGRect(origin: CGPointZero, size: view.frame.size)
        view.addSubview(activityIndicator)
        
        segmentedControlChangeHandler()
        
        uiCreated = true
    }
    
    // MARK: User interaction handling
    
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
        
        selectedAsset = nil
    }
    
    func longPressHandler(recognizer: UILongPressGestureRecognizer)
    {
        guard let touchedCell = touchedCell,
            asset = assets[touchedCell.indexPath.row] as? PHAsset where
            recognizer.state == UIGestureRecognizerState.Began else
        {
            return
        }
        
        let contextMenuController = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertControllerStyle.ActionSheet)
        let toggleFavouriteAction = UIAlertAction(title: asset.favorite ? "Remove Favourite" : "Make Favourite", style: UIAlertActionStyle.Default, handler: toggleFavourite)
        
        contextMenuController.addAction(toggleFavouriteAction)
        
        if let popoverPresentationController = contextMenuController.popoverPresentationController
        {
            popoverPresentationController.permittedArrowDirections = [ UIPopoverArrowDirection.Down]
            popoverPresentationController.sourceRect = CGRect(origin: recognizer.locationInView(self.view), size: CGSize(width: 0, height: 0))
            
            popoverPresentationController.sourceView = view
        }
        
        presentViewController(contextMenuController, animated: true, completion: nil)
    }
    
    func toggleFavourite(_: UIAlertAction!) -> Void
    {
        if let touchedCell = touchedCell, targetEntity = assets[touchedCell.indexPath.row] as? PHAsset
        {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges(
                {
                    let changeRequest = PHAssetChangeRequest(forAsset: targetEntity)
                    changeRequest.favorite = !targetEntity.favorite
                },
                completionHandler: nil)
        }
    }
    
    // MARK: Image management
    
    func requestImageForAsset(asset: PHAsset)
    {
        activityIndicator.startAnimating()
        
        selectedAsset = asset
        
        manager.requestImageForAsset(asset,
            targetSize: returnImageSize,
            contentMode: PHImageContentMode.AspectFill,
            options: requestOptions,
            resultHandler: imageRequestResultHandler)
    }
    
    func imageRequestResultHandler(image: UIImage?, properties: [NSObject: AnyObject]?)
    {
        if let delegate = delegate, image = image, selectedAssetLocalIdentifier = selectedAsset?.localIdentifier
        {
            PhotoBrowser.executeInMainQueue
            {
                delegate.photoBrowserDidSelectImage(image, localIdentifier: selectedAssetLocalIdentifier)
            }
        }
        // TODO : Handle no image case (asset is broken in iOS)
        
        activityIndicator.stopAnimating()
        selectedAsset = nil
        dismissViewControllerAnimated(true, completion: nil)
    }

    // MARK: System Layout
    
    override func viewDidLayoutSubviews()
    {
        if uiCreated
        {
            background.frame = view.frame.insetBy(dx: 50, dy: 50)
            activityIndicator.frame = view.frame.insetBy(dx: 50, dy: 50)
            blurOverlay.frame = CGRect(x: 0, y: 0, width: background.frame.width, height: background.frame.height)
            
            segmentedControl.frame = CGRect(x: 0, y: 0, width: background.frame.width, height: 40).insetBy(dx: 5, dy: 5)
            collectionViewWidget.frame = CGRect(x: 0, y: 40, width: background.frame.width, height: background.frame.height - 40)
        }
    }
    
    deinit
    {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self)
    }
    
    static func executeInMainQueue(function: () -> Void)
    {
        dispatch_async(dispatch_get_main_queue(), function)
    }
}

// MARK: PHPhotoLibraryChangeObserver

extension PhotoBrowser: PHPhotoLibraryChangeObserver
{
    func photoLibraryDidChange(changeInstance: PHChange)
    {
        guard let assets = assets else
        {
            return
        }
        
        if let changeDetails = changeInstance.changeDetailsForFetchResult(assets) where uiCreated
        {
            PhotoBrowser.executeInMainQueue{ self.assets = changeDetails.fetchResultAfterChanges }
        }
    }
}

// MARK: UICollectionViewDataSource

extension PhotoBrowser: UICollectionViewDataSource
{
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return assets.count
    }
}

// MARK: UICollectionViewDelegate

extension PhotoBrowser: UICollectionViewDelegate
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
        touchedCell = (cell: self.collectionView(collectionViewWidget, cellForItemAtIndexPath: indexPath), indexPath: indexPath)
    }
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        if let asset = assets[indexPath.row] as? PHAsset
        {
            requestImageForAsset(asset)
        }
    }
}

// MARK:

extension PhotoBrowser: UIViewControllerPreviewingDelegate
{
    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard let touchedCell = touchedCell,
            asset = assets[touchedCell.indexPath.row] as? PHAsset else
        {
            return nil
        }
        
        let previewSize = min(view.frame.width, view.frame.height) * 0.8
        
        let peekController = PeekViewController(frame: CGRect(x: 0, y: 0,
            width: previewSize,
            height: previewSize))

        peekController.asset = asset
        
        return peekController
    }
    
    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController)
    {
        guard let touchedCell = touchedCell,
            asset = assets[touchedCell.indexPath.row] as? PHAsset else
        {
            dismissViewControllerAnimated(true, completion: nil)
            
            return
        }
        
        requestImageForAsset(asset)
    }
}

// MARK: PeekViewController

class PeekViewController: UIViewController
{
    let itemRenderer: ImageItemRenderer
    
    required init(frame: CGRect)
    {
        itemRenderer = ImageItemRenderer(frame: frame)
        
        super.init(nibName: nil, bundle: nil)
        
        preferredContentSize = frame.size
        
        view.addSubview(itemRenderer)
    }

    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
 
    func toggleFavourite()
    {
        if let targetEntity = asset
        {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges(
                {
                    let changeRequest = PHAssetChangeRequest(forAsset: targetEntity)
                    changeRequest.favorite = !targetEntity.favorite
                },
                completionHandler: nil)
        }
    }
    
    var previewActions: [UIPreviewActionItem]
    {
        return [UIPreviewAction(title: asset!.favorite ? "Remove Favourite" : "Make Favourite",
            style: UIPreviewActionStyle.Default,
            handler:
            {
                (previewAction, viewController) in (viewController as? PeekViewController)?.toggleFavourite()
            })]
    }
    
    var asset: PHAsset?
    {
        didSet
        {
            if let asset = asset
            {
                itemRenderer.asset = asset;
            }
        }
    }
}

// MARK: ActivityIndicator overlay

class ActivityIndicator: UIView
{
    let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.WhiteLarge)
    let label = UILabel()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        
        addSubview(activityIndicator)
        addSubview(label)
        
        backgroundColor = UIColor(white: 0.15, alpha: 0.85)
        label.textColor = UIColor.whiteColor()
        label.textAlignment = NSTextAlignment.Center
        
        label.text = "Loading..."
        
        stopAnimating()
    }

    override func layoutSubviews()
    {
        activityIndicator.frame = CGRect(origin: CGPointZero, size: frame.size)
        
        label.frame = CGRect(x: 0,
            y: label.intrinsicContentSize().height,
            width: frame.width,
            height: label.intrinsicContentSize().height)
    }
    
    func updateProgress(value: Double)
    {
        PhotoBrowser.executeInMainQueue
        {
            self.label.text = "Loading \(Int(value * 100))%"
        }
    }
    
    func startAnimating()
    {
        activityIndicator.startAnimating()
        
        NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "show", userInfo: nil, repeats: false)
    }
    
    func show()
    {
        PhotoBrowser.executeInMainQueue
        {
            self.label.text = "Loading..."
            self.hidden = false
        }
    }
    
    func stopAnimating()
    {
        hidden = true
        activityIndicator.stopAnimating()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
}

struct PhotoBrowserConstants
{
    static let thumbnailSize = CGSize(width: 100, height: 100)
    static let animationDuration = 0.175
}
