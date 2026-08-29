#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>

// ==========================================
// Configurable Settings
// ==========================================
// Set this to your live Bot-Hosting VPS domain / IP + Port
#define AUTH_SERVER_BASE_URL @"http://fi14.bot-hosting.cloud:25981"
#define AUTH_VALIDATE_URL    AUTH_SERVER_BASE_URL @"/api/v1/auth/validate"
#define AUTH_HEARTBEAT_URL   AUTH_SERVER_BASE_URL @"/api/v1/auth/heartbeat"

#define APP_TITLE @"EXTERNALFF AUTHENTICATION"
#define APP_SUBTITLE @"Live Realtime License Verification"
#define SUPPORT_URL @"https://discord.gg/nMQaamDNj2"
#define KEYCHAIN_KEY @"com.externalff.auth.license_key"
#define KEYCHAIN_HWID @"com.externalff.auth.device_hwid"

// Unified Cyberpunk Theme Palette
#define THEME_BG          [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0] // #0a0d14 Deep Obsidian
#define THEME_CARD_BG     [UIColor colorWithRed:0.07 green:0.09 blue:0.15 alpha:0.95] // #111726 Dark Glass Card
#define THEME_CARD_BORDER [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.25] // Indigo border
#define THEME_ACCENT      [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0] // #6366f1 Neon Indigo
#define THEME_TEXT_WHITE  [UIColor colorWithRed:0.97 green:0.98 blue:0.99 alpha:1.0] // #f8fafc Crisp White
#define THEME_TEXT_MUTED  [UIColor colorWithRed:0.58 green:0.64 blue:0.72 alpha:1.0] // #94a3b8 Slate Muted

// Forward declarations & Core Interfaces
@interface AuthGateManager : NSObject
@property (nonatomic, strong) UIWindow *authWindow;
+ (instancetype)shared;
- (void)startAuthGate;
- (void)reshowLockdownGateWithReason:(NSString *)reason;
- (void)showAuthWindowWithError:(NSString *)errorReason;
@end

@interface LiveSecurityGuard : NSObject
+ (instancetype)shared;
+ (BOOL)isSessionAuthorized;
+ (void)setAuthorizedSessionWithKey:(NSString *)key token:(NSString *)token expiresAt:(NSNumber *)expiresAt;
+ (void)enforceLockdownWithReason:(NSString *)reason;
+ (void)startHeartbeatTimer;
+ (void)stopHeartbeatTimer;
@end

// ==========================================
// Keychain & Storage Helpers
// ==========================================
@interface AuthStorage : NSObject
+ (void)saveString:(NSString *)value forKey:(NSString *)key;
+ (NSString *)getStringForKey:(NSString *)key;
+ (NSString *)getDeviceHWID;
@end

@implementation AuthStorage

+ (void)saveString:(NSString *)value forKey:(NSString *)key {
    if (!value || !key) return;
    
    // 1. Save to iOS Keychain (persists across reinstalls and resigning)
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *deleteQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecAttrService: @"com.externalff.auth.service"
    };
    SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecAttrService: @"com.externalff.auth.service",
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    };
    SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    
    // 2. Also save to NSUserDefaults as secondary backup
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)getStringForKey:(NSString *)key {
    if (!key) return nil;
    
    // 1. Try reading from iOS Keychain first
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecAttrService: @"com.externalff.auth.service",
        (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess && result != NULL) {
        NSData *data = (__bridge_transfer NSData *)result;
        NSString *val = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (val && val.length > 0) return val;
    }
    
    // 2. Fallback to NSUserDefaults
    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}

+ (NSString *)getDeviceHWID {
    // 1. Check permanent iOS Keychain
    NSString *cachedHWID = [self getStringForKey:KEYCHAIN_HWID];
    if (cachedHWID && cachedHWID.length > 0) {
        return cachedHWID;
    }
    
    // 2. Query Apple's identifierForVendor
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (!vendorID || vendorID.length == 0) {
        vendorID = [[NSUUID UUID] UUIDString];
    }
    
    // 3. Save permanently to iOS Keychain
    [self saveString:vendorID forKey:KEYCHAIN_HWID];
    return vendorID;
}

@end

// ==========================================
// Targeted Main Menu Theme Styler
// ==========================================
@interface MainMenuThemeEngine : NSObject
+ (void)styleViewController:(UIViewController *)vc;
+ (void)styleViewHierarchy:(UIView *)view isRoot:(BOOL)isRoot;
@end

@implementation MainMenuThemeEngine

+ (void)styleViewController:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    
    // Skip the Auth Gate itself
    if ([NSStringFromClass([vc class]) containsString:@"AuthGate"]) return;
    
    // Set root view background
    vc.view.backgroundColor = THEME_BG;
    
    // Set Navigation / Status Bar style
    if (vc.navigationController) {
        vc.navigationController.navigationBar.barTintColor = THEME_BG;
        vc.navigationController.navigationBar.backgroundColor = THEME_BG;
        vc.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName: THEME_TEXT_WHITE};
    }
    
    // Style Tab Bar if present
    if (vc.tabBarController) {
        UITabBar *tabBar = vc.tabBarController.tabBar;
        tabBar.barTintColor = THEME_BG;
        tabBar.backgroundColor = THEME_BG;
        tabBar.tintColor = THEME_ACCENT;
        tabBar.unselectedItemTintColor = THEME_TEXT_MUTED;
        tabBar.layer.borderColor = [UIColor colorWithRed:0.2 green:0.25 blue:0.35 alpha:0.3].CGColor;
        tabBar.layer.borderWidth = 0.5;
        
        NSArray *items = tabBar.items;
        if (items.count > 0) [items[0] setTitle:@"Home"];
        if (items.count > 1) [items[1] setTitle:@"Mods"];
        
        for (UIViewController *child in vc.tabBarController.viewControllers) {
            NSString *cname = NSStringFromClass([child class]);
            if ([cname containsString:@"NoExploit"]) {
                child.title = @"Mods";
                child.navigationItem.title = @"Mods";
                child.tabBarItem.title = @"Mods";
            } else if ([cname containsString:@"Exploit"]) {
                child.title = @"Home";
                child.navigationItem.title = @"Home";
                child.tabBarItem.title = @"Home";
            }
        }
    }
    
    [self styleViewHierarchy:vc.view isRoot:YES];
    [self realignMenuLayout:vc];
}

+ (void)realignMenuLayout:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    
    // Find scrollView if present
    UIScrollView *sv = nil;
    if ([vc.view isKindOfClass:[UIScrollView class]]) {
        sv = (UIScrollView *)vc.view;
    } else {
        for (UIView *sub in vc.view.subviews) {
            if ([sub isKindOfClass:[UIScrollView class]]) {
                sv = (UIScrollView *)sub;
                break;
            }
        }
    }
    
    if (!sv) return;
    
    NSString *cname = NSStringFromClass([vc class]);
    BOOL isNoExploit = [cname containsString:@"NoExploit"] || [vc.title isEqualToString:@"Mods"];
    
    // Precise Ghidra Geometry:
    // Home (ProxyExploitViewController, has top START box @ y=48):
    //   Cards end at y=450.0. Reset @ y=468.0. Status @ y=522.0. ContentSize @ 670.0.
    // Mods (ProxyNoExploitViewController, no top START box, starts directly at y=16):
    //   Cards end at y=342.0. Reset @ y=360.0. Status @ y=414.0. ContentSize @ 514.0.
    
    CGFloat resetY = isNoExploit ? 360.0 : 468.0;
    CGFloat statusY = isNoExploit ? 414.0 : 522.0;
    CGFloat contentH = isNoExploit ? 514.0 : 670.0;
    
    for (UIView *sub in sv.subviews) {
        if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            NSString *t = [btn titleForState:UIControlStateNormal] ?: @"";
            if ([t isEqualToString:@"Reset"]) {
                CGRect f = btn.frame;
                f.origin.y = resetY;
                f.size.height = 44.0;
                btn.frame = f;
            }
        } else if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            // Target the multiline status / diagnostics label in the scroll view
            if (lbl.numberOfLines != 1 && lbl.superview == sv) {
                CGRect f = lbl.frame;
                f.origin.y = statusY;
                lbl.frame = f;
            }
        }
    }
    
    CGSize cs = sv.contentSize;
    if (cs.height > 400) {
        cs.height = contentH;
        sv.contentSize = cs;
    }
}

+ (void)styleViewHierarchy:(UIView *)view isRoot:(BOOL)isRoot {
    if (!view) return;
    if ([NSStringFromClass([view class]) containsString:@"AuthGate"]) return;
    
    if (isRoot) {
        view.backgroundColor = THEME_BG;
    }
    
    for (UIView *sub in view.subviews) {
        // 1. Labels
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)sub;
            NSString *text = lbl.text ?: @"";
            
            // Check if label is inside a switch row card
            BOOL isInsideSwitchCard = NO;
            UIView *p = lbl.superview;
            if (p) {
                for (UIView *sibling in p.subviews) {
                    if ([sibling isKindOfClass:[UISwitch class]]) {
                        isInsideSwitchCard = YES;
                        break;
                    }
                }
            }
            
            NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([trimmed isEqualToString:@"Exploit"]) {
                lbl.text = @"Home";
                lbl.textColor = THEME_TEXT_WHITE;
                lbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
            } else if ([trimmed isEqualToString:@"No Exploit"]) {
                lbl.text = @"Mods";
                lbl.textColor = THEME_TEXT_WHITE;
                lbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
            } else if ([trimmed isEqualToString:@"Home"] || [trimmed isEqualToString:@"Mods"] || [trimmed isEqualToString:@"Mod"] || [trimmed isEqualToString:@"Account"]) {
                lbl.textColor = THEME_TEXT_WHITE;
                lbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
            } else if ([trimmed containsString:@"ModChest"] || [trimmed containsString:@"Chest"]) {
                UIView *card = lbl.superview;
                if (card) {
                    card.hidden = YES;
                    card.frame = CGRectZero;
                    [card removeFromSuperview];
                }
            } else if ([trimmed containsString:@"Maggic"] || [trimmed containsString:@"Magic"]) {
                lbl.text = @"200% Magic Bullet";
                lbl.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
            } else if (isInsideSwitchCard || [trimmed isEqualToString:@"Drag"] || [trimmed isEqualToString:@"100% Body"] || [trimmed isEqualToString:@"95% Body"] || [trimmed containsString:@"Magic Bullet"]) {
                // Feature label inside white card: Dark bold black
                lbl.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
            } else {
                // All status, diagnostics, and dynamic messages on the dark background ("Drag applied ✓", "Exploit: running", etc.): Bright Light Cyan/Slate
                lbl.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
            }
        }
        
        // 2. Switches & their parent row card
        else if ([sub isKindOfClass:[UISwitch class]]) {
            UISwitch *sw = (UISwitch *)sub;
            UIView *parent = sw.superview;
            
            // Check if this switch card belongs to ModChest or has an empty label
            BOOL isModChest = NO;
            if (parent) {
                for (UIView *sibling in parent.subviews) {
                    if ([sibling isKindOfClass:[UILabel class]]) {
                        UILabel *l = (UILabel *)sibling;
                        NSString *t = l.text ?: @"";
                        NSString *tr = [t stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if ([tr containsString:@"ModChest"] || [tr containsString:@"Chest"] || [tr isEqualToString:@""]) {
                            isModChest = YES;
                            break;
                        }
                    }
                }
            }
            
            if (isModChest) {
                if (parent) {
                    parent.hidden = YES;
                    parent.frame = CGRectZero;
                    [parent removeFromSuperview];
                }
                continue;
            }
            
            sw.onTintColor = THEME_ACCENT;
            sw.thumbTintColor = [UIColor whiteColor];
            
            // Style the parent row card
            if (parent && parent != view) {
                parent.backgroundColor = THEME_CARD_BG;
                parent.layer.cornerRadius = 12;
                parent.layer.borderColor = THEME_CARD_BORDER.CGColor;
                parent.layer.borderWidth = 1.0;
                parent.layer.masksToBounds = YES;
            }
        }
        
        // 3. Segmented Controls ("Free Fire | Free Fire MAX", "Aim | Visuals")
        else if ([sub isKindOfClass:[UISegmentedControl class]]) {
            UISegmentedControl *sc = (UISegmentedControl *)sub;
            sc.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.18 alpha:0.9];
            sc.selectedSegmentTintColor = THEME_ACCENT;
            sc.layer.cornerRadius = 10;
            sc.layer.borderColor = THEME_CARD_BORDER.CGColor;
            sc.layer.borderWidth = 1.0;
            sc.layer.masksToBounds = YES;
            [sc setTitleTextAttributes:@{NSForegroundColorAttributeName: THEME_TEXT_WHITE, NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightBold]} forState:UIControlStateSelected];
            [sc setTitleTextAttributes:@{NSForegroundColorAttributeName: THEME_TEXT_MUTED, NSFontAttributeName: [UIFont systemFontOfSize:13 weight:UIFontWeightMedium]} forState:UIControlStateNormal];
        }
        
        // 4. Buttons
        else if ([sub isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)sub;
            NSString *title = [btn titleForState:UIControlStateNormal] ?: @"";
            
            if ([title isEqualToString:@"START"]) {
                btn.backgroundColor = THEME_ACCENT;
                [btn setTitleColor:THEME_TEXT_WHITE forState:UIControlStateNormal];
                btn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
                btn.layer.cornerRadius = 10;
                btn.layer.shadowColor = THEME_ACCENT.CGColor;
                btn.layer.shadowOffset = CGSizeMake(0, 4);
                btn.layer.shadowRadius = 8;
                btn.layer.shadowOpacity = 0.4;
            } else if ([title isEqualToString:@"STOP"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.25];
                [btn setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
                btn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.5].CGColor;
                btn.layer.borderWidth = 1.0;
                btn.layer.cornerRadius = 10;
            } else if ([title isEqualToString:@"Reset"]) {
                btn.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.18 alpha:0.8];
                [btn setTitleColor:THEME_ACCENT forState:UIControlStateNormal];
                btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
                btn.layer.borderColor = THEME_CARD_BORDER.CGColor;
                btn.layer.borderWidth = 1.0;
                btn.layer.cornerRadius = 10;
            }
        }
        
        // 5. Status Card / Container boxes
        else if (sub.subviews.count > 0 && ![sub isKindOfClass:[UIScrollView class]]) {
            // Check if this container contains the START/STOP button or sandbox status
            BOOL isStatusCard = NO;
            for (UIView *child in sub.subviews) {
                if ([child isKindOfClass:[UIButton class]]) {
                    UIButton *b = (UIButton *)child;
                    NSString *t = [b titleForState:UIControlStateNormal];
                    if ([t isEqualToString:@"START"] || [t isEqualToString:@"STOP"]) {
                        isStatusCard = YES;
                        break;
                    }
                }
            }
            if (isStatusCard) {
                sub.backgroundColor = THEME_CARD_BG;
                sub.layer.cornerRadius = 16;
                sub.layer.borderColor = THEME_CARD_BORDER.CGColor;
                sub.layer.borderWidth = 1.2;
                sub.layer.masksToBounds = YES;
            }
        }
        
        // Recurse children
        [self styleViewHierarchy:sub isRoot:NO];
    }
}

@end

// ==========================================
// Dynamic Label Hook (for Runtime Messages like "Drag applied ✓")
// ==========================================
@interface UILabel (DynamicRuntimeThemeHook)
@end

@implementation UILabel (DynamicRuntimeThemeHook)

- (void)hook_dynamicRuntimeSetText:(NSString *)text {
    if (!text || [NSStringFromClass([self class]) containsString:@"AuthGate"]) {
        [self hook_dynamicRuntimeSetText:text];
        return;
    }
    
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([trimmed isEqualToString:@"Exploit"]) {
        [self hook_dynamicRuntimeSetText:@"Home"];
        self.textColor = THEME_TEXT_WHITE;
        return;
    }
    if ([trimmed isEqualToString:@"No Exploit"]) {
        [self hook_dynamicRuntimeSetText:@"Mods"];
        self.textColor = THEME_TEXT_WHITE;
        return;
    }
    if ([trimmed containsString:@"Maggic"] || [trimmed containsString:@"Magic Bullet"]) {
        [self hook_dynamicRuntimeSetText:@"200% Magic Bullet"];
        self.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
        return;
    }
    if ([trimmed containsString:@"ModChest"] || [trimmed containsString:@"Chest"]) {
        UIView *p = self.superview;
        if (p) {
            p.hidden = YES;
            p.frame = CGRectZero;
            [p removeFromSuperview];
        }
        return;
    }
    
    [self hook_dynamicRuntimeSetText:text];
    
    // Check if this label is inside a switch row card
    BOOL isInsideSwitchCard = NO;
    UIView *p = self.superview;
    if (p) {
        for (UIView *sibling in p.subviews) {
            if ([sibling isKindOfClass:[UISwitch class]]) {
                isInsideSwitchCard = YES;
                break;
            }
        }
    }
    
    if (isInsideSwitchCard || [text isEqualToString:@"Drag"] || [text isEqualToString:@"100% Body"] || [text isEqualToString:@"95% Body"] || [text containsString:@"Magic Bullet"]) {
        self.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
    } else if ([trimmed isEqualToString:@"Home"] || [trimmed isEqualToString:@"Mods"] || [trimmed isEqualToString:@"Mod"] || [trimmed isEqualToString:@"Account"]) {
        self.textColor = THEME_TEXT_WHITE;
    } else {
        // Any status/diagnostics/runtime toast on the dark background ("Drag applied ✓", "Exploit: running", etc.)
        self.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
    }
}

@end

// ==========================================
// Switch Row Creation Hook (Removes ModChest & Renames Magic Bullet)
// ==========================================
@interface NSObject (SwitchRowHook)
@end

@implementation NSObject (SwitchRowHook)

- (double)hook_addSwitchRowWithTitle:(NSString *)title option:(NSInteger)option toContainer:(UIView *)container y:(double)y {
    NSString *t = title ? [title stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
    if ([t containsString:@"ModChest"] || [t containsString:@"Chest"] || option == 4) {
        return y;
    }
    if ([t containsString:@"Maggic"] || [t containsString:@"Magic"]) {
        title = @"200% Magic Bullet";
    }
    return [self hook_addSwitchRowWithTitle:title option:option toContainer:container y:y];
}

@end

// ==========================================
// UIViewController & UINavigationItem & UITabBarItem Title Hooks
// ==========================================
@interface UIViewController (ThemeTitleHook)
@end

@implementation UIViewController (ThemeTitleHook)

- (void)hook_vc_setTitle:(NSString *)title {
    if ([title isEqualToString:@"Exploit"]) {
        [self hook_vc_setTitle:@"Home"];
        self.navigationItem.title = @"Home";
        self.tabBarItem.title = @"Home";
        return;
    }
    if ([title isEqualToString:@"No Exploit"]) {
        [self hook_vc_setTitle:@"Mods"];
        self.navigationItem.title = @"Mods";
        self.tabBarItem.title = @"Mods";
        return;
    }
    [self hook_vc_setTitle:title];
}

@end

@interface UINavigationItem (ThemeNavTitleHook)
@end

@implementation UINavigationItem (ThemeNavTitleHook)

- (void)hook_nav_setTitle:(NSString *)title {
    if ([title isEqualToString:@"Exploit"]) {
        [self hook_nav_setTitle:@"Home"];
        return;
    }
    if ([title isEqualToString:@"No Exploit"]) {
        [self hook_nav_setTitle:@"Mods"];
        return;
    }
    [self hook_nav_setTitle:title];
}

@end

@interface UITabBarItem (ThemeRenameHook)
@end

@implementation UITabBarItem (ThemeRenameHook)

- (void)hook_tab_setTitle:(NSString *)title {
    if ([title isEqualToString:@"Exploit"]) {
        [self hook_tab_setTitle:@"Home"];
        return;
    }
    if ([title isEqualToString:@"No Exploit"]) {
        [self hook_tab_setTitle:@"Mods"];
        return;
    }
    [self hook_tab_setTitle:title];
}

@end

// ==========================================
// Swizzle Specifically for Exploit View Controllers
// ==========================================
static void SwizzleMethod(Class cls, SEL origSel, SEL newSel) {
    Method origMethod = class_getInstanceMethod(cls, origSel);
    Method newMethod = class_getInstanceMethod(cls, newSel);
    if (!origMethod || !newMethod) return;
    
    BOOL didAdd = class_addMethod(cls, origSel, method_getImplementation(newMethod), method_getTypeEncoding(newMethod));
    if (didAdd) {
        class_replaceMethod(cls, newSel, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    } else {
        method_exchangeImplementations(origMethod, newMethod);
    }
}

// ==========================================
// RootViewController Account Tab Access Blocker
// ==========================================
@interface NSObject (RootViewControllerTabBlocker)
@end

@implementation NSObject (RootViewControllerTabBlocker)

- (BOOL)hook_root_tabBarController:(UITabBarController *)tbc shouldSelectViewController:(UIViewController *)vc {
    NSUInteger idx = NSNotFound;
    if (tbc && [tbc respondsToSelector:@selector(viewControllers)]) {
        idx = [tbc.viewControllers indexOfObject:vc];
    }
    
    NSString *cls = NSStringFromClass([vc class]);
    NSString *title = vc.tabBarItem.title ?: vc.title ?: @"";
    
    if (idx == 2 || [title isEqualToString:@"Account"] || [cls containsString:@"Debug"] || [cls containsString:@"Account"] || [cls containsString:@"Settings"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Access Restricted"
                                                                           message:@"No access to this tab."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            if (tbc) {
                [tbc presentViewController:alert animated:YES completion:nil];
            }
        });
        return NO;
    }
    
    return [self hook_root_tabBarController:tbc shouldSelectViewController:vc];
}

@end

@interface UIViewController (ExploitThemeHook)
@end

@implementation UIViewController (ExploitThemeHook)

- (void)hook_viewDidLayoutSubviews {
    [self hook_viewDidLayoutSubviews];    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Exploit"] || [className containsString:@"Proxy"] || [className containsString:@"Account"]) {
        if ([className containsString:@"NoExploit"] || [self.title isEqualToString:@"No Exploit"]) {
            self.title = @"Mods";
            self.navigationItem.title = @"Mods";
            self.tabBarItem.title = @"Mods";
        } else if ([className containsString:@"Exploit"] || [self.title isEqualToString:@"Exploit"]) {
            self.title = @"Home";
            self.navigationItem.title = @"Home";
            self.tabBarItem.title = @"Home";
        }
        [MainMenuThemeEngine styleViewController:self];
    }
}

// ==========================================
// Core Engine Anti-Bypass Hooks (The Dead Man's Gates)
// ==========================================
- (void)hook_homeStartCheatBackend {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        [LiveSecurityGuard enforceLockdownWithReason:@"Access Denied: Live Realtime Key Required."];
        return;
    }
    [self hook_homeStartCheatBackend];
}

- (void)hook_ProxyExploitStartTapped {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        [LiveSecurityGuard enforceLockdownWithReason:@"Access Denied: Live Realtime Key Required."];
        return;
    }
    [self hook_ProxyExploitStartTapped];
}

- (void)hook_startTapped {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        [LiveSecurityGuard enforceLockdownWithReason:@"Access Denied: Live Realtime Key Required."];
        return;
    }
    [self hook_startTapped];
}

- (void)hook_switchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) {
            [(UISwitch *)sender setOn:NO animated:YES];
        }
        [LiveSecurityGuard enforceLockdownWithReason:@"Cheat Switch Blocked: Realtime Authentication Required."];
        return;
    }
    [self hook_switchChanged:sender];
}

- (void)hook_homeFgAttachSwitchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) [(UISwitch *)sender setOn:NO animated:YES];
        [LiveSecurityGuard enforceLockdownWithReason:@"Feature Locked: Realtime Authentication Required."];
        return;
    }
    [self hook_homeFgAttachSwitchChanged:sender];
}

- (void)hook_homeHudSwitchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) [(UISwitch *)sender setOn:NO animated:YES];
        [LiveSecurityGuard enforceLockdownWithReason:@"Feature Locked: Realtime Authentication Required."];
        return;
    }
    [self hook_homeHudSwitchChanged:sender];
}

- (void)hook_homeKgvnSwitchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) [(UISwitch *)sender setOn:NO animated:YES];
        [LiveSecurityGuard enforceLockdownWithReason:@"Feature Locked: Realtime Authentication Required."];
        return;
    }
    [self hook_homeKgvnSwitchChanged:sender];
}

- (void)hook_runBackgroundCheatTick {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        return; // Drop tick without execution
    }
    [self hook_runBackgroundCheatTick];
}

+ (void)installThemeHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SwizzleMethod([UIViewController class], @selector(viewDidLayoutSubviews), @selector(hook_viewDidLayoutSubviews));
        SwizzleMethod([UIViewController class], @selector(setTitle:), @selector(hook_vc_setTitle:));
        SwizzleMethod([UINavigationItem class], @selector(setTitle:), @selector(hook_nav_setTitle:));
        SwizzleMethod([UITabBarItem class], @selector(setTitle:), @selector(hook_tab_setTitle:));
        SwizzleMethod([UILabel class], @selector(setText:), @selector(hook_dynamicRuntimeSetText:));
        
        Class expVCClass = objc_getClass("ProxyExploitViewController");
        if (expVCClass) {
            SwizzleMethod(expVCClass, @selector(addSwitchRowWithTitle:option:toContainer:y:), @selector(hook_addSwitchRowWithTitle:option:toContainer:y:));
            SwizzleMethod(expVCClass, @selector(_homeStartCheatBackend), @selector(hook_homeStartCheatBackend));
            SwizzleMethod(expVCClass, @selector(ProxyExploitStartTapped), @selector(hook_ProxyExploitStartTapped));
            SwizzleMethod(expVCClass, @selector(startTapped), @selector(hook_startTapped));
            SwizzleMethod(expVCClass, @selector(switchChanged:), @selector(hook_switchChanged:));
            SwizzleMethod(expVCClass, @selector(_homeFgAttachSwitchChanged:), @selector(hook_homeFgAttachSwitchChanged:));
            SwizzleMethod(expVCClass, @selector(_homeHudSwitchChanged:), @selector(hook_homeHudSwitchChanged:));
            SwizzleMethod(expVCClass, @selector(_homeKgvnSwitchChanged:), @selector(hook_homeKgvnSwitchChanged:));
            SwizzleMethod(expVCClass, @selector(runBackgroundCheatTick), @selector(hook_runBackgroundCheatTick));
        }
        Class noExpVCClass = objc_getClass("ProxyNoExploitViewController");
        if (noExpVCClass) {
            SwizzleMethod(noExpVCClass, @selector(addSwitchRowWithTitle:option:toContainer:y:), @selector(hook_addSwitchRowWithTitle:option:toContainer:y:));
            SwizzleMethod(noExpVCClass, @selector(switchChanged:), @selector(hook_switchChanged:));
            SwizzleMethod(noExpVCClass, @selector(startTapped), @selector(hook_startTapped:));
        }
        
        Class rootVCClass = objc_getClass("RootViewController");
        if (rootVCClass) {
            SwizzleMethod(rootVCClass, @selector(tabBarController:shouldSelectViewController:), @selector(hook_root_tabBarController:shouldSelectViewController:));
        }
    });
}

@end

// ==========================================
// Live Realtime Security Guard & Heartbeat Engine
// ==========================================
@interface LiveSecurityGuard ()
@property (nonatomic, assign) BOOL isAuthorized;
@property (nonatomic, copy) NSString *activeKey;
@property (nonatomic, copy) NSString *activeToken;
@property (nonatomic, assign) NSTimeInterval expiresAtTimestamp;
@property (nonatomic, assign) NSTimeInterval lastSuccessfulHeartbeat;
@property (nonatomic, assign) NSInteger consecutiveFailures;
@property (nonatomic, strong) dispatch_source_t heartbeatTimer;
@end

@implementation LiveSecurityGuard

+ (instancetype)shared {
    static LiveSecurityGuard *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[LiveSecurityGuard alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isAuthorized = NO;
        _consecutiveFailures = 0;
        _expiresAtTimestamp = 0;
    }
    return self;
}

+ (BOOL)isSessionAuthorized {
    LiveSecurityGuard *guard = [self shared];
    if (!guard.isAuthorized || guard.activeToken.length == 0) {
        return NO;
    }
    if (guard.expiresAtTimestamp > 0 && [[NSDate date] timeIntervalSince1970] > guard.expiresAtTimestamp) {
        [self enforceLockdownWithReason:@"License has expired."];
        return NO;
    }
    return YES;
}

+ (void)setAuthorizedSessionWithKey:(NSString *)key token:(NSString *)token expiresAt:(NSNumber *)expiresAt {
    LiveSecurityGuard *guard = [self shared];
    guard.isAuthorized = YES;
    guard.activeKey = key;
    guard.activeToken = token;
    guard.consecutiveFailures = 0;
    guard.lastSuccessfulHeartbeat = [[NSDate date] timeIntervalSince1970];
    if (expiresAt && [expiresAt isKindOfClass:[NSNumber class]] && [expiresAt doubleValue] > 0) {
        guard.expiresAtTimestamp = [expiresAt doubleValue];
    } else {
        guard.expiresAtTimestamp = 0; // Lifetime
    }
    [self startHeartbeatTimer];
}

+ (void)enforceLockdownWithReason:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        LiveSecurityGuard *guard = [self shared];
        guard.isAuthorized = NO;
        guard.activeToken = nil;
        [self stopHeartbeatTimer];
        
        // 1. Terminate cheat engines
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            UIViewController *root = w.rootViewController;
            if (root) {
                if ([root respondsToSelector:@selector(_homeStopCheatBackend)]) {
                    [root performSelector:@selector(_homeStopCheatBackend)];
                }
                for (UIViewController *child in root.childViewControllers) {
                    if ([child respondsToSelector:@selector(_homeStopCheatBackend)]) {
                        [child performSelector:@selector(_homeStopCheatBackend)];
                    }
                }
            }
            // 2. Force turn off all switches
            [self disableAllSwitchesInView:w];
        }
        
        // 3. Reshow Auth Gate with Lockout reason
        [[AuthGateManager shared] reshowLockdownGateWithReason:reason];
    });
}

+ (void)disableAllSwitchesInView:(UIView *)view {
    if ([view isKindOfClass:[UISwitch class]]) {
        [(UISwitch *)view setOn:NO animated:NO];
    }
    for (UIView *sub in view.subviews) {
        [self disableAllSwitchesInView:sub];
    }
}

+ (void)startHeartbeatTimer {
    LiveSecurityGuard *guard = [self shared];
    [self stopHeartbeatTimer];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    guard.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    // Ping live server every 30 seconds
    dispatch_source_set_timer(guard.heartbeatTimer, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), 30 * NSEC_PER_SEC, 5 * NSEC_PER_SEC);
    
    dispatch_source_set_event_handler(guard.heartbeatTimer, ^{
        [self sendHeartbeatPing];
    });
    dispatch_resume(guard.heartbeatTimer);
}

+ (void)stopHeartbeatTimer {
    LiveSecurityGuard *guard = [self shared];
    if (guard.heartbeatTimer) {
        dispatch_source_cancel(guard.heartbeatTimer);
        guard.heartbeatTimer = nil;
    }
}

+ (void)sendHeartbeatPing {
    LiveSecurityGuard *guard = [self shared];
    if (!guard.isAuthorized || !guard.activeKey || !guard.activeToken) return;
    
    NSString *hwid = [AuthStorage getDeviceHWID];
    NSDictionary *payload = @{
        @"key": guard.activeKey,
        @"hwid": hwid,
        @"token": guard.activeToken
    };
    
    NSError *err;
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&err];
    if (!data) return;
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:AUTH_HEARTBEAT_URL]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:data];
    [req setTimeoutInterval:10.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable resData, NSURLResponse * _Nullable response, NSError * _Nullable netErr) {
        if (netErr || !resData) {
            guard.consecutiveFailures++;
            // 3 missed heartbeats = 90 seconds offline / server blocked -> Dead Man's Switch trips
            if (guard.consecutiveFailures >= 3) {
                [self enforceLockdownWithReason:@"Server connection lost. Realtime internet connection required."];
            }
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:resData options:0 error:nil];
        BOOL valid = [json[@"valid"] boolValue];
        if (!valid) {
            NSString *code = json[@"code"] ?: @"REVOKED";
            NSString *msg = [NSString stringWithFormat:@"Access Terminated: %@", code];
            [self enforceLockdownWithReason:msg];
            return;
        }
        
        // Heartbeat passed cleanly
        guard.consecutiveFailures = 0;
        guard.lastSuccessfulHeartbeat = [[NSDate date] timeIntervalSince1970];
    }];
    [task resume];
}

@end

// ==========================================
// Auth Gate View Controller
// ==========================================
@interface AuthGateViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *keyTextField;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIButton *supportButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *hwidLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, copy) void (^onSuccessBlock)(void);
@property (nonatomic, copy) NSString *initialErrorReason;
@end

@implementation AuthGateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];

    [self setupUI];
    
    if (self.initialErrorReason && self.initialErrorReason.length > 0) {
        self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
        self.statusLabel.text = self.initialErrorReason;
    } else {
        // Auto validate if key exists
        NSString *savedKey = [AuthStorage getStringForKey:KEYCHAIN_KEY];
        if (savedKey && savedKey.length > 0) {
            self.keyTextField.text = savedKey;
            [self performAuthWithKey:savedKey isAutoLogin:YES];
        }
    }
}

- (void)setupUI {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];
    
    CGFloat cardWidth = MIN(self.view.bounds.size.width - 40, 360);
    CGFloat cardHeight = 360;
    
    self.cardView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - cardWidth)/2, (self.view.bounds.size.height - cardHeight)/2, cardWidth, cardHeight)];
    self.cardView.backgroundColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.15 alpha:0.98];
    self.cardView.layer.cornerRadius = 16;
    self.cardView.layer.borderColor = [UIColor colorWithRed:0.25 green:0.30 blue:0.45 alpha:0.45].CGColor;
    self.cardView.layer.borderWidth = 1.0;
    self.cardView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.cardView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 24, cardWidth - 40, 28)];
    titleLabel.text = APP_TITLE;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightHeavy];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 52, cardWidth - 40, 18)];
    subLabel.text = APP_SUBTITLE;
    subLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    subLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    subLabel.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:subLabel];
    
    NSString *hwid = [AuthStorage getDeviceHWID];
    NSString *shortHWID = hwid.length > 18 ? [NSString stringWithFormat:@"%@...%@", [hwid substringToIndex:8], [hwid substringFromIndex:hwid.length-6]] : hwid;
    
    self.hwidLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 82, cardWidth - 40, 28)];
    self.hwidLabel.text = [NSString stringWithFormat:@"HWID: %@", shortHWID];
    self.hwidLabel.textColor = [UIColor colorWithRed:0.5 green:0.6 blue:0.9 alpha:1.0];
    self.hwidLabel.font = [UIFont fontWithName:@"Menlo" size:11] ?: [UIFont systemFontOfSize:11];
    self.hwidLabel.textAlignment = NSTextAlignmentCenter;
    self.hwidLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.4];
    self.hwidLabel.layer.cornerRadius = 6;
    self.hwidLabel.clipsToBounds = YES;
    self.hwidLabel.userInteractionEnabled = YES;
    
    UITapGestureRecognizer *hwidTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyHWID)];
    [self.hwidLabel addGestureRecognizer:hwidTap];
    [self.cardView addSubview:self.hwidLabel];
    
    self.keyTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 122, cardWidth - 40, 48)];
    self.keyTextField.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.10 alpha:1.0];
    self.keyTextField.textColor = [UIColor whiteColor];
    self.keyTextField.font = [UIFont fontWithName:@"Menlo-Bold" size:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.keyTextField.placeholder = @"EFF-XXXX-XXXX-XXXX";
    self.keyTextField.textAlignment = NSTextAlignmentCenter;
    self.keyTextField.layer.cornerRadius = 10;
    self.keyTextField.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    self.keyTextField.layer.borderWidth = 1.0;
    self.keyTextField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyTextField.delegate = self;
    self.keyTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"ENTER LICENSE KEY" attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.4 alpha:1.0]}];
    
    // Inline Paste Icon button on the right side of the text field
    UIButton *pasteIconBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteIconBtn.frame = CGRectMake(0, 0, 42, 48);
    if (@available(iOS 13.0, *)) {
        UIImage *img = [UIImage systemImageNamed:@"doc.on.clipboard"];
        [pasteIconBtn setImage:img forState:UIControlStateNormal];
        pasteIconBtn.tintColor = [UIColor colorWithRed:0.6 green:0.7 blue:1.0 alpha:1.0];
    } else {
        [pasteIconBtn setTitle:@"📋" forState:UIControlStateNormal];
    }
    [pasteIconBtn addTarget:self action:@selector(pasteKeyAction) forControlEvents:UIControlEventTouchUpInside];
    self.keyTextField.rightView = pasteIconBtn;
    self.keyTextField.rightViewMode = UITextFieldViewModeAlways;
    [self.cardView addSubview:self.keyTextField];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 178, cardWidth - 40, 36)];
    self.statusLabel.text = @"";
    self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [self.cardView addSubview:self.statusLabel];
    
    self.loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.loginButton.frame = CGRectMake(20, 222, cardWidth - 40, 48);
    self.loginButton.backgroundColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0];
    [self.loginButton setTitle:@"ACTIVATE" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    self.loginButton.layer.cornerRadius = 10;
    [self.loginButton addTarget:self action:@selector(loginButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.loginButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(cardWidth / 2, 246);
    self.spinner.color = [UIColor whiteColor];
    self.spinner.hidesWhenStopped = YES;
    [self.cardView addSubview:self.spinner];
    
    self.supportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.supportButton.frame = CGRectMake(20, 282, cardWidth - 40, 32);
    [self.supportButton setTitle:@"Get Key / Contact Support" forState:UIControlStateNormal];
    [self.supportButton setTitleColor:[UIColor colorWithWhite:0.6 alpha:1.0] forState:UIControlStateNormal];
    self.supportButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    [self.supportButton addTarget:self action:@selector(openSupport) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.supportButton];
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)copyHWID {
    NSString *hwid = [AuthStorage getDeviceHWID];
    [UIPasteboard generalPasteboard].string = hwid;
    self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.8 blue:0.5 alpha:1.0];
    self.statusLabel.text = @"HWID Copied to Clipboard!";
}

- (void)pasteKeyAction {
    NSString *clip = [UIPasteboard generalPasteboard].string;
    if (clip && clip.length > 0) {
        self.keyTextField.text = [clip stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

- (void)openSupport {
    NSURL *url = [NSURL URLWithString:SUPPORT_URL];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

- (void)setLoading:(BOOL)loading {
    if (loading) {
        [self.spinner startAnimating];
        [self.loginButton setTitle:@"" forState:UIControlStateNormal];
        self.loginButton.enabled = NO;
    } else {
        [self.spinner stopAnimating];
        [self.loginButton setTitle:@"ACTIVATE" forState:UIControlStateNormal];
        self.loginButton.enabled = YES;
    }
}

- (void)loginButtonTapped {
    [self dismissKeyboard];
    NSString *key = [self.keyTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (key.length == 0) {
        self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
        self.statusLabel.text = @"Please enter a valid license key.";
        return;
    }
    [self performAuthWithKey:key isAutoLogin:NO];
}

- (void)performAuthWithKey:(NSString *)key isAutoLogin:(BOOL)isAutoLogin {
    [self setLoading:YES];
    self.statusLabel.text = @"Validating live license...";
    self.statusLabel.textColor = [UIColor colorWithWhite:0.8 alpha:1.0];
    
    NSString *hwid = [AuthStorage getDeviceHWID];
    NSString *deviceName = [[UIDevice currentDevice] name] ?: @"iOS Device";
    
    NSDictionary *payload = @{
        @"key": key,
        @"hwid": hwid,
        @"device_name": deviceName,
        @"app_version": @"1.0"
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:AUTH_VALIDATE_URL]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:jsonData];
    [request setTimeoutInterval:10.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO];
            
            if (error) {
                self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
                self.statusLabel.text = [NSString stringWithFormat:@"Connection Error: %@", error.localizedDescription];
                return;
            }
            
            if (!data) {
                self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
                self.statusLabel.text = @"Empty response from server.";
                return;
            }
            
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            BOOL success = [json[@"success"] boolValue];
            NSString *msg = json[@"message"] ?: @"Unknown response";
            
            if (success) {
                [AuthStorage saveString:key forKey:KEYCHAIN_KEY];
                NSDictionary *dataDict = json[@"data"];
                NSString *remainStr = dataDict[@"remaining_formatted"] ?: @"Valid";
                NSString *token = dataDict[@"token"];
                NSNumber *expiresAt = dataDict[@"expires_at"];
                
                // Initialize LiveSecurityGuard
                [LiveSecurityGuard setAuthorizedSessionWithKey:key token:token expiresAt:expiresAt];
                
                self.statusLabel.textColor = [UIColor colorWithRed:0.2 green:0.85 blue:0.45 alpha:1.0];
                self.statusLabel.text = [NSString stringWithFormat:@"Access Granted! (%@)", remainStr];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (self.onSuccessBlock) {
                        self.onSuccessBlock();
                    }
                });
            } else {
                self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
                self.statusLabel.text = msg;
            }
        });
    }];
    
    [task resume];
}

@end

// ==========================================
// Auth Gate Manager Implementation
// ==========================================
@implementation AuthGateManager

+ (instancetype)shared {
    static AuthGateManager *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[AuthGateManager alloc] init];
    });
    return inst;
}

- (void)startAuthGate {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIViewController installThemeHooks];
        [self showAuthWindowWithError:nil];
    });
}

- (void)reshowLockdownGateWithReason:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showAuthWindowWithError:reason];
    });
}

- (void)showAuthWindowWithError:(NSString *)errorReason {
    if (!self.authWindow) {
        UIScreen *mainScreen = [UIScreen mainScreen];
        self.authWindow = [[UIWindow alloc] initWithFrame:mainScreen.bounds];
        self.authWindow.windowLevel = UIWindowLevelAlert + 100;
    }
    
    AuthGateViewController *vc = [[AuthGateViewController alloc] init];
    vc.initialErrorReason = errorReason;
    __weak typeof(self) weakSelf = self;
    vc.onSuccessBlock = ^{
        [UIView animateWithDuration:0.4 animations:^{
            weakSelf.authWindow.alpha = 0.0;
        } completion:^(BOOL finished) {
            UIWindow *appWindow = nil;
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w != weakSelf.authWindow && !w.hidden) {
                    appWindow = w;
                    break;
                }
            }
            if (appWindow) {
                [appWindow makeKeyAndVisible];
                if (appWindow.rootViewController) {
                    [MainMenuThemeEngine styleViewController:appWindow.rootViewController];
                }
            }
            weakSelf.authWindow.hidden = YES;
            weakSelf.authWindow.rootViewController = nil;
            weakSelf.authWindow = nil;
        }];
    };
    
    self.authWindow.rootViewController = vc;
    self.authWindow.alpha = 1.0;
    self.authWindow.hidden = NO;
    [self.authWindow makeKeyAndVisible];
}

@end

// ==========================================
// Constructor Hook
// ==========================================
__attribute__((constructor))
static void InitAuthGate() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[AuthGateManager shared] startAuthGate];
    }];
}
