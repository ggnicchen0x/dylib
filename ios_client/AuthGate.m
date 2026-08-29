#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>

// ==========================================
// Configurable Settings
// ==========================================
#define AUTH_SERVER_URL @"http://192.168.1.163:8000/api/v1/auth/validate" // PC LAN IP (or replace with your public domain / VPS / ngrok)
#define APP_TITLE @"PROXYVN AUTHENTICATION"
#define APP_SUBTITLE @"Enter your license key to activate"
#define SUPPORT_URL @"https://t.me/your_telegram_channel"
#define KEYCHAIN_KEY @"com.proxyvn.auth.license_key"
#define KEYCHAIN_HWID @"com.proxyvn.auth.device_hwid"

// Unified Cyberpunk Theme Palette
#define THEME_BG          [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0] // #0a0d14 Deep Obsidian
#define THEME_CARD_BG     [UIColor colorWithRed:0.07 green:0.09 blue:0.15 alpha:0.95] // #111726 Dark Glass Card
#define THEME_CARD_BORDER [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.25] // Indigo border
#define THEME_ACCENT      [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0] // #6366f1 Neon Indigo
#define THEME_TEXT_WHITE  [UIColor colorWithRed:0.97 green:0.98 blue:0.99 alpha:1.0] // #f8fafc Crisp White
#define THEME_TEXT_MUTED  [UIColor colorWithRed:0.58 green:0.64 blue:0.72 alpha:1.0] // #94a3b8 Slate Muted

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
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)getStringForKey:(NSString *)key {
    return [[NSUserDefaults standardUserDefaults] stringForKey:key];
}

+ (NSString *)getDeviceHWID {
    NSString *cachedHWID = [self getStringForKey:KEYCHAIN_HWID];
    if (cachedHWID && cachedHWID.length > 0) {
        return cachedHWID;
    }
    
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    if (!vendorID || vendorID.length == 0) {
        vendorID = [[NSUUID UUID] UUIDString];
    }
    
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
    }
    
    [self styleViewHierarchy:vc.view isRoot:YES];
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
            
            if ([text isEqualToString:@"Exploit"] || [text isEqualToString:@"No Exploit"] || [text isEqualToString:@"Account"]) {
                lbl.textColor = THEME_TEXT_WHITE;
                lbl.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
            } else if ([text containsString:@"no target file"] || [text containsString:@"patch bytes"]) {
                lbl.textColor = THEME_TEXT_MUTED;
                lbl.font = [UIFont systemFontOfSize:11 weight:UIFontWeightRegular];
            } else if ([text containsString:@"sandbox"]) {
                lbl.textColor = [UIColor colorWithRed:0.7 green:0.75 blue:0.85 alpha:1.0];
            } else {
                // Feature label (e.g. "Drag", "100% Body", "Maggic Bullet", "ModChest")
                lbl.textColor = THEME_TEXT_WHITE;
                lbl.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemiBold];
            }
        }
        
        // 2. Switches & their parent row card
        else if ([sub isKindOfClass:[UISwitch class]]) {
            UISwitch *sw = (UISwitch *)sub;
            sw.onTintColor = THEME_ACCENT;
            sw.thumbTintColor = [UIColor whiteColor];
            
            // Style the parent row card
            UIView *parent = sw.superview;
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
                btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemiBold];
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

@interface UIViewController (ExploitThemeHook)
@end

@implementation UIViewController (ExploitThemeHook)

- (void)hook_viewDidLayoutSubviews {
    [self hook_viewDidLayoutSubviews];
    
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Exploit"] || [className containsString:@"Proxy"] || [className containsString:@"Account"]) {
        [MainMenuThemeEngine styleViewController:self];
    }
}

+ (void)installThemeHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SwizzleMethod([UIViewController class], @selector(viewDidLayoutSubviews), @selector(hook_viewDidLayoutSubviews));
    });
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
@end

@implementation AuthGateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];

    [self setupUI];
    
    // Auto validate if key exists
    NSString *savedKey = [AuthStorage getStringForKey:KEYCHAIN_KEY];
    if (savedKey && savedKey.length > 0) {
        self.keyTextField.text = savedKey;
        [self performAuthWithKey:savedKey isAutoLogin:YES];
    }
}

- (void)setupUI {
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.frame = self.view.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:blurView];
    
    CGFloat cardWidth = MIN(self.view.bounds.size.width - 40, 360);
    CGFloat cardHeight = 440;
    
    self.cardView = [[UIView alloc] initWithFrame:CGRectMake((self.view.bounds.size.width - cardWidth)/2, (self.view.bounds.size.height - cardHeight)/2, cardWidth, cardHeight)];
    self.cardView.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.18 alpha:0.95];
    self.cardView.layer.cornerRadius = 20;
    self.cardView.layer.borderColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.3].CGColor;
    self.cardView.layer.borderWidth = 1.5;
    self.cardView.layer.shadowColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.4].CGColor;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 10);
    self.cardView.layer.shadowRadius = 25;
    self.cardView.layer.shadowOpacity = 0.8;
    self.cardView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:self.cardView];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 25, cardWidth - 40, 30)];
    titleLabel.text = APP_TITLE;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightHeavy];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, cardWidth - 40, 20)];
    subLabel.text = APP_SUBTITLE;
    subLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    subLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    subLabel.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:subLabel];
    
    NSString *hwid = [AuthStorage getDeviceHWID];
    NSString *shortHWID = hwid.length > 18 ? [NSString stringWithFormat:@"%@...%@", [hwid substringToIndex:8], [hwid substringFromIndex:hwid.length-6]] : hwid;
    
    self.hwidLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 90, cardWidth - 40, 28)];
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
    
    self.keyTextField = [[UITextField alloc] initWithFrame:CGRectMake(20, 135, cardWidth - 40, 48)];
    self.keyTextField.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.12 alpha:1.0];
    self.keyTextField.textColor = [UIColor whiteColor];
    self.keyTextField.font = [UIFont fontWithName:@"Menlo-Bold" size:13] ?: [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    self.keyTextField.placeholder = @"PVN-XXXX-XXXX-XXXX";
    self.keyTextField.textAlignment = NSTextAlignmentCenter;
    self.keyTextField.layer.cornerRadius = 10;
    self.keyTextField.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    self.keyTextField.layer.borderWidth = 1.0;
    self.keyTextField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyTextField.delegate = self;
    self.keyTextField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:@"ENTER LICENSE KEY" attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.4 alpha:1.0]}];
    [self.cardView addSubview:self.keyTextField];
    
    self.pasteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pasteButton.frame = CGRectMake(20, 192, cardWidth - 40, 32);
    [self.pasteButton setTitle:@"📋 Paste from Clipboard" forState:UIControlStateNormal];
    [self.pasteButton setTitleColor:[UIColor colorWithRed:0.6 green:0.7 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.pasteButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.pasteButton addTarget:self action:@selector(pasteKeyAction) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.pasteButton];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 230, cardWidth - 40, 40)];
    self.statusLabel.text = @"";
    self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [self.cardView addSubview:self.statusLabel];
    
    self.loginButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.loginButton.frame = CGRectMake(20, 280, cardWidth - 40, 48);
    self.loginButton.backgroundColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0];
    [self.loginButton setTitle:@"ACTIVATE & ENTER" forState:UIControlStateNormal];
    [self.loginButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.loginButton.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
    self.loginButton.layer.cornerRadius = 10;
    self.loginButton.layer.shadowColor = [UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:0.5].CGColor;
    self.loginButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.loginButton.layer.shadowRadius = 10;
    self.loginButton.layer.shadowOpacity = 0.8;
    [self.loginButton addTarget:self action:@selector(loginButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.loginButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.center = CGPointMake(cardWidth / 2, 304);
    self.spinner.color = [UIColor whiteColor];
    self.spinner.hidesWhenStopped = YES;
    [self.cardView addSubview:self.spinner];
    
    self.supportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.supportButton.frame = CGRectMake(20, 350, cardWidth - 40, 36);
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
        [self.loginButton setTitle:@"ACTIVATE & ENTER" forState:UIControlStateNormal];
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
    self.statusLabel.text = @"Validating license...";
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
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:AUTH_SERVER_URL]];
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
// Auth Gate Manager
// ==========================================
@interface AuthGateManager : NSObject
@property (nonatomic, strong) UIWindow *authWindow;
+ (instancetype)shared;
- (void)startAuthGate;
@end

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
        // Install targeted theme swizzler
        [UIViewController installThemeHooks];
        
        UIScreen *mainScreen = [UIScreen mainScreen];
        self.authWindow = [[UIWindow alloc] initWithFrame:mainScreen.bounds];
        self.authWindow.windowLevel = UIWindowLevelAlert + 100;
        
        AuthGateViewController *vc = [[AuthGateViewController alloc] init];
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
        [self.authWindow makeKeyAndVisible];
    });
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
