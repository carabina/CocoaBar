//
//  CocoaBarDefaultLayout.swift
//  CocoaBar Example
//
//  Created by Merrick Sapsford on 07/06/2016.
//  Copyright © 2016 Merrick Sapsford. All rights reserved.
//

import UIKit

class CocoaBarDefaultLayout: CocoaBarLayout {
    
    @IBOutlet weak var titleLabel: UILabel?

    override func updateLayoutForBackgroundStyle(_ newStyle: BackgroundStyle, backgroundView: UIView?) {
        switch newStyle {
        case .blurDark:
            self.titleLabel?.textColor = UIColor.white()
            self.dismissButton?.setTitleColor(UIColor.lightText(), for: UIControlState())
        default:
            self.titleLabel?.textColor = UIColor.black()
            self.dismissButton?.setTitleColor(self.tintColor, for: UIControlState())
        }
    }
}
