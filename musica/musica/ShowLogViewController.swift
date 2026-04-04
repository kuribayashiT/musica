//
//  ShowLogViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2019/04/17.
//  Copyright © 2019 K.T. All rights reserved.
//

import UIKit

class ShowLogViewController: UIViewController {

    @IBOutlet weak var logView: UITextView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 動画は一旦止める
        if AVPlayerViewControllerManager.shared.controller.player != nil {
            AVPlayerViewControllerManager.shared.controller.player?.pause()
        }
        selectMusicView.isHidden = true
        logView.text = LOG_TEXT
    }
    @IBAction func clearLogBtnTapped(_ sender: Any) {
        logView.text = ""
        LOG_TEXT = ""
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
