//
//  UITableView+ForceTouch.m
//
//  Created by McDowell, Ian J on 10/12/15.
//

#import "UITableView+ForceTouch.h"
#import <objc/runtime.h>

struct MethodSwizzle {
    Class class;
    Method originalMethod;
    SEL originalSelector;
    Method swizzledMethod;
    SEL swizzleSelector;
};
typedef struct MethodSwizzle MethodSwizzle;

MethodSwizzle MSMakeSwizzle(Class class, SEL originalSelector, SEL swizzleSelector, BOOL instanceMethod) {
    MethodSwizzle swizzle;
    swizzle.class = class;
    if (instanceMethod) {
        swizzle.originalMethod = class_getInstanceMethod(class, originalSelector);
        swizzle.swizzledMethod = class_getInstanceMethod(class, swizzleSelector);
    } else {
        swizzle.originalMethod = class_getClassMethod(class, originalSelector);
        swizzle.swizzledMethod = class_getClassMethod(class, swizzleSelector);
    }
    swizzle.originalSelector = originalSelector;
    swizzle.swizzleSelector = swizzleSelector;
    return swizzle;
}

@implementation UITableView (ForceTouch)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        int num_swizzles = 4;
        MethodSwizzle* swizzles = malloc(sizeof(MethodSwizzle) * num_swizzles);
        swizzles[0] = MSMakeSwizzle(class, @selector(touchesBegan:withEvent:), @selector(forceTouch_touchesBegan:withEvent:), YES);
        swizzles[1] = MSMakeSwizzle(class, @selector(touchesMoved:withEvent:), @selector(forceTouch_touchesMoved:withEvent:), YES);
        swizzles[2] = MSMakeSwizzle(class, @selector(touchesEnded:withEvent:), @selector(forceTouch_touchesEnded:withEvent:), YES);
        swizzles[3] = MSMakeSwizzle(class, @selector(touchesCancelled:withEvent:), @selector(forceTouch_touchesCancelled:withEvent:), YES);

        for (int i = 0; i < num_swizzles; i++) {
            MethodSwizzle swizzle = swizzles[i];
            
            BOOL didAddMethod = class_addMethod(swizzle.class,
                                                swizzle.originalSelector,
                                                method_getImplementation(swizzle.swizzledMethod),
                                                method_getTypeEncoding(swizzle.swizzledMethod));
            
            if (didAddMethod) {
                class_replaceMethod(swizzle.class,
                                    swizzle.swizzleSelector,
                                    method_getImplementation(swizzle.originalMethod),
                                    method_getTypeEncoding(swizzle.originalMethod));
            } else {
                method_exchangeImplementations(swizzle.originalMethod, swizzle.swizzledMethod);
            }
        }
        
        free(swizzles);
    });
}

- (void)forceTouch_touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forceTouch_touchesBegan:touches withEvent:event];
    
    [self analyzeForceOfTouches:touches didEnd:NO];
}

- (void)forceTouch_touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forceTouch_touchesMoved:touches withEvent:event];
    
    [self analyzeForceOfTouches:touches didEnd:NO];
}

- (void)forceTouch_touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forceTouch_touchesEnded:touches withEvent:event];
    
    [self analyzeForceOfTouches:touches didEnd:YES];
}

- (void)forceTouch_touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self forceTouch_touchesCancelled:touches withEvent:event];
    
    [self analyzeForceOfTouches:touches didEnd:YES];
}

- (void)analyzeForceOfTouches:(NSSet<UITouch *> *)touches didEnd:(BOOL)didEnd {
    if (![[UITraitCollection class] respondsToSelector:@selector(traitCollectionWithForceTouchCapability:)]) return;
    UITraitCollection *traitCollection = [UITraitCollection traitCollectionWithForceTouchCapability:UIForceTouchCapabilityAvailable];
    if (traitCollection.forceTouchCapability != UIForceTouchCapabilityAvailable) return;
    
    for (UITouch *touch in [touches allObjects]) {
        NSIndexPath *indexPathForRowTouched = [self indexPathForRowAtPoint:[touch locationInView:self]];
        
        for (UITableViewCell *cell in [self visibleCells]) {
            if ([[self indexPathForCell:cell] isEqual:indexPathForRowTouched]) {
                if (![[cell class] conformsToProtocol:@protocol(UIForceTouchTableViewCell)]) return;
                id<UIForceTouchTableViewCell> forceTouchCell = (id<UIForceTouchTableViewCell>)cell;
                CGPoint location = [touch locationInView:cell];
                if (didEnd) {
                    [forceTouchCell applyForce:0 atLocation:location];
                } else {
                    [forceTouchCell applyForce:touch.force / touch.maximumPossibleForce atLocation:location];
                }
            }
        }
    }
}

@end
