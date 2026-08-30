#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#define BACKEND_SERVER_URL @"http://fi14.bot-hosting.cloud:25981/server.php"
#define LICENSE_KEY_STORAGE @"external.license.key"

#pragma mark - FluckAuthCore Runtime Interception

@interface FluckAuthCoreHook : NSObject
@end

@implementation FluckAuthCoreHook

- (NSString *)hooked_savedKey {
    return [[NSUserDefaults standardUserDefaults] stringForKey:LICENSE_KEY_STORAGE];
}

@end

static void InstallAuthHooks(void) {
    Class coreClass = NSClassFromString(@"FluckAuthCore");
    if (coreClass) {
        Method orig = class_getInstanceMethod(coreClass, NSSelectorFromString(@"savedKey"));
        Method hook = class_getInstanceMethod([FluckAuthCoreHook class], @selector(hooked_savedKey));
        if (orig && hook) {
            method_setImplementation(orig, method_getImplementation(hook));
            NSLog(@"[AuthGate] FluckAuthCore::savedKey intercepted -> routed to %@", LICENSE_KEY_STORAGE);
        }
    }
}

#pragma mark - AuthGateViewController Interface

@interface AuthGateViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, strong) UIViewController *originalRootVC;
@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UIButton *pasteButton;
@property (nonatomic, strong) UIButton *activateButton;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;

- (void)activateTapped:(id)sender;
- (void)pasteTapped:(id)sender;
- (void)finishAuthentication;

@end

#pragma mark - AuthGateViewController Implementation

@implementation AuthGateViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:0.98];
    
    [self setupBackground];
    [self setupCardView];
    [self setupHeader];
    [self setupInputFields];
    [self setupButtons];
    [self setupStatusLabel];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissKeyboard)];
    [self.view addGestureRecognizer:tap];
    
    NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:LICENSE_KEY_STORAGE];
    if (savedKey && savedKey.length > 0) {
        self.keyField.text = savedKey;
    }
}

- (void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (void)setupBackground {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = self.view.bounds;
    gradient.colors = @[
        (id)[UIColor colorWithRed:0.08 green:0.12 blue:0.20 alpha:1.0].CGColor,
        (id)[UIColor colorWithRed:0.04 green:0.05 blue:0.07 alpha:1.0].CGColor
    ];
    gradient.startPoint = CGPointMake(0.5, 0.0);
    gradient.endPoint = CGPointMake(0.5, 1.0);
    [self.view.layer insertSublayer:gradient atIndex:0];
}

- (void)setupCardView {
    self.cardView = [[UIView alloc] init];
    self.cardView.translatesAutoresizingMaskIntoConstraints = NO;
    self.cardView.backgroundColor = [UIColor colorWithRed:0.11 green:0.13 blue:0.18 alpha:0.95];
    self.cardView.layer.cornerRadius = 20.0;
    self.cardView.layer.borderWidth = 1.0;
    self.cardView.layer.borderColor = [UIColor colorWithRed:0.22 green:0.28 blue:0.40 alpha:0.60].CGColor;
    
    self.cardView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.cardView.layer.shadowOffset = CGSizeMake(0, 10);
    self.cardView.layer.shadowRadius = 25.0;
    self.cardView.layer.shadowOpacity = 0.5;
    
    [self.view addSubview:self.cardView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.cardView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [self.cardView.widthAnchor constraintEqualToConstant:340.0],
        [self.cardView.heightAnchor constraintEqualToConstant:380.0]
    ]];
}

- (void)setupHeader {
    self.titleLabel = [[UILabel alloc] init];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.text = @"VIP AUTHENTICATION";
    self.titleLabel.font = [UIFont boldSystemFontOfSize:20.0];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    [self.cardView addSubview:self.titleLabel];
    
    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.text = @"Enter your subscription license key to access";
    self.subtitleLabel.font = [UIFont systemFontOfSize:13.0];
    self.subtitleLabel.textColor = [UIColor colorWithRed:0.60 green:0.65 blue:0.75 alpha:1.0];
    self.subtitleLabel.textAlignment = NSTextAlignmentCenter;
    self.subtitleLabel.numberOfLines = 2;
    [self.cardView addSubview:self.subtitleLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.titleLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:28.0],
        [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16.0],
        [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16.0],
        
        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:6.0],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20.0],
        [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-20.0]
    ]];
}

- (void)setupInputFields {
    UIView *inputContainer = [[UIView alloc] init];
    inputContainer.translatesAutoresizingMaskIntoConstraints = NO;
    inputContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.08 blue:0.12 alpha:0.95];
    inputContainer.layer.cornerRadius = 12.0;
    inputContainer.layer.borderWidth = 1.0;
    inputContainer.layer.borderColor = [UIColor colorWithRed:0.20 green:0.25 blue:0.35 alpha:0.50].CGColor;
    [self.cardView addSubview:inputContainer];
    
    self.keyField = [[UITextField alloc] init];
    self.keyField.translatesAutoresizingMaskIntoConstraints = NO;
    self.keyField.placeholder = @"PROXY-VIP-XXXX-XXXX";
    self.keyField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.keyField.placeholder
                                                                           attributes:@{NSForegroundColorAttributeName: [UIColor colorWithRed:0.45 green:0.50 blue:0.60 alpha:0.8]}];
    self.keyField.textColor = [UIColor whiteColor];
    self.keyField.font = [UIFont fontWithName:@"Menlo" size:14.0] ?: [UIFont systemFontOfSize:14.0];
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.returnKeyType = UIReturnKeyDone;
    self.keyField.delegate = self;
    [inputContainer addSubview:self.keyField];
    
    self.pasteButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.pasteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.pasteButton setTitle:@"PASTE" forState:UIControlStateNormal];
    self.pasteButton.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [self.pasteButton setTitleColor:[UIColor colorWithRed:0.35 green:0.65 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    [self.pasteButton addTarget:self action:@selector(pasteTapped:) forControlEvents:UIControlEventTouchUpInside];
    [inputContainer addSubview:self.pasteButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [inputContainer.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:24.0],
        [inputContainer.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20.0],
        [inputContainer.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-20.0],
        [inputContainer.heightAnchor constraintEqualToConstant:48.0],
        
        [self.keyField.leadingAnchor constraintEqualToAnchor:inputContainer.leadingAnchor constant:14.0],
        [self.keyField.centerYAnchor constraintEqualToAnchor:inputContainer.centerYAnchor],
        [self.keyField.trailingAnchor constraintEqualToAnchor:self.pasteButton.leadingAnchor constant:-8.0],
        
        [self.pasteButton.trailingAnchor constraintEqualToAnchor:inputContainer.trailingAnchor constant:-12.0],
        [self.pasteButton.centerYAnchor constraintEqualToAnchor:inputContainer.centerYAnchor],
        [self.pasteButton.widthAnchor constraintEqualToConstant:55.0]
    ]];
}

- (void)setupButtons {
    self.activateButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.activateButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.activateButton setTitle:@"ACTIVATE LICENSE" forState:UIControlStateNormal];
    self.activateButton.titleLabel.font = [UIFont boldSystemFontOfSize:15.0];
    [self.activateButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.activateButton.backgroundColor = [UIColor colorWithRed:0.20 green:0.50 blue:0.95 alpha:1.0];
    self.activateButton.layer.cornerRadius = 12.0;
    self.activateButton.layer.shadowColor = [UIColor colorWithRed:0.20 green:0.50 blue:0.95 alpha:0.4].CGColor;
    self.activateButton.layer.shadowOffset = CGSizeMake(0, 4);
    self.activateButton.layer.shadowRadius = 10.0;
    self.activateButton.layer.shadowOpacity = 0.8;
    [self.activateButton addTarget:self action:@selector(activateTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.cardView addSubview:self.activateButton];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;
    [self.activateButton addSubview:self.spinner];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.activateButton.topAnchor constraintEqualToAnchor:self.keyField.superview.bottomAnchor constant:20.0],
        [self.activateButton.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:20.0],
        [self.activateButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-20.0],
        [self.activateButton.heightAnchor constraintEqualToConstant:50.0],
        
        [self.spinner.trailingAnchor constraintEqualToAnchor:self.activateButton.trailingAnchor constant:-16.0],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.activateButton.centerYAnchor]
    ]];
}

- (void)setupStatusLabel {
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.font = [UIFont systemFontOfSize:12.5];
    self.statusLabel.textColor = [UIColor colorWithRed:0.60 green:0.65 blue:0.75 alpha:1.0];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;
    [self.cardView addSubview:self.statusLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.activateButton.bottomAnchor constant:16.0],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16.0],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16.0]
    ]];
}

#pragma mark - Actions

- (void)pasteTapped:(id)sender {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    if (pasteboard.string && pasteboard.string.length > 0) {
        self.keyField.text = [pasteboard.string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        [self updateStatus:@"Key pasted from clipboard." isError:NO];
    } else {
        [self updateStatus:@"Clipboard is empty." isError:YES];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self activateTapped:nil];
    return YES;
}

- (void)activateTapped:(id)sender {
    [self.view endEditing:YES];
    
    NSString *rawKey = self.keyField.text;
    NSString *trimmedKey = [rawKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (!trimmedKey || trimmedKey.length == 0) {
        [self updateStatus:@"Please enter your license key." isError:YES];
        return;
    }
    
    [self validateKeyWithServer:trimmedKey isAutoLogin:NO];
}

#pragma mark - Server Authentication Engine

- (void)setLoading:(BOOL)loading {
    if (loading) {
        [self.spinner startAnimating];
        self.activateButton.enabled = NO;
        self.activateButton.alpha = 0.8;
    } else {
        [self.spinner stopAnimating];
        self.activateButton.enabled = YES;
        self.activateButton.alpha = 1.0;
    }
}

- (void)updateStatus:(NSString *)message isError:(BOOL)isError {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = message;
        if (isError) {
            self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0];
        } else {
            self.statusLabel.textColor = [UIColor colorWithRed:0.35 green:0.85 blue:0.45 alpha:1.0];
        }
    });
}

- (void)validateKeyWithServer:(NSString *)key isAutoLogin:(BOOL)isAutoLogin {
    [self setLoading:YES];
    [self updateStatus:isAutoLogin ? @"Verifying saved license..." : @"Validating with authentication server..." isError:NO];
    
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: @"IOS-DEVICE-1";
    NSString *escapedKey = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *escapedUdid = [udid stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    
    NSString *urlString = [NSString stringWithFormat:@"%@?license_key=%@&udid=%@", BACKEND_SERVER_URL, escapedKey, escapedUdid];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:10.0];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setLoading:NO];
            
            if (error != nil || data == nil) {
                [self updateStatus:@"Server unreachable. Please check your connection." isError:YES];
                return;
            }
            
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            
            if (httpResponse.statusCode == 200 && responseString && ([responseString containsString:@"Nicchx"] || [responseString containsString:@"momo"])) {
                // Store strictly under external.license.key
                [[NSUserDefaults standardUserDefaults] setObject:key forKey:LICENSE_KEY_STORAGE];
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
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        PresentAuthGate();
    }];
}
