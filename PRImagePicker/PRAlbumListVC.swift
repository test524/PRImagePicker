//
//  PRAlbumListVC.swift
//  PRImagePicker
//
//  Created by Pavan Kumar Reddy on 30/12/17.
//  Copyright © 2017 Pavan. All rights reserved.
//
//print(UIDevice.current.localizedModel)
//print(UIDevice.current.name)
//print(UIDevice.current.systemName)
//print(UIDevice.current.systemVersion)
//print(UIDevice.current.model)

import UIKit
import Photos

enum Section: Int
{
    case allPhotos = 0
    case smartAlbums
    case userCollections
    static let count = 3
}

enum mediaTypes:String
{
    case image
    case video
    case imageAndVideo
}

enum selectionType:String
{
    case single
    case multiple
}

enum CellIdentifier: String {
    case allPhotos, collection
}

let KImageSelectionColor = UIColor.init(red: 28/255, green: 123/255, blue: 252/255, alpha: 1.0)
var KFilePHAssetSelectionArray  =  [PHAsset]()
var KFiles = [Files]()

protocol PRAlbumListVCDelegate
{
    func selectedFiles(mediaFiles:[Files])
}

//MARK:- PRAlbumListVC 
class PRAlbumListVC: UITableViewController
{
    static let screenSize = UIScreen.main.bounds.size
    static let isiPad =  UIDevice.current.model == "iPhone" ? false : true
    private lazy var imageManager = PHCachingImageManager()
    private var allPhotos: PHFetchResult<PHAsset>!
    private var smartAlbums:PHFetchResult<PHAssetCollection>!
    private var userCollections: PHFetchResult<PHCollection>!
    var maxFileSelection:Int = 1
    var fileType:mediaTypes = .imageAndVideo
    var fileSeletionType:selectionType = .single
    var delegate:PRAlbumListVCDelegate?
    var smartAlbumsStrings:[PHAssetCollectionSubtype]!
    var maxFileSelectionMessage = "Max file seletion reached."
    
    let sectionLocalizedTitles = ["",NSLocalizedString("Smart Albums", comment: ""), NSLocalizedString("Albums", comment: "")]

    override func viewDidLoad()
    {
        super.viewDidLoad()

        if fileType == mediaTypes.image
        {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }
        else if fileType == mediaTypes.video
        {
            fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        }
        
        tableView.register(AlbumCell.self, forCellReuseIdentifier: CellIdentifier.allPhotos.rawValue)
        tableView.register(AlbumCell.self, forCellReuseIdentifier: CellIdentifier.collection.rawValue)
        
        self.view.backgroundColor = .white
        self.navigationItem.title = "Albums"
        
        let barButtonCancel = UIBarButtonItem.init(barButtonSystemItem: .cancel, target: self, action: #selector(dismissVC))
        self.navigationItem.leftBarButtonItem = barButtonCancel
        
        let barButtonDone = UIBarButtonItem.init(barButtonSystemItem: .done, target: self, action: #selector(btnDoneAction))
        self.navigationItem.rightBarButtonItem = barButtonDone
        
        tableView.separatorStyle = .none
        fetchAllAlbumsCount()
        requestAlbumFileAccess()

    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(true)
        self.makeToolBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
    }
    
    func openSettings()
    {
        let cameraUnavailableAlertController = UIAlertController (title: "Photo Library Unavailable", message: "Please check to see if device settings doesn't allow photo library access", preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: "Settings", style: .destructive) { (_) -> Void in
            let settingsUrl = NSURL(string:UIApplicationOpenSettingsURLString)
            if let url = settingsUrl
            {
                //UIApplication.shared.openURL(url as URL)
                if #available(iOS 10.0, *) {
                    UIApplication.shared.open(url as URL, options: [:], completionHandler: { (succcess) in
                    })
                } else {
                    // Fallback on earlier versions
                }
            }
        }
        
        let cancelAction = UIAlertAction.init(title: "Cancel", style: .default) { (action) in
            self.navigationController?.dismiss(animated: true, completion: nil)
        }
        
        cameraUnavailableAlertController .addAction(settingsAction)
        cameraUnavailableAlertController .addAction(cancelAction)
        self.present(cameraUnavailableAlertController , animated: true, completion: nil)
        
    }
    func requestAlbumFileAccess()
    {
        PHPhotoLibrary.requestAuthorization({ (authStatus) in
           
                switch authStatus {
                case .authorized:
                    
                DispatchQueue.main.async {
                    self.fetchAllAlbumsCount()
                    self.tableView.reloadData()
                }
                    
                    break
                case .denied:
                    self.openSettings()
                    break
                case .notDetermined:
                    self.requestAlbumFileAccess()
                    break
                case .restricted:
                    self.openSettings()
                    break
                }
        })
    }
    
    //MARK: Smart albums
    func fetchAllAlbumsCount()
    {
        
        smartAlbumsStrings = [PHAssetCollectionSubtype.smartAlbumFavorites,
                              PHAssetCollectionSubtype.smartAlbumRecentlyAdded,
                              PHAssetCollectionSubtype.smartAlbumPanoramas,
                              PHAssetCollectionSubtype.smartAlbumSelfPortraits,
                              PHAssetCollectionSubtype.smartAlbumScreenshots,
                              PHAssetCollectionSubtype.smartAlbumVideos]
        
        allPhotos = PHAsset.fetchAssets(with: fetchOptions)
        
        let folderNames = self.getFolderIdentifiers(subTypes: smartAlbumsStrings)
        
        smartAlbums = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: folderNames, options: nil)
        userCollections = PHCollectionList.fetchTopLevelUserCollections(with: nil)
        PHPhotoLibrary.shared().register(self)
    }
    
    //MARK: FolderIdentifiers for album types
    func getFolderIdentifiers(subTypes:[PHAssetCollectionSubtype]) -> [String]
    {
        var folderNames = [String]()
        for case let type in subTypes
        {
            let allAlbums:PHFetchResult<PHAssetCollection> = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: type, options: nil)
            
            allAlbums.enumerateObjects { (collection, idx, bool) in
                folderNames.append(collection.localIdentifier)
            }
        }
        return folderNames
    }
    
    //MARK: Nav bar actions
    @objc func dismissVC()
    {
        KFilePHAssetSelectionArray.removeAll()
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func btnDoneAction()
    {
        self.selectFiles { (bool) in
            self.navigationController?.dismiss(animated: true, completion: nil)
            self.delegate?.selectedFiles(mediaFiles: KFiles)
            KFiles.removeAll()
            KFilePHAssetSelectionArray.removeAll()
        }
    }
    
    //MARK: Final image selection
    func selectFiles(completion: @escaping (Bool) -> Void)
    {
        var images = [UIImage]()
        let manager = PHCachingImageManager.default()
        
        for (key , asset) in KFilePHAssetSelectionArray.enumerated()
        {
            let requestImageOption = PHImageRequestOptions()
            requestImageOption.deliveryMode = PHImageRequestOptionsDeliveryMode.highQualityFormat
            requestImageOption.isSynchronous = true
            
            //Image and Video thumbnail
            if asset.mediaType == .image
            {
                manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode:PHImageContentMode.default, options: requestImageOption) { (image:UIImage?, _) in
                    
                    if let img = image
                    {
                        images.append(img)
                        let fileObj = Files.init(image: img, videoThumbNailImage: nil, videoURl: nil)
                        KFiles.append(fileObj)
                        if key == KFilePHAssetSelectionArray.count - 1
                        {
                            completion(true)
                        }
                    }
                }
            }
            else
            {
                
                manager.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode:PHImageContentMode.default, options: requestImageOption) { (image:UIImage?, _) in
                    
                    if let img = image
                    {
                        manager.requestAVAsset(forVideo: asset, options: nil, resultHandler: { (assetobj: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) in
                            
                            guard  let urlAsset = assetobj as? AVURLAsset else
                            {
                                return
                            }
                            
                            let localVideoUrl:URL = urlAsset.url
                            let fileObj = Files.init(image: nil, videoThumbNailImage: img, videoURl: localVideoUrl)
                            KFiles.append(fileObj)
                            if key == KFilePHAssetSelectionArray.count - 1
                            {
                                completion(true)
                            }
                        })
                    }
                }
                //
                
            }
            
        }
    }
    
    deinit
    {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }
    
    let flowLayout:UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        let noOfCells = isiPad ? 5 : 4
        let cellWidth =  ((screenSize.width-(CGFloat(noOfCells-1)))/CGFloat(noOfCells))
        let cellHeight =  screenSize.width/CGFloat(noOfCells)
        layout.itemSize = CGSize.init(width: cellWidth, height: cellHeight)
        layout.minimumLineSpacing = 1
        layout.minimumInteritemSpacing = 1
        return layout
    }()
    
    let flowLayoutForPanoramas:UICollectionViewFlowLayout = {
        let layout = UICollectionViewFlowLayout()
        let noOfCells = 1
        let cellWidth = screenSize.width
        let cellHeight = screenSize.height/8
        layout.itemSize = CGSize.init(width: cellWidth, height: cellHeight)
        layout.minimumLineSpacing = 5
        layout.minimumInteritemSpacing = 0
        return layout
    }()
    
    let fetchOptions:PHFetchOptions = {
        let allPhotosOptions = PHFetchOptions()
        //allPhotosOptions.includeAssetSourceTypes = .typeUserLibrary
        allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return allPhotosOptions
     }()
    
    let paragraphStyle:NSMutableParagraphStyle = {
        let style = NSMutableParagraphStyle()
        return style
    }()
    
}


extension UIViewController
{
    //Toobar display
    func makeToolBar()
    {
        if KFilePHAssetSelectionArray.count == 0
        {
            self.navigationController?.setToolbarHidden(true, animated: true)
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }
        else
        {
            self.navigationController?.setToolbarHidden(false, animated: true)
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
        
        if let items = self.toolbarItems
        {
            if  items.count  == 3
            {
                 let barButton = items[1]
                 barButton.title = "\(KFilePHAssetSelectionArray.count) File(s) selected"
            }
        }
        else
        {
            let barButton = UIBarButtonItem.init(title:"\(KFilePHAssetSelectionArray.count) File(s) selected", style: .done, target: self, action: nil)
            let leftSpace = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
            let rightSpace = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
            self.setToolbarItems([leftSpace,barButton,rightSpace], animated: true)
        }
        
    }
}

// MARK: UITableView
extension PRAlbumListVC
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        //if authStatus == .authorized
        //{
            return Section.count
        //}
        //return 0
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        switch Section(rawValue: section)!
        {
        case .allPhotos: return 1
        case .smartAlbums:
            guard let array = smartAlbums else{return 0}
            return array.count
        case .userCollections:
            guard let array = userCollections else{return 0}
            return array.count
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        return 110
    }
    
    func addThubNailImage(cell:AlbumCell , asset:PHAsset)
    {
        let scale = UIScreen.main.scale
        if  asset.mediaType == .video
        {
            cell.videoBtn.isHidden = false
        }
        else
        {
           cell.videoBtn.isHidden = true
        }
        
        imageManager.requestImage(for: asset, targetSize: CGSize.init(width: 80*scale, height: 80*scale), contentMode: .aspectFill, options: nil, resultHandler: { (image, _) in
            
            guard let img = image else
            {return}
            
            
            cell.thumbnailImage = img
        })
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let collection: PHCollection
        let cell = tableView.dequeueReusableCell(withIdentifier: CellIdentifier.allPhotos.rawValue, for: indexPath) as! AlbumCell
        paragraphStyle.paragraphSpacing = cell.albumName.font.lineHeight * 0.40
        switch Section(rawValue: indexPath.section)! {
            
        case .allPhotos:
            
            let titleText = NSMutableAttributedString.init(string: "All Images\n\(allPhotos.count)", attributes: [NSAttributedStringKey.paragraphStyle:paragraphStyle])
            cell.albumName.attributedText = titleText
            
            if allPhotos.count != 0
            {
                let asset = allPhotos[0]
                self.addThubNailImage(cell:cell , asset:asset)
            }
            
            return cell
            
        case .smartAlbums:
            
            
            collection = smartAlbums.object(at: indexPath.row)
            
            guard let assetCollection = collection as? PHAssetCollection
                else { fatalError("expected asset collection") }
            
            let assests = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
            
            let titleText = NSMutableAttributedString.init(string: "\(collection.localizedTitle!)\n\(assests.count)", attributes: [NSAttributedStringKey.paragraphStyle:paragraphStyle])

            cell.albumName.attributedText = titleText

            if assests.count != 0
            {
                let asset = assests[0]
                self.addThubNailImage(cell:cell , asset:asset)
            }
            
            return cell
            
        case .userCollections:
            
            let collection = userCollections.object(at: indexPath.row)
            guard let assetCollection = collection as? PHAssetCollection
                else { fatalError("expected asset collection") }
            let assests = PHAsset.fetchAssets(in: assetCollection, options: nil)
            if assests.count != 0
            {
                let asset = assests[0]
                self.addThubNailImage(cell:cell , asset:asset)
            }
            let titleText = NSMutableAttributedString.init(string: "\(collection.localizedTitle!)\n\(assests.count)", attributes: [NSAttributedStringKey.paragraphStyle:paragraphStyle])
            cell.albumName.attributedText = titleText
            return cell
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        if section == 0
        {return nil}
        return sectionLocalizedTitles[section]
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        
        if section == 0
        {return CGFloat.leastNormalMagnitude}
        return 50
    }
   
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        var  destination = PRImageGridVC.init(collectionViewLayout: flowLayout)
        

        switch Section(rawValue: indexPath.section)!
        {
        case .allPhotos:
            
            destination.fetchResult = allPhotos
            
        case .smartAlbums ,.userCollections:
            
            let collection: PHCollection

            switch Section(rawValue: indexPath.section)!
            {
            case .smartAlbums:
                collection = smartAlbums.object(at: indexPath.row)
                if let smartAlbumTitle = collection.localizedTitle
                {
                    if smartAlbumTitle == "Panoramas"
                    {
                        print(collection.localizedTitle!)
                        destination = PRImageGridVC.init(collectionViewLayout: flowLayoutForPanoramas)
                    }
                }
            case .userCollections:
                collection = userCollections.object(at: indexPath.row)
            default: return
            }
            
            guard let assetCollection = collection as? PHAssetCollection
                else { fatalError("expected asset collection") }
            
            destination.fetchResult = PHAsset.fetchAssets(in: assetCollection, options: fetchOptions)
            destination.assetCollection = assetCollection
            break
        }
        
         destination.albumListVC = self
         self.navigationController?.pushViewController(destination, animated: true)
    }
}

// MARK: PHPhotoLibraryChangeObserver
extension PRAlbumListVC: PHPhotoLibraryChangeObserver {
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        // Change notifications may be made on a background queue. Re-dispatch to the
        // main queue before acting on the change as we'll be updating the UI.
        DispatchQueue.main.sync {
            // Check each of the three top-level fetches for changes.
            
            if let changeDetails = changeInstance.changeDetails(for: allPhotos) {
                // Update the cached fetch result.
                allPhotos = changeDetails.fetchResultAfterChanges
                // (The table row for this one doesn't need updating, it always says "All Photos".)
            }
            
            // Update the cached fetch results, and reload the table sections to match.
            if let changeDetails = changeInstance.changeDetails(for: smartAlbums) {
                smartAlbums = changeDetails.fetchResultAfterChanges
                tableView.reloadSections(IndexSet(integer: Section.smartAlbums.rawValue), with: .automatic)
            }
            if let changeDetails = changeInstance.changeDetails(for: userCollections) {
                userCollections = changeDetails.fetchResultAfterChanges
                tableView.reloadSections(IndexSet(integer: Section.userCollections.rawValue), with: .automatic)
            }
            
        }
    }
}

//MARK:- Final object file structure
struct Files
{
    var  image:UIImage!
    var  videoThumbNailImage:UIImage!
    var  videoURl:URL!
}

//MARK:- AlbumCell
class AlbumCell :UITableViewCell
{
    
    var thumbnailImage: UIImage! {
        didSet {
            albumImageView.image = thumbnailImage
        }
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        contentView.addSubview(albumImageView)
        contentView.addSubview(albumName)
        albumImageView.addSubview(videoBtn)

        NSLayoutConstraint.activate([
            
            albumImageView.leftAnchor.constraint(equalTo: leftAnchor , constant:15),
            albumImageView.topAnchor.constraint(equalTo: topAnchor,constant:5),
            albumImageView.bottomAnchor.constraint(equalTo: bottomAnchor),
            albumImageView.widthAnchor.constraint(equalToConstant: 100)
            
            ])
        
        NSLayoutConstraint.activate([
            
            albumName.leftAnchor.constraint(equalTo: albumImageView.rightAnchor , constant:10),
            albumName.topAnchor.constraint(equalTo: topAnchor,constant:5),
            albumName.bottomAnchor.constraint(equalTo: bottomAnchor,constant:-5),
            albumName.rightAnchor.constraint(equalTo: rightAnchor,constant:-10),
            
            ])
        NSLayoutConstraint.activate([
            
            videoBtn.leftAnchor.constraint(equalTo: albumImageView.leftAnchor),
            videoBtn.rightAnchor.constraint(equalTo: albumImageView.rightAnchor),
            videoBtn.topAnchor.constraint(equalTo: albumImageView.topAnchor),
            videoBtn.bottomAnchor.constraint(equalTo: albumImageView.bottomAnchor)
            
            ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let albumImageView:UIImageView = {
        let imgVw = UIImageView()
        imgVw.contentMode = .scaleAspectFill
        imgVw.translatesAutoresizingMaskIntoConstraints = false
        imgVw.clipsToBounds = true
        imgVw.backgroundColor = .red
        imgVw.image = #imageLiteral(resourceName: "placeholder")
        return imgVw
    }()
    
   
    let albumName:UILabel = {
       let lbl = UILabel()
        lbl.font = UIFont.boldSystemFont(ofSize: 15)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.numberOfLines = 0
        return lbl
    }()
    
    let videoBtn:UIButton = {
        let imgVw = UIButton.init(type: .system)
        imgVw.translatesAutoresizingMaskIntoConstraints = false
        imgVw.isUserInteractionEnabled = false
        imgVw.contentMode = .scaleAspectFit
        imgVw.setImage(#imageLiteral(resourceName: "play"), for: .normal)
        imgVw.isHidden = true
        imgVw.tintColor = .white
        return imgVw
    }()
    
    override func prepareForReuse() {
        super.prepareForReuse()
        albumImageView.image = nil
        thumbnailImage = #imageLiteral(resourceName: "placeholder")
    }
}
