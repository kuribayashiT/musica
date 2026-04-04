//
//  YoutubeHtmlPlayerViewController.swift
//  musica
//
//  Created by 栗林貴大 on 2021/05/05.
//  Copyright © 2021 K.T. All rights reserved.
//

import UIKit

class YoutubeHtmlPlayerViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(
            frame: CGRect(x: 0, y: 0, width: 640, height: 360),
            configuration: config
        )
        guard let path: String = Bundle.main.path(forResource: "index", ofType: "html") else {
            return
        }

        let localHTMLUrl = URL(fileURLWithPath: path, isDirectory: false)
        webView.loadFileURL(localHTMLUrl, allowingReadAccessTo: localHTMLUrl)
        
        view.addSubview(webView)
    }
}
