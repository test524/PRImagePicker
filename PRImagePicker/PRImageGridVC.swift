//
//  PRImageGridVC.swift
//  PRImagePicker
//
//  Created by Pavan Kumar Reddy on 30/12/17.
//  Copyright © 2017 Pavan. All rights reserved.
//

import UIKit
import Photos

private let reuseIdentifier = "CellImage"

private extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath] {
        let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect)!
        return allLayoutAttributes.map { $0.indexPath }
    }
}

class PRImageGridVC: UICollectionViewController
{
    
    var fetchResult: PHFetchResult<PHAsset>!
    var assetCollection: PHAssetCollection!

    fileprivate let imageManager = PHCachingImageManager()
    fileprivate var thumbnailSize: CGSize!
    fileprivate var previousPreheatRect = CGRect.zero
    var delegate:PRAlbumListVCDelegate?
    var albumListVC:PRAlbumListVC!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView?.backgroundColor = .white
        resetCachedAssets()
        
        PHPhotoLibrary.shared().register(self)
        
        collectionView?.register(ImageCell.self, forCellWithReuseIdentifier: reuseIdentifier)
        collectionView?.isPrefetchingEnabled  = true
        print(fetchResult.count)
        
        //Done RightBarButton
        let done =  UIBarButtonItem.init(barButtonSystemItem: .done, target: albumListVC, action: #selector(btnDoneAction))
        self.navigationItem.setRightBarButtonItems([done], animated: true)
        
    }
    
    deinit
    {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //Toolbar
        self.makeToolBar()
        
        // Determine the size of the thumbnails to request from the PHCachingImageManager
        //let scale = UIScreen.main.scale
        let cellSize = (collectionViewLayout as! UICollectionViewFlowLayout).itemSize
        thumbnailSize = CGSize(width: cellSize.width, height: cellSize.height)
        
       
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        updateCachedAssets()
    }
    

    // MARK: UICollectionView
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let asset = fetchResult.object(at: indexPath.item)
        
        // Dequeue a GridViewCell.
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier:reuseIdentifier, for: indexPath) as? ImageCell
            else { fatalError("unexpected cell in collection view") }
        
        if asset.mediaType == .video
        {
             cell.videoBtn.isHidden = false
        }
        else
        {
             cell.videoBtn.isHidden = true
        }
        
        //Image selection
        cell.selectedImageView.alpha = KFilePHAssetSelectionArray.contains(asset) == true ? 0.5 : 0
        //
        
        // Request an image for the asset from the PHCachingImageManager.
        cell.representedAssetIdentifier = asset.localIdentifier
        imageManager.requestImage(for: asset, targetSize: thumbnailSize, contentMode: .aspectFill, options: nil, resultHandler: { image, _ in
            // The cell may have been recycled by the time this handler gets called;
            // set the cell's thumbnail image only if it's still showing the same asset.
            if cell.representedAssetIdentifier == asset.localIdentifier {
                cell.thumbnailImage = image
            }
        })
        
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if let cell  = self.collectionView?.cellForItem(at: indexPath) as? ImageCell
        {
            if albumListVC.fileSeletionType == .single
            {
                cell.selectedImageView.alpha = 0
                let asset = fetchResult.object(at: indexPath.item)
                if !KFilePHAssetSelectionArray.contains(asset)
                {
                    KFilePHAssetSelectionArray.append(asset)
                }
                albumListVC.btnDoneAction()
            }
            else
            {
                multipleSelection(indexPath:indexPath  ,cell:cell)
            }
        }
    }
    
    func multipleSelection(indexPath:IndexPath , cell:ImageCell)
    {
        if albumListVC.maxFileSelection == KFilePHAssetSelectionArray.count
        {
            cell.selectedImageView.alpha = 0
            let asset = fetchResult.object(at: indexPath.item)
            if KFilePHAssetSelectionArray.contains(asset)
            {
                if let indexitem = KFilePHAssetSelectionArray.index(of: asset)
                {
                    KFilePHAssetSelectionArray.remove(at: indexitem)
                }
            }
        }
        else
        {
            //Cell selection and deselection color
            cell.selectedImageView.alpha = cell.selectedImageView.alpha == 0 ? 0.5 : 0
            //
            
            //Adding and removing Assets in Global array
            let asset = fetchResult.object(at: indexPath.item)
            if KFilePHAssetSelectionArray.contains(asset)
            {
                if let indexitem = KFilePHAssetSelectionArray.index(of: asset)
                {
                    KFilePHAssetSelectionArray.remove(at: indexitem)
                }
            }
            else
            {
                if albumListVC.maxFileSelection != KFilePHAssetSelectionArray.count
                {
                    KFilePHAssetSelectionArray.append(asset)
                }
            }
            
            //ToolBar
            self.makeToolBar()
        }
    }
    
    /*override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        
        //Single Selection
        if let cell  = self.collectionView?.cellForItem(at: indexPath) as? ImageCell
        {
            cell.selectedImageView.alpha = 0
        }
    }*/
    
    // MARK: UIScrollView
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    // MARK: Asset Caching
    fileprivate func resetCachedAssets() {
        imageManager.stopCachingImagesForAllAssets()
        previousPreheatRect = .zero
    }
    
    //MARK:- Done button
    @objc func btnDoneAction()
    {
        //let images = self.selectFiles()
        //self.delegate?.selectFiles(images: images, videoUrls: nil)
        //self.navigationController?.dismiss(animated: true, completion: nil)
    }

    fileprivate func updateCachedAssets() {
        // Update only if the view is visible.
        guard isViewLoaded && view.window != nil else { return }
        
        // The preheat window is twice the height of the visible rect.
        let visibleRect = CGRect(origin: collectionView!.contentOffset, size: collectionView!.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        
        // Update only if the visible area is significantly different from the last preheated area.
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        
        // Compute the assets to start caching and to stop caching.
        let (addedRects, removedRects) = differencesBetweenRects(previousPreheatRect, preheatRect)
        let addedAssets = addedRects
            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
            .map { indexPath in fetchResult.object(at: indexPath.item) }
        let removedAssets = removedRects
            .flatMap { rect in collectionView!.indexPathsForElements(in: rect) }
            .map { indexPath in fetchResult.object(at: indexPath.item) }
        
        // Update the assets the PHCachingImageManager is caching.
        imageManager.startCachingImages(for: addedAssets,
                                        targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        imageManager.stopCachingImages(for: removedAssets,
                                       targetSize: thumbnailSize, contentMode: .aspectFill, options: nil)
        
        // Store the preheat rect to compare against in the future.
        previousPreheatRect = preheatRect
    }
    
    fileprivate func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: [CGRect], removed: [CGRect]) {
        if old.intersects(new) {
            var added = [CGRect]()
            if new.maxY > old.maxY {
                added += [CGRect(x: new.origin.x, y: old.maxY,
                                 width: new.width, height: new.maxY - old.maxY)]
            }
            if old.minY > new.minY {
                added += [CGRect(x: new.origin.x, y: new.minY,
                                 width: new.width, height: old.minY - new.minY)]
            }
            var removed = [CGRect]()
            if new.maxY < old.maxY {
                removed += [CGRect(x: new.origin.x, y: new.maxY,
                                   width: new.width, height: old.maxY - new.maxY)]
            }
            if old.minY < new.minY {
                removed += [CGRect(x: new.origin.x, y: old.minY,
                                   width: new.width, height: new.minY - old.minY)]
            }
            return (added, removed)
        } else {
            return ([new], [old])
        }
    }
    
}

// MARK: PHPhotoLibraryChangeObserver
extension PRImageGridVC: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
        guard let changes = changeInstance.changeDetails(for: fetchResult)
            else { return }
        
        // Change notifications may be made on a background queue. Re-dispatch to the
        // main queue before acting on the change as we'll be updating the UI.
        DispatchQueue.main.sync {
            // Hang on to the new fetch result.
            fetchResult = changes.fetchResultAfterChanges
            if changes.hasIncrementalChanges {
                // If we have incremental diffs, animate them in the collection view.
                guard let collectionView = self.collectionView else { fatalError() }
                collectionView.performBatchUpdates({
                    // For indexes to make sense, updates must be in this order:
                    // delete, insert, reload, move
                    if let removed = changes.removedIndexes, removed.count > 0 {
                        collectionView.deleteItems(at: removed.map({ IndexPath(item: $0, section: 0) }))
                    }
                    if let inserted = changes.insertedIndexes, inserted.count > 0 {
                        collectionView.insertItems(at: inserted.map({ IndexPath(item: $0, section: 0) }))
                    }
                    if let changed = changes.changedIndexes, changed.count > 0 {
                        collectionView.reloadItems(at: changed.map({ IndexPath(item: $0, section: 0) }))
                    }
                    changes.enumerateMoves { fromIndex, toIndex in
                        collectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                                to: IndexPath(item: toIndex, section: 0))
                    }
                })
            } else {
                // Reload the collection view if incremental diffs are not available.
                collectionView!.reloadData()
            }
            resetCachedAssets()
        }
    }
}



