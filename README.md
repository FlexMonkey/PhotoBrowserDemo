# PhotoBrowserDemo
A Swift image browser/picker for use with PHImageManager

Original blog post: http://flexmonkey.blogspot.co.uk/2015/01/creating-phimagemanager-browserpicker.html

*This project has now been updated to work under Swift 2.0 / Xcode 7 and can target both iPads and iPhones*


One of the side effects of using PHImageManager for asset management in Nodality is that I can no longer use UIImagePickerController to allow my users to select their images. Therefore, I’ve spent some time creating an image browser/picker to work with PHImageManager which, as a stand alone component, I thought I’d share (GitHub repo is here).

My browser appears as a modal dialog in the centre of a given UIView with a segmented control displaying different albums and a set of thumbnails of the images contained within the selected album. Not only can the user select an image, they can also toggle whether that image is a favourite.

The syntax to launch the browser couldn’t be simpler (in my demonstration harness, launchPhotoBrowser() is invoked by a button press):

    func launchPhotoBrowser()
    {
        let photoBrowserViewController = PhotoBrowserViewController()
        
        photoBrowserViewController.delegate = self
        
        photoBrowserViewController.launch()
    }

…and, as long as the delegate is defined, the selected image can be accessed via a PhotoBrowserDelegate function:

    func photoBrowser(didSelectImage: UIImage)
    {
        imageView.image = didSelectImage
    }

Inside PhotoBrowserViewController, the first thing I do is ensure this app is authorised to access the photo library. This is done inside viewDidLoad(). If we do have authorisation, I can go ahead and create the user interface, if not, I need to request authorisation:

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

The requestAuthorization() method has a handler: if I get authorisation after the request, I can create the user interface, if not I dismiss the browser:

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

There’s a little gotcha here: the handler may not be invoked in the main queue and, therefore, any user interface changes won’t have an immediate effect. That’s why I’ve wrapped both of the above bits of code in a little helper function that ensures they do get executed in the main queue:

    func executeInMainQueue(function: () -> Void)
    {
        dispatch_async(dispatch_get_main_queue(), function)
    }

Now I’m ready to actually build the user interface. The segmented control is driven by a query on PHAssetCollection, I want a segment for each “Smart Album” that contains image assets (but I make an exception for “Favourites” which appears even if it’s empty).

Inside createUserInterface(), The first step is to get the asset collections:

        assetCollections = PHAssetCollection.fetchAssetCollectionsWithType(PHAssetCollectionType.SmartAlbum, subtype: PHAssetCollectionSubtype.AlbumRegular, options: nil)

…then I loop over each, and fetch a count of all the image assets within it and add it to an array of strings which will be used to populate the segmented control. At the same time, I also build an array of CGPoints, one for each segmented control item, which I’ll use later on:

        for var i = 0 ; i < assetCollections.count ; i++
        {
            let assetCollection = assetCollections[i] as? PHAssetCollection
            
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "mediaType = %i", PHAssetMediaType.Image.rawValue)
            
            let assetsInCollection  = PHAsset.fetchAssetsInAssetCollection(assetCollection, options: fetchOptions)
            
            if assetsInCollection.count > 0 || assetCollection?.localizedTitle == "Favorites"
            {
                if let localizedTitle = assetCollection?.localizedTitle
                {
                    segmentedControlItems.append(localizedTitle)
                    
                    contentOffsets.append(CGPoint(x: 0, y: 0))
                }
            }
        }

The rest of createUserInterface() is pretty basic stuff: I sort the segmented control items into alphabetical order, set the layout for the main UICollectionView, add the components to the view and assign a long press gesture recogniser to the UICollectionView.

When the user changes the selected item in the segmented control, let’s say they switch from “moments” to “favourites”, segmentedControlChangeHandler() is invoked. Here I store the collection view’s scroll position or contentOffset and fetch all the image assets for the selected collection. This is done by finding which collection in assetCollections has a localisedTitle that matches the selected segmented control item:

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

The assets property of PhotoBrowserViewController has a didSet observer which fires when I set the assets above. There are three cases that I handle here: 

If a single item has been removed (typically a favourite has been un-favourited), I remove it with deleteItemsAtIndexPaths
If the count of the assets has changed, I fade out the collection view, reload its data, scroll to its previous position and fade it back in again
If no items have been removed (e.g. a favourite status has been changed), I simple reload the collection view’s data

The guts of that didSet observer look like this:

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


…and for the second case, the fadeOutComplete() method looks like this:

    func fadeOutComplete(value: Bool)
    {
        collectionViewWidget.reloadData()
        collectionViewWidget.contentOffset = contentOffsets[segmentedControl.selectedSegmentIndex]
        UIView.animateWithDuration(PhotoBrowserConstants.animationDuration, animations: { self.collectionViewWidget.alpha = 1.0 })
    }

This fade out / fade in approach means that the repopulation of the grid and resetting of the scroll position happen when the control view is hidden and avoids a sudden jump in the user interface.

When the user performs a long press on a cell, I want to pop up a little context menu allowing them to toggle the favourite status of that asset. This is done in longPressHandler(), but before that’s invoked, I make a note of the highlighted cell and assign it to longPressTarget:

    func collectionView(collectionView: UICollectionView, didHighlightItemAtIndexPath indexPath: NSIndexPath)
    {
        longPressTarget = (cell: self.collectionView(collectionViewWidget, cellForItemAtIndexPath: indexPath), indexPath: indexPath)
    }

…now back inside longPressHandler(), I check the gesture is in the correct state and make a reference to the asset associated with longPressTarget:

 let entity = assets[_longPressTarget.indexPath.row] as? PHAsset

Adding a UIAlertController is stuff I’ve covered in the past, the end result is that when the user performs that long press, toggleFavourite() is invoked. Here I use PHPhotoLibrary’s performChange() method to toggle the favourite value of the selected asset:

    func toggleFavourite(value: UIAlertAction!) -> Void
    {
        if let _longPressTarget = longPressTarget
        {
            let targetEntity = assets[_longPressTarget.indexPath.row] as? PHAsset
            
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                let changeRequest = PHAssetChangeRequest(forAsset: targetEntity)
                changeRequest.favorite = !targetEntity!.favorite
                }, completionHandler: nil)
        }
    }

Because in viewDidLoad() I registered the view controller as a change observer on the photo library:

 PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)

…when that favourite-toggle change occurs, photoLibraryDidChange()  is invoked:

    func photoLibraryDidChange(changeInstance: PHChange!)
    {
        if uiCreated
        {
            let changeDetails = changeInstance.changeDetailsForFetchResult(assets)
            
            executeInMainQueue({ self.assets = changeDetails.fetchResultAfterChanges })
        }
    }

…and my assets property is repopulated which causes a refresh of the collection view and, if the user is viewing the favourites album, any unfavorites are nicely removed from the view.

Finally, when the user makes a selection I want to request a high quality, full sized version of the asset and hand it to the delegate. The first part of this happens in the collectionView method for didSelectItAtIndexPath:

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

…with the imageRequestResultHandler wrapping up the process:

   func imageRequestResultHandler(image: UIImage!, properties: [NSObject: AnyObject]!) -> Void
    {
        if let _delegate = delegate
        {
            _delegate.photoBrowser(image)
        }
        
        dismissViewControllerAnimated(true, completion: nil)
    }

I’ve also registered my item renderer, ImageItemRenderer, as a change observer on PHPhotoLibrary. This allows it to add a little star icon to favourites and dynamically update if that status changes:

    func photoLibraryDidChange(changeInstance: PHChange!)
    {
        dispatch_async(dispatch_get_main_queue(), { self.setLabel() })
    }

 […]

    func setLabel()
    {
        if let _asset = asset
        {
            label.text = (_asset.favorite ? "★ " : "") + NSDateFormatter.localizedStringFromDate(_asset.creationDate, dateStyle: NSDateFormatterStyle.MediumStyle, timeStyle: NSDateFormatterStyle.NoStyle)
        }
    }

And there we have it - a nice little image browser and picker for use with PHImageManager which includes the ability to favourite images and persists its scroll position between albums.


All the source code for this project is available in my GitHub repository here. 

One little caveat - this works fine on iPad but fails when targeting iPhone. I'll take a look at this over the weekend.
