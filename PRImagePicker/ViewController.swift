//
//  ViewController.swift
//  PRImagePicker
//
//  Created by Pavan Kumar Reddy on 30/12/17.
//  Copyright © 2017 Pavan. All rights reserved.
//

import UIKit

class ViewController: UIViewController , PRAlbumListVCDelegate
{
    func selectedFiles(mediaFiles:[Files])
    {
        print(mediaFiles)
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.view.backgroundColor = .white
    }

    //MARK:- Custom image picker
    @IBAction func btnActionForSelectFiles(_ sender: UIButton)
    {
        let albumListVC = PRAlbumListVC()
        let navVC = UINavigationController.init(rootViewController: albumListVC)
        albumListVC.delegate = self
        albumListVC.maxFileSelection = 4
        albumListVC.fileType = .image
        albumListVC.fileSeletionType = .multiple
        //albumListVC.maxFileSelectionMessage = "Test"
        self.present(navVC, animated: true, completion: nil)
    }
    
}


