#import "AYLicenseGate.h"
#import <UIKit/UIKit.h>
#import <Security/Security.h>

// These values match the 3105 license client. The service name is scoped by
// the containing application, so this does not share a key across apps.
static NSString *const AYEndpoint = @"https://licenseshop-he9jxzob.manus.space/api/v1/licenses/validate";
static NSString *const AYKeychainService = @"com.yangjiii.3105.license";
static NSString *const AYPurchaseURL = @"https://chat.whatsapp.com/EBQf7teedZJCgRTNztqEv4?s=cl&p=i&mlu=4&ilr=4";

static UIColor *AYAccent(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *traits) {
        return traits.userInterfaceStyle == UIUserInterfaceStyleDark
            ? [UIColor colorWithRed:1 green:0.64 blue:0.42 alpha:1]
            : [UIColor colorWithRed:0.85 green:0.42 blue:0.20 alpha:1];
    }];
}

static NSString *AYStoredKey(void) {
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService: AYKeychainService,
                            (__bridge id)kSecReturnData: @YES,
                            (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne};
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status != errSecSuccess) return nil;
    NSData *data = [NSData dataWithBytes:CFDataGetBytePtr((CFDataRef)result)
                                length:CFDataGetLength((CFDataRef)result)];
    CFRelease(result);
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static BOOL AYSaveKey(NSString *key) {
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService: AYKeychainService};
    SecItemDelete((__bridge CFDictionaryRef)query);
    NSMutableDictionary *item = [query mutableCopy];
    item[(__bridge id)kSecValueData] = [key dataUsingEncoding:NSUTF8StringEncoding];
    item[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly;
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == errSecSuccess;
}

static void AYDeleteKey(void) {
    NSDictionary *query = @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService: AYKeychainService};
    SecItemDelete((__bridge CFDictionaryRef)query);
}

@interface AYLicenseGate : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UIWindow *gateWindow;
@property (nonatomic, assign) UIWindow *previousWindow;
@property (nonatomic, strong) UITextField *keyField;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UILabel *keyLabel;
@property (nonatomic, strong) UILabel *footnote;
@property (nonatomic, strong) UIButton *loginButton;
@property (nonatomic, strong) UIButton *retryButton;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) void (^activation)(void);
@property (nonatomic, copy) NSString *savedKey;
@property (nonatomic, assign) BOOL checking;
@property (nonatomic, assign) BOOL activated;
@end

@implementation AYLicenseGate

- (UILabel *)label:(NSString *)text size:(CGFloat)size weight:(UIFontWeight)weight color:(UIColor *)color {
    UILabel *label = [UILabel new];
    label.text = text;
    label.font = [UIFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.numberOfLines = 0;
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    UIScrollView *scroll = [UIScrollView new];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 22;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.layoutMargins = UIEdgeInsetsMake(30, 22, 30, 22);
    stack.layoutMarginsRelativeArrangement = YES;
    [scroll addSubview:stack];
    NSLayoutConstraint *width = [stack.widthAnchor constraintEqualToAnchor:scroll.widthAnchor];
    width.priority = UILayoutPriorityDefaultHigh;
    [NSLayoutConstraint activateConstraints:@[
        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
        [stack.centerXAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.centerXAnchor],
        [stack.widthAnchor constraintLessThanOrEqualToConstant:470], width,
        [stack.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor constant:-10]
    ]];

    UIStackView *header = [UIStackView new];
    header.axis = UILayoutConstraintAxisVertical;
    header.alignment = UIStackViewAlignmentCenter;
    header.spacing = 9;
    UIImageView *logo = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"bag.fill"]];
    logo.contentMode = UIViewContentModeCenter;
    logo.tintColor = UIColor.whiteColor;
    logo.backgroundColor = AYAccent();
    logo.layer.cornerRadius = 13;
    logo.clipsToBounds = YES;
    [logo.widthAnchor constraintEqualToConstant:58].active = YES;
    [logo.heightAnchor constraintEqualToConstant:58].active = YES;
    [header addArrangedSubview:logo];
    UILabel *title = [self label:@"Bem-vindo à Ayam Store" size:28 weight:UIFontWeightBold color:UIColor.labelColor];
    title.textAlignment = NSTextAlignmentCenter;
    [header addArrangedSubview:title];
    UILabel *subtitle = [self label:@"Dono da loja  ·  Criador: Jesus Cristo" size:13 weight:UIFontWeightMedium color:UIColor.secondaryLabelColor];
    subtitle.textAlignment = NSTextAlignmentCenter;
    [header addArrangedSubview:subtitle];
    [stack addArrangedSubview:header];

    UIStackView *panel = [UIStackView new];
    panel.axis = UILayoutConstraintAxisVertical;
    panel.spacing = 14;
    panel.layoutMargins = UIEdgeInsetsMake(20, 20, 20, 20);
    panel.layoutMarginsRelativeArrangement = YES;
    panel.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
    panel.layer.cornerRadius = 23;
    panel.layer.borderWidth = 1;
    panel.layer.borderColor = [UIColor.separatorColor colorWithAlphaComponent:0.12].CGColor;
    [panel addArrangedSubview:[self label:@"Acesso exclusivo" size:21 weight:UIFontWeightBold color:UIColor.labelColor]];
    [panel addArrangedSubview:[self label:@"Insira sua chave para continuar" size:15 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor]];

    self.keyLabel = [self label:@"CHAVE DE LICENÇA" size:12 weight:UIFontWeightBold color:UIColor.secondaryLabelColor];
    [panel addArrangedSubview:self.keyLabel];
    self.keyField = [UITextField new];
    self.keyField.placeholder = @"Digite sua chave";
    self.keyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.keyField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
    self.keyField.returnKeyType = UIReturnKeyGo;
    self.keyField.delegate = self;
    self.keyField.leftViewMode = UITextFieldViewModeAlways;
    UIImageView *keyIcon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"key.horizontal.fill"]];
    keyIcon.tintColor = AYAccent();
    keyIcon.contentMode = UIViewContentModeCenter;
    keyIcon.frame = CGRectMake(0, 0, 42, 52);
    self.keyField.leftView = keyIcon;
    self.keyField.backgroundColor = UIColor.tertiarySystemGroupedBackgroundColor;
    self.keyField.layer.cornerRadius = 15;
    [self.keyField.heightAnchor constraintEqualToConstant:52].active = YES;
    [panel addArrangedSubview:self.keyField];

    self.errorLabel = [self label:@"" size:13 weight:UIFontWeightMedium color:UIColor.systemRedColor];
    self.errorLabel.hidden = YES;
    [panel addArrangedSubview:self.errorLabel];
    self.loginButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loginButton.backgroundColor = AYAccent();
    self.loginButton.tintColor = UIColor.whiteColor;
    self.loginButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    self.loginButton.layer.cornerRadius = 15;
    [self.loginButton setTitle:@"Entrar" forState:UIControlStateNormal];
    [self.loginButton addTarget:self action:@selector(login) forControlEvents:UIControlEventTouchUpInside];
    [self.loginButton.heightAnchor constraintEqualToConstant:52].active = YES;
    [panel addArrangedSubview:self.loginButton];
    self.retryButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.retryButton setTitle:@"Tentar novamente com a chave salva" forState:UIControlStateNormal];
    [self.retryButton addTarget:self action:@selector(retrySavedKey) forControlEvents:UIControlEventTouchUpInside];
    self.retryButton.hidden = YES;
    [panel addArrangedSubview:self.retryButton];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.spinner.color = UIColor.whiteColor;
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    [self.loginButton addSubview:self.spinner];
    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.loginButton.centerYAnchor],
        [self.spinner.leadingAnchor constraintEqualToAnchor:self.loginButton.leadingAnchor constant:15]
    ]];

    UIButton *purchase = [UIButton buttonWithType:UIButtonTypeSystem];
    [purchase setTitle:@"Comprar acesso  ↗" forState:UIControlStateNormal];
    purchase.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    purchase.contentEdgeInsets = UIEdgeInsetsMake(0, 15, 0, 15);
    purchase.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    purchase.tintColor = AYAccent();
    purchase.backgroundColor = [AYAccent() colorWithAlphaComponent:0.08];
    purchase.layer.cornerRadius = 14;
    [purchase.heightAnchor constraintEqualToConstant:46].active = YES;
    [purchase addTarget:self action:@selector(openPurchase) forControlEvents:UIControlEventTouchUpInside];
    [panel addArrangedSubview:purchase];
    [stack addArrangedSubview:panel];

    UILabel *verse = [self label:@"❝\nTudo quanto tem fôlego louve ao Senhor. Louvai ao Senhor!\n\nSALMOS 150:6" size:18 weight:UIFontWeightSemibold color:UIColor.labelColor];
    verse.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:verse];
    self.footnote = [self label:@"♧\nSua licença é validada neste dispositivo. A chave é armazenada no Keychain e nunca é exibida novamente." size:12 weight:UIFontWeightRegular color:UIColor.secondaryLabelColor];
    self.footnote.textAlignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:self.footnote];
    if (!self.savedKey.length) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.checking && self.gateWindow && !self.gateWindow.hidden) [self.keyField becomeFirstResponder];
        });
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [self login];
    return YES;
}

- (void)openPurchase {
    NSURL *url = [NSURL URLWithString:AYPurchaseURL];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)setBusy:(BOOL)busy {
    self.checking = busy;
    self.loginButton.enabled = !busy;
    [self.loginButton setTitle:busy ? @"Validando..." : @"Entrar" forState:UIControlStateNormal];
    if (busy) [self.spinner startAnimating]; else [self.spinner stopAnimating];
    self.retryButton.enabled = !busy;
}

- (void)showError:(NSString *)message {
    self.errorLabel.text = message;
    self.errorLabel.hidden = !message.length;
    self.retryButton.hidden = !message.length || !self.savedKey.length;
    if (message.length && self.activated) [self showGate];
}

- (void)applyCopy:(NSDictionary *)copy {
    if (![copy isKindOfClass:[NSDictionary class]]) return;
    if ([copy[@"keyLabel"] isKindOfClass:[NSString class]]) self.keyLabel.text = [copy[@"keyLabel"] uppercaseString];
    if ([copy[@"placeholder"] isKindOfClass:[NSString class]]) self.keyField.placeholder = copy[@"placeholder"];
    if ([copy[@"buttonText"] isKindOfClass:[NSString class]] && !self.checking) [self.loginButton setTitle:copy[@"buttonText"] forState:UIControlStateNormal];
    if ([copy[@"footnote"] isKindOfClass:[NSString class]]) self.footnote.text = copy[@"footnote"];
}

- (void)login {
    NSString *key = [self.keyField.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!key.length || self.checking) {
        if (!key.length) [self showError:@"Digite uma chave de licença."];
        return;
    }
    [self.keyField resignFirstResponder];
    [self validateKey:key isSaved:NO];
}

- (void)retrySavedKey {
    if (self.savedKey.length && !self.checking) [self validateKey:self.savedKey isSaved:YES];
}

- (void)validateKey:(NSString *)key isSaved:(BOOL)isSaved {
    if (self.checking) return;
    [self setBusy:YES];
    [self showError:nil];
    NSURL *url = [NSURL URLWithString:AYEndpoint];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"3105-iOS" forHTTPHeaderField:@"User-Agent"];
    NSString *device = UIDevice.currentDevice.identifierForVendor.UUIDString ?: [NSString stringWithFormat:@"ios-%@-%@", UIDevice.currentDevice.systemVersion, UIDevice.currentDevice.model];
    NSString *version = [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"1.1.1";
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:@{@"licenseKey": key, @"deviceFingerprint": device, @"appVersion": version} options:0 error:nil];
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setBusy:NO];
            if (error || ![response isKindOfClass:[NSHTTPURLResponse class]]) {
                [self showError:@"Não foi possível conectar ao servidor de licenças."];
                return;
            }
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;
            NSDictionary *body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            if (![body isKindOfClass:[NSDictionary class]]) body = nil;
            BOOL hasVerdict = [body[@"valid"] isKindOfClass:[NSNumber class]];
            BOOL rejectedLicense = hasVerdict && ![body[@"valid"] boolValue] &&
                ((http.statusCode >= 200 && http.statusCode < 300) || http.statusCode == 401 || http.statusCode == 403);
            if (rejectedLicense) {
                if (isSaved) { AYDeleteKey(); self.savedKey = nil; }
                NSString *message = [body[@"message"] isKindOfClass:[NSString class]] ? body[@"message"] : nil;
                if (!message.length && [body[@"reason"] isKindOfClass:[NSString class]]) message = body[@"reason"];
                [self showError:message.length ? message : @"A licença não foi aceita."];
                return;
            }
            if (http.statusCode < 200 || http.statusCode >= 300 || !hasVerdict) {
                [self showError:[NSString stringWithFormat:@"Servidor de licenças retornou HTTP %ld.", (long)http.statusCode]];
                return;
            }
            if (!isSaved && !AYSaveKey(key)) {
                [self showError:@"Não foi possível salvar a licença no Keychain."];
                return;
            }
            self.savedKey = key;
            [self applyCopy:body[@"loginConfig"]];
            [self dismissGate];
            if (!self.activated) {
                self.activated = YES;
                if (self.activation) self.activation();
            }
        });
    }] resume];
}

- (void)showGate {
    if (self.gateWindow && !self.gateWindow.hidden) return;
    if (!self.gateWindow) {
        UIWindowScene *scene = nil;
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) {
            if ([candidate isKindOfClass:[UIWindowScene class]] && candidate.activationState == UISceneActivationStateForegroundActive) {
                scene = (UIWindowScene *)candidate;
                break;
            }
        }
        if (scene) self.gateWindow = [[UIWindow alloc] initWithWindowScene:scene];
        else self.gateWindow = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        self.gateWindow.windowLevel = UIWindowLevelAlert + 1;
        self.gateWindow.rootViewController = self;
    }
    self.previousWindow = UIApplication.sharedApplication.keyWindow;
    [self.gateWindow makeKeyAndVisible];
}

- (void)dismissGate {
    [self.keyField resignFirstResponder];
    self.gateWindow.hidden = YES;
    [self.previousWindow makeKeyWindow];
}
@end

void AYLicenseGateStart(void (^activation)(void)) {
    dispatch_async(dispatch_get_main_queue(), ^{
        static AYLicenseGate *gate;
        if (gate) return;
        gate = [AYLicenseGate new];
        gate.activation = activation;
        gate.savedKey = AYStoredKey();
        [gate showGate];
        if (gate.savedKey.length) [gate retrySavedKey];
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (gate.activated && gate.savedKey.length && !gate.checking) [gate validateKey:gate.savedKey isSaved:YES];
        }];
    });
}
