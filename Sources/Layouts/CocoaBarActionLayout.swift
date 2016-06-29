//
//  CocoaBarActionLayout.swift
//  CocoaBar Example
//
//  Created by Merrick Sapsford on 07/06/2016.
//  Copyright © 2016 Merrick Sapsford. All rights reserved.
//

import UIKit

public class CocoaBarActionLayout: CocoaBarLayout {
    
    @IBOutlet weak var titleLabel: UILabel?
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView?
    
    // MARK: Lifecycle
    
    override public func updateLayoutForBackgroundStyle(_ newStyle: BackgroundStyle, backgroundView: UIView?) {
        switch newStyle {
        case .blurDark:
            self.titleLabel?.textColor = UIColor.white()
            self.actionButton?.setTitleColor(UIColor.lightText(), for: UIControlState())
            self.activityIndicator?.color = UIColor.white()
        default:
            self.titleLabel?.textColor = UIColor.black()
            self.actionButton?.setTitleColor(self.tintColor, for: UIControlState())
            self.activityIndicator?.color = UIColor.darkGray()
        }
    }
    
    public override func prepareLayoutForShowing() {
        super.prepareLayoutForShowing()
        
        self.stopLoading() // stop loading
    }

    // MARK: Public
    
    /**
     Display an activity indicator in place of the action button.
     */
    public func startLoading() {
        self.activityIndicator?.startAnimating()
        self.activityIndicator?.isHidden = false
        self.actionButton?.isHidden = true
    }
    
    /**
     Hide the activity indicator.
     */
    public func stopLoading() {
        self.activityIndicator?.stopAnimating()
        self.activityIndicator?.isHidden = true
        self.actionButton?.isHidden = false
    }
}
