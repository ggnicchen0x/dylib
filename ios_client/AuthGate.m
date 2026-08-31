#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define BACKEND_SERVER_URL @"http://fi14.bot-hosting.cloud:25981/server.php"
#define BACKEND_BYTES_URL  @"http://fi14.bot-hosting.cloud:25981/bytes.php"
#define LICENSE_KEY_STORAGE @"external.license.key"

#pragma mark - FluckAuthCore & ProxyPatchBytes Interception

@interface FluckAuthCoreHook : NSObject
@end

@implementation FluckAuthCoreHook

- (NSString *)hooked_savedKey {
    NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.key"] ?:
                    [[NSUserDefaults standardUserDefaults] stringForKey:LICENSE_KEY_STORAGE];
    return key ?: @"PROXY-VIP-2012-42DF";
}

- (NSString *)hooked_packageName {
    NSString *pkg = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.package"] ?:
                    [[NSUserDefaults standardUserDefaults] stringForKey:@"proxy.package.name"];
    if (!pkg || pkg.length == 0 || [pkg isEqualToString:@"—"]) {
        pkg = @"Premium";
    }
    return pkg;
}

- (NSString *)hooked_expiryText {
    NSString *exp = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.expiry"] ?:
                    [[NSUserDefaults standardUserDefaults] stringForKey:@"external.license.expiry"];
    if (!exp || exp.length == 0 || [exp isEqualToString:@"Lifetime"] || [exp isEqualToString:@"—"]) {
        NSDate *oneMonthFromNow = [[NSDate date] dateByAddingTimeInterval:30 * 86400];
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        exp = [df stringFromDate:oneMonthFromNow];
        [[NSUserDefaults standardUserDefaults] setObject:exp forKey:@"fluck.license.expiry"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return exp;
}

@end

@interface ProxyPatchBytesHook : NSObject
@end

@implementation ProxyPatchBytesHook

+ (NSData *)hooked_bytesForPatch:(NSString *)patchName {
    if (!patchName || patchName.length == 0) return nil;
    
    NSString *escapedPatch = [patchName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *urlString = [NSString stringWithFormat:@"%@?patch=%@", BACKEND_BYTES_URL, escapedPatch];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:12.0];
    
    NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:LICENSE_KEY_STORAGE];
    if (key && key.length > 0) {
        [request setValue:key forHTTPHeaderField:@"X-License-Key"];
    }
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    __block NSData *resultData = nil;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error && data && data.length > 100) {
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            if (httpResp.statusCode == 200) {
                resultData = data;
            }
        }
        dispatch_semaphore_signal(sema);
    }];
    [task resume];
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)));
    
    if (resultData) {
        NSLog(@"[AuthGate] Successfully downloaded patch '%@' (%lu bytes) from backend server", patchName, (unsigned long)resultData.length);
    } else {
        NSLog(@"[AuthGate] Failed to fetch patch '%@' from backend server", patchName);
    }
    return resultData;
}

- (NSData *)instance_hooked_bytesForPatch:(NSString *)patchName {
    return [ProxyPatchBytesHook hooked_bytesForPatch:patchName];
}

@end

#pragma mark - Unified VIP Dark Theme Engine

@interface VIPThemeManager : NSObject
+ (UIColor *)colorObsidianBg;
+ (UIColor *)colorCardSlate;
+ (UIColor *)colorCardBorder;
+ (UIColor *)colorAccentBlue;
+ (UIColor *)colorCyanHighlight;
+ (UIColor *)colorTextPrimary;
+ (UIColor *)colorTextSecondary;
+ (UIColor *)colorInputContainer;
+ (void)applyVIPThemeToViewController:(UIViewController *)vc;
+ (void)applyVIPThemeToView:(UIView *)rootView;
+ (void)applyVIPThemeToTabBar:(UITabBar *)tabBar;
+ (void)applyVIPThemeToImGuiMenu:(UIView *)menuView;
+ (void)installThemeHooks;
@end

#pragma mark - RootViewController Table View Cell Swizzle

@interface RootViewControllerCellHook : NSObject
@end

@implementation RootViewControllerCellHook

- (UITableViewCell *)hooked_tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [self hooked_tableView:tableView cellForRowAtIndexPath:indexPath];
    if (!cell) return cell;
    
    cell.backgroundColor = [VIPThemeManager colorCardSlate];
    cell.contentView.backgroundColor = [VIPThemeManager colorCardSlate];
    cell.textLabel.textColor = [VIPThemeManager colorTextPrimary];
    cell.detailTextLabel.textColor = [VIPThemeManager colorTextSecondary];
    
    if (indexPath.section == 0) {
        // Section 0: Account Card
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Package Name";
            NSString *pkg = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.package"] ?: @"Premium";
            cell.detailTextLabel.text = pkg;
            cell.detailTextLabel.textColor = [VIPThemeManager colorCyanHighlight];
            cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:14.0];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Key";
            NSString *key = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.key"] ?:
                            [[NSUserDefaults standardUserDefaults] stringForKey:LICENSE_KEY_STORAGE] ?:
                            @"PROXY-VIP-2012-42DF";
            cell.detailTextLabel.text = key;
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextPrimary];
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"Expires On";
            NSString *exp = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.expiry"] ?:
                            [[NSUserDefaults standardUserDefaults] stringForKey:@"external.license.expiry"];
            if (!exp || exp.length == 0 || [exp isEqualToString:@"Lifetime"] || [exp isEqualToString:@"—"]) {
                NSDate *oneMonthFromNow = [[NSDate date] dateByAddingTimeInterval:30 * 86400];
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                exp = [df stringFromDate:oneMonthFromNow];
                [[NSUserDefaults standardUserDefaults] setObject:exp forKey:@"fluck.license.expiry"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            cell.detailTextLabel.text = exp;
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextSecondary];
        } else if (indexPath.row == 3) {
            if ([cell.textLabel.text containsString:@"Logout"] || [cell.detailTextLabel.text containsString:@"Logout"]) {
                cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.28 blue:0.28 alpha:1.0];
            }
        }
    } else if (indexPath.section == 1) {
        // Section 1: Device Diagnostics
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Device Name";
            NSString *devName = [UIDevice currentDevice].name;
            if (!devName || devName.length == 0 || [devName isEqualToString:@"—"]) {
                devName = @"iPhone";
            }
            cell.detailTextLabel.text = devName;
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextPrimary];
        } else if (indexPath.row == 1) {
            cell.textLabel.text = @"Device Model";
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextSecondary];
        } else if (indexPath.row == 2) {
            cell.textLabel.text = @"iOS Version";
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextSecondary];
        } else if (indexPath.row == 3) {
            cell.textLabel.text = @"Battery Info";
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextSecondary];
        } else if (indexPath.row == 4) {
            cell.textLabel.text = @"Jailbreak";
            cell.detailTextLabel.text = @"No";
            cell.detailTextLabel.textColor = [VIPThemeManager colorTextSecondary];
        }
    }
    
    return cell;
}

@end

static void InstallAuthHooks(void) {
    Class coreClass = NSClassFromString(@"FluckAuthCore");
    if (coreClass) {
        Method origKey = class_getInstanceMethod(coreClass, NSSelectorFromString(@"savedKey"));
        Method hookKey = class_getInstanceMethod([FluckAuthCoreHook class], @selector(hooked_savedKey));
        if (origKey && hookKey) {
            method_setImplementation(origKey, method_getImplementation(hookKey));
            NSLog(@"[AuthGate] FluckAuthCore::savedKey intercepted");
        }
        
        Method origPkg = class_getInstanceMethod(coreClass, NSSelectorFromString(@"packageName"));
        Method hookPkg = class_getInstanceMethod([FluckAuthCoreHook class], @selector(hooked_packageName));
        if (origPkg && hookPkg) {
            method_setImplementation(origPkg, method_getImplementation(hookPkg));
            NSLog(@"[AuthGate] FluckAuthCore::packageName intercepted -> Premium");
        }
        
        Method origExp = class_getInstanceMethod(coreClass, NSSelectorFromString(@"expiryText"));
        Method hookExp = class_getInstanceMethod([FluckAuthCoreHook class], @selector(hooked_expiryText));
        if (origExp && hookExp) {
            method_setImplementation(origExp, method_getImplementation(hookExp));
            NSLog(@"[AuthGate] FluckAuthCore::expiryText intercepted -> Backend 1-Month Expiry");
        }
    }
    
    Class patchClass = NSClassFromString(@"ProxyPatchBytes");
    if (patchClass) {
        Method origClassMethod = class_getClassMethod(patchClass, NSSelectorFromString(@"bytesForPatch:"));
        Method hookClassMethod = class_getClassMethod([ProxyPatchBytesHook class], @selector(hooked_bytesForPatch:));
        if (origClassMethod && hookClassMethod) {
            method_setImplementation(origClassMethod, method_getImplementation(hookClassMethod));
            NSLog(@"[AuthGate] ProxyPatchBytes +bytesForPatch: intercepted");
        }
        Method origInstMethod = class_getInstanceMethod(patchClass, NSSelectorFromString(@"bytesForPatch:"));
        Method hookInstMethod = class_getInstanceMethod([ProxyPatchBytesHook class], @selector(instance_hooked_bytesForPatch:));
        if (origInstMethod && hookInstMethod) {
            method_setImplementation(origInstMethod, method_getImplementation(hookInstMethod));
            NSLog(@"[AuthGate] ProxyPatchBytes -bytesForPatch: intercepted");
        }
    }
    
    Class rootClass = NSClassFromString(@"RootViewController");
    if (rootClass) {
        Method origCell = class_getInstanceMethod(rootClass, NSSelectorFromString(@"tableView:cellForRowAtIndexPath:"));
        Method hookCell = class_getInstanceMethod([RootViewControllerCellHook class], @selector(hooked_tableView:cellForRowAtIndexPath:));
        if (origCell && hookCell) {
            method_exchangeImplementations(origCell, hookCell);
            NSLog(@"[AuthGate] RootViewController tableView:cellForRowAtIndexPath: swizzled for Account & Theme");
        }
    }
}

@implementation VIPThemeManager

+ (UIColor *)colorObsidianBg {
    return [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:0.98];
}

+ (UIColor *)colorCardSlate {
    return [UIColor colorWithRed:0.11 green:0.13 blue:0.18 alpha:0.95];
}

+ (UIColor *)colorCardBorder {
    return [UIColor colorWithRed:0.22 green:0.28 blue:0.40 alpha:0.60];
}

+ (UIColor *)colorAccentBlue {
    return [UIColor colorWithRed:0.20 green:0.50 blue:0.95 alpha:1.0];
}

+ (UIColor *)colorCyanHighlight {
    return [UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:1.0];
}

+ (UIColor *)colorTextPrimary {
    return [UIColor whiteColor];
}

+ (UIColor *)colorTextSecondary {
    return [UIColor colorWithRed:0.60 green:0.65 blue:0.75 alpha:1.0];
}

+ (UIColor *)colorInputContainer {
    return [UIColor colorWithRed:0.07 green:0.08 blue:0.12 alpha:0.95];
}

+ (void)applyVIPThemeToViewController:(UIViewController *)vc {
    if (!vc || !vc.isViewLoaded) return;
    
    if (@available(iOS 13.0, *)) {
        vc.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    vc.view.backgroundColor = [self colorObsidianBg];
    
    BOOL hasGradient = NO;
    for (CALayer *sub in vc.view.layer.sublayers) {
        if ([sub isKindOfClass:[CAGradientLayer class]] && [sub.name isEqualToString:@"VIPGradient"]) {
            hasGradient = YES;
            sub.frame = vc.view.bounds;
            break;
        }
    }
    
    if (!hasGradient) {
        CAGradientLayer *gradient = [CAGradientLayer layer];
        gradient.name = @"VIPGradient";
        gradient.frame = vc.view.bounds;
        gradient.colors = @[
            (id)[UIColor colorWithRed:0.08 green:0.12 blue:0.20 alpha:1.0].CGColor,
            (id)[UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:1.0].CGColor
        ];
        gradient.startPoint = CGPointMake(0.5, 0.0);
        gradient.endPoint = CGPointMake(0.5, 1.0);
        [vc.view.layer insertSublayer:gradient atIndex:0];
    }
    
    [self applyVIPThemeToView:vc.view];
    
    if (vc.tabBarController) {
        [self applyVIPThemeToTabBar:vc.tabBarController.tabBar];
    }
    if (vc.navigationController) {
        vc.navigationController.navigationBar.barTintColor = [self colorObsidianBg];
        vc.navigationController.navigationBar.tintColor = [self colorAccentBlue];
        vc.navigationController.navigationBar.titleTextAttributes = @{
            NSForegroundColorAttributeName: [self colorTextPrimary],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:18.0]
        };
    }
}

+ (void)applyVIPThemeToView:(UIView *)rootView {
    if (!rootView) return;
    
    for (UIView *subview in rootView.subviews) {
        if ([subview isKindOfClass:[UISegmentedControl class]]) {
            UISegmentedControl *seg = (UISegmentedControl *)subview;
            seg.backgroundColor = [self colorInputContainer];
            if (@available(iOS 13.0, *)) {
                seg.selectedSegmentTintColor = [self colorAccentBlue];
            }
            seg.layer.cornerRadius = 10.0;
            seg.layer.borderWidth = 1.0;
            seg.layer.borderColor = [self colorCardBorder].CGColor;
            seg.clipsToBounds = YES;
            
            [seg setTitleTextAttributes:@{
                NSForegroundColorAttributeName: [self colorTextSecondary],
                NSFontAttributeName: [UIFont systemFontOfSize:13.0]
            } forState:UIControlStateNormal];
            
            [seg setTitleTextAttributes:@{
                NSForegroundColorAttributeName: [self colorTextPrimary],
                NSFontAttributeName: [UIFont boldSystemFontOfSize:13.0]
            } forState:UIControlStateSelected];
            continue;
        }
        
        if ([subview isKindOfClass:[UISwitch class]]) {
            UISwitch *sw = (UISwitch *)subview;
            sw.onTintColor = [self colorAccentBlue];
            sw.thumbTintColor = [UIColor whiteColor];
            continue;
        }
        
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *btn = (UIButton *)subview;
            NSString *title = [btn titleForState:UIControlStateNormal];
            
            if ([title isEqualToString:@"STOP"] || [title isEqualToString:@"START"]) {
                btn.backgroundColor = [self colorAccentBlue];
                [btn setTitleColor:[self colorTextPrimary] forState:UIControlStateNormal];
                btn.layer.cornerRadius = 10.0;
                btn.layer.shadowColor = [self colorAccentBlue].CGColor;
                btn.layer.shadowOffset = CGSizeMake(0, 3);
                btn.layer.shadowRadius = 8.0;
                btn.layer.shadowOpacity = 0.5;
            } else if ([title isEqualToString:@"Reset"] || [title containsString:@"Reset"]) {
                btn.backgroundColor = [self colorCardSlate];
                [btn setTitleColor:[self colorCyanHighlight] forState:UIControlStateNormal];
                btn.layer.cornerRadius = 10.0;
                btn.layer.borderWidth = 1.0;
                btn.layer.borderColor = [self colorCardBorder].CGColor;
            }
            continue;
        }
        
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *lbl = (UILabel *)subview;
            NSString *txt = lbl.text;
            if (txt && (
                [txt containsString:@"sandbox escaped"] ||
                [txt containsString:@"patch bytes"] ||
                [txt containsString:@"unavailable"] ||
                [txt containsString:@"server/key"] ||
                [txt containsString:@"Enter your"]
            )) {
                lbl.textColor = [self colorTextSecondary];
            } else {
                lbl.textColor = [self colorTextPrimary];
            }
            continue;
        }
        
        if (subview.layer.cornerRadius > 0 && subview != rootView) {
            subview.backgroundColor = [self colorCardSlate];
            subview.layer.borderColor = [self colorCardBorder].CGColor;
            subview.layer.borderWidth = 1.0;
            subview.layer.shadowColor = [UIColor blackColor].CGColor;
            subview.layer.shadowOffset = CGSizeMake(0, 4);
            subview.layer.shadowRadius = 8.0;
            subview.layer.shadowOpacity = 0.35;
        }
        
        NSString *clsName = NSStringFromClass([subview class]);
        if ([clsName containsString:@"MenuUIView"] || [clsName containsString:@"MenuView"]) {
            [self applyVIPThemeToImGuiMenu:subview];
        }
        
        [self applyVIPThemeToView:subview];
    }
}

+ (void)applyVIPThemeToTabBar:(UITabBar *)tabBar {
    if (!tabBar) return;
    
    tabBar.barTintColor = [self colorObsidianBg];
    tabBar.backgroundColor = [self colorObsidianBg];
    tabBar.tintColor = [self colorAccentBlue];
    tabBar.unselectedItemTintColor = [self colorTextSecondary];
    
    if (@available(iOS 13.0, *)) {
        UITabBarAppearance *appearance = [[UITabBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [self colorObsidianBg];
        
        appearance.stackedLayoutAppearance.selected.iconColor = [self colorAccentBlue];
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = @{
            NSForegroundColorAttributeName: [self colorAccentBlue],
            NSFontAttributeName: [UIFont boldSystemFontOfSize:11.0]
        };
        appearance.stackedLayoutAppearance.normal.iconColor = [self colorTextSecondary];
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = @{
            NSForegroundColorAttributeName: [self colorTextSecondary],
            NSFontAttributeName: [UIFont systemFontOfSize:11.0]
        };
        
        tabBar.standardAppearance = appearance;
        if (@available(iOS 15.0, *)) {
            tabBar.scrollEdgeAppearance = appearance;
        }
    }
}

+ (void)applyVIPThemeToImGuiMenu:(UIView *)menuView {
    if (!menuView) return;
    
    menuView.backgroundColor = [self colorCardSlate];
    menuView.layer.cornerRadius = 16.0;
    menuView.layer.borderWidth = 1.0;
    menuView.layer.borderColor = [self colorCardBorder].CGColor;
    menuView.layer.shadowColor = [UIColor blackColor].CGColor;
    menuView.layer.shadowOffset = CGSizeMake(0, 8);
    menuView.layer.shadowRadius = 16.0;
    menuView.layer.shadowOpacity = 0.6;
    
    for (UIView *child in menuView.subviews) {
        if ([child isKindOfClass:[UILabel class]]) {
            ((UILabel *)child).textColor = [self colorTextPrimary];
        } else if ([child isKindOfClass:[UISwitch class]]) {
            ((UISwitch *)child).onTintColor = [self colorAccentBlue];
        } else if ([child isKindOfClass:[UISlider class]]) {
            UISlider *sl = (UISlider *)child;
            sl.minimumTrackTintColor = [self colorAccentBlue];
            sl.thumbTintColor = [UIColor whiteColor];
        }
    }
}

+ (void)installThemeHooks {
    [[NSUserDefaults standardUserDefaults] setObject:@"dark" forKey:@"proxy.theme.mode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"proxy.theme.changed" object:nil];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class vcClass = [UIViewController class];
        SEL origSel = @selector(viewWillAppear:);
        SEL hookSel = @selector(vip_viewWillAppear:);
        
        Method origMethod = class_getInstanceMethod(vcClass, origSel);
        Method hookMethod = class_getInstanceMethod(vcClass, hookSel);
        
        if (!hookMethod) {
            void (^hookBlock)(id, BOOL) = ^(id selfObj, BOOL animated) {
                SEL orig = @selector(viewWillAppear:);
                void (*origFunc)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))class_getMethodImplementation([UIViewController class], orig);
                if (origFunc) origFunc(selfObj, orig, animated);
                
                UIViewController *vc = (UIViewController *)selfObj;
                NSString *className = NSStringFromClass([vc class]);
                if ([className containsString:@"ProxyExploit"] ||
                    [className containsString:@"ProxyNoExploit"] ||
                    [className containsString:@"RootViewController"] ||
                    [className containsString:@"ProxyDebug"]) {
                    [VIPThemeManager applyVIPThemeToViewController:vc];
                }
            };
            
            IMP newImp = imp_implementationWithBlock(hookBlock);
            method_setImplementation(origMethod, newImp);
            NSLog(@"[VIPThemeManager] UIViewController viewWillAppear swizzled successfully.");
        }
    });
}

@end

#pragma mark - Custom VIP Login Gatekeeper Controller

@interface AuthGateViewController : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UIViewController *originalRootVC;
@end

@implementation AuthGateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupVIPUI];
    [self autoLoginIfKeySaved];
}

- (void)setupVIPUI {
    self.view.backgroundColor = [VIPThemeManager colorObsidianBg];
    
    CAGradientLayer *bgGradient = [CAGradientLayer layer];
    bgGradient.frame = [UIScreen mainScreen].bounds;
    bgGradient.colors = @[
        (id)[UIColor colorWithRed:0.07 green:0.10 blue:0.16 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:1.0].CGColor
    ];
    bgGradient.startPoint = CGPointMake(0.5, 0.0);
    bgGradient.endPoint = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:bgGradient atIndex:0];
    
    UIView *card = [[UIView alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [VIPThemeManager colorCardSlate];
    card.layer.cornerRadius = 20.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = [VIPThemeManager colorCardBorder].CGColor;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 10);
    card.layer.shadowRadius = 24.0;
    card.layer.shadowOpacity = 0.55;
    [self.view addSubview:card];
    
    UILabel *badge = [[UILabel alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.text = @"VIP ACCESS";
    badge.textColor = [VIPThemeManager colorCyanHighlight];
    badge.font = [UIFont boldSystemFontOfSize:11.0];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.backgroundColor = [UIColor colorWithRed:0.15 green:0.25 blue:0.40 alpha:0.40];
    badge.layer.cornerRadius = 8.0;
    badge.layer.masksToBounds = YES;
    [card addSubview:badge];
    
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = @"Authentication";
    title.textColor = [VIPThemeManager colorTextPrimary];
    title.font = [UIFont boldSystemFontOfSize:22.0];
    title.textAlignment = NSTextAlignmentCenter;
    [card addSubview:title];
    
    UILabel *subtitle = [[UILabel alloc] init];
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    subtitle.text = @"Enter your license key to activate your session";
    subtitle.textColor = [VIPThemeManager colorTextSecondary];
    subtitle.font = [UIFont systemFontOfSize:13.0];
    subtitle.textAlignment = NSTextAlignmentCenter;
    subtitle.numberOfLines = 0;
    [card addSubview:subtitle];
    
    UIView *inputContainer = [[UIView alloc] init];
    inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    inputContainer.backgroundColor = [VIPThemeManager colorInputContainer];
    inputContainer.layer.cornerRadius = 12.0;
    inputContainer.layer.borderWidth = 1.0;
    inputContainer.layer.borderColor = [VIPThemeManager colorCardBorder].CGColor;
    [card addSubview:inputContainer];
    
    self.keyField = [[UITextField alloc] init];
    self.keyField.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyField.placeholder = @"PROXY-XXXX-XXXX-XXXX";
    self.keyField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"PROXY-XXXX-XXXX-XXXX" attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.45 alpha:1.0]}];
    self.keyField.textColor = [VIPThemeManager colorTextPrimary];
    self.keyField.font = [UIFont fontWithName:@"Menlo" size:14.0] ?: [UIFont systemFontOfSize:14.0];
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.returnKeyType = UIReturnKeyDone;
    self.keyField.delegate = self;
    [inputContainer addSubview:self.keyField];
    
    UIButton *pasteBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    pasteBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [pasteBtn setTitle:@"PASTE" forState:UIControlStateNormal];
    [pasteBtn setTitleColor:[VIPThemeManager colorCyanHighlight] forState:UIControlStateNormal];
    pasteBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [pasteBtn addTarget:self action:@selector(pasteTapped) forControlEvents:UIControlEventTouchUpInside];
    [inputContainer addSubview:pasteBtn];
    
    self.activateButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton setTitle:@"ACTIVATE LICENSE" forState:UIControlStateNormal];
    [self.activateButton setTitleColor:[VIPThemeManager colorTextPrimary] forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    self.activateButton.backgroundColor = [VIPThemeManager colorAccentBlue];
    self.activateButton.layer.cornerRadius = 14.0;
    self.activateButton.layer.shadowColor = [VIPThemeManager colorAccentBlue].CGColor;
    self.activateButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.activateButton.layer.shadowRadius = 12.0;
    self.activateButton.layer.shadowOpacity = 0.5;
    [self.activateButton addTarget:self action:@selector(activateTapped) forControlEvents:UIControlEventTouchUpInside];
    [card addSubview:self.activateButton];
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"";
    self.statusLabel.textColor = [VIPThemeManager colorTextSecondary];
    self.statusLabel.font = [UIFont systemFontOfSize:12.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 0;
    [card addSubview:self.statusLabel];
    
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [card addSubview:self.activityIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [card.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor constant:-20],
        [card.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [card.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        
        [badge.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        [badge.centerXAnchor constraintEqualToAnchor:card.centerXAnchor],
        [badge.widthAnchor constraintEqualToConstant:96],
        [badge.heightAnchor constraintEqualToConstant:24],
        
        [title.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:12],
        [title.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [subtitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [subtitle.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        
        [inputContainer.topAnchor constraintEqualToAnchor:subtitle.bottomAnchor constant:24],
        [inputContainer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [inputContainer.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [inputContainer.heightAnchor constraintEqualToConstant:50],
        
        [self.keyField.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:14],
        [self.keyField.centerYAnchor constraintEqualToAnchor:inputContainer.centerYAnchor],
        [self.keyField.trailingAnchor constraintEqualToAnchor:pasteBtn.leadingAnchor constant:-8],
        
        [pasteBtn.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-14],
        [pasteBtn.centerYAnchor constraintEqualToAnchor:inputContainer.centerYAnchor],
        [pasteBtn.widthAnchor constraintEqualToConstant:54],
        
        [self.activateButton.topAnchor constraintEqualToAnchor:inputContainer.bottomAnchor constant:18],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [self.activateButton.heightAnchor constraintEqualToConstant:50],
        
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:14],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [self.statusLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],
        
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.activateButton.centerYAnchor],
        [self.activityIndicator.trailingAnchor constraintEqualToAnchor:self.activateButton.trailingAnchor constant:-20]
    ]];
}

- (void)pasteTapped {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (pasteboard.string) {
        self.keyField.text = [pasteboard.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self activateTapped];
    return YES;
}

- (void)autoLoginIfKeySaved {
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"fluck.license.key"] ?:
                         [[NSUserDefaults standardUserDefaults] stringForKey:LICENSE_KEY_STORAGE];
    if (savedKey && savedKey.length > 0) {
        self.keyField.text = savedKey;
        [self validateKeyWithServer:savedKey isAutoLogin:YES];
    }
}

- (void)activateTapped {
    [self.view endEditing:YES];
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!key || key.length == 0) {
        [self updateStatus:@"Please enter a valid license key." isError:YES];
        return;
    }
    [self validateKeyWithServer:key isAutoLogin:NO];
}

- (void)updateStatus:(NSString *)msg isError:(BOOL)isError {
    self.statusLabel.text = msg;
    self.statusLabel.textColor = isError ? [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0] : [VIPThemeManager colorCyanHighlight];
}

- (void)validateKeyWithServer:(NSString *)key isAutoLogin:(BOOL)isAuto {
    [self.activityIndicator startAnimating];
    self.activateButton.enabled = NO;
    self.activateButton.alpha = 0.7;
    [self updateStatus:isAuto ? @"Validating saved license..." : @"Connecting to auth server..." isError:NO];
    
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"PROXY-VIP-DEVICE";
    
    NSURL *url = [NSURL URLWithString:BACKEND_SERVER_URL];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setTimeoutInterval:10.0];
    
    NSDictionary *bodyDict = @{
        @"license_key": key,
        @"key": key,
        @"udid": udid
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:nil];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            self.activateButton.enabled = YES;
            self.activateButton.alpha = 1.0;
            
            if (error || !data) {
                [self updateStatus:@"Server unreachable. Please check your internet connection." isError:YES];
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            if (httpResponse.statusCode == 200 && responseString && [responseString containsString:@"momo"]) {
                NSString *expiry = json[@"expiry"] ?: json[@"expires_at"] ?: json[@"fluck.license.expiry"];
                if (!expiry || expiry.length == 0 || [expiry isEqualToString:@"Lifetime"]) {
                    NSDate *oneMonthFromNow = [[NSDate date] dateByAddingTimeInterval:30 * 86400];
                    NSDateFormatter *df = [[NSDateFormatter alloc] init];
                    [df setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                    expiry = [df stringFromDate:oneMonthFromNow];
                }
                NSString *pkgName = json[@"package_name"] ?: json[@"package"] ?: @"Premium";
                
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:LICENSE_KEY_STORAGE];
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:@"fluck.license.key"];
                [[NSUserDefaults standardUserDefaults] setObject:expiry forKey:@"fluck.license.expiry"];
                [[NSUserDefaults standardUserDefaults] setObject:pkgName forKey:@"fluck.license.package"];
                [[NSUserDefaults standardUserDefaults] setObject:pkgName forKey:@"proxy.package.name"];
                [[NSUserDefaults standardUserDefaults] setObject:@"dark" forKey:@"proxy.theme.mode"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                
                Class coreClass = NSClassFromString(@"FluckAuthCore");
                if (coreClass) {
                    id sharedCore = [coreClass performSelector:NSSelectorFromString(@"shared")];
                    if (sharedCore && [sharedCore respondsToSelector:NSSelectorFromString(@"saveKey:")]) {
                        [sharedCore performSelector:NSSelectorFromString(@"saveKey:") withObject:key];
                    }
                    if (sharedCore && [sharedCore respondsToSelector:NSSelectorFromString(@"markGatePassed")]) {
                        [sharedCore performSelector:NSSelectorFromString(@"markGatePassed")];
                    }
                }
                
                [self updateStatus:@"Activated successfully! Launching..." isError:NO];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self finishAuthentication];
                });
            } else if (httpResponse.statusCode == 403) {
                [self updateStatus:@"License key has expired, is revoked, or bound to another device." isError:YES];
            } else if (httpResponse.statusCode == 401) {
                [self updateStatus:@"Invalid license key. Please check your key." isError:YES];
            } else {
                [self updateStatus:@"Key verification failed. Access denied." isError:YES];
            }
        });
    }];
    
    [task resume];
}

- (void)finishAuthentication {
    [UIView animateWithDuration:0.3 animations:^{
        self.view.alpha = 0.0;
        self.view.transform = CGAffineTransformMakeScale(1.05, 1.05);
    } completion:^(BOOL finished) {
        UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
        if (self.originalRootVC) {
            window.rootViewController = self.originalRootVC;
            [VIPThemeManager applyVIPThemeToViewController:self.originalRootVC];
        } else if (self.presentingViewController) {
            [self dismissViewControllerAnimated:NO completion:nil];
        }
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

@end

#pragma mark - Safe Presentation Hook

static void PresentAuthGate(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow ?: [UIApplication sharedApplication].windows.firstObject;
        if (!window || !window.rootViewController) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                PresentAuthGate();
            });
            return;
        }
        
        UIViewController *currentRoot = window.rootViewController;
        if ([currentRoot isKindOfClass:[AuthGateViewController class]]) {
            return;
        }
        
        AuthGateViewController *authVC = [[AuthGateViewController alloc] init];
        authVC.originalRootVC = currentRoot;
        window.rootViewController = authVC;
    });
}

__attribute__((constructor))
static void AuthGateInitialize(void) {
    NSLog(@"[AuthGate] Dynamic Library Loaded Successfully");
    
    InstallAuthHooks();
    [VIPThemeManager installThemeHooks];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        PresentAuthGate();
    }];
}
