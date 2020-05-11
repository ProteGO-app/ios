//
//  PWAViewController.swift
//  safesafe
//
//  Created by Lukasz szyszkowski on 09/04/2020.
//  Copyright © 2020 Lukasz szyszkowski. All rights reserved.
//

import UIKit
import WebKit
import SnapKit

final class PWAViewController: ViewController<PWAViewModel> {
    
    private enum Constants {
        static let color = UIColor(red:0.18, green:0.45, blue:0.85, alpha:1.00)
    }
    
    private var webKitView: WKWebView?
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
//        navigationController?.setStatusBar(backgroundColor: Constants.color)
    }
    
    override func start() {
        viewModel.delegate = self
    }
    
    override func setup() {   }
    
    override func layout() {
        webKitView?.snp.makeConstraints({ maker in
            maker.leading.trailing.bottom.equalToSuperview()
            maker.top.equalToSuperview()
        })
    }
}

extension PWAViewController: PWAViewModelDelegate {
    func load(url: URL) {
        webKitView?.load(URLRequest(url: url))
    }
    
    func configureWebKit(controler: WKUserContentController) {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controler
        let webKitView = WKWebView(frame: .zero, configuration: configuration)
        webKitView.allowsBackForwardNavigationGestures = false
        webKitView.allowsLinkPreview = false
        if #available(iOS 11.0, *) {
            webKitView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webKitView.scrollView.bounces = false
        webKitView.navigationDelegate = self
        
        add(subview: webKitView)
        JSBridge.shared.register(webView: webKitView)
        
        self.webKitView = webKitView
    }
}

extension PWAViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if viewModel.manageNativeActions(with: navigationAction.request.url) || viewModel.openExternallyIfNeeded(url: navigationAction.request.url) {
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}