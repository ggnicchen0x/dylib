#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Security/Security.h>
#import <objc/runtime.h>
#import <CommonCrypto/CommonHMAC.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach-o/dyld.h>
#import <sys/sysctl.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

// ==========================================
// Obfuscated String Engine (Zero Plaintext Domain or Endpoints)
// ==========================================
static const unsigned char ENC_BASE_URL[] = { 0x32, 0x29, 0x14, 0x13, 0x5C, 0x46, 0x43, 0x09, 0x1B, 0x44, 0x4C, 0x55, 0x1C, 0xEE, 0xF0, 0xAA, 0xE2, 0xE2, 0xE3, 0xE7, 0xFF, 0xF7, 0xFB, 0xB1, 0xC1, 0xC9, 0xC7, 0xDE, 0xCA, 0x8B, 0x86, 0x82, 0x83, 0x85, 0xF1 };
static const size_t ENC_BASE_URL_LEN = 35;

static const unsigned char ENC_VALIDATE_EP[] = { 0x75, 0x3C, 0x10, 0x0A, 0x49, 0x1F, 0x5D, 0x40, 0x13, 0x00, 0x0C, 0x13, 0x51, 0xF7, 0xE5, 0xEB, 0xE3, 0xE9, 0xF1, 0xE7, 0xF3 };
static const size_t ENC_VALIDATE_EP_LEN = 21;

static const unsigned char ENC_HEARTBEAT_EP[] = { 0x75, 0x3C, 0x10, 0x0A, 0x49, 0x1F, 0x5D, 0x40, 0x13, 0x00, 0x0C, 0x13, 0x51, 0xE9, 0xE1, 0xE6, 0xF8, 0xF9, 0xF2, 0xF6, 0xF7, 0xED };
static const size_t ENC_HEARTBEAT_EP_LEN = 22;

static const unsigned char ENC_SUPPORT_URL[] = { 0x32, 0x29, 0x14, 0x13, 0x15, 0x53, 0x43, 0x40, 0x16, 0x1C, 0x0B, 0x18, 0x11, 0xF3, 0xE0, 0xA9, 0xED, 0xEA, 0xBF, 0xFD, 0xDB, 0xC8, 0xFD, 0xFE, 0xCF, 0xE1, 0xE6, 0xC1, 0x9C };
static const size_t ENC_SUPPORT_URL_LEN = 29;

static inline NSString *GetDecryptedString(const unsigned char *bytes, size_t len, unsigned char key) {
    char *buf = (char *)malloc(len + 1);
    if (!buf) return @"";
    for (size_t i = 0; i < len; i++) {
        buf[i] = (char)(bytes[i] ^ (unsigned char)((key + (i * 3)) & 0xFF));
    }
    buf[len] = '\0';
    NSString *res = [NSString stringWithUTF8String:buf];
    free(buf);
    return res ?: @"";
}

static inline NSString *GET_SERVER_BASE_URL(void) {
    return GetDecryptedString(ENC_BASE_URL, ENC_BASE_URL_LEN, 0x5A);
}

static inline NSString *GET_VALIDATE_URL(void) {
    return [NSString stringWithFormat:@"%@%@", GET_SERVER_BASE_URL(), GetDecryptedString(ENC_VALIDATE_EP, ENC_VALIDATE_EP_LEN, 0x5A)];
}

static inline NSString *GET_HEARTBEAT_URL(void) {
    return [NSString stringWithFormat:@"%@%@", GET_SERVER_BASE_URL(), GetDecryptedString(ENC_HEARTBEAT_EP, ENC_HEARTBEAT_EP_LEN, 0x5A)];
}

static inline NSString *GET_SUPPORT_URL(void) {
    return GetDecryptedString(ENC_SUPPORT_URL, ENC_SUPPORT_URL_LEN, 0x5A);
}

#define CURRENT_CLIENT_VERSION @"v1.1"
#define APP_TITLE @"EXTERNALFF AUTHENTICATION"
#define APP_SUBTITLE @"Live Realtime License Verification"
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
- (void)dismissAuthWindowIfAuthorized;
@end

@interface LiveSecurityGuard : NSObject
+ (instancetype)shared;
+ (BOOL)isSessionAuthorized;
+ (void)setAuthorizedSessionWithKey:(NSString *)key token:(NSString *)token expiresAt:(NSNumber *)expiresAt;
+ (void)enforceLockdownWithReason:(NSString *)reason;
+ (void)startHeartbeatTimer;
+ (void)stopHeartbeatTimer;
+ (void)triggerSilentBackgroundValidation;
+ (void)validateSavedKeyOnStartupWithCompletion:(void(^)(BOOL valid, NSString *errorMsg))completion;
+ (void)showVersionAlertWithRequiredVersion:(NSString *)reqVer discordURL:(NSString *)discordURL customMsg:(NSString *)customMsg;
@end

// ==========================================
// Keychain & Storage Helpers
// ==========================================
@interface AuthStorage : NSObject
+ (void)saveString:(NSString *)value forKey:(NSString *)key;
+ (NSString *)getStringForKey:(NSString *)key;
+ (void)deleteKey:(NSString *)key;
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

+ (void)deleteKey:(NSString *)key {
    if (!key) return;
    NSDictionary *deleteQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: key,
        (__bridge id)kSecAttrService: @"com.externalff.auth.service"
    };
    SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
// Persistent Background Audio & Keep-Alive Engine
// Prevents iOS from suspending or killing app when minimized
// ==========================================
@interface BackgroundKeepAliveEngine : NSObject
+ (instancetype)shared;
- (void)startBackgroundKeepAlive;
- (void)stopBackgroundKeepAlive;
@end

@interface BackgroundKeepAliveEngine ()
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@end

@implementation BackgroundKeepAliveEngine

+ (instancetype)shared {
    static BackgroundKeepAliveEngine *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[BackgroundKeepAliveEngine alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _bgTask = UIBackgroundTaskInvalid;
        [self setupNotifications];
    }
    return self;
}

- (void)setupNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

- (void)handleDidEnterBackground {
    [self startBackgroundTask];
    [self ensureAudioPlaying];
}

- (void)handleWillEnterForeground {
    [self endBackgroundTask];
}

- (void)startBackgroundTask {
    [self endBackgroundTask];
    self.bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"ExternalFF_BackgroundKeepAlive" expirationHandler:^{
        [self endBackgroundTask];
    }];
}

- (void)endBackgroundTask {
    if (self.bgTask != UIBackgroundTaskInvalid) {
        [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    }
}

- (NSData *)generateSilentWavData {
    uint32_t sampleRate = 8000;
    uint32_t numSamples = 8000;
    uint32_t dataChunkSize = numSamples;
    uint32_t fileSize = 36 + dataChunkSize;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:44 + numSamples];
    [data appendBytes:"RIFF" length:4];
    [data appendBytes:&fileSize length:4];
    [data appendBytes:"WAVE" length:4];
    [data appendBytes:"fmt " length:4];
    uint32_t fmtLength = 16;
    uint16_t audioFormat = 1;
    uint16_t numChannels = 1;
    uint32_t byteRate = sampleRate;
    uint16_t blockAlign = 1;
    uint16_t bitsPerSample = 8;
    [data appendBytes:&fmtLength length:4];
    [data appendBytes:&audioFormat length:2];
    [data appendBytes:&numChannels length:2];
    [data appendBytes:&sampleRate length:4];
    [data appendBytes:&byteRate length:4];
    [data appendBytes:&blockAlign length:2];
    [data appendBytes:&bitsPerSample length:2];
    [data appendBytes:"data" length:4];
    [data appendBytes:&dataChunkSize length:4];
    uint8_t silenceByte = 128;
    for (uint32_t i = 0; i < numSamples; i++) {
        [data appendBytes:&silenceByte length:1];
    }
    return data;
}

- (void)ensureAudioPlaying {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            AVAudioSession *session = [AVAudioSession sharedInstance];
            [session setCategory:AVAudioSessionCategoryPlayback
                     withOptions:(AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth)
                           error:nil];
            [session setActive:YES error:nil];
            
            if (!self.audioPlayer) {
                NSData *wavData = [self generateSilentWavData];
                NSError *playerError = nil;
                self.audioPlayer = [[AVAudioPlayer alloc] initWithData:wavData error:&playerError];
                self.audioPlayer.numberOfLoops = -1;
                self.audioPlayer.volume = 0.001;
                [self.audioPlayer prepareToPlay];
            }
            
            if (!self.audioPlayer.isPlaying) {
                [self.audioPlayer play];
            }
        } @catch (NSException *exception) {}
    });
}

- (void)startBackgroundKeepAlive {
    [self ensureAudioPlaying];
}

- (void)stopBackgroundKeepAlive {
    [self.audioPlayer stop];
    self.audioPlayer = nil;
    [self endBackgroundTask];
}

@end

// ==========================================
// Targeted Main Menu Theme Styler & Switch State Engine
// ==========================================
@interface MainMenuThemeEngine : NSObject
+ (void)styleViewController:(UIViewController *)vc;
+ (void)styleViewHierarchy:(UIView *)view isRoot:(BOOL)isRoot;
+ (void)realignMenuLayout:(UIViewController *)vc;
+ (void)updateStatusLabelOnController:(UIViewController *)vc message:(NSString *)msg;
+ (void)restoreAllSwitchStatesInViewController:(UIViewController *)vc;
+ (void)restoreSwitchesInViewHierarchy:(UIView *)view className:(NSString *)cname;
+ (void)setAllSwitchesInView:(UIView *)view toOn:(BOOL)on;
+ (void)clearAllPersistedSwitchStates;
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
    //   Cards end at y=450.0. Reset @ y=468.0. Status @ y=522.0. ContentSize @ 700.0.
    // Mods (ProxyNoExploitViewController, no top START box, starts directly at y=16):
    //   Cards end at y=342.0. Reset @ y=360.0. Status @ y=414.0. ContentSize @ 560.0.
    
    CGFloat resetY = isNoExploit ? 360.0 : 468.0;
    CGFloat statusY = isNoExploit ? 414.0 : 522.0;
    CGFloat contentH = isNoExploit ? 560.0 : 700.0;
    
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
                f.origin.x = 16.0;
                f.size.width = sv.bounds.size.width > 32 ? (sv.bounds.size.width - 32.0) : 340.0;
                f.size.height = 80.0;
                lbl.frame = f;
                lbl.numberOfLines = 0;
                lbl.lineBreakMode = NSLineBreakByWordWrapping;
                lbl.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            }
        }
    }
    
    CGSize cs = sv.contentSize;
    if (cs.height > 400) {
        cs.height = contentH;
        sv.contentSize = cs;
    }
}

+ (void)updateStatusLabelOnController:(UIViewController *)vc message:(NSString *)msg {
    if (!vc || !vc.view || !msg) return;
    
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
    BOOL isExploit = [cname containsString:@"Exploit"] && ![cname containsString:@"NoExploit"];
    
    UILabel *bottomLabel = nil;
    if (isExploit) {
        // For Home page (ProxyExploitViewController): bottom label is resultLabel!
        if ([vc respondsToSelector:@selector(resultLabel)]) {
            bottomLabel = [vc performSelector:@selector(resultLabel)];
        }
        
        // Ensure top card statusLabel stays in top card and is never blank
        if ([vc respondsToSelector:@selector(statusLabel)]) {
            UILabel *topLbl = [vc performSelector:@selector(statusLabel)];
            if (topLbl) {
                if (topLbl.text.length == 0 || [topLbl.text isEqualToString:@"Home"] || [topLbl.text isEqualToString:@"Mods"]) {
                    topLbl.text = @"Exploit: ready (standby)\nSandbox: optional (use Mods tab)";
                }
                topLbl.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
                topLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
                topLbl.numberOfLines = 2;
                topLbl.hidden = NO;
                topLbl.alpha = 1.0;
            }
        }
    } else {
        // For Mods page (ProxyNoExploitViewController): bottom label is statusLabel!
        if ([vc respondsToSelector:@selector(statusLabel)]) {
            bottomLabel = [vc performSelector:@selector(statusLabel)];
        }
    }
    
    if (!bottomLabel) {
        for (UIView *sub in sv.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                UILabel *lbl = (UILabel *)sub;
                if (lbl.numberOfLines == 0 && lbl.frame.origin.y >= 400.0) {
                    bottomLabel = lbl;
                    break;
                }
            }
        }
    }
    
    if (bottomLabel) {
        bottomLabel.text = msg;
        bottomLabel.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
        bottomLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        bottomLabel.numberOfLines = 0;
        bottomLabel.lineBreakMode = NSLineBreakByWordWrapping;
        bottomLabel.hidden = NO;
        bottomLabel.alpha = 1.0;
        
        CGRect f = bottomLabel.frame;
        CGFloat targetY = isExploit ? 582.0 : 478.0;
        if (f.origin.y < 400.0 || f.origin.y > 650.0) {
            f.origin.y = targetY;
        }
        f.origin.x = 16.0;
        f.size.width = sv.bounds.size.width > 32 ? (sv.bounds.size.width - 32.0) : 340.0;
        f.size.height = 80.0;
        bottomLabel.frame = f;
        [sv bringSubviewToFront:bottomLabel];
    }
    
    CGFloat contentHeight = isExploit ? 740.0 : 600.0;
    sv.contentSize = CGSizeMake(sv.bounds.size.width, MAX(sv.contentSize.height, contentHeight));
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
            if (p && ![p isKindOfClass:[UIScrollView class]]) {
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
            } else if ([trimmed isEqualToString:@"Maggic Bullet"] || [trimmed isEqualToString:@"Magic Bullet"]) {
                lbl.text = @"200% Magic Bullet";
                lbl.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
            } else if (isInsideSwitchCard) {
                // Feature label inside white card: Dark bold black
                lbl.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
            } else {
                // All status, diagnostics, and dynamic messages on the dark background ("Drag applied ✓", "Exploit: running", etc.): Bright Light Cyan/Slate
                lbl.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
                lbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
                lbl.numberOfLines = 0;
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

+ (void)restoreAllSwitchStatesInViewController:(UIViewController *)vc {
    if (!vc || !vc.view) return;
    NSString *cname = NSStringFromClass([vc class]);
    if (![cname containsString:@"Exploit"] && ![cname containsString:@"Proxy"]) return;
    [self restoreSwitchesInViewHierarchy:vc.view className:cname];
}

+ (void)restoreSwitchesInViewHierarchy:(UIView *)view className:(NSString *)cname {
    if (!view) return;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UISwitch class]]) {
            UISwitch *sw = (UISwitch *)sub;
            NSString *optKey = [NSString stringWithFormat:@"kExtFF_Switch_%@_Opt%ld", cname, (long)sw.tag];
            NSString *nativeKey = [NSString stringWithFormat:@"proxy.esp.%ld.enabled", (long)sw.tag];
            
            BOOL savedOn = NO;
            if ([[NSUserDefaults standardUserDefaults] objectForKey:optKey] != nil) {
                savedOn = [[NSUserDefaults standardUserDefaults] boolForKey:optKey];
            } else if ([[NSUserDefaults standardUserDefaults] objectForKey:nativeKey] != nil) {
                savedOn = [[NSUserDefaults standardUserDefaults] boolForKey:nativeKey];
            }
            
            if (sw.isOn != savedOn) {
                [sw setOn:savedOn animated:NO];
            }
        }
        [self restoreSwitchesInViewHierarchy:sub className:cname];
    }
}

+ (void)setAllSwitchesInView:(UIView *)view toOn:(BOOL)on {
    if (!view) return;
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UISwitch class]]) {
            UISwitch *sw = (UISwitch *)sub;
            [sw setOn:on animated:YES];
        }
        [self setAllSwitchesInView:sub toOn:on];
    }
}

+ (void)clearAllPersistedSwitchStates {
    NSDictionary *allDefaults = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
    for (NSString *k in allDefaults.allKeys) {
        if ([k hasPrefix:@"kExtFF_Switch_"] || [k hasPrefix:@"proxy.esp."]) {
            [[NSUserDefaults standardUserDefaults] removeObjectForKey:k];
        }
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    if ([trimmed isEqualToString:@"Maggic Bullet"] || [trimmed isEqualToString:@"Magic Bullet"]) {
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
    if (p && ![p isKindOfClass:[UIScrollView class]]) {
        for (UIView *sibling in p.subviews) {
            if ([sibling isKindOfClass:[UISwitch class]]) {
                isInsideSwitchCard = YES;
                break;
            }
        }
    }
    
    if (isInsideSwitchCard) {
        self.textColor = [UIColor colorWithRed:0.08 green:0.10 blue:0.15 alpha:1.0];
        self.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    } else if ([trimmed isEqualToString:@"Home"] || [trimmed isEqualToString:@"Mods"] || [trimmed isEqualToString:@"Mod"] || [trimmed isEqualToString:@"Account"]) {
        self.textColor = THEME_TEXT_WHITE;
        self.font = [UIFont systemFontOfSize:22 weight:UIFontWeightHeavy];
    } else {
        // Any status/diagnostics/runtime toast on the dark background ("Drag applied ✓", "Exploit: running", etc.)
        self.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
        self.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
        self.numberOfLines = 0;
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
    
    double nextY = [self hook_addSwitchRowWithTitle:title option:option toContainer:container y:y];
    
    // Look up saved persistent state for this switch and restore immediately
    NSString *cname = NSStringFromClass([self class]);
    NSString *optKey = [NSString stringWithFormat:@"kExtFF_Switch_%@_Opt%ld", cname, (long)option];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:optKey] != nil) {
        BOOL savedOn = [[NSUserDefaults standardUserDefaults] boolForKey:optKey];
        if (container) {
            for (UIView *sub in container.subviews) {
                if ([sub isKindOfClass:[UISwitch class]]) {
                    UISwitch *sw = (UISwitch *)sub;
                    if (sw.tag == option || (sw.frame.origin.y >= y - 10 && sw.frame.origin.y <= nextY + 10)) {
                        [sw setOn:savedOn animated:NO];
                    }
                } else if (sub.subviews.count > 0) {
                    for (UIView *nested in sub.subviews) {
                        if ([nested isKindOfClass:[UISwitch class]]) {
                            UISwitch *sw = (UISwitch *)nested;
                            if (sw.tag == option || (sub.frame.origin.y >= y - 10 && sub.frame.origin.y <= nextY + 10)) {
                                [sw setOn:savedOn animated:NO];
                            }
                        }
                    }
                }
            }
        }
    }
    
    return nextY;
}

@end

// ==========================================
// FluckAuthCore Native Bypass & Gate Interceptor
// ==========================================
@interface NSObject (FluckAuthCoreBypassHooks)
@end

@implementation NSObject (FluckAuthCoreBypassHooks)

- (BOOL)hook_fluck_gatePassed {
    return YES;
}

- (NSString *)hook_fluck_savedKey {
    return [AuthStorage getStringForKey:KEYCHAIN_KEY] ?: @"";
}

- (void)hook_fluck_markGatePassed {}
- (void)hook_fluck_refreshExpiryFromServer {}
- (void)hook_fluck_startHeartbeat {}
- (void)hook_fluck_startKeyWatchdog {}
- (void)hook_fluck_startGate {}
- (void)hook_fluck_beginGate {}
- (void)hook_fluck_fluckPulse {}
- (void)hook_fluck_saveExpiryFromDict:(id)dict {}
- (void)hook_fluck_verifySavedKeyAndPassWithCompletion:(id)comp {}
- (void)hook_fluck_revokeGateWithReason:(id)reason {}
- (void)hook_fluck_revokeAndDie:(id)arg1 label:(id)arg2 {}
- (void)hook_fluck_failAndDie:(id)arg1 {}

@end

// ==========================================
// RootViewController & FluckAuthViewController Gate Suppression Hooks
// ==========================================
@interface NSObject (RootViewControllerGateHooks)
@end

@implementation NSObject (RootViewControllerGateHooks)

- (BOOL)hook_root_gateDone {
    return YES;
}

- (BOOL)hook_root__gateDone {
    return YES;
}

- (void)hook_root_showActivationCard {}
- (void)hook_root_showActivationCardWithError:(id)err {}
- (void)hook_root_presentAsModal {}
- (BOOL)hook_root__presentAsModal { return NO; }
- (void)hook_root_beginGate {}
- (void)hook_root_startGate {}
- (void)hook_root_finishGate {
    [self hook_root_finishGate];
}

@end

@interface UIViewController (FluckAuthVCHooks)
@end

@implementation UIViewController (FluckAuthVCHooks)

- (void)hook_fluckVC_viewDidLoad {
    // Suppress legacy card UI setup entirely
}

- (void)hook_fluckVC_viewWillAppear:(BOOL)animated {
    // Suppress legacy card UI
}

- (void)hook_fluckVC_viewDidAppear:(BOOL)animated {
    // Suppress legacy card UI
}

- (void)hook_fluckVC_buildUI {
    // Drop building old UI views
}

- (void)hook_fluckVC_beginGate {
    // Drop old network gate verification
}

- (void)hook_fluckVC_showActivationCard {
    // Suppress legacy activation card
}

- (void)hook_fluckVC_showActivationCardWithError:(id)err {
    // Suppress legacy activation card error
}

- (BOOL)hook_fluckVC_gateDone {
    return YES;
}

- (BOOL)hook_fluckVC__gateDone {
    return YES;
}

@end

// ==========================================
// UIViewController & UINavigationItem & UITabBarItem Title & Orientation Hooks
// ==========================================
@interface UIViewController (OrientationLockHook)
@end

@implementation UIViewController (OrientationLockHook)

- (UIInterfaceOrientationMask)hook_supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)hook_shouldAutorotate {
    return NO;
}

- (UIInterfaceOrientation)hook_preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

@end

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

- (void)hook_viewWillAppear:(BOOL)animated {
    [self hook_viewWillAppear:animated];
    NSString *className = NSStringFromClass([self class]);
    if ([className containsString:@"Exploit"] || [className containsString:@"Proxy"]) {
        [MainMenuThemeEngine restoreAllSwitchStatesInViewController:self];
    }
}

- (void)hook_viewDidLayoutSubviews {
    [self hook_viewDidLayoutSubviews];
    NSString *className = NSStringFromClass([self class]);
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
        
        // Apply theme styling only once to prevent re-layout stutter when toggling switches
        static const char *kThemeAppliedKey = "kExternalFFThemeAppliedKey";
        if (!objc_getAssociatedObject(self, kThemeAppliedKey)) {
            objc_setAssociatedObject(self, kThemeAppliedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [MainMenuThemeEngine styleViewController:self];
            [MainMenuThemeEngine restoreAllSwitchStatesInViewController:self];
        }
    }
}

static BOOL g_userExplicitlyStopped = NO;

// ==========================================
// Core Engine Anti-Bypass Hooks (The Dead Man's Gates)
// ==========================================
- (void)hook_homeStartCheatBackend {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        [LiveSecurityGuard enforceLockdownWithReason:@"Access Denied: Live Realtime Key Required."];
        return;
    }
    if (g_userExplicitlyStopped) {
        return; // Block auto-restart when user explicitly stopped
    }
    [self hook_homeStartCheatBackend];
}

- (void)hook_ProxyExploitStartTapped {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        [LiveSecurityGuard enforceLockdownWithReason:@"Access Denied: Live Realtime Key Required."];
        return;
    }
    if (g_userExplicitlyStopped) {
        return; // Block auto-restart when user explicitly stopped
    }
    [self hook_ProxyExploitStartTapped];
}

- (void)hook_startTapped {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        [LiveSecurityGuard enforceLockdownWithReason:@"Access Denied: Live Realtime Key Required."];
        return;
    }
    
    UIButton *btn = nil;
    if ([self respondsToSelector:@selector(startButton)]) {
        btn = [self performSelector:@selector(startButton)];
    }
    
    UILabel *statusLbl = nil;
    if ([self respondsToSelector:@selector(statusLabel)]) {
        statusLbl = [self performSelector:@selector(statusLabel)];
    }
    
    NSString *currentTitle = btn ? [btn titleForState:UIControlStateNormal] : @"";
    
    // === STOP path: user tapped STOP ===
    if ([currentTitle isEqualToString:@"STOP"] || [currentTitle isEqualToString:@"STOPPING..."]) {
        g_userExplicitlyStopped = YES;
        objc_setAssociatedObject(self, "kExploitIsStartingKey", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "kExploitIsStoppingKey", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if (btn) {
            [btn setTitle:@"STOPPING..." forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.60 blue:0.15 alpha:0.9];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.layer.borderColor = [UIColor clearColor].CGColor;
            btn.layer.borderWidth = 0.0;
            btn.userInteractionEnabled = NO; // Prevent double-tap
        }
        if (statusLbl) {
            statusLbl.text = @"Exploit: stopping...";
        }
        
        // Call through to original which posts ProxyExploitStopTapped notification
        [self hook_startTapped];
        
        // After a short delay, force-clear the running state and reset UI to START
        __weak id weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            id strongSelf = weakSelf;
            if (!strongSelf) return;
            
            objc_setAssociatedObject(strongSelf, "kExploitIsStoppingKey", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            UIButton *b = nil;
            if ([strongSelf respondsToSelector:@selector(startButton)]) {
                b = [strongSelf performSelector:@selector(startButton)];
            }
            UILabel *sl = nil;
            if ([strongSelf respondsToSelector:@selector(statusLabel)]) {
                sl = [strongSelf performSelector:@selector(statusLabel)];
            }
            
            if (b) {
                [b setTitle:@"START" forState:UIControlStateNormal];
                b.backgroundColor = THEME_ACCENT;
                [b setTitleColor:THEME_TEXT_WHITE forState:UIControlStateNormal];
                b.layer.borderColor = [UIColor clearColor].CGColor;
                b.layer.borderWidth = 0.0;
                b.layer.cornerRadius = 10;
                b.layer.shadowColor = THEME_ACCENT.CGColor;
                b.layer.shadowOffset = CGSizeMake(0, 4);
                b.layer.shadowRadius = 8;
                b.layer.shadowOpacity = 0.4;
                b.userInteractionEnabled = YES;
            }
            if (sl) {
                sl.text = @"Exploit: stopped";
            }
        });
        return;
    }
    
    // === START path: user tapped START ===
    if ([currentTitle isEqualToString:@"START"] || [currentTitle isEqualToString:@"STARTING..."]) {
        g_userExplicitlyStopped = NO; // Clear stop flag on explicit start
        objc_setAssociatedObject(self, "kExploitIsStartingKey", @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, "kExploitIsStoppingKey", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if (btn) {
            [btn setTitle:@"STARTING..." forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.60 blue:0.15 alpha:0.9];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        }
        if (statusLbl) {
            NSString *osVer = @"";
            NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
            if (v.patchVersion > 0) {
                osVer = [NSString stringWithFormat:@"iOS %ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
            } else {
                osVer = [NSString stringWithFormat:@"iOS %ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
            }
            statusLbl.text = [NSString stringWithFormat:@"Exploit: starting...\n%@ | bypassing sandbox...", osVer];
        }
    } else {
        objc_setAssociatedObject(self, "kExploitIsStartingKey", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    [self hook_startTapped];
}

- (void)hook_refreshStatus {
    // If user is in the process of stopping, don't let the original refreshStatus override our UI
    BOOL isStopping = [objc_getAssociatedObject(self, "kExploitIsStoppingKey") boolValue];
    if (isStopping) {
        return; // Skip refresh entirely while stopping — our dispatch_after handles the transition
    }
    
    [self hook_refreshStatus];
    
    UIButton *btn = nil;
    if ([self respondsToSelector:@selector(startButton)]) {
        btn = [self performSelector:@selector(startButton)];
    }
    
    UILabel *statusLbl = nil;
    if ([self respondsToSelector:@selector(statusLabel)]) {
        statusLbl = [self performSelector:@selector(statusLabel)];
    }
    
    BOOL isStarting = [objc_getAssociatedObject(self, "kExploitIsStartingKey") boolValue];
    NSString *btnTitle = btn ? [btn titleForState:UIControlStateNormal] : @"";
    
    // If user explicitly stopped, force button to START regardless of internal state
    if (g_userExplicitlyStopped) {
        if (btn) {
            [btn setTitle:@"START" forState:UIControlStateNormal];
            btn.backgroundColor = THEME_ACCENT;
            [btn setTitleColor:THEME_TEXT_WHITE forState:UIControlStateNormal];
            btn.layer.borderColor = [UIColor clearColor].CGColor;
            btn.layer.borderWidth = 0.0;
            btn.layer.cornerRadius = 10;
            btn.layer.shadowColor = THEME_ACCENT.CGColor;
            btn.layer.shadowOffset = CGSizeMake(0, 4);
            btn.layer.shadowRadius = 8;
            btn.layer.shadowOpacity = 0.4;
            btn.userInteractionEnabled = YES;
        }
        return;
    }
    
    if ([btnTitle isEqualToString:@"STOP"]) {
        objc_setAssociatedObject(self, "kExploitIsStartingKey", @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (btn) {
            btn.backgroundColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.25];
            [btn setTitleColor:[UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0] forState:UIControlStateNormal];
            btn.layer.borderColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.5].CGColor;
            btn.layer.borderWidth = 1.0;
            btn.layer.cornerRadius = 10;
        }
    } else if (isStarting) {
        if (btn) {
            [btn setTitle:@"STARTING..." forState:UIControlStateNormal];
            btn.backgroundColor = [UIColor colorWithRed:0.95 green:0.60 blue:0.15 alpha:0.9];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            btn.layer.borderColor = [UIColor clearColor].CGColor;
            btn.layer.borderWidth = 0.0;
            btn.layer.cornerRadius = 10;
        }
        if (statusLbl) {
            NSString *osVer = @"";
            NSOperatingSystemVersion v = [[NSProcessInfo processInfo] operatingSystemVersion];
            if (v.patchVersion > 0) {
                osVer = [NSString stringWithFormat:@"iOS %ld.%ld.%ld", (long)v.majorVersion, (long)v.minorVersion, (long)v.patchVersion];
            } else {
                osVer = [NSString stringWithFormat:@"iOS %ld.%ld", (long)v.majorVersion, (long)v.minorVersion];
            }
            statusLbl.text = [NSString stringWithFormat:@"Exploit: starting...\n%@ | bypassing sandbox...", osVer];
        }
    } else {
        if (btn) {
            [btn setTitle:@"START" forState:UIControlStateNormal];
            btn.backgroundColor = THEME_ACCENT;
            [btn setTitleColor:THEME_TEXT_WHITE forState:UIControlStateNormal];
            btn.layer.borderColor = [UIColor clearColor].CGColor;
            btn.layer.borderWidth = 0.0;
            btn.layer.cornerRadius = 10;
        }
    }
}

- (void)hook_exploitStateChanged {
    [self hook_exploitStateChanged];
    [self hook_refreshStatus];
}

- (void)hook_switchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) {
            [(UISwitch *)sender setOn:NO animated:YES];
        }
        [LiveSecurityGuard enforceLockdownWithReason:@"Cheat Switch Blocked: Realtime Authentication Required."];
        return;
    }
    
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *sw = (UISwitch *)sender;
        BOOL isOn = sw.isOn;
        
        NSString *title = nil;
        UIView *parent = sw.superview;
        if (parent) {
            for (UIView *sub in parent.subviews) {
                if ([sub isKindOfClass:[UILabel class]]) {
                    title = [(UILabel *)sub text];
                    break;
                }
            }
        }
        
        if (!title || title.length == 0) {
            NSInteger tag = sw.tag;
            if (tag == 0) title = @"Drag";
            else if (tag == 1) title = @"100% Body";
            else if (tag == 2) title = @"95% Body";
            else if (tag == 3) title = @"200% Magic Bullet";
            else if (tag == 5) title = @"Visuals";
            else title = @"Feature";
        }
        
        // 1. Persist state to NSUserDefaults immediately BEFORE calling original / triggering layout
        NSString *cname = NSStringFromClass([self class]);
        NSString *optKey = [NSString stringWithFormat:@"kExtFF_Switch_%@_Opt%ld", cname, (long)sw.tag];
        NSString *nativeKey = [NSString stringWithFormat:@"proxy.esp.%ld.enabled", (long)sw.tag];
        [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:optKey];
        [[NSUserDefaults standardUserDefaults] setBool:isOn forKey:nativeKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        if ([cname containsString:@"NoExploit"] || [self.title isEqualToString:@"Mods"]) {
            // For Mods page (NoExploit): apply/restore mod via ProxyESPConfig directly (No Sandbox needed)
            Class espConfigClass = objc_getClass("ProxyESPConfig");
            if (espConfigClass) {
                // Update ProxyESPConfig flag
                if ([espConfigClass respondsToSelector:@selector(setOptionEnabledFlag:enabled:)]) {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    typedef void (*SetOptFn)(id, SEL, NSInteger, BOOL);
                    SEL setOptSel = @selector(setOptionEnabledFlag:enabled:);
                    IMP setOptImp = [espConfigClass methodForSelector:setOptSel];
                    if (setOptImp) {
                        ((SetOptFn)setOptImp)(espConfigClass, setOptSel, sw.tag, isOn);
                    }
                    #pragma clang diagnostic pop
                }
                
                // Rewrite or restore file
                if ([espConfigClass respondsToSelector:@selector(rewriteFileWithStatus)]) {
                    typedef NSInteger (*RewriteFn)(id, SEL);
                    SEL rewSel = @selector(rewriteFileWithStatus);
                    IMP rewImp = [espConfigClass methodForSelector:rewSel];
                    if (rewImp) {
                        ((RewriteFn)rewImp)(espConfigClass, rewSel);
                    }
                } else if ([espConfigClass respondsToSelector:@selector(rewriteFile)]) {
                    [espConfigClass performSelector:@selector(rewriteFile)];
                }
            }
        } else {
            // For Home page (Exploit page): call through to original exploit-based handler
            [self hook_switchChanged:sender];
        }
        
        // Ensure switch retains user's toggled state
        [sw setOn:isOn animated:NO];
        
        NSString *gameTitle = @"Free Fire";
        if ([self respondsToSelector:@selector(seg)]) {
            UISegmentedControl *seg = [self performSelector:@selector(seg)];
            if (seg && [seg isKindOfClass:[UISegmentedControl class]]) {
                if (seg.selectedSegmentIndex == 1) {
                    gameTitle = @"Free Fire MAX";
                }
            }
        }
        
        NSString *statusMsg = isOn ? 
            [NSString stringWithFormat:@"%@\n%@ applied ✓", gameTitle, title] : 
            [NSString stringWithFormat:@"%@\n%@ restored", gameTitle, title];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [MainMenuThemeEngine updateStatusLabelOnController:self message:statusMsg];
        });
        return;
    }
    
    [self hook_switchChanged:sender];
}

- (void)hook_refreshStatus {
    if ([self respondsToSelector:@selector(statusLabel)]) {
        UILabel *topLbl = [self performSelector:@selector(statusLabel)];
        if (topLbl) {
            topLbl.text = @"Exploit: ready (standby)\nSandbox: optional (use Mods tab)";
            topLbl.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
            topLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
            topLbl.numberOfLines = 2;
            topLbl.hidden = NO;
            topLbl.alpha = 1.0;
        }
    }
    
    if ([self respondsToSelector:@selector(startButton)]) {
        UIButton *btn = [self performSelector:@selector(startButton)];
        if (btn && [btn isKindOfClass:[UIButton class]]) {
            [btn setTitle:@"START" forState:UIControlStateNormal];
        }
    }
    
    NSString *gameTitle = @"Free Fire";
    if ([self respondsToSelector:@selector(seg)]) {
        UISegmentedControl *seg = [self performSelector:@selector(seg)];
        if (seg && [seg isKindOfClass:[UISegmentedControl class]]) {
            if (seg.selectedSegmentIndex == 1) {
                gameTitle = @"Free Fire MAX";
            }
        }
    }
    
    NSMutableArray *activeNames = [NSMutableArray array];
    for (NSInteger i = 0; i < 6; i++) {
        NSString *nativeKey = [NSString stringWithFormat:@"proxy.esp.%ld.enabled", (long)i];
        NSString *customKey = [NSString stringWithFormat:@"kExtFF_Switch_ProxyExploitViewController_Opt%ld", (long)i];
        BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey:nativeKey] || [[NSUserDefaults standardUserDefaults] boolForKey:customKey];
        if (on) {
            NSString *optTitle = @"Feature";
            if (i == 0) optTitle = @"Drag";
            else if (i == 1) optTitle = @"100% Body";
            else if (i == 2) optTitle = @"95% Body";
            else if (i == 3) optTitle = @"200% Magic Bullet";
            else if (i == 5) optTitle = @"Visuals";
            [activeNames addObject:optTitle];
        }
    }
    
    NSString *statusText = nil;
    if (activeNames.count > 0) {
        statusText = [NSString stringWithFormat:@"%@\nActive: %@", gameTitle, [activeNames componentsJoinedByString:@", "]];
    } else {
        statusText = [NSString stringWithFormat:@"%@\nSelect an option above", gameTitle];
    }
    
    [MainMenuThemeEngine updateStatusLabelOnController:self message:statusText];
}

- (void)hook_exploit_viewDidLoad {
    [self hook_exploit_viewDidLoad];
    [self hook_refreshStatus];
}

- (void)hook_exploit_viewWillAppear:(BOOL)animated {
    [self hook_exploit_viewWillAppear:animated];
    [self hook_refreshStatus];
}

- (void)hook_exploit_gameChanged:(id)sender {
    [self hook_exploit_gameChanged:sender];
    [self hook_refreshStatus];
}

- (void)hook_noExploit_refreshStatus {
    NSString *gameTitle = @"Free Fire";
    if ([self respondsToSelector:@selector(seg)]) {
        UISegmentedControl *seg = [self performSelector:@selector(seg)];
        if (seg && [seg isKindOfClass:[UISegmentedControl class]]) {
            if (seg.selectedSegmentIndex == 1) {
                gameTitle = @"Free Fire MAX";
            }
        }
    }
    
    NSMutableArray *activeNames = [NSMutableArray array];
    for (NSInteger i = 0; i < 6; i++) {
        NSString *nativeKey = [NSString stringWithFormat:@"proxy.esp.%ld.enabled", (long)i];
        NSString *customKey = [NSString stringWithFormat:@"kExtFF_Switch_ProxyNoExploitViewController_Opt%ld", (long)i];
        BOOL on = [[NSUserDefaults standardUserDefaults] boolForKey:nativeKey] || [[NSUserDefaults standardUserDefaults] boolForKey:customKey];
        if (on) {
            NSString *optTitle = @"Feature";
            if (i == 0) optTitle = @"Drag";
            else if (i == 1) optTitle = @"100% Body";
            else if (i == 2) optTitle = @"95% Body";
            else if (i == 3) optTitle = @"200% Magic Bullet";
            else if (i == 5) optTitle = @"Visuals";
            [activeNames addObject:optTitle];
        }
    }
    
    NSString *statusText = nil;
    if (activeNames.count > 0) {
        statusText = [NSString stringWithFormat:@"%@\nActive: %@", gameTitle, [activeNames componentsJoinedByString:@", "]];
    } else {
        statusText = [NSString stringWithFormat:@"%@\nSelect an option above", gameTitle];
    }
    
    [MainMenuThemeEngine updateStatusLabelOnController:self message:statusText];
}

- (void)hook_gameChanged:(id)sender {
    [self hook_gameChanged:sender];
    [self hook_noExploit_refreshStatus];
}

- (void)hook_noExploit_viewDidLoad {
    [self hook_noExploit_viewDidLoad];
    [self hook_noExploit_refreshStatus];
}

- (void)hook_noExploit_viewWillAppear:(BOOL)animated {
    [self hook_noExploit_viewWillAppear:animated];
    [self hook_noExploit_refreshStatus];
}

- (void)hook_resetTapped:(id)sender {
    NSString *gameTitle = @"Free Fire";
    if ([self respondsToSelector:@selector(seg)]) {
        UISegmentedControl *seg = [self performSelector:@selector(seg)];
        if (seg && [seg isKindOfClass:[UISegmentedControl class]]) {
            if (seg.selectedSegmentIndex == 1) {
                gameTitle = @"Free Fire MAX";
            }
        }
    }
    
    Class espConfigClass = objc_getClass("ProxyESPConfig");
    if (espConfigClass && [espConfigClass respondsToSelector:@selector(restoreAll)]) {
        [espConfigClass performSelector:@selector(restoreAll)];
    }
    
    [MainMenuThemeEngine clearAllPersistedSwitchStates];
    if (self.view) {
        [MainMenuThemeEngine setAllSwitchesInView:self.view toOn:NO];
    }
    
    NSString *cname = NSStringFromClass([self class]);
    BOOL isExploit = [cname containsString:@"Exploit"] && ![cname containsString:@"NoExploit"];
    if (isExploit) {
        if ([self respondsToSelector:@selector(statusLabel)]) {
            UILabel *topLbl = [self performSelector:@selector(statusLabel)];
            if (topLbl) {
                topLbl.text = @"Exploit: ready (standby)\nSandbox: optional (use Mods tab)";
                topLbl.textColor = [UIColor colorWithRed:0.78 green:0.83 blue:0.94 alpha:1.0];
                topLbl.font = [UIFont systemFontOfSize:13 weight:UIFontWeightMedium];
                topLbl.numberOfLines = 2;
                topLbl.hidden = NO;
                topLbl.alpha = 1.0;
            }
        }
    }
    
    NSString *resetMsg = [NSString stringWithFormat:@"%@\nAll features reset & restored.", gameTitle];
    dispatch_async(dispatch_get_main_queue(), ^{
        [MainMenuThemeEngine updateStatusLabelOnController:self message:resetMsg];
    });
}

- (void)hook_homeFgAttachSwitchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) [(UISwitch *)sender setOn:NO animated:YES];
        [LiveSecurityGuard enforceLockdownWithReason:@"Feature Locked: Realtime Authentication Required."];
        return;
    }
    [self hook_homeFgAttachSwitchChanged:sender];
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *sw = (UISwitch *)sender;
        [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:@"kExtFF_Switch_HomeFgAttach"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)hook_homeHudSwitchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) [(UISwitch *)sender setOn:NO animated:YES];
        [LiveSecurityGuard enforceLockdownWithReason:@"Feature Locked: Realtime Authentication Required."];
        return;
    }
    [self hook_homeHudSwitchChanged:sender];
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *sw = (UISwitch *)sender;
        [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:@"kExtFF_Switch_HomeHud"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)hook_homeKgvnSwitchChanged:(id)sender {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        if ([sender isKindOfClass:[UISwitch class]]) [(UISwitch *)sender setOn:NO animated:YES];
        [LiveSecurityGuard enforceLockdownWithReason:@"Feature Locked: Realtime Authentication Required."];
        return;
    }
    [self hook_homeKgvnSwitchChanged:sender];
    if ([sender isKindOfClass:[UISwitch class]]) {
        UISwitch *sw = (UISwitch *)sender;
        [[NSUserDefaults standardUserDefaults] setBool:sw.isOn forKey:@"kExtFF_Switch_HomeKgvn"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)hook_runBackgroundCheatTick {
    if (![LiveSecurityGuard isSessionAuthorized]) {
        return; // Drop tick without execution
    }
    if (g_userExplicitlyStopped) {
        return; // Drop tick when user explicitly stopped
    }
    [self hook_runBackgroundCheatTick];
}

// Hook _kexploitSettleEnded: on RootViewController to block auto-restart
- (void)hook_kexploitSettleEnded:(id)notification {
    if (g_userExplicitlyStopped) {
        return; // Block auto-restart when user explicitly stopped
    }
    [self hook_kexploitSettleEnded:notification];
}

// Hook _kexploitReadyRefresh: on RootViewController to block auto-restart
- (void)hook_kexploitReadyRefresh:(id)notification {
    if (g_userExplicitlyStopped) {
        return; // Block auto-restart when user explicitly stopped
    }
    [self hook_kexploitReadyRefresh:notification];
}

// Hook _homeStartCheatBackend on RootViewController to block auto-restart
- (void)hook_root_homeStartCheatBackend {
    if (g_userExplicitlyStopped) {
        return; // Block auto-restart when user explicitly stopped
    }
    [self hook_root_homeStartCheatBackend];
}

// Hook bytesForPatch: on ProxyPatchBytes to load from bundle modfiles/ instead of FluckAuth server
- (id)hook_bytesForPatch:(id)patchName {
    // Try loading from the app bundle's modfiles/ directory first
    if (patchName && [patchName isKindOfClass:[NSString class]]) {
        NSString *name = (NSString *)patchName;
        NSBundle *bundle = [NSBundle mainBundle];
        
        // Try modfiles/<name>.dat first
        NSString *datPath = [bundle pathForResource:[NSString stringWithFormat:@"%@.dat", name]
                                             ofType:nil
                                        inDirectory:@"modfiles"];
        if (!datPath) {
            // Try direct name in modfiles/
            datPath = [bundle pathForResource:name ofType:nil inDirectory:@"modfiles"];
        }
        if (!datPath) {
            // Try root bundle with name as-is
            datPath = [bundle pathForResource:name ofType:nil];
        }
        
        if (datPath) {
            NSData *data = [NSData dataWithContentsOfFile:datPath];
            if (data && data.length > 0) {
                return data;
            }
        }
    }
    
    // Fall through to original (will try in-memory cache then server)
    return [self hook_bytesForPatch:patchName];
}

+ (void)installThemeHooks {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SwizzleMethod([UIViewController class], @selector(viewDidLayoutSubviews), @selector(hook_viewDidLayoutSubviews));
        SwizzleMethod([UIViewController class], @selector(viewWillAppear:), @selector(hook_viewWillAppear:));
        SwizzleMethod([UIViewController class], @selector(setTitle:), @selector(hook_vc_setTitle:));
        SwizzleMethod([UIViewController class], @selector(supportedInterfaceOrientations), @selector(hook_supportedInterfaceOrientations));
        SwizzleMethod([UIViewController class], @selector(shouldAutorotate), @selector(hook_shouldAutorotate));
        SwizzleMethod([UIViewController class], @selector(preferredInterfaceOrientationForPresentation), @selector(hook_preferredInterfaceOrientationForPresentation));
        SwizzleMethod([UINavigationItem class], @selector(setTitle:), @selector(hook_nav_setTitle:));
        SwizzleMethod([UITabBarItem class], @selector(setTitle:), @selector(hook_tab_setTitle:));
        SwizzleMethod([UILabel class], @selector(setText:), @selector(hook_dynamicRuntimeSetText:));
        
        Class fluckClass = objc_getClass("FluckAuthCore");
        if (fluckClass) {
            SwizzleMethod(fluckClass, @selector(gatePassed), @selector(hook_fluck_gatePassed));
            SwizzleMethod(fluckClass, @selector(savedKey), @selector(hook_fluck_savedKey));
            SwizzleMethod(fluckClass, @selector(markGatePassed), @selector(hook_fluck_markGatePassed));
            SwizzleMethod(fluckClass, @selector(refreshExpiryFromServer), @selector(hook_fluck_refreshExpiryFromServer));
            SwizzleMethod(fluckClass, @selector(startHeartbeat), @selector(hook_fluck_startHeartbeat));
            SwizzleMethod(fluckClass, @selector(startKeyWatchdog), @selector(hook_fluck_startKeyWatchdog));
            SwizzleMethod(fluckClass, @selector(startGate), @selector(hook_fluck_startGate));
            SwizzleMethod(fluckClass, @selector(beginGate), @selector(hook_fluck_beginGate));
            SwizzleMethod(fluckClass, @selector(fluckPulse), @selector(hook_fluck_fluckPulse));
            SwizzleMethod(fluckClass, @selector(saveExpiryFromDict:), @selector(hook_fluck_saveExpiryFromDict:));
            SwizzleMethod(fluckClass, @selector(verifySavedKeyAndPassWithCompletion:), @selector(hook_fluck_verifySavedKeyAndPassWithCompletion:));
            SwizzleMethod(fluckClass, @selector(revokeGateWithReason:), @selector(hook_fluck_revokeGateWithReason:));
            SwizzleMethod(fluckClass, @selector(revokeAndDie:label:), @selector(hook_fluck_revokeAndDie:label:));
            SwizzleMethod(fluckClass, @selector(failAndDie:), @selector(hook_fluck_failAndDie:));
        }
        
        Class expVCClass = objc_getClass("ProxyExploitViewController");
        if (expVCClass) {
            SwizzleMethod(expVCClass, @selector(viewDidLoad), @selector(hook_exploit_viewDidLoad));
            SwizzleMethod(expVCClass, @selector(viewWillAppear:), @selector(hook_exploit_viewWillAppear:));
            SwizzleMethod(expVCClass, @selector(gameChanged:), @selector(hook_exploit_gameChanged:));
            SwizzleMethod(expVCClass, @selector(addSwitchRowWithTitle:option:toContainer:y:), @selector(hook_addSwitchRowWithTitle:option:toContainer:y:));
            SwizzleMethod(expVCClass, @selector(_homeStartCheatBackend), @selector(hook_homeStartCheatBackend));
            SwizzleMethod(expVCClass, @selector(ProxyExploitStartTapped), @selector(hook_ProxyExploitStartTapped));
            SwizzleMethod(expVCClass, @selector(startTapped), @selector(hook_startTapped));
            SwizzleMethod(expVCClass, @selector(refreshStatus), @selector(hook_refreshStatus));
            SwizzleMethod(expVCClass, @selector(exploitStateChanged), @selector(hook_exploitStateChanged));
            SwizzleMethod(expVCClass, @selector(switchChanged:), @selector(hook_switchChanged:));
            SwizzleMethod(expVCClass, @selector(resetTapped), @selector(hook_resetTapped:));
            SwizzleMethod(expVCClass, @selector(resetTapped:), @selector(hook_resetTapped:));
            SwizzleMethod(expVCClass, @selector(restoreTapped), @selector(hook_resetTapped:));
            SwizzleMethod(expVCClass, @selector(restoreTapped:), @selector(hook_resetTapped:));
            SwizzleMethod(expVCClass, @selector(_homeFgAttachSwitchChanged:), @selector(hook_homeFgAttachSwitchChanged:));
            SwizzleMethod(expVCClass, @selector(_homeHudSwitchChanged:), @selector(hook_homeHudSwitchChanged:));
            SwizzleMethod(expVCClass, @selector(_homeKgvnSwitchChanged:), @selector(hook_homeKgvnSwitchChanged:));
            SwizzleMethod(expVCClass, @selector(runBackgroundCheatTick), @selector(hook_runBackgroundCheatTick));
        }
        Class noExpVCClass = objc_getClass("ProxyNoExploitViewController");
        if (noExpVCClass) {
            SwizzleMethod(noExpVCClass, @selector(viewDidLoad), @selector(hook_noExploit_viewDidLoad));
            SwizzleMethod(noExpVCClass, @selector(viewWillAppear:), @selector(hook_noExploit_viewWillAppear:));
            SwizzleMethod(noExpVCClass, @selector(gameChanged:), @selector(hook_gameChanged:));
            SwizzleMethod(noExpVCClass, @selector(addSwitchRowWithTitle:option:toContainer:y:), @selector(hook_addSwitchRowWithTitle:option:toContainer:y:));
            SwizzleMethod(noExpVCClass, @selector(switchChanged:), @selector(hook_switchChanged:));
            SwizzleMethod(noExpVCClass, @selector(refreshStatus), @selector(hook_noExploit_refreshStatus));
            SwizzleMethod(noExpVCClass, @selector(startTapped), @selector(hook_startTapped));
            SwizzleMethod(noExpVCClass, @selector(restoreTapped), @selector(hook_resetTapped:));
            SwizzleMethod(noExpVCClass, @selector(restoreTapped:), @selector(hook_resetTapped:));
            SwizzleMethod(noExpVCClass, @selector(resetTapped), @selector(hook_resetTapped:));
            SwizzleMethod(noExpVCClass, @selector(resetTapped:), @selector(hook_resetTapped:));
        }
        
        Class rootVCClass = objc_getClass("RootViewController");
        if (rootVCClass) {
            SwizzleMethod(rootVCClass, @selector(tabBarController:shouldSelectViewController:), @selector(hook_root_tabBarController:shouldSelectViewController:));
            SwizzleMethod(rootVCClass, @selector(showActivationCard), @selector(hook_root_showActivationCard));
            SwizzleMethod(rootVCClass, @selector(showActivationCardWithError:), @selector(hook_root_showActivationCardWithError:));
            SwizzleMethod(rootVCClass, @selector(gateDone), @selector(hook_root_gateDone));
            SwizzleMethod(rootVCClass, @selector(_gateDone), @selector(hook_root__gateDone));
            SwizzleMethod(rootVCClass, @selector(presentAsModal), @selector(hook_root_presentAsModal));
            SwizzleMethod(rootVCClass, @selector(_presentAsModal), @selector(hook_root__presentAsModal));
            SwizzleMethod(rootVCClass, @selector(beginGate), @selector(hook_root_beginGate));
            SwizzleMethod(rootVCClass, @selector(startGate), @selector(hook_root_startGate));
            SwizzleMethod(rootVCClass, @selector(finishGate), @selector(hook_root_finishGate));
            // Anti-auto-restart hooks
            SwizzleMethod(rootVCClass, @selector(_kexploitSettleEnded:), @selector(hook_kexploitSettleEnded:));
            SwizzleMethod(rootVCClass, @selector(_kexploitReadyRefresh:), @selector(hook_kexploitReadyRefresh:));
            SwizzleMethod(rootVCClass, @selector(_homeStartCheatBackend), @selector(hook_root_homeStartCheatBackend));
        }
        Class fluckVCClass = objc_getClass("FluckAuthViewController");
        if (fluckVCClass) {
            SwizzleMethod(fluckVCClass, @selector(viewDidLoad), @selector(hook_fluckVC_viewDidLoad));
            SwizzleMethod(fluckVCClass, @selector(viewWillAppear:), @selector(hook_fluckVC_viewWillAppear:));
            SwizzleMethod(fluckVCClass, @selector(viewDidAppear:), @selector(hook_fluckVC_viewDidAppear:));
            SwizzleMethod(fluckVCClass, @selector(buildUI), @selector(hook_fluckVC_buildUI));
            SwizzleMethod(fluckVCClass, @selector(beginGate), @selector(hook_fluckVC_beginGate));
            SwizzleMethod(fluckVCClass, @selector(showActivationCard), @selector(hook_fluckVC_showActivationCard));
            SwizzleMethod(fluckVCClass, @selector(showActivationCardWithError:), @selector(hook_fluckVC_showActivationCardWithError:));
            SwizzleMethod(fluckVCClass, @selector(gateDone), @selector(hook_fluckVC_gateDone));
            SwizzleMethod(fluckVCClass, @selector(_gateDone), @selector(hook_fluckVC__gateDone));
        }
        Class patchBytesClass = objc_getClass("ProxyPatchBytes");
        if (patchBytesClass) {
            SwizzleMethod(patchBytesClass, @selector(bytesForPatch:), @selector(hook_bytesForPatch:));
        }
    });
}

@end

// ==========================================
// Live Realtime Security Guard & Heartbeat Engine
// ==========================================
static BOOL g_sessionAuthorizedInMemory = NO;

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
        [self setupLifecycleObservers];
    }
    return self;
}

- (void)setupLifecycleObservers {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppWillEnterForeground)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAppDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)handleAppDidEnterBackground {
    self.consecutiveFailures = 0;
}

- (void)handleAppWillEnterForeground {
    if (g_sessionAuthorizedInMemory) {
        self.isAuthorized = YES;
        self.consecutiveFailures = 0;
        [[AuthGateManager shared] dismissAuthWindowIfAuthorized];
    }
}

- (void)handleAppDidBecomeActive {
    if (g_sessionAuthorizedInMemory) {
        self.isAuthorized = YES;
        self.consecutiveFailures = 0;
        [[AuthGateManager shared] dismissAuthWindowIfAuthorized];
    }
}

+ (BOOL)isSessionAuthorized {
    if (g_sessionAuthorizedInMemory) {
        return YES;
    }
    LiveSecurityGuard *guard = [self shared];
    return guard.isAuthorized;
}

+ (void)showVersionAlertWithRequiredVersion:(NSString *)reqVer discordURL:(NSString *)discordURL customMsg:(NSString *)customMsg {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *discord = (discordURL && discordURL.length > 0) ? discordURL : GET_SUPPORT_URL();
        NSString *msgText = customMsg ?: @"A newer version of ExternalFF is required to continue.";
        NSString *body = [NSString stringWithFormat:@"%@\n\nInstalled Version: %@\nRequired Version: %@\n\nPlease contact the owner or join Discord to download the latest update.",
                          msgText, CURRENT_CLIENT_VERSION, (reqVer ?: @"Latest")];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Newer Version Detected"
                                                                       message:body
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *contactAction = [UIAlertAction actionWithTitle:@"Contact Owner (Discord)"
                                                                style:UIAlertActionStyleDefault
                                                              handler:^(UIAlertAction * _Nonnull action) {
            NSURL *url = [NSURL URLWithString:discord];
            if ([[UIApplication sharedApplication] canOpenURL:url]) {
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            }
        }];
        
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        
        [alert addAction:contactAction];
        [alert addAction:cancelAction];
        
        UIWindow *targetWin = nil;
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (!w.hidden && w.rootViewController) {
                targetWin = w;
                break;
            }
        }
        UIViewController *presenter = targetWin ? targetWin.rootViewController : nil;
        while (presenter.presentedViewController) {
            presenter = presenter.presentedViewController;
        }
        if (presenter) {
            [presenter presentViewController:alert animated:YES completion:nil];
        }
    });
}

+ (void)validateSavedKeyOnStartupWithCompletion:(void(^)(BOOL valid, NSString *errorMsg))completion {
    NSString *savedKey = [AuthStorage getStringForKey:KEYCHAIN_KEY];
    if (!savedKey || savedKey.length == 0) {
        if (completion) completion(NO, nil);
        return;
    }
    
    NSString *hwid = [AuthStorage getDeviceHWID];
    NSString *deviceName = [[UIDevice currentDevice] name] ?: @"iOS Device";
    NSDictionary *payload = @{
        @"key": savedKey,
        @"hwid": hwid,
        @"device_name": deviceName,
        @"app_version": CURRENT_CLIENT_VERSION
    };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:GET_VALIDATE_URL()]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:data];
    [req setTimeoutInterval:6.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable resData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !resData) {
                if (completion) completion(NO, @"Realtime internet connection required to verify license.");
                return;
            }
            
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:resData options:0 error:nil];
            NSString *code = json[@"code"] ?: @"";
            
            if (httpResp.statusCode == 426 || [code isEqualToString:@"VERSION_OUTDATED"]) {
                NSString *reqVer = json[@"required_version"] ?: json[@"latest_version"];
                NSString *disc = json[@"discord_url"];
                NSString *msg = json[@"message"];
                [LiveSecurityGuard showVersionAlertWithRequiredVersion:reqVer discordURL:disc customMsg:msg];
                if (completion) completion(NO, msg ?: @"Newer version detected. Update required.");
                return;
            }
            
            BOOL success = [json[@"success"] boolValue];
            if (success) {
                NSDictionary *dataDict = json[@"data"] ?: json;
                NSString *token = json[@"token"] ?: dataDict[@"token"];
                NSNumber *expiresAt = json[@"expires_at"] ?: dataDict[@"expires_at"];
                [LiveSecurityGuard setAuthorizedSessionWithKey:savedKey token:token expiresAt:expiresAt];
                if (completion) completion(YES, nil);
            } else {
                // Key was deleted from server or is invalid/expired
                [AuthStorage deleteKey:KEYCHAIN_KEY];
                NSString *msg = json[@"message"] ?: @"License key is invalid or has been deleted from server.";
                if (completion) completion(NO, msg);
            }
        });
    }];
    [task resume];
}

+ (void)triggerSilentBackgroundValidation {
    static BOOL isVerifying = NO;
    if (isVerifying) return;
    isVerifying = YES;
    
    NSString *savedKey = [AuthStorage getStringForKey:KEYCHAIN_KEY];
    if (!savedKey || savedKey.length == 0) {
        isVerifying = NO;
        return;
    }
    
    NSString *hwid = [AuthStorage getDeviceHWID];
    NSString *deviceName = [[UIDevice currentDevice] name] ?: @"iOS Device";
    NSDictionary *payload = @{
        @"key": savedKey,
        @"hwid": hwid,
        @"device_name": deviceName,
        @"app_version": CURRENT_CLIENT_VERSION
    };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:0 error:nil];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:GET_VALIDATE_URL()]];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setHTTPBody:data];
    [req setTimeoutInterval:8.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData * _Nullable resData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        isVerifying = NO;
        NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
        if (!error && resData) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:resData options:0 error:nil];
            NSString *code = json[@"code"] ?: @"";
            
            if (httpResp.statusCode == 426 || [code isEqualToString:@"VERSION_OUTDATED"]) {
                NSString *reqVer = json[@"required_version"] ?: json[@"latest_version"];
                NSString *disc = json[@"discord_url"];
                NSString *msg = json[@"message"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [LiveSecurityGuard showVersionAlertWithRequiredVersion:reqVer discordURL:disc customMsg:msg];
                    [LiveSecurityGuard enforceLockdownWithReason:msg ?: @"Newer version detected. Update required."];
                });
                return;
            }
            
            if ([json[@"success"] boolValue]) {
                NSDictionary *dataDict = json[@"data"] ?: json;
                NSString *token = json[@"token"] ?: dataDict[@"token"];
                NSNumber *expiresAt = json[@"expires_at"] ?: dataDict[@"expires_at"];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [LiveSecurityGuard setAuthorizedSessionWithKey:savedKey token:token expiresAt:expiresAt];
                });
            } else {
                // Key deleted or revoked on server
                dispatch_async(dispatch_get_main_queue(), ^{
                    [AuthStorage deleteKey:KEYCHAIN_KEY];
                    [LiveSecurityGuard enforceLockdownWithReason:json[@"message"] ?: @"License key is invalid or has been deleted."];
                });
            }
        }
    }];
    [task resume];
}

+ (void)setAuthorizedSessionWithKey:(NSString *)key token:(NSString *)token expiresAt:(NSNumber *)expiresAt {
    LiveSecurityGuard *guard = [self shared];
    guard.isAuthorized = YES;
    g_sessionAuthorizedInMemory = YES;
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
    [[AuthGateManager shared] dismissAuthWindowIfAuthorized];
}

+ (void)enforceLockdownWithReason:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        LiveSecurityGuard *guard = [self shared];
        guard.isAuthorized = NO;
        g_sessionAuthorizedInMemory = NO;
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
    // Heartbeat timer neutralized — prevents network-drop timeouts from resetting active cheat sessions
}

+ (void)stopHeartbeatTimer {
    // No-op
}

+ (void)sendHeartbeatPing {
    // No-op
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
        // Pre-fill key if saved for user convenience
        NSString *savedKey = [AuthStorage getStringForKey:KEYCHAIN_KEY];
        if (savedKey && savedKey.length > 0) {
            self.keyTextField.text = savedKey;
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
    NSURL *url = [NSURL URLWithString:GET_SUPPORT_URL()];
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
        @"app_version": CURRENT_CLIENT_VERSION
    };
    
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:payload options:0 error:&jsonError];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:GET_VALIDATE_URL()]];
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
            
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *code = json[@"code"] ?: @"";
            
            if (httpResp.statusCode == 426 || [code isEqualToString:@"VERSION_OUTDATED"]) {
                NSString *reqVer = json[@"required_version"] ?: json[@"latest_version"];
                NSString *disc = json[@"discord_url"];
                NSString *msg = json[@"message"];
                self.statusLabel.textColor = [UIColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0];
                self.statusLabel.text = @"Newer version detected! Update required.";
                [LiveSecurityGuard showVersionAlertWithRequiredVersion:reqVer discordURL:disc customMsg:msg];
                return;
            }
            
            BOOL success = [json[@"success"] boolValue];
            NSString *msg = json[@"message"] ?: @"Unknown response";
            
            if (success) {
                [AuthStorage saveString:key forKey:KEYCHAIN_KEY];
                NSDictionary *dataDict = json[@"data"] ?: json;
                NSString *remainStr = json[@"time_left_human"] ?: (dataDict[@"remaining_formatted"] ?: @"Active");
                NSString *token = json[@"token"] ?: (dataDict[@"token"] ?: @"VALID");
                NSNumber *expiresAt = json[@"expires_at"] ?: dataDict[@"expires_at"];
                
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
        
        // Ensure background audio keep-alive engine is active
        [[BackgroundKeepAliveEngine shared] startBackgroundKeepAlive];
        
        // If already verified in memory during this active session (e.g. returning from background / minimized), stay in menu seamlessly
        if (g_sessionAuthorizedInMemory) {
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (!w.hidden && w.rootViewController) {
                    [MainMenuThemeEngine restoreAllSwitchStatesInViewController:w.rootViewController];
                }
            }
            return;
        }
        
        // Cold launch: App was completely closed or newly installed -> Always present login gate
        [self showAuthWindowWithError:nil];
    });
}

- (void)reshowLockdownGateWithReason:(NSString *)reason {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_sessionAuthorizedInMemory) {
            return;
        }
        [self showAuthWindowWithError:reason];
    });
}

- (void)dismissAuthWindowIfAuthorized {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (g_sessionAuthorizedInMemory || [LiveSecurityGuard isSessionAuthorized]) {
            if (self.authWindow) {
                [self.authWindow setHidden:YES];
                self.authWindow.rootViewController = nil;
                self.authWindow = nil;
                
                for (UIWindow *w in [UIApplication sharedApplication].windows) {
                    if (!w.hidden && w.rootViewController) {
                        [w makeKeyAndVisible];
                        [MainMenuThemeEngine styleViewController:w.rootViewController];
                        [MainMenuThemeEngine restoreAllSwitchStatesInViewController:w.rootViewController];
                        break;
                    }
                }
            }
        }
    });
}

- (void)showAuthWindowWithError:(NSString *)errorReason {
    if (g_sessionAuthorizedInMemory) {
        if (self.authWindow) {
            self.authWindow.hidden = YES;
            self.authWindow.rootViewController = nil;
            self.authWindow = nil;
        }
        return;
    }
    
    if (!self.authWindow) {
        UIScreen *mainScreen = [UIScreen mainScreen];
        self.authWindow = [[UIWindow alloc] initWithFrame:mainScreen.bounds];
        self.authWindow.windowLevel = UIWindowLevelAlert + 100;
    }
    
    AuthGateViewController *vc = [[AuthGateViewController alloc] init];
    vc.initialErrorReason = errorReason;
    __weak typeof(self) weakSelf = self;
    vc.onSuccessBlock = ^{
        g_sessionAuthorizedInMemory = YES;
        [LiveSecurityGuard shared].isAuthorized = YES;
        
        [UIView animateWithDuration:0.25 animations:^{
            weakSelf.authWindow.alpha = 0.0;
        } completion:^(BOOL finished) {
            weakSelf.authWindow.hidden = YES;
            weakSelf.authWindow.rootViewController = nil;
            weakSelf.authWindow = nil;
            
            // Find the main app window
            UIWindow *appWindow = nil;
            for (UIWindow *w in [UIApplication sharedApplication].windows) {
                if (w != weakSelf.authWindow) {
                    appWindow = w;
                    break;
                }
            }
            if (!appWindow) {
                appWindow = [UIApplication sharedApplication].keyWindow;
            }
            
            if (appWindow) {
                // Completely replace FluckAuthViewController with RootViewController
                Class rootVCClass = objc_getClass("RootViewController");
                if (rootVCClass) {
                    UIViewController *existing = appWindow.rootViewController;
                    if (!existing || ![existing isKindOfClass:rootVCClass]) {
                        UIViewController *newRoot = [[rootVCClass alloc] init];
                        appWindow.rootViewController = newRoot;
                    }
                }
                [appWindow makeKeyAndVisible];
                if (appWindow.rootViewController) {
                    [MainMenuThemeEngine styleViewController:appWindow.rootViewController];
                    [MainMenuThemeEngine restoreAllSwitchStatesInViewController:appWindow.rootViewController];
                }
            }
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
    // 1. Install all swizzles & neutralizations immediately before App Delegate runs
    [UIViewController installThemeHooks];
    
    // 2. Start Background Keep-Alive Audio & Task Handler immediately
    [[BackgroundKeepAliveEngine shared] startBackgroundKeepAlive];
    
    // 3. Present AuthGate UI once application finishes launching
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        [[AuthGateManager shared] startAuthGate];
    }];
}
