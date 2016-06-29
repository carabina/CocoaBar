//
//  CocoaBar.swift
//  CocoaBar Example
//
//  Created by Merrick Sapsford on 23/05/2016.
//  Copyright © 2016 Merrick Sapsford. All rights reserved.
//

import UIKit

private let CocoaBarHideNotification: String =  "CocoaBarHideNotification"
private let CocoaBarAnimatedKey: String =       "animated"

public typealias CocoaBarPopulationClosure = (layout: CocoaBarLayout) -> Void
public typealias CocoaBarAnimationCompletionClosure = (animated: Bool, completed: Bool, visible: Bool) -> Void

/**
 The delegate for CocoaBar updates and action responses.
 */
public protocol CocoaBarDelegate: class {
    
    /**
     The action button on the CocoaBar has been pressed.
     
     :param: cocoaBar       The CocoaBar that contains the action button.
     :param: actionButton   The action button that was pressed.
     
     */
    func cocoaBar(_ cocoaBar: CocoaBar, actionButtonPressed actionButton: UIButton?)
    /**
     The CocoaBar will show.
     
     :param: cocoaBar       The CocoaBar that will show.
     :param: animated       Whether the show transition will be animated.
     
     */
    func cocoaBar(_ cocoaBar: CocoaBar, willShowAnimated animated: Bool)
    /**
     The CocoaBar has shown.
     
     :param: cocoaBar       The CocoaBar that has shown.
     :param: animated       Whether the show transition was animated.
     
     */
    func cocoaBar(_ cocoaBar: CocoaBar, didShowAnimated animated: Bool)
    /**
     The CocoaBar will hide.
     
     :param: cocoaBar       The CocoaBar that will hide.
     :param: animated       Whether the hide transition will be animated.
     
     */
    func cocoaBar(_ cocoaBar: CocoaBar, willHideAnimated animated: Bool)
    /**
     The CocoaBar has hidden.
     
     :param: cocoaBar       The CocoaBar that has become hidden.
     :param: animated       Whether the hide transition was animated.
     
     */
    func cocoaBar(_ cocoaBar: CocoaBar, didHideAnimated animated: Bool)
}

/**
 CocoaBar is a view that appears from the bottom of a window or view, to display some
 contextually important information in an inobtrusive manner.
 */
public class CocoaBar: UIView, CocoaBarLayoutDelegate {
    
    /**
     The duration to display the CocoaBar for when shown.
     */
    public enum DisplayDuration {
        
        /**
         Display the bar for 2 seconds before auto-dismissal.
         */
        case short
        /**
         Display the bar for 4 seconds before auto-dismissal.
         */
        case long
        /**
         Display the bar for 8 seconds before auto-dismissal.
         */
        case extraLong
        /**
         Display the bar indeterminately.
         */
        case indeterminate
        
        var value: Double {
            switch self {
            case .short:
                return 2.0
            case .long:
                return 4.0
            case .extraLong:
                return 8.0
                
            default:
                return DBL_MAX
            }
        }
    }
    
    /**
     The style of the CocoaBar
     */
    public enum Style {
        
        /**
         Default style - text label with no buttons.
         */
        case `default`
        /**
         Action style - text label with right side action button.
        */
        case action
    }
    
    // MARK: Constants
    
    internal let CocoaBarWidthIpad: Float = 400.0
    
    // MARK: Variables
    
    private var displayWindow: UIWindow?
    private var displayView: UIView?

    private var bottomMarginConstraint: NSLayoutConstraint?
    private var heightConstraint: NSLayoutConstraint?
    private var widthConstraint: NSLayoutConstraint?
    private var layoutContainer: UIView?
    
    private var customLayout: CocoaBarLayout?
    private var defaultLayout: CocoaBarLayout = CocoaBarDefaultLayout()
    
    private var isAnimating: Bool = false
    
    private var displayTimer: Timer?
    
    // MARK: Properties
    
    /**
     The layout for the Cocoabar to use when displaying. The bar will use 
     CocoaBarDefaultLayout if a custom layout is not specified.
     */
    public var layout: CocoaBarLayout {
        get {
            guard let customLayout = customLayout else {
                return defaultLayout
            }
            return customLayout
        }
        set (newLayout) {
            if (customLayout != newLayout) && (newLayout != defaultLayout) {
                customLayout = newLayout
                self.updateLayout(newLayout)
            }
        }
    }
    
    /**
     Whether the CocoaBar is currently showing
     */
    public private(set) var isShowing: Bool = false
    
    /**
     Whether the CocoaBar has tap to dismiss enabled. If enabled, the CocoaBar
     will dismiss when tapped while it is showing.
     */
    public var tapToDismiss: Bool = false
    
    /**
     The object that acts as a delegate to the CocoaBar
     */
    public weak var delegate: CocoaBarDelegate?
    
    /**
     The CocoaBar that is attached to the key window.
     */
    public private(set) static var keyCocoaBar: CocoaBar?
    
    // MARK: Init
    
    /**
     Create a new instance of a CocoaBar that will display from a window. Using 
     the keyWindow will set the instance to the keyCocoaBar for access from class
     methods.
     */
    public init(window: UIWindow?) {
        
        self.displayWindow = window
        
        super.init(frame: CGRect.zero)
        
        // set key bar to the one initialised on key window
        if let window = window {
            
            // if keyCocoaBar does not exist - assume that this is key window
            if CocoaBar.keyCocoaBar == nil {
                window.becomeKey()
            }
            
            if window.isKeyWindow == true {
                CocoaBar.keyCocoaBar = self
            }
        }
        self.registerForNotifications()
    }
    
    /**
     Create a new instance of a CocoaBar that will display from a view.
     */
    public init(view: UIView?) {
        
        self.displayView = view
        
        super.init(frame: CGRect.zero)
        
        self.registerForNotifications()
    }
    
    required public init?(coder aDecoder: NSCoder) {

        super.init(coder: aDecoder)
        
        self.registerForNotifications()
    }

    deinit {
        NotificationCenter.default().removeObserver(self)
    }
    
    // MARK: Lifecycle
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        
        // hide if tap to dismiss enabled
        let point = self.convert(point, to: self)
        if self.isShowing && self.bounds.contains(point) && tapToDismiss {
            self.hideAnimated(true, completion: nil)
        }
        return hitView
    }
    
    // MARK: Private
    
    private func registerForNotifications() {
        
        let notificationCenter = NotificationCenter.default()
        notificationCenter.addObserver(self, selector: #selector(hideNotificationReceived), name: CocoaBarHideNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(windowDidBecomeVisible), name: NSNotification.Name.UIWindowDidBecomeVisible, object: nil)
    }
    
    private func setUpIfRequired() {
        if let displayWindow = self.displayWindow { // if we have a display window
            if self.superview == nil {
                
                // add bar to display window
                displayWindow.addSubview(self)
                self.setUpConstraints()
            }
        } else if let displayView = self.displayView { // fallback to displaying from view
            if self.superview == nil {
                
                displayView.addSubview(self)
                self.setUpConstraints()
            }
        }
        
        // set up view components
        if self.layoutContainer == nil {
            self.setUpComponents()
        }
    }
    
    private func setUpConstraints() {
        self.heightConstraint = self.autoSetHeight(0.0)
        self.heightConstraint?.isActive = false
        
        if UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.phone { // iPhone - fill screen
            if let constraints = self.autoPinToSidesAndBottom() {
                self.bottomMarginConstraint = constraints[2]
            }
        } else { // iPad - center on bottom
            
            if let constraints = self.autoPinToBottomAndCenter() {
                self.bottomMarginConstraint = constraints[0]
            }
            self.widthConstraint = self.autoSetWidth(CocoaBarWidthIpad)
        }
    }
    
    private func setUpComponents() {
        
        // set up layout container
        let layoutContainer = UIView()
        self.addSubview(layoutContainer)
        layoutContainer.autoPinToEdges()
        self.layoutContainer = layoutContainer
        self.updateLayout(self.layout)
    }
    
    private func bringBarToFront() {
        if let displayWindow = self.displayWindow {
            displayWindow.bringSubview(toFront: self)
        }
    }
    
    private func updateLayout(_ layout: CocoaBarLayout) {
        if let layoutContainer = self.layoutContainer {
            
            // clear layout container
            for view in layoutContainer.subviews {
                view.removeFromSuperview()
            }
            
            // update height if required
            let requiresHeightConstraint = (layout.height != nil)
            self.heightConstraint?.isActive = requiresHeightConstraint
            if requiresHeightConstraint {
                self.heightConstraint?.constant = CGFloat(layout.height!)
            }
            
            layout.delegate = self
            layoutContainer.addSubview(layout)
            layout.autoPinToEdges()
        }
    }
    
    private func setUpDisplayTimer(_ duration: Double) {
        if self.displayTimer == nil {
            self.displayTimer = Timer.scheduledTimer(timeInterval: duration,
                                                                       target: self,
                                                                       selector: #selector(displayTimerElapsed),
                                                                       userInfo: nil,
                                                                       repeats: false)
        }
    }
    
    private func destroyDisplayTimer() {
        if let displayTimer = self.displayTimer {
            displayTimer.invalidate()
            self.displayTimer = nil
        }
    }
    
    @objc private func displayTimerElapsed(_ timer: Timer?) {
        self.destroyDisplayTimer()
        self.hideAnimated(true, completion: nil)
    }
    
    private func layoutForStyle(_ style: Style?) -> CocoaBarLayout? {
        if let style = style {
            
            var layout: CocoaBarLayout
            switch style {
                
            case .action:
                layout = CocoaBarActionLayout()
                break
                
            default:
                layout = CocoaBarDefaultLayout()
                break
            }
            return layout
        }
        return nil
    }
    
    private func doShowAnimated(_ animated: Bool,
                                duration: Double,
                                layout: CocoaBarLayout?,
                                populate: CocoaBarPopulationClosure?,
                                completion: CocoaBarAnimationCompletionClosure?) {
        if !self.isShowing {
            
            // update layout
            self.setUpIfRequired()
            self.bringBarToFront()
            if let layout = layout {
                self.layout = layout
            }
            
            if let populate = populate {
                populate(layout: self.layout)
            }
            
            if animated { // animate in
                if !self.isAnimating {
                    
                    if let delegate = self.delegate {
                        delegate.cocoaBar(self, willShowAnimated: animated)
                    }
                    
                    // hide layout offscreen initially
                    self.layout.layoutIfNeeded()
                    self.bottomMarginConstraint?.constant = -((self.layout.height != nil) ? CGFloat(self.layout.height!) : self.layout.bounds.size.height)
                    
                    self.layout.prepareForShow()
                    self.layout.showShadowAnimated(animated)
                    self.layoutIfNeeded()
                    self.bottomMarginConstraint?.constant = 0.0
                    self.isAnimating = true
                    UIView.animate(withDuration: 0.2,
                                               delay: 0.0,
                                               options: UIViewAnimationOptions.curveEaseOut,
                                               animations:
                        {
                            self.layoutIfNeeded()
                        },
                                               completion:
                        { (completed) in
                            self.isShowing = true
                            self.isAnimating = false
                            self.setUpDisplayTimer(duration)
                            
                            if let delegate = self.delegate {
                                delegate.cocoaBar(self, didShowAnimated: animated)
                            }
                            if let completion = completion {
                                completion(animated: animated, completed: completed, visible: self.isShowing)
                            }
                        }
                    )
                }
            } else {
                
                if let delegate = self.delegate {
                    delegate.cocoaBar(self, willShowAnimated: animated)
                }
                
                self.bottomMarginConstraint?.constant = 0.0
                self.layout.prepareForShow()
                self.layout.showShadowAnimated(animated)
                self.layoutIfNeeded()
                self.isShowing = true
                self.setUpDisplayTimer(duration)
                
                if let completion = completion {
                    completion(animated: animated, completed: true, visible: self.isShowing)
                }
                if let delegate = self.delegate {
                    delegate.cocoaBar(self, didShowAnimated: animated)
                }
            }
        }
    }
    
    private func doHideAnimated(_ animated: Bool,
                                completion: CocoaBarAnimationCompletionClosure?) {
        if self.isShowing && !self.isAnimating {
            self.destroyDisplayTimer()
            
            if animated {
                if !self.isAnimating { // animate out
                    
                    if let delegate = self.delegate {
                        delegate.cocoaBar(self, willHideAnimated: animated)
                    }
                    
                    self.bottomMarginConstraint?.constant = -self.bounds.size.height
                    self.isAnimating = true
                    
                    self.layout.prepareForHide()
                    self.layout.hideShadowAnimated(animated)
                    UIView.animate(withDuration: 0.2,
                                               delay: 0.0,
                                               options: UIViewAnimationOptions.curveEaseIn,
                                               animations:
                        {
                            self.layoutIfNeeded()
                        },
                                               completion:
                        { (completed) in
                            self.isShowing = false
                            self.isAnimating = false
                            
                            if let delegate = self.delegate {
                                delegate.cocoaBar(self, didHideAnimated: animated)
                            }
                            if let completion = completion {
                                completion(animated: animated, completed: completed, visible: self.isShowing)
                            }
                        }
                    )
                }
            } else {
                
                if let delegate = self.delegate {
                    delegate.cocoaBar(self, willHideAnimated: animated)
                }
                
                self.bottomMarginConstraint?.constant = self.bounds.size.height
                self.layout.prepareForHide()
                self.layout.hideShadowAnimated(animated)
                self.layoutIfNeeded()
                self.isShowing = false
                
                if let completion = completion {
                    completion(animated: animated, completed: true, visible: self.isShowing)
                }
                if let delegate = self.delegate {
                    delegate.cocoaBar(self, didHideAnimated: animated)
                }
            }
        }

    }
    
    // MARK: Public
    
    /**
     Shows the CocoaBar
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The duration to display the bar for (DisplayDuration enum).
     :param: layout         The layout to use for the bar. Using nil will keep the existing layout.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public func showAnimated(_ animated: Bool,
                             duration: DisplayDuration,
                             layout: CocoaBarLayout?,
                             populate: CocoaBarPopulationClosure?,
                             completion: CocoaBarAnimationCompletionClosure?) {
        
        self.showAnimated(animated,
                          duration: duration.value,
                          layout: layout,
                          populate: populate,
                          completion: completion)
    }
    
    /**
     Shows the CocoaBar
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The duration to display the bar for (DisplayDuration enum).
     :param: style          The style to use for the bar. Using nil will use the existing style.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public func showAnimated(_ animated: Bool,
                             duration: DisplayDuration,
                             style: Style?,
                             populate: CocoaBarPopulationClosure?,
                             completion: CocoaBarAnimationCompletionClosure?) {
        
        self.showAnimated(animated,
                          duration: duration,
                          layout: self.layoutForStyle(style),
                          populate: populate,
                          completion: completion)
    }
    
    /**
     Shows the CocoaBar
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The exact duration to display the bar for (Double).
     :param: layout         The layout to use for the bar. Using nil will keep the existing layout.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public func showAnimated(_ animated: Bool,
                             duration: Double,
                             layout: CocoaBarLayout?,
                             populate: CocoaBarPopulationClosure?,
                             completion: CocoaBarAnimationCompletionClosure?) {
        self.doShowAnimated(animated,
                            duration: duration,
                            layout: layout,
                            populate: populate,
                            completion: completion)
    }
    
    /**
     Shows the CocoaBar
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The exact duration to display the bar for (Double).
     :param: style          The style to use for the bar. Using nil will use the existing style.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public func showAnimated(_ animated: Bool,
                             duration: Double,
                             style: Style?,
                             populate: CocoaBarPopulationClosure?,
                             completion: CocoaBarAnimationCompletionClosure?) {
        
        self.showAnimated(animated,
                          duration: duration,
                          layout: self.layoutForStyle(style),
                          populate: populate,
                          completion: completion)
    }
    
    /**
     Hides the CocoaBar
     
     :param: animated       Whether to animate hiding the bar.
     :param: completion     Closure for completion of the hide transition.
     
     */
    public func hideAnimated(_ animated: Bool,
                             completion: CocoaBarAnimationCompletionClosure?) {
        self.doHideAnimated(animated,
                            completion: completion)
    }
    
    // MARK: KeyCocoaBar
    
    /**
     Shows the keyCocoaBar if it exists. The keyCocoaBar is the CocoaBar attached to the keyWindow.
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The duration to display the bar for (DisplayDuration enum).
     :param: layout         The layout to use for the bar. Using nil will keep the existing layout.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public class func showAnimated(_ animated: Bool,
                                   duration: DisplayDuration,
                                   layout: CocoaBarLayout?,
                                   populate: CocoaBarPopulationClosure?,
                                   completion: CocoaBarAnimationCompletionClosure?) {
        
        CocoaBar.showAnimated(animated,
                              duration: duration.value,
                              layout: layout,
                              populate: populate,
                              completion: completion)
    }
    
    /**
     Shows the keyCocoaBar if it exists. The keyCocoaBar is the CocoaBar attached to the keyWindow.
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The duration to display the bar for (DisplayDuration enum).
     :param: style          The style to use for the bar. Using nil will use the existing style.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public class func showAnimated(_ animated: Bool,
                                   duration: DisplayDuration,
                                   style: Style?,
                                   populate: CocoaBarPopulationClosure?,
                                   completion: CocoaBarAnimationCompletionClosure?) {
        CocoaBar.showAnimated(animated,
                              duration: duration,
                              layout: CocoaBar.keyCocoaBar?.layoutForStyle(style),
                              populate: populate,
                              completion: completion)
    }
    
    /**
     Shows the keyCocoaBar if it exists. The keyCocoaBar is the CocoaBar attached to the keyWindow.
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The exact duration to display the bar for (Double).
     :param: layout         The layout to use for the bar. Using nil will keep the existing layout.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public class func showAnimated(_ animated: Bool,
                                   duration: Double,
                                   layout: CocoaBarLayout?,
                                   populate: CocoaBarPopulationClosure?,
                                   completion: CocoaBarAnimationCompletionClosure?) {
        
        if let keyBar = self.keyCocoaBar {
            keyBar.showAnimated(animated,
                                duration: duration,
                                layout: layout,
                                populate: populate,
                                completion: completion)
        } else {
            print("Could not show as no CocoaBar is currently attached to the keyWindow")
        }
    }
    
    /**
     Shows the keyCocoaBar if it exists. The keyCocoaBar is the CocoaBar attached to the keyWindow.
     
     :param: animated       Whether to animate showing the bar.
     :param: duration       The exact duration to display the bar for (Double).
     :param: style          The style to use for the bar. Using nil will use the existing style.
     :param: populate       Closure to populate the layout with data.
     :param: completion     Closure for completion of the show transition.
     
     */
    public class func showAnimated(_ animated: Bool,
                                   duration: Double,
                                   style: Style?,
                                   populate: CocoaBarPopulationClosure?,
                                   completion: CocoaBarAnimationCompletionClosure?) {
        
        CocoaBar.showAnimated(animated,
                              duration: duration,
                              layout: CocoaBar.keyCocoaBar?.layoutForStyle(style),
                              populate: populate,
                              completion: completion)
    }
    
    /**
     Hides the keyCocoaBar if it exists. The keyCocoaBar is the CocoaBar attached to the keyWindow.
     
     :param: animated       Whether to animate hiding the bar.
     :param: completion     Closure for completion of the hide transition.
     
     */
    public class func hideAnimated(_ animated: Bool,
                                   completion: CocoaBarAnimationCompletionClosure?) {
        
        if let keyBar = self.keyCocoaBar {
            keyBar.hideAnimated(animated,
                                completion: completion)
        } else {
            print("Could not hide as no CocoaBar is currently attached to the keyWindow")
        }
    }
    
    // MARK: Notifications
    
    @objc func hideNotificationReceived(_ notification: Notification) {
        var animated = true
        if let userInfo = (notification as NSNotification).userInfo {
            animated = userInfo[CocoaBarAnimatedKey] as! Bool
        }
        self.hideAnimated(animated, completion: nil)
    }
    
    @objc func windowDidBecomeVisible(_ notification: Notification) {
        self.bringBarToFront()
    }
    
    // MARK: CocoaBarLayoutDelegate
    
    func cocoaBarLayoutDismissButtonPressed(_ dismissButton: UIButton?) {
        self.hideAnimated(true, completion: nil)
    }
    
    func cocoaBarLayoutActionButtonPressed(_ actionButton: UIButton?) {
        if let delegate = self.delegate {
            delegate.cocoaBar(self, actionButtonPressed: actionButton)
        }
    }
}

private extension CocoaBarLayout {
    
    private func showShadowAnimated(_ animated: Bool) {
        if self.showDropShadow {
            self.layer.shadowOpacity = self.visibleOpacity
            if animated {
                let animation = CABasicAnimation(keyPath: "shadowOpacity")
                animation.duration = 0.2
                animation.fromValue = 0.0
                animation.toValue = self.visibleOpacity
                self.layer.add(animation, forKey: "shadowOpacity")
            }
        }
    }
    
    private func hideShadowAnimated(_ animated: Bool) {
        if self.showDropShadow {
            self.layer.shadowOpacity = 0.0
            if animated {
                let animation = CABasicAnimation(keyPath: "shadowOpacity")
                animation.duration = 0.2
                animation.fromValue = self.visibleOpacity
                animation.toValue = 0.0
                self.layer.add(animation, forKey: "shadowOpacity")
            }
        }
    }
}
