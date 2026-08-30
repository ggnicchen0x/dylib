#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "CustomAuthViewController.h"

static IMP original_didFinishLaunching = NULL;

BOOL custom_didFinishLaunching(id self, SEL _cmd, UIApplication *application, NSDictionary *launchOptions) {
    BOOL result = YES;
    if (original_didFinishLaunching) {
        result = ((BOOL (*)(id, SEL, UIApplication *, NSDictionary *))original_didFinishLaunching)(self, _cmd, application, launchOptions);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [application keyWindow] ?: [application windows].firstObject;
        if (!window) {
            window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
            [window makeKeyAndVisible];
        }
        
        CustomAuthViewController *authVC = [[CustomAuthViewController alloc] init];
        window.rootViewController = authVC;
        [window makeKeyAndVisible];
    });
    
    return result;
}

__attribute__((constructor))
static void CustomAuthInitialize(void) {
    NSLog(@"[CustomAuth] Dynamic Library Loaded into Process");
    
    // Register Notification for Application Did Finish Launching
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        UIApplication *app = [UIApplication sharedApplication];
        UIWindow *window = app.keyWindow ?: app.windows.firstObject;
        if (window) {
            CustomAuthViewController *authVC = [[CustomAuthViewController alloc] init];
            window.rootViewController = authVC;
            [window makeKeyAndVisible];
        }
    }];
    
    // Also swizzle MainApplicationDelegate as backup guarantee
    Class appDelegateClass = NSClassFromString(@"MainApplicationDelegate");
    if (appDelegateClass) {
        SEL sel = @selector(application:didFinishLaunchingWithOptions:);
        Method m = class_getInstanceMethod(appDelegateClass, sel);
        if (m) {
            original_didFinishLaunching = method_getImplementation(m);
            method_setImplementation(m, (IMP)custom_didFinishLaunching);
            NSLog(@"[CustomAuth] Successfully hooked MainApplicationDelegate didFinishLaunchingWithOptions");
        }
    }
}
