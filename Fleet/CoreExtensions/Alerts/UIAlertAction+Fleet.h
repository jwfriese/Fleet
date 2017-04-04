#import <UIKit/UIKit.h>

@interface UIAlertAction (Fleet)

@property (nonatomic, copy, readonly) void(^handler)(UIAlertAction *);

@end
