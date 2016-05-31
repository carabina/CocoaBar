//
//  CocoaBarErrorCondensedLayout.swift
//  CocoaBar Example
//
//  Created by Merrick Sapsford on 27/05/2016.
//  Copyright © 2016 Merrick Sapsford. All rights reserved.
//

import UIKit

class CocoaBarErrorCondensedLayout: CocoaBarLayout {

    @IBOutlet weak var titleLabel: UILabel?
    
    override func updateLayoutForBackgroundStyle(newStyle: BackgroundStyle, backgroundView: UIView?) {
        switch newStyle {
        case .BlurDark:
            self.titleLabel?.textColor = UIColor.whiteColor()
        default:
            self.titleLabel?.textColor = UIColor.blackColor()
        }
    }
    
    override func requiredHeight() -> Float {
        return 52.0
    }
}
