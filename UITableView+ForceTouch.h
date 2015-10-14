//
//  UITableView+ForceTouch.h
//
//  Created by McDowell, Ian J on 10/12/15.
//

#import <UIKit/UIKit.h>

@protocol UIForceTouchTableViewCell <NSObject>

- (void)applyForce:(CGFloat)force atLocation:(CGPoint)location;

@end

@interface UITableView (ForceTouch)

@end
