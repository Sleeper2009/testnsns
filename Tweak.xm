#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <QuartzCore/QuartzCore.h>

#if __has_include(<rootless.h>)
    #import <rootless.h>
    #define JB_PATH(path) jbroot(path)
#else
    #define JB_PATH(path) (@"/var/jb" path)
#endif

// ================= DIAGNOSTIC LOGGER =================
// Bat/tat bang file: touch /var/mobile/Documents/lm_diag_on
// Log ra: /var/mobile/Documents/LiquidMorphDiag.log

static BOOL gDiagWindowOpen = NO;
static NSTimeInterval gDiagWindowStart = 0;
static const NSTimeInterval kDiagWindowDuration = 1.2; // giay, du dai de bat het animation launch

static BOOL LMDiagEnabled(void) {
    static BOOL cached = NO;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *flagPath = JB_PATH(@"/var/mobile/Documents/lm_diag_on");
        cached = [[NSFileManager defaultManager] fileExistsAtPath:flagPath] ||
                 [[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Documents/lm_diag_on"];
    });
    return cached;
}

static NSString *LMDiagLogPath(void) {
    NSString *p = JB_PATH(@"/var/mobile/Documents/LiquidMorphDiag.log");
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb"]) return p;
    return @"/var/mobile/Documents/LiquidMorphDiag.log";
}

static void LMDiagLog(NSString *format, ...) {
    if (!LMDiagEnabled()) return;
    @try {
        va_list args;
        va_start(args, format);
        NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
        va_end(args);

        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval rel = gDiagWindowOpen ? (now - gDiagWindowStart) : -1;

        NSString *line = [NSString stringWithFormat:@"[+%.4fs] %@\n", rel, msg];

        NSString *path = LMDiagLogPath();
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:path]) {
            [fm createFileAtPath:path contents:nil attributes:nil];
        }
        NSFileHandle *h = [NSFileHandle fileHandleForWritingAtPath:path];
        if (h) {
            [h seekToEndOfFile];
            [h writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
            [h closeFile];
        }
    } @catch (__unused NSException *e) {}
}

static void LMDiagOpenWindow(NSString *reason) {
    if (!LMDiagEnabled()) return;
    gDiagWindowOpen = YES;
    gDiagWindowStart = [[NSDate date] timeIntervalSince1970];
    LMDiagLog(@"===== WINDOW OPEN (%@) =====", reason);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kDiagWindowDuration * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
        LMDiagLog(@"===== WINDOW CLOSE =====\n");
        gDiagWindowOpen = NO;
    });
}

static NSString *LMDiagDescribeLayer(CALayer *layer) {
    if (!layer) return @"(nil)";
    id delegate = layer.delegate;
    NSString *delegateClass = delegate ? NSStringFromClass([delegate class]) : @"(none)";
    return [NSString stringWithFormat:@"class=%@ delegate=%@ frame=%@ super=%@",
            NSStringFromClass([layer class]),
            delegateClass,
            NSStringFromCGRect(layer.frame),
            layer.superlayer ? NSStringFromClass([layer.superlayer class]) : @"(none)"];
}

// ================= HOOKS: bat su kien tap/home de mo cua so log =================

%hook SBIconView
- (void)_handleTap {
    LMDiagOpenWindow(@"_handleTap");
    %orig;
}
%end

%hook SBIconController
- (void)handleHomeButtonTap {
    LMDiagOpenWindow(@"handleHomeButtonTap");
    %orig;
}
%end

// ================= HOOK: CALayer — addAnimation / actionForKey / addSublayer =================
// Gop chung mot khoi %hook CALayer duy nhat de tranh trung method giua cac khoi khac nhau

%hook CALayer

- (void)addAnimation:(CAAnimation *)animation forKey:(NSString *)key {
    if (gDiagWindowOpen) {
        NSString *extra = @"";
        if ([animation isKindOfClass:[CABasicAnimation class]]) {
            CABasicAnimation *ba = (CABasicAnimation *)animation;
            extra = [NSString stringWithFormat:@" keyPath=%@ from=%@ to=%@ dur=%.3f",
                     ba.keyPath, ba.fromValue, ba.toValue, ba.duration];
        } else if ([animation isKindOfClass:[CAKeyframeAnimation class]]) {
            CAKeyframeAnimation *ka = (CAKeyframeAnimation *)animation;
            extra = [NSString stringWithFormat:@" keyPath=%@ valuesCount=%lu dur=%.3f",
                     ka.keyPath, (unsigned long)ka.values.count, ka.duration];
        } else if ([animation isKindOfClass:[CATransition class]]) {
            extra = [NSString stringWithFormat:@" type=CATransition dur=%.3f", animation.duration];
        } else if ([animation isKindOfClass:[CAAnimationGroup class]]) {
            CAAnimationGroup *g = (CAAnimationGroup *)animation;
            extra = [NSString stringWithFormat:@" GROUP subCount=%lu dur=%.3f",
                     (unsigned long)g.animations.count, animation.duration];
        }
        LMDiagLog(@"addAnimation key=%@%@ | layer: %@", key, extra, LMDiagDescribeLayer(self));
    }
    %orig;
}

- (id<CAAction>)actionForKey:(NSString *)key {
    id<CAAction> result = %orig;
    if (gDiagWindowOpen) {
        static NSSet *interestingKeys;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            interestingKeys = [NSSet setWithArray:@[@"transform", @"position", @"bounds",
                                                      @"cornerRadius", @"path", @"opacity",
                                                      @"contents", @"frame", @"sublayerTransform"]];
        });
        if ([interestingKeys containsObject:key]) {
            LMDiagLog(@"actionForKey='%@' -> %@ | layer: %@",
                      key,
                      result ? NSStringFromClass([(id)result class]) : @"(nil action)",
                      LMDiagDescribeLayer(self));
        }
    }
    return result;
}

- (void)addSublayer:(CALayer *)layer {
    if (gDiagWindowOpen) {
        LMDiagLog(@"addSublayer: %@ into parent: %@", LMDiagDescribeLayer(layer), LMDiagDescribeLayer(self));
    }
    %orig;
}

%end

// ================= HOOK: UIView — didAddSubview =================
// Bat snapshot view ton tai rat ngan ma dump tinh khong thay duoc

%hook UIView

- (void)didAddSubview:(UIView *)subview {
    %orig;
    if (gDiagWindowOpen) {
        LMDiagLog(@"didAddSubview: %@ (class=%@) into %@ (class=%@) frame=%@",
                  subview, NSStringFromClass([subview class]),
                  self, NSStringFromClass([self class]),
                  NSStringFromCGRect(subview.frame));
    }
}

%end

%ctor {
    @autoreleasepool {
        LMDiagLog(@"===== LiquidMorphDiag loaded into %@ =====", [[NSProcessInfo processInfo] processName]);
    }
}
