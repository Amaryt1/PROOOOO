#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <os/log.h>

static NSString *const configURL=@"https://raw.githubusercontent.com/Amaryt1/PROOOOO/main/config.json";
static NSString *const storeKey=@"AMARYTKit5.";
static const NSInteger kitVersion=5;
static NSUserDefaults *prefs(void){return NSUserDefaults.standardUserDefaults;}
static NSString *key(NSString *s){if([s isEqual:@"config"])return @"AMARYTKit7.config";return [storeKey stringByAppendingString:s];}
static NSURL *asset(NSString *name){return [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:[@"AMARYTKit" stringByAppendingPathComponent:name]];}
static id decode(NSData *data){return data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;}
static void trace(NSString *message){
 os_log_with_type(OS_LOG_DEFAULT,OS_LOG_TYPE_DEFAULT,"AMARYTKit: %{public}@",message);
 static dispatch_queue_t queue;static dispatch_once_t once;
 dispatch_once(&once,^{queue=dispatch_queue_create("AMARYT.diagnostics",DISPATCH_QUEUE_SERIAL);});
 dispatch_async(queue,^{
  NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
  NSURL *url=[docs URLByAppendingPathComponent:@"AMARYT-debug.txt"];
  NSData *line=[[NSString stringWithFormat:@"%@ %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
  NSFileHandle *h=[NSFileHandle fileHandleForWritingToURL:url error:nil];
  if(!h){[line writeToURL:url atomically:YES];return;}
  @try{if([h seekToEndOfFile]>65536)[h truncateFileAtOffset:0];[h writeData:line];}@catch(NSException *ex){os_log_error(OS_LOG_DEFAULT,"AMARYTKit: diagnostic write failed");}@finally{[h closeFile];}
 });
}
static NSString *jsonText(id value){
 if(!value || ![NSJSONSerialization isValidJSONObject:value])return nil;
 return [[NSString alloc]initWithData:[NSJSONSerialization dataWithJSONObject:value options:0 error:nil] encoding:NSUTF8StringEncoding];
}
static BOOL samePanel(NSURL *url){return url.isFileURL && [url.URLByResolvingSymlinksInPath.path isEqual:asset(@"panel.html").URLByResolvingSymlinksInPath.path];}
static id member(id object,const char *name){
 Ivar iv=class_getInstanceVariable(object_getClass(object),name);
 return iv && ivar_getTypeEncoding(iv)[0]=='@' ? object_getIvar(object,iv):nil;
}
@interface AMARYTKit:NSObject<WKScriptMessageHandler,WKNavigationDelegate,NSURLSessionDownloadDelegate>
@property(nonatomic,weak) UIViewController *host;
@property(nonatomic,strong) JSContext *policy;
@property(nonatomic,strong) NSDictionary *config,*catalog,*transfer;
@property(nonatomic,strong) NSString *kind,*status,*modsSource;
@property(nonatomic,strong) NSMutableSet *seen,*pending;
@property(nonatomic,strong) WKWebView *panel;
@property(nonatomic,strong) UIButton *storeButton;
@property(nonatomic,strong) NSURLSession *session;
@property(nonatomic,strong) NSURLSessionDownloadTask *download;
@property(nonatomic,strong) NSMutableDictionary *requests;
@property(nonatomic) BOOL visible,ready,started,verifying;
@property(nonatomic,strong) NSTimer *expiry;
@property(nonatomic,strong) UIView *fallback;
@property(nonatomic,strong) NSArray *files;
@property(nonatomic,strong) NSURL *stage;
@property(nonatomic) NSUInteger fileIndex;
@property(nonatomic) NSInteger lastPercent;
@property(nonatomic) NSTimeInterval checked;
@property(nonatomic,strong) NSString *connection;
@property(nonatomic,strong) NSString *layoutSignature;
@property(nonatomic,strong) NSString *pendingInstallId;
@property(nonatomic,strong) NSArray *pendingInstallDirs;
@property(nonatomic) NSInteger installChecks;
@property(nonatomic,strong) UILabel *activeBadge;
@property(nonatomic,strong) UIScrollView *tabScroll;
@property(nonatomic,weak) UIView *tabParent;
@property(nonatomic,strong) NSDictionary *shownConfig;
-(NSArray*)installed;
@end
static AMARYTKit *kit;
@implementation AMARYTKit
-(instancetype)init{
 if((self=[super init])){
  _policy=[JSContext new];_policy.exceptionHandler=^(JSContext *ctx,JSValue *error){trace([NSString stringWithFormat:@"policy exception %@",error]);};
  [_policy evaluateScript:[NSString stringWithContentsOfURL:asset(@"policy.js") encoding:NSUTF8StringEncoding error:nil]?:@""];
  trace([_policy[@"acceptsJSON"] isUndefined]?@"policy.js missing":@"policy.js loaded");_connection=@"الإعدادات المحلية";
  _seen=[NSMutableSet set];_pending=[NSMutableSet set];_requests=[NSMutableDictionary new];
  NSURLSessionConfiguration *sc=NSURLSessionConfiguration.ephemeralSessionConfiguration;
  sc.timeoutIntervalForRequest=8;sc.timeoutIntervalForResource=180;sc.URLCache=nil;
  _session=[NSURLSession sessionWithConfiguration:sc delegate:self delegateQueue:NSOperationQueue.mainQueue];
  [self loadConfig];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(active:) name:UIApplicationDidBecomeActiveNotification object:nil];
 }return self;
}
-(BOOL)valid:(id)obj mods:(BOOL)mods{
 NSString *raw=jsonText(obj);
 return raw && [NSPropertyListSerialization propertyList:obj isValidForFormat:NSPropertyListBinaryFormat_v1_0] &&
   [[self.policy[@"acceptsJSON"] callWithArguments:@[raw,@(mods)]] toBool];
}
-(void)loadConfig{
 NSDictionary *cached=[prefs() dictionaryForKey:key(@"config")][@"value"];
 NSDictionary *legacy=[prefs() dictionaryForKey:@"AMARYTKit5.config"][@"value"];
 if(!cached && [self valid:legacy mods:NO] && [[[self.policy[@"mode"] callWithArguments:@[legacy,@(kitVersion),@(NSDate.date.timeIntervalSince1970*1000)]] toString] isEqual:@"force"])cached=legacy;
 self.config=[self valid:cached mods:NO]?cached:decode([NSData dataWithContentsOfURL:asset(@"config.json")]);
 if(![self valid:self.config mods:NO]){
  NSDictionary *local=decode([NSData dataWithContentsOfURL:asset(@"config.json")]);
  self.config=[local[@"welcome"][@"title"] isKindOfClass:NSString.class]?local:nil;
  trace(@"using bundled configuration after policy validation failure");
 }
 trace(self.config?@"config loaded and validated":@"config validation failed");
}
-(NSDictionary*)catalogWithPilot:(NSDictionary*)catalog{
 if(![NSFileManager.defaultManager fileExistsAtPath:asset(@"pilot-cars.zip").path])return catalog;
 NSDictionary *local=decode([NSData dataWithContentsOfURL:asset(@"mods.json")]);
 if(![self valid:local mods:YES] || ![catalog[@"mods"] isKindOfClass:NSArray.class])return catalog;
 NSDictionary *pilot=[local[@"mods"] firstObject];if(![pilot[@"bundleArchive"] isEqual:@"pilot-cars.zip"])return catalog;
 for(NSDictionary *m in catalog[@"mods"])if([m[@"id"] isEqual:pilot[@"id"]])return catalog;
 NSMutableDictionary *merged=[catalog mutableCopy];NSMutableArray *models=[NSMutableArray arrayWithObject:pilot];[models addObjectsFromArray:catalog[@"mods"]];
 merged[@"mods"]=models;return merged;
}
-(void)loadMods{
 self.modsSource=self.config[@"modsURL"];NSDictionary *c=[prefs() dictionaryForKey:key(@"catalog")];
 NSDictionary *base=[c[@"url"] isEqual:self.modsSource] && [self valid:c[@"value"] mods:YES]?c[@"value"]:decode([NSData dataWithContentsOfURL:asset(@"mods.json")]);
 self.catalog=[self catalogWithPilot:base];
}
-(void)fetch:(BOOL)mods{
 NSString *url=mods?self.config[@"modsURL"]:configURL;
 NSURL *endpoint=[NSURL URLWithString:url?:@""];
 if(!endpoint.host.length || ![endpoint.scheme.lowercaseString isEqual:@"https"] || [self.pending containsObject:url])return;
 if(!mods)self.checked=NSProcessInfo.processInfo.systemUptime;
 trace(mods?@"catalog request":@"config request");[self.pending addObject:url];
 NSString *slot=mods?@"catalog":@"config";NSDictionary *cache=[prefs() dictionaryForKey:key(slot)];
 NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:endpoint cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
 if([cache[@"url"] isEqual:url] && [self valid:cache[@"value"] mods:mods] && [cache[@"etag"] length])[req setValue:cache[@"etag"] forHTTPHeaderField:@"If-None-Match"];
 NSURLSessionDownloadTask *task=[self.session downloadTaskWithRequest:req];
 self.requests[@(task.taskIdentifier)]=@{@"url":url,@"slot":slot};[task resume];
}
-(void)active:(NSNotification*)note{
 if(self.visible){[self evaluate];[self refreshIfNeeded];}
}
-(void)refreshIfNeeded{
 if(!self.started || NSProcessInfo.processInfo.systemUptime-self.checked>=30){self.started=YES;[self fetch:NO];}
}
-(void)appeared:(UIViewController*)vc{
 if(!vc.viewIfLoaded.window || vc.viewIfLoaded.hidden || vc.isBeingDismissed)return;
 if(self.host!=vc){[self hide];self.layoutSignature=nil;[self.activeBadge removeFromSuperview];self.activeBadge=nil;}
 self.host=vc;self.visible=YES;
 // Preserve diagnostics in the log without exposing build details to players.
 [self.activeBadge removeFromSuperview];self.activeBadge=nil;
 [self layout:vc];[self evaluate];
 trace(@"launcher visible");[self refreshIfNeeded];
}
-(void)hide{
 [self.panel.configuration.userContentController removeScriptMessageHandlerForName:@"amar"];
 [self.fallback removeFromSuperview];self.fallback=nil;self.shownConfig=nil;[self.panel removeFromSuperview];self.panel=nil;self.kind=nil;self.ready=NO;
 [self.expiry invalidate];self.expiry=nil;
}
-(NSString*)updateMode{return [[self.policy[@"mode"] callWithArguments:@[self.config,@(kitVersion),@(NSDate.date.timeIntervalSince1970*1000)]] toString];}
-(NSString*)seenKey:(NSString*)kind{
 if([kind isEqual:@"optional"])return [NSString stringWithFormat:@"optional-%@",self.config[@"update"][@"latest"]];
 return [NSString stringWithFormat:@"%@-%@",kind,self.config[kind][@"id"]];
}
-(void)evaluate{
 if(!self.visible || !self.host.viewIfLoaded.window || !self.config)return;
 NSString *mode=[self updateMode];
 if([mode isEqual:@"force"]){[self show:@"force"];return;}
 if([self.kind isEqual:@"force"])[self hide];
 if([self.kind isEqual:@"catalog"] && [self.config[@"sections"][@"mods"] boolValue]){[self render];return;}
 for(NSString *kind in @[@"welcome",@"notification",@"optional"]){
  BOOL optional=[kind isEqual:@"optional"];
  if(optional?![mode isEqual:kind]:![self.config[kind][@"enabled"] boolValue])continue;
  NSString *marker=[self seenKey:kind];
  if([self.seen containsObject:marker] || (!optional && [self.config[kind][@"frequency"] isEqual:@"once"] && [prefs() boolForKey:key(marker)]))continue;
  [self show:kind];return;
 }
 [self hide];
}
-(void)show:(NSString*)kind{
 if(!self.visible || !self.host.viewIfLoaded.window)return;
 BOOL native=![kind isEqual:@"catalog"];
 if(native && self.fallback.superview==self.host.view && [self.kind isEqual:kind] && self.shownConfig==self.config)return;
 if(self.fallback && !native)[self hide];
 if(![self.kind isEqual:kind])trace([@"display " stringByAppendingString:kind]);
 if(!native && !self.panel){
  WKWebViewConfiguration *cfg=[WKWebViewConfiguration new];cfg.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;
  [cfg.userContentController addScriptMessageHandler:self name:@"amar"];
  WKWebView *p=[[WKWebView alloc]initWithFrame:self.host.view.bounds configuration:cfg];p.navigationDelegate=self;
  p.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;p.opaque=NO;p.backgroundColor=UIColor.clearColor;p.scrollView.backgroundColor=UIColor.clearColor;
  p.accessibilityViewIsModal=YES;self.panel=p;[self.host.view addSubview:p];
  [p loadFileURL:asset(@"panel.html") allowingReadAccessToURL:asset(@"panel.html").URLByDeletingLastPathComponent];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(self.panel==p && !self.ready)[self nativePanel];});
 }
 self.kind=kind;if(native){self.shownConfig=self.config;[self nativePanel];}else{[self.host.view bringSubviewToFront:self.panel];[self render];}
 [self.expiry invalidate];self.expiry=nil;
 if([kind isEqual:@"force"]){
  double end=[[self.policy evaluateScript:@"Date.parse"] callWithArguments:@[self.config[@"update"][@"expiresUTC"]]].toDouble/1000;
  self.expiry=[NSTimer scheduledTimerWithTimeInterval:MAX(.1,end-NSDate.date.timeIntervalSince1970+.1) target:self selector:@selector(expired:) userInfo:nil repeats:NO];
 }
}
-(void)expired:(NSTimer*)timer{[self evaluate];}
-(void)webView:(WKWebView*)web didFinishNavigation:(WKNavigation*)nav{if(web==self.panel){self.ready=YES;trace(@"panel navigation finished");[self render];}}
-(void)webView:(WKWebView*)web didFailProvisionalNavigation:(WKNavigation*)nav withError:(NSError*)error{if(web==self.panel)[self nativePanel];}
-(void)webView:(WKWebView*)web didFailNavigation:(WKNavigation*)nav withError:(NSError*)error{if(web==self.panel)[self nativePanel];}
-(void)webViewWebContentProcessDidTerminate:(WKWebView*)web{if(web==self.panel)[self nativePanel];}
-(void)webView:(WKWebView*)web decidePolicyForNavigationAction:(WKNavigationAction*)action decisionHandler:(void (^)(WKNavigationActionPolicy))reply{
 reply(samePanel(action.request.URL)?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);
}
-(void)render{
 if(!self.ready || !self.kind)return;
 NSDictionary *state=@{@"kind":self.kind,@"config":self.config,@"version":@(kitVersion),@"catalog":self.catalog?:@{@"categories":@[],@"mods":@[]},@"favorites":[prefs() arrayForKey:key(@"favorites")]?:@[],@"downloaded":[self downloaded],@"installed":[self installed],@"busy":@(self.transfer!=nil),@"connection":self.connection?:@"",@"build":@"9",@"status":self.status?:@"",@"last":@([prefs() doubleForKey:key(@"last")])};
 NSData *data=[NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
 NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 WKWebView *web=self.panel;if(json)[web evaluateJavaScript:[NSString stringWithFormat:@"render(%@)",json] completionHandler:^(id result,NSError *error){if(error && self.panel==web)[self nativePanel];}];
}
-(void)openStore{if([self.config[@"sections"][@"mods"] boolValue] && ![[self updateMode] isEqual:@"force"]){[self loadMods];[self show:@"catalog"];[self fetch:YES];}}
-(void)nativeAction:(UIButton*)button{
 NSString *a=button.accessibilityIdentifier;
 if([a hasPrefix:@"social-"]){[self action:@"social" ident:[a substringFromIndex:7]];return;}
 if([a isEqual:@"mods"]){[self openStore];return;}
 if([a isEqual:@"news"]){
  UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"أخبار AMAR YT" message:[self.config[@"news"] count]?[self.config[@"news"] componentsJoinedByString:@"\n"]:@"لا توجد أخبار منشورة حاليًا." preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"إغلاق" style:UIAlertActionStyleCancel handler:nil]];[self.host presentViewController:alert animated:YES completion:nil];return;
 }[self action:a ident:@""];
}
-(void)nativePanel{
 NSString *kind=self.kind;if(!self.visible || !kind || !self.host.viewIfLoaded.window)return;
 BOOL welcome=[kind isEqual:@"welcome"],forced=[kind isEqual:@"force"],update=forced || [kind isEqual:@"optional"];
 NSDictionary *m=self.config[update?@"update":kind];
 [self.panel.configuration.userContentController removeScriptMessageHandlerForName:@"amar"];
 [self.panel removeFromSuperview];self.panel=nil;self.ready=NO;[self.fallback removeFromSuperview];
 UIView *root=self.host.view,*shade=[[UIView alloc]initWithFrame:root.bounds];self.fallback=shade;
 shade.semanticContentAttribute=UISemanticContentAttributeForceRightToLeft;shade.accessibilityViewIsModal=YES;
 shade.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;shade.backgroundColor=[UIColor colorWithWhite:.015 alpha:.82];[root addSubview:shade];
 UIColor *gold=[UIColor colorWithRed:.95 green:.74 blue:.26 alpha:1];
 UIView *card=[UIView new];card.translatesAutoresizingMaskIntoConstraints=NO;card.clipsToBounds=YES;card.layer.cornerRadius=22;card.layer.borderWidth=1;card.layer.borderColor=gold.CGColor;
 card.backgroundColor=[UIColor colorWithRed:.075 green:.092 blue:.124 alpha:1];[shade addSubview:card];
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[card addSubview:scroll];
 UIStackView *stack=[UIStackView new];stack.translatesAutoresizingMaskIntoConstraints=NO;stack.axis=UILayoutConstraintAxisVertical;stack.spacing=9;
 stack.layoutMargins=UIEdgeInsetsMake(16,18,16,18);stack.layoutMarginsRelativeArrangement=YES;[scroll addSubview:stack];
 UILayoutGuide *safe=shade.safeAreaLayoutGuide;
 CGFloat cap=root.traitCollection.userInterfaceIdiom==UIUserInterfaceIdiomPad?500:366;
 NSLayoutConstraint *width=[card.widthAnchor constraintEqualToConstant:cap];width.priority=UILayoutPriorityDefaultHigh;
 NSLayoutConstraint *height=[card.heightAnchor constraintEqualToAnchor:stack.heightAnchor];height.priority=UILayoutPriorityDefaultHigh;
 [NSLayoutConstraint activateConstraints:@[width,height,[card.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor],[card.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],[card.widthAnchor constraintLessThanOrEqualToAnchor:safe.widthAnchor constant:-24],[card.heightAnchor constraintLessThanOrEqualToAnchor:safe.heightAnchor constant:-24],[scroll.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:card.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:card.bottomAnchor],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor]]];
 UILabel *(^label)(NSString*,UIFontTextStyle)=^UILabel*(NSString *text,UIFontTextStyle style){
  UILabel *l=[UILabel new];l.numberOfLines=0;l.textAlignment=NSTextAlignmentCenter;l.textColor=UIColor.whiteColor;l.font=[UIFont preferredFontForTextStyle:style];l.adjustsFontForContentSizeCategory=YES;l.text=text;[stack addArrangedSubview:l];return l;
 };
 UIButton *(^button)(NSString*,NSString*,NSString*)=^UIButton*(NSString *title,NSString *symbol,NSString *action){
  UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:title forState:0];[b setImage:[UIImage systemImageNamed:symbol] forState:0];b.tintColor=gold;b.accessibilityLabel=title;b.accessibilityIdentifier=action;
  b.titleLabel.font=[UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];b.titleLabel.adjustsFontForContentSizeCategory=YES;b.titleLabel.numberOfLines=0;b.titleLabel.textAlignment=NSTextAlignmentCenter;
  b.layer.cornerRadius=10;b.backgroundColor=[UIColor colorWithWhite:1 alpha:.07];b.contentEdgeInsets=UIEdgeInsetsMake(5,4,5,4);
  [[b.heightAnchor constraintGreaterThanOrEqualToConstant:44] setActive:YES];[b addTarget:self action:@selector(nativeAction:) forControlEvents:UIControlEventTouchUpInside];return b;
 };
 UIStackView *(^row)(void)=^UIStackView*{UIStackView *r=[UIStackView new];r.axis=UIContentSizeCategoryIsAccessibilityCategory(root.traitCollection.preferredContentSizeCategory)?UILayoutConstraintAxisVertical:UILayoutConstraintAxisHorizontal;r.spacing=5;r.distribution=UIStackViewDistributionFillEqually;[stack addArrangedSubview:r];return r;};
 UIImage *logo=[UIImage imageWithContentsOfFile:[NSBundle.mainBundle.resourcePath stringByAppendingPathComponent:@"GTAVArabic/custom_social_icon.jpeg"]];
 UIImageView *mark=[[UIImageView alloc]initWithImage:logo?:[UIImage systemImageNamed:@"gamecontroller.fill"]];mark.contentMode=UIViewContentModeScaleAspectFit;mark.tintColor=gold;mark.accessibilityLabel=@"AMAR YT";[stack addArrangedSubview:mark];[[mark.heightAnchor constraintEqualToConstant:54] setActive:YES];
 label(m[@"title"]?:@"المودات",UIFontTextStyleTitle2).accessibilityTraits=UIAccessibilityTraitHeader;
 label(m[@"body"]?:@"تعذر فتح الفهرس. أعد فتح قسم المودات للمحاولة مجددًا.",UIFontTextStyleBody);
 if(update){label([NSString stringWithFormat:@"الإصدار المطلوب %@",m[forced?@"minimum":@"latest"]],UIFontTextStyleSubheadline);for(NSString *line in m[@"features"])label(line,UIFontTextStyleFootnote);}
 if(welcome){
  UIStackView *links=row();
  if([self.config[@"sections"][@"mods"] boolValue])[links addArrangedSubview:button(@"المودات",@"shippingbox",@"mods")];
  [links addArrangedSubview:button(@"الأخبار",@"bell",@"news")];
  if([m[@"contactURL"] length])[links addArrangedSubview:button(@"الدعم",@"paperplane",@"contact")];
 }
 UIButton *primary=button(m[@"action"]?:@"إغلاق",update?@"arrow.down.circle":@"gamecontroller.fill",update?@"update":@"close");primary.backgroundColor=gold;primary.tintColor=UIColor.blackColor;[stack addArrangedSubview:primary];
 if([m[@"contactURL"] length] && [m[@"contact"] length])[stack addArrangedSubview:button(m[@"contact"],@"bubble.left",@"contact")];
 if(welcome){UIStackView *social=row();[social addArrangedSubview:button(@"Instagram",@"camera",@"social-instagram")];[social addArrangedSubview:button(@"Telegram",@"paperplane",@"social-telegram")];[social addArrangedSubview:button(@"TikTok",@"music.note",@"social-tiktok")];}
 if(!forced && m)[stack addArrangedSubview:button(@"إغلاق",@"xmark",@"close")];
 [root bringSubviewToFront:self.activeBadge];
 if(!UIAccessibilityIsReduceMotionEnabled()){card.alpha=.2;[UIView animateWithDuration:.22 animations:^{card.alpha=1;}];}
 UIAccessibilityPostNotification(UIAccessibilityScreenChangedNotification,stack);
 trace([NSString stringWithFormat:@"native %@ mounted on %@",kind,NSStringFromClass(self.host.class)]);
}
static char sidebarFrames;
static CGRect originalFrame(UIView *v){
 NSArray *pair=objc_getAssociatedObject(v,&sidebarFrames);
 return pair && CGRectEqualToRect(v.frame,[pair[1] CGRectValue])?[pair[0] CGRectValue]:v.frame;
}
static BOOL brandView(UIView *v){
 NSString *s=[v isKindOfClass:UILabel.class]?[(UILabel*)v text]:v.accessibilityLabel;
 if([[s.uppercaseString stringByReplacingOccurrencesOfString:@" " withString:@""] containsString:@"AMARYT"])return YES;
 for(UIView *child in v.subviews)if(brandView(child))return YES;
 return NO;
}
-(void)layout:(UIViewController*)vc{
 NSArray *tabs=member(vc,"_tabs");UIView *side=member(vc,"_sidebar");
 if(![side isKindOfClass:UIView.class] || ![tabs isKindOfClass:NSArray.class])return;
 NSDictionary *names=@{@"GAMES":@"الألعاب",@"الألعاب":@"الألعاب",@"DATA":@"الحفظ",@"SAVES":@"الحفظ",@"الحفظ":@"الحفظ",@"البيانات وملفات الحفظ":@"الحفظ",@"ملفات الحفظ":@"الحفظ",@"SETTINGS":@"الإعدادات",@"الإعدادات":@"الإعدادات",@"MODS":@"المودات",@"المودات":@"المودات"};
 NSMutableArray *visible=[NSMutableArray new];NSMutableArray<NSNumber*> *widths=[NSMutableArray new];CGFloat total=0;SEL action=NSSelectorFromString(@"tabTapped:");
 NSMutableArray *geometry=[NSMutableArray new];
 for(UIButton *button in tabs){
  if(![button isKindOfClass:UIButton.class] || ![[button actionsForTarget:vc forControlEvent:UIControlEventTouchUpInside] containsObject:NSStringFromSelector(action)])continue;
  NSAttributedString *old=[button attributedTitleForState:0];NSString *name=names[button.accessibilityLabel.uppercaseString?:@""]?:names[old.string.uppercaseString?:@""];if(!name && button.tag>=0 && button.tag<4){
   // The original controller assigns these tags for GAMES, DATA, SETTINGS, MODS.
   name=(@[@"الألعاب",@"الحفظ",@"الإعدادات",@"المودات"])[button.tag];
  }
  if(!name)continue;
  static char captionKey;
  UILabel *caption=objc_getAssociatedObject(button,&captionKey);
  if(!caption){
   caption=[UILabel new];caption.userInteractionEnabled=NO;caption.isAccessibilityElement=NO;
   caption.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
   caption.textAlignment=NSTextAlignmentCenter;caption.font=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];caption.numberOfLines=1;
   [button addSubview:caption];objc_setAssociatedObject(button,&captionKey,caption,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  caption.text=name;caption.textColor=old.length?[old attribute:NSForegroundColorAttributeName atIndex:0 effectiveRange:NULL]:nil;
  if(!caption.textColor)caption.textColor=button.currentTitleColor?:UIColor.whiteColor;
  caption.frame=button.bounds;button.titleLabel.alpha=0;button.accessibilityLabel=name;
  if(button.subviews.lastObject!=caption)[button bringSubviewToFront:caption];
  CGFloat desired=ceil([caption sizeThatFits:CGSizeMake(CGFLOAT_MAX,48)].width)+20;
  if(!button.hidden){[visible addObject:button];total+=desired;[widths addObject:@(desired)];[geometry addObject:[NSString stringWithFormat:@"%@ %.0f",name,button.frame.size.width]];}
 }
 if(visible.count){
  UIButton *first=visible.firstObject;UIView *parent=first.superview==self.tabScroll?self.tabParent:first.superview;UIView *avatar=member(vc,"_avatar");
  CGRect rail=[side convertRect:side.bounds toView:parent];CGFloat left=MAX(parent.safeAreaInsets.left+3,CGRectGetMaxX(rail)+4);
  CGFloat right=CGRectGetWidth(parent.bounds)-parent.safeAreaInsets.right-4;
  if([avatar isKindOfClass:UIView.class] && !avatar.hidden && avatar.superview==parent)right=MIN(right,CGRectGetMinX(avatar.frame)-5);
  CGFloat gap=4,full=total+gap*(visible.count-1),room=right-left;
  if(room>0 && parent){
   BOOL compact=full>room;CGFloat y=first.frame.origin.y,height=MAX(32,first.frame.size.height);
   if(first.superview==self.tabScroll && y==0)y=self.tabScroll.frame.origin.y;
   if(compact){
    if(!self.tabScroll || self.tabParent!=parent){self.tabScroll=[UIScrollView new];self.tabScroll.showsHorizontalScrollIndicator=YES;self.tabParent=parent;[parent addSubview:self.tabScroll];}
    self.tabScroll.frame=CGRectMake(left,y,room,height);self.tabScroll.contentSize=CGSizeMake(full,height);
   }
   CGFloat x=compact?0:right-full;
   NSUInteger index=0;
   for(UIButton *button in visible){
    UIView *container=compact?self.tabScroll:parent;if(button.superview!=container)[container addSubview:button];
    CGRect f=CGRectMake(x,compact?0:y,widths[index++].doubleValue,height);
    if(!CGRectEqualToRect(button.frame,f))button.frame=f;x=CGRectGetMaxX(f)+gap;
   }
   if(!compact && self.tabScroll){for(UIView *v in self.tabScroll.subviews.copy)if([tabs containsObject:v])[parent addSubview:v];[self.tabScroll removeFromSuperview];self.tabScroll=nil;self.tabParent=nil;}
  }
 }
 if(self.storeButton.superview!=side){
  [self.storeButton removeFromSuperview];UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];self.storeButton=b;
  b.titleLabel.font=[UIFont boldSystemFontOfSize:14];b.tintColor=UIColor.whiteColor;b.layer.cornerRadius=7;b.backgroundColor=[UIColor colorWithWhite:.16 alpha:1];
  [b setImage:[UIImage systemImageNamed:@"shippingbox"] forState:0];b.accessibilityLabel=@"المودات";
  [b addTarget:self action:@selector(openStore) forControlEvents:UIControlEventTouchUpInside];[side addSubview:b];
 }
 BOOL enabled=self.config ? [self.config[@"sections"][@"mods"] boolValue]:YES;
 CGFloat h=CGRectGetHeight(side.bounds),w=CGRectGetWidth(side.bounds);
 UIView *anchor=member(vc,"_gta6Icon");CGFloat afterGame=anchor.superview==side?CGRectGetMaxY(originalFrame(anchor)):0;
 CGFloat upperBrand=CGFLOAT_MAX;
 for(UIView *v in side.subviews){
  if(v==self.storeButton || v.hidden || v.alpha<.01)continue;
  CGRect f=originalFrame(v);
  if(CGRectGetMidY(f)>afterGame && f.size.height<h*.3 && brandView(v))upperBrand=MIN(upperBrand,CGRectGetMaxY(f));
 }
 // In collapsed mode text is hidden; use the next icon row following GTA VI.
 CGFloat iconBottom=CGFLOAT_MAX;
 for(UIView *v in side.subviews){
  if(v==self.storeButton || v.hidden || v.alpha<.01)continue;
  CGRect f=originalFrame(v);
  if(CGRectGetMidY(f)>afterGame+2 && f.size.height>=16 && f.size.height<=64 &&
     ([v isKindOfClass:UIControl.class] || [v isKindOfClass:UIImageView.class]))iconBottom=MIN(iconBottom,CGRectGetMaxY(f));
 }
 CGFloat pivot=MIN(upperBrand,iconBottom);
 if(pivot==CGFLOAT_MAX)pivot=afterGame;
 for(UIView *v in side.subviews){
  if(v==self.storeButton || v.hidden)continue;CGRect f=originalFrame(v);
  if(f.size.height<=64 && CGRectGetMinY(f)<pivot && CGRectGetMidY(f)>afterGame && CGRectGetMaxY(f)<=pivot+12)pivot=MAX(pivot,CGRectGetMaxY(f));
 }
 CGFloat row=MIN(44,MAX(0,h*.13)),next=h;
 for(UIView *v in side.subviews){
  if(v==self.storeButton || v.hidden || v.alpha<.01)continue;
  CGRect f=originalFrame(v);if(f.size.height<h*.85 && CGRectGetMinY(f)>=pivot)next=MIN(next,CGRectGetMinY(f));
 }
 BOOL reserve=enabled && next-pivot<row+6;CGFloat k=reserve && h>0?(h-row-6)/h:1;
 for(UIView *v in side.subviews){
  if(v==self.storeButton || v.hidden)continue;CGRect raw=originalFrame(v);if(raw.size.height>h*.85)continue;
  CGRect f=raw;if(reserve){f.origin.y=raw.origin.y*k+(CGRectGetMidY(raw)>pivot?row+6:0);f.size.height=raw.size.height*k;}
  objc_setAssociatedObject(v,&sidebarFrames,@[[NSValue valueWithCGRect:raw],[NSValue valueWithCGRect:f]],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(!CGRectEqualToRect(v.frame,f))v.frame=f;
 }
 self.storeButton.frame=CGRectMake(3,MIN(h-row,MAX(0,pivot*k+2)),MAX(0,w-6),row);self.storeButton.hidden=!enabled;
 NSString *caption=w>=96?@"  المودات":@"";if(![[self.storeButton titleForState:0] isEqual:caption])[self.storeButton setTitle:caption forState:0];
 NSString *sig=[NSString stringWithFormat:@"tabs=%lu sidebar=%.0fx%.0f modsY=%.0f",(unsigned long)visible.count,w,h,self.storeButton.frame.origin.y];
 if(![self.layoutSignature isEqual:sig]){self.layoutSignature=sig;trace(sig);trace([NSString stringWithFormat:@"tab widths before %@ after %@",geometry,[visible valueForKeyPath:@"frame"]]);}
 UIView *top=self.fallback?:self.panel;if(top && top.superview==vc.view && [vc.view.subviews indexOfObject:top]+2<vc.view.subviews.count)[vc.view bringSubviewToFront:top];if(self.activeBadge.superview==vc.view && vc.view.subviews.lastObject!=self.activeBadge)[vc.view bringSubviewToFront:self.activeBadge];
}
-(void)userContentController:(WKUserContentController*)c didReceiveScriptMessage:(WKScriptMessage*)msg{
 if(msg.webView!=self.panel || !msg.frameInfo.mainFrame || !samePanel(msg.frameInfo.request.URL) || ![msg.body isKindOfClass:NSDictionary.class])return;
 NSString *a=msg.body[@"action"],*ident=msg.body[@"id"];if(![a isKindOfClass:NSString.class] || ![ident isKindOfClass:NSString.class])return;
 [self action:a ident:ident];
}
-(void)action:(NSString*)a ident:(NSString*)ident{
 BOOL force=[[self updateMode] isEqual:@"force"];BOOL store=[self.kind isEqual:@"catalog"] && !force;
 if([a isEqual:@"close"] && !force){
  if(!store){NSString *mark=[self seenKey:self.kind];[self.seen addObject:mark];if([self.config[self.kind][@"frequency"] isEqual:@"once"])[prefs() setBool:YES forKey:key(mark)];}
  [self hide];[self evaluate];return;
 }
 BOOL update=force || [self.kind isEqual:@"optional"];NSDictionary *m=self.config[update?@"update":self.kind];
 NSString *link=nil;
 if([a isEqual:@"update"] && update)link=m[@"url"];
 if([a isEqual:@"contact"] && !store)link=m[@"contactURL"];
 if((store || [self.kind isEqual:@"welcome"]) && [a isEqual:@"social"])link=self.config[@"social"][ident];
 if(link.length){NSURL *url=[NSURL URLWithString:link];if([url.scheme.lowercaseString isEqual:@"https"])[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];}
 if(!store)return;
 if([a isEqual:@"clearCatalog"]){[prefs() removeObjectForKey:key(@"catalog")];[self loadMods];self.status=@"تم مسح قائمة المودات المخزّنة.";[self render];return;}
 if([a isEqual:@"refreshConfig"]){[self fetch:NO];return;}
 if([a isEqual:@"refreshMods"]){[self fetch:YES];return;}
 if([a isEqual:@"cancelDownload"]){if(self.download){[self.download cancel];self.download=nil;}if(self.transfer)[self finishTransfer:@"تم إلغاء التنزيل."];return;}
 for(NSDictionary *mod in self.catalog[@"mods"])if([mod[@"id"] isEqual:ident]){
  if([a isEqual:@"favorite"]){NSMutableArray *f=[[prefs() arrayForKey:key(@"favorites")] mutableCopy]?:[NSMutableArray new];if([f containsObject:ident])[f removeObject:ident];else [f addObject:ident];[prefs() setObject:f forKey:key(@"favorites")];[self render];}
  if([a isEqual:@"download"] && !self.download && !self.verifying && [mod[@"minKit"] integerValue]<=kitVersion && kitVersion<=[mod[@"maxKit"] integerValue]){
   [self beginMod:mod];
  }break;
 }
}

static NSURL *nativeModsRoot(void){
 NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 return [[docs URLByAppendingPathComponent:@"GTAV" isDirectory:YES] URLByAppendingPathComponent:@"mods" isDirectory:YES];
}
static BOOL installedFolders(NSArray *names){
 if(![names isKindOfClass:NSArray.class] || !names.count || names.count>20)return NO;
 NSFileManager *fm=NSFileManager.defaultManager;
 for(id name in names){
  if(![name isKindOfClass:NSString.class] || ![(NSString*)name length] || [(NSString*)name containsString:@"/"] || [(NSString*)name containsString:@".."])return NO;
  NSURL *folder=[nativeModsRoot() URLByAppendingPathComponent:name isDirectory:YES];
  BOOL isDir=NO;
  if(![fm fileExistsAtPath:folder.path isDirectory:&isDir] || !isDir)return NO;
  if(![fm contentsOfDirectoryAtPath:folder.path error:nil].count)return NO;
 }return YES;
}
static NSURL *modRoot(void){
 NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 return [docs URLByAppendingPathComponent:@"AMARYT-Mods" isDirectory:YES];
}
static BOOL regularFolder(NSURL *url){
 return [[[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil] fileType] isEqual:NSFileTypeDirectory];
}
-(NSArray*)installed{
 NSMutableArray *found=[NSMutableArray new];
 for(NSDictionary *m in self.catalog[@"mods"]?:@[]){
  if(installedFolders(m[@"expectedMods"]))[found addObject:m[@"id"]];
 }return found;
}
-(void)pollNativeImport{
 NSString *identifier=self.pendingInstallId;
 if(!identifier.length)return;
 if(installedFolders(self.pendingInstallDirs)){
  self.pendingInstallId=nil;self.pendingInstallDirs=nil;
  self.status=@"تم التثبيت بنجاح.";
  trace([NSString stringWithFormat:@"native importer confirmed %@",identifier]);
  [self render];return;
 }
 if(++self.installChecks>=40){
  self.pendingInstallId=nil;self.pendingInstallDirs=nil;
  self.status=@"تعذّر تأكيد التثبيت. راجع قائمة المودات الأصلية.";
  trace([NSString stringWithFormat:@"native importer not confirmed %@",identifier]);
  [self render];return;
 }
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{if([self.pendingInstallId isEqual:identifier])[self pollNativeImport];});
}
-(void)importArchive:(NSURL*)url forMod:(NSDictionary*)mod{
 if(![url isFileURL] || ![NSFileManager.defaultManager fileExistsAtPath:url.path]){
  self.status=@"ملف التثبيت غير متوفر.";[self render];return;
 }
 UIViewController *vc=self.host;SEL selector=NSSelectorFromString(@"importModsFrom:");
 if(!vc.viewIfLoaded.window || ![vc respondsToSelector:selector]){
  self.status=@"تم تحميل ZIP. استخدم زر استيراد مود في المشغّل.";
  [self render];return;
 }
 trace([NSString stringWithFormat:@"invoke original importer %@",mod[@"id"]]);
 self.pendingInstallId=mod[@"id"];self.pendingInstallDirs=mod[@"expectedMods"];self.installChecks=0;
 self.status=@"جارٍ استيراد المود إلى اللعبة…";[self render];
 @try{
  ((void(*)(id,SEL,id))objc_msgSend)(vc,selector,@[url]);
 }@catch(NSException *exception){
  trace([NSString stringWithFormat:@"native import exception %@",exception.name]);
  self.pendingInstallId=nil;self.pendingInstallDirs=nil;
  self.status=@"تعذّر الاستيراد تلقائيًا. استخدم الاستيراد اليدوي.";
  [self render];return;
 }
 if(self.pendingInstallDirs.count){
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC),dispatch_get_main_queue(),^{if(self.pendingInstallId)[self pollNativeImport];});
 }else{
  self.pendingInstallId=nil;self.pendingInstallDirs=nil;
  self.status=@"تم إرسال ZIP إلى مستورد اللعبة. تحقق من نتيجة الاستيراد.";
  [self render];
 }
}
-(NSArray*)downloaded{
 NSURL *root=modRoot();NSMutableArray *result=[NSMutableArray new];if(!regularFolder(root))return result;
 for(NSURL *dir in [NSFileManager.defaultManager contentsOfDirectoryAtURL:root includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles error:nil]){
  if(!regularFolder(dir))continue;
  NSArray *files=[NSArray arrayWithContentsOfURL:[dir URLByAppendingPathComponent:@".amar-files.plist"]];
  if(!files.count)continue;
  BOOL present=YES;
  for(NSDictionary *file in files){
   if(![file isKindOfClass:NSDictionary.class] || ![file[@"name"] isKindOfClass:NSString.class] || ![file[@"name"] isEqual:[file[@"name"] lastPathComponent]]){present=NO;break;}
   NSDictionary *a=[NSFileManager.defaultManager attributesOfItemAtPath:[dir URLByAppendingPathComponent:file[@"name"]].path error:nil];
   if(![a.fileType isEqual:NSFileTypeRegular] || a.fileSize!=[file[@"size"] unsignedLongLongValue]){present=NO;break;}
  }if(present)[result addObject:dir.lastPathComponent];
 }return result;
}
-(void)finishTransfer:(NSString*)status{
 if(self.stage)[NSFileManager.defaultManager removeItemAtURL:self.stage error:nil];
 self.stage=nil;self.transfer=nil;self.files=nil;self.download=nil;self.status=status;[self render];
}
-(void)nextFile{
 if(self.fileIndex==self.files.count){
  NSFileManager *fm=NSFileManager.defaultManager;NSURL *root=modRoot();
  NSURL *dst=[root URLByAppendingPathComponent:self.transfer[@"id"] isDirectory:YES];
  BOOL ok=[fm createDirectoryAtURL:root withIntermediateDirectories:YES attributes:nil error:nil] && regularFolder(root);
  ok=ok && [self.files writeToURL:[self.stage URLByAppendingPathComponent:@".amar-files.plist"] atomically:YES];
  if(ok && [fm fileExistsAtPath:dst.path]){
   ok=regularFolder(dst) && [[NSArray arrayWithContentsOfURL:[dst URLByAppendingPathComponent:@".amar-files.plist"]] count]>0 &&
      [fm replaceItemAtURL:dst withItemAtURL:self.stage backupItemName:nil options:0 resultingItemURL:nil error:nil];
  }else if(ok)ok=[fm moveItemAtURL:self.stage toURL:dst error:nil];
  NSURL *archiveURL=nil;NSDictionary *completedMod=self.transfer;
  if(ok && [self.files.firstObject[@"extension"] isEqual:@"zip"])archiveURL=[dst URLByAppendingPathComponent:self.files.firstObject[@"name"]];
  [self finishTransfer:ok?@"تم التحميل والتحقق من الملفات.":@"تعذّر حفظ المود."];
  if(archiveURL)[self importArchive:archiveURL forMod:completedMod];
  return;
 }
 NSDictionary *file=self.files[self.fileIndex];NSURL *url=[NSURL URLWithString:file[@"url"]];
 if(!url.host.length || ![url.scheme.lowercaseString isEqual:@"https"]){[self finishTransfer:@"رابط الملف غير صالح."];return;}
 self.lastPercent=-1;self.download=[self.session downloadTaskWithURL:url];
 self.status=[NSString stringWithFormat:@"تنزيل %lu / %lu · %@",(unsigned long)self.fileIndex+1,(unsigned long)self.files.count,file[@"name"]];[self render];[self.download resume];
}
-(void)beginMod:(NSDictionary*)mod{
 if(self.transfer)return;
 NSDictionary *archive=nil;
 if([mod[@"archiveURL"] isKindOfClass:NSString.class] && [mod[@"archiveSize"] unsignedLongLongValue]>0){
  archive=@{@"name":[mod[@"id"] stringByAppendingString:@".zip"],@"url":mod[@"archiveURL"],@"size":mod[@"archiveSize"],@"sha256":mod[@"archiveSha256"],@"extension":@"zip"};
 }else if([mod[@"bundleArchive"] isEqual:@"pilot-cars.zip"]){
  archive=@{@"name":@"pilot-cars.zip",@"url":@"bundle://pilot-cars.zip",@"size":mod[@"archiveSize"],@"sha256":mod[@"archiveSha256"],@"extension":@"zip"};
 }
 self.files=archive?@[archive]:(mod[@"files"]?:@[@{@"name":[NSString stringWithFormat:@"%@.%@",mod[@"id"],mod[@"extension"]],@"url":mod[@"url"],@"size":mod[@"size"],@"sha256":mod[@"sha256"],@"extension":mod[@"extension"]}]);
 NSURL *prior=[modRoot() URLByAppendingPathComponent:mod[@"id"]];
 NSArray *receipt=[NSArray arrayWithContentsOfURL:[prior URLByAppendingPathComponent:@".amar-files.plist"]];
 if([receipt isEqual:self.files] && [[self downloaded] containsObject:mod[@"id"]]){[self finishTransfer:@"كل ملفات هذه النسخة موجودة."];return;}
 self.stage=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
 if(![NSFileManager.defaultManager createDirectoryAtURL:self.stage withIntermediateDirectories:NO attributes:nil error:nil]){[self finishTransfer:@"تعذّر إنشاء مجلد التنزيل المؤقت."];return;}
 self.transfer=mod;self.fileIndex=0;
 if([mod[@"bundleArchive"] isEqual:@"pilot-cars.zip"]){
  self.verifying=YES;self.status=@"جارٍ تجهيز حزمة السيارات…";[self render];
  NSURL *source=asset(@"pilot-cars.zip"),*dst=[self.stage URLByAppendingPathComponent:self.files.firstObject[@"name"]];
  NSDictionary *archiveFile=self.files.firstObject;
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   BOOL ok=[NSFileManager.defaultManager copyItemAtURL:source toURL:dst error:nil];
   if(ok){
    unsigned long long total=[[[NSFileManager.defaultManager attributesOfItemAtPath:dst.path error:nil] objectForKey:NSFileSize] unsignedLongLongValue];
    if(total!=[archiveFile[@"size"] unsignedLongLongValue])ok=NO;
    NSInputStream *stream=[NSInputStream inputStreamWithURL:dst];[stream open];
    CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);uint8_t bytes[65536],digest[CC_SHA256_DIGEST_LENGTH];NSInteger n=0;
    while(ok && (n=[stream read:bytes maxLength:sizeof(bytes)])>0)CC_SHA256_Update(&ctx,bytes,(CC_LONG)n);
    if(ok && n<0)ok=NO;[stream close];
    if(ok){CC_SHA256_Final(digest,&ctx);NSMutableString *h=[NSMutableString new];for(int k=0;k<CC_SHA256_DIGEST_LENGTH;k++)[h appendFormat:@"%02x",digest[k]];ok=[h isEqualToString:archiveFile[@"sha256"]];}
   }
   dispatch_async(dispatch_get_main_queue(),^{self.verifying=NO;if(ok){self.fileIndex=self.files.count;[self nextFile];}else [self finishTransfer:@"تعذّر التحقق من الحزمة المدمجة."];});
  });return;
 }
 [self nextFile];
}
-(void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)req completionHandler:(void (^)(NSURLRequest*))done{
 done([req.URL.scheme.lowercaseString isEqual:@"https"]?req:nil);
}
-(void)URLSession:(NSURLSession*)s downloadTask:(NSURLSessionDownloadTask*)t didWriteData:(int64_t)chunk totalBytesWritten:(int64_t)bytes totalBytesExpectedToWrite:(int64_t)expected{
 int64_t limit=t==self.download?[self.files[self.fileIndex][@"size"] longLongValue]:2097152;
 if(bytes>limit || expected>limit){[t cancel];return;}
 if(t==self.download && limit>0){
  NSInteger pct=10*(bytes*10/limit);
  if(pct!=self.lastPercent){self.lastPercent=pct;
   self.status=[NSString stringWithFormat:@"ملف %lu / %lu · %@ · %ld%%",(unsigned long)self.fileIndex+1,(unsigned long)self.files.count,self.files[self.fileIndex][@"name"],(long)pct];
   if(self.ready && [self.kind isEqual:@"catalog"]){NSString *args=jsonText(@[self.status]);[self.panel evaluateJavaScript:[NSString stringWithFormat:@"transferProgress.apply(null,%@)",args] completionHandler:nil];}
  }
 }
}
static BOOL saveMod(NSURL *tmp,NSDictionary *mod,NSURL *stage){
 NSFileManager *fm=NSFileManager.defaultManager;
 unsigned long long size=[[fm attributesOfItemAtPath:tmp.path error:nil] fileSize];
 if(size!=[mod[@"size"] unsignedLongLongValue])return NO;
 NSInputStream *stream=[NSInputStream inputStreamWithURL:tmp];[stream open];
 unsigned char buf[65536],digest[CC_SHA256_DIGEST_LENGTH];CC_SHA256_CTX ctx;CC_SHA256_Init(&ctx);
 NSInteger n;BOOL header=NO;NSUInteger total=0;
 while((n=[stream read:buf maxLength:sizeof buf])>0){if(!total)header=n>=4 && ([mod[@"extension"] isEqual:@"zip"]?(buf[0]==0x50 && buf[1]==0x4b && buf[2]==0x03 && buf[3]==0x04):(!memcmp(buf,"RSC7",4)));CC_SHA256_Update(&ctx,buf,(CC_LONG)n);total+=n;}
 [stream close];if(!header || n<0 || total!=size)return NO;
 CC_SHA256_Final(digest,&ctx);NSMutableString *sha=[NSMutableString new];for(unsigned i=0;i<sizeof digest;i++)[sha appendFormat:@"%02x",digest[i]];
 if(![sha isEqual:mod[@"sha256"]])return NO;
 return [fm moveItemAtURL:tmp toURL:[stage URLByAppendingPathComponent:mod[@"name"]] error:nil];
}
-(void)URLSession:(NSURLSession*)s downloadTask:(NSURLSessionDownloadTask*)t didFinishDownloadingToURL:(NSURL*)location{
 NSHTTPURLResponse *response=(id)t.response;NSInteger code=response.statusCode;
 if(t==self.download){
  NSDictionary *m=self.files[self.fileIndex];NSURL *stage=self.stage;self.download=nil;
  NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
  if(code!=200 || ![NSFileManager.defaultManager moveItemAtURL:location toURL:tmp error:nil]){[self finishTransfer:@"فشل تنزيل أحد الملفات. لم يُعتمد المود."];return;}
  self.verifying=YES;self.status=@"جارٍ التحقق من الحجم والبصمة…";
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   BOOL ok=saveMod(tmp,m,stage);[NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
   dispatch_async(dispatch_get_main_queue(),^{self.verifying=NO;if(ok){self.fileIndex++;[self nextFile];}else [self finishTransfer:@"فشل التحقق من الحجم أو البصمة أو ترويسة المورد. لم يُعتمد المود."];});
  });return;
 }
 NSDictionary *request=self.requests[@(t.taskIdentifier)];if(!request)return;
 BOOL mods=[request[@"slot"] isEqual:@"catalog"];
 if(mods && ![request[@"url"] isEqual:self.modsSource])return;
 NSString *slot=key(request[@"slot"]);NSDictionary *previous=[prefs() dictionaryForKey:slot];
 BOOL ok=code==304 && [previous[@"url"] isEqual:request[@"url"]] && [self valid:previous[@"value"] mods:mods];
 if(code==200 && [[NSFileManager.defaultManager attributesOfItemAtPath:location.path error:nil] fileSize]<=2097152){
  id value=decode([NSData dataWithContentsOfURL:location]);ok=[self valid:value mods:mods];
  if(ok){
   NSString *etag=@"";for(NSString *k in response.allHeaderFields)if([k caseInsensitiveCompare:@"etag"]==NSOrderedSame)etag=response.allHeaderFields[k];
   [prefs() setObject:@{@"url":request[@"url"],@"value":value,@"etag":etag} forKey:slot];
   if(mods)self.catalog=[self catalogWithPilot:value];else{self.config=value;if(self.modsSource && ![self.modsSource isEqual:value[@"modsURL"]]){[self loadMods];if([self.kind isEqual:@"catalog"])[self fetch:YES];}}
  }
 }
 trace([NSString stringWithFormat:@"%@ HTTP %ld %@",mods?@"catalog":@"config",(long)code,ok?@"accepted":@"rejected"]);
 if(!mods)self.connection=ok?@"متصل بـ GitHub":@"تعذر اعتماد إعدادات GitHub";
 self.status=ok?(mods?@"قائمة المودات محدّثة.":@"اكتمل فحص الإصدار."):@"تعذّر اعتماد البيانات. تُعرض آخر نسخة صالحة.";
 if(ok && !mods){[prefs() setDouble:NSDate.date.timeIntervalSince1970 forKey:key(@"last")];if([self.kind isEqual:@"catalog"] && [[self updateMode] isEqual:@"optional"]){[self show:@"optional"];return;}}
 if(self.host)[self layout:self.host];[self evaluate];
}
-(void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)task didCompleteWithError:(NSError*)err{
 NSNumber *ident=@(task.taskIdentifier);NSString *url=self.requests[ident][@"url"];if(url)[self.pending removeObject:url];[self.requests removeObjectForKey:ident];
 if(task==self.download && err){[self finishTransfer:@"انقطع تنزيل أحد الملفات. لم يُعتمد المود."];return;}
 if(err){trace([NSString stringWithFormat:@"network error %ld",(long)err.code]);if([url isEqual:configURL])self.connection=@"غير متصل · إعدادات محفوظة";}
 if(err)self.status=@"تعذّر الاتصال أو تجاوز الملف الحجم المحدد.";[self render];
}
@end
// Chain only the launcher's own lifecycle implementations after UIKit has loaded.
@interface AMARWindowProbe : UIView
@property(nonatomic,weak) UIViewController *owner;
@end
@implementation AMARWindowProbe
-(void)didMoveToWindow{
 [super didMoveToWindow];
 if(!self.window){if(kit.host==self.owner){kit.visible=NO;[kit hide];}return;}
 dispatch_async(dispatch_get_main_queue(),^{
  UIViewController *vc=self.owner;if(self.window && vc.viewIfLoaded.window==self.window){
   trace(@"probe mounted inside launcher view");[kit appeared:vc];
  }
 });
}
@end
static IMP appeared,disappeared,layout,toggle,didLoad;
static void onLoad(UIViewController *vc,SEL sel){
 ((void(*)(id,SEL))didLoad)(vc,sel);
 AMARWindowProbe *probe=[AMARWindowProbe new];probe.owner=vc;probe.hidden=YES;probe.userInteractionEnabled=NO;[vc.view addSubview:probe];
 trace(@"launcher viewDidLoad");
}
static void onToggle(UIViewController *vc,SEL sel){((void(*)(id,SEL))toggle)(vc,sel);[vc.view setNeedsLayout];}
static void onAppear(UIViewController *vc,SEL s,BOOL animated){((void(*)(id,SEL,BOOL))appeared)(vc,s,animated);[kit appeared:vc];}
static void onDisappear(UIViewController *vc,SEL s,BOOL animated){((void(*)(id,SEL,BOOL))disappeared)(vc,s,animated);if(kit.host==vc){kit.visible=NO;[kit hide];}}
static void onLayout(UIViewController *vc,SEL s){((void(*)(id,SEL))layout)(vc,s);if(kit.host==vc)[kit layout:vc];else if(vc.viewIfLoaded.window)[kit appeared:vc];}
static IMP install(Class cls,SEL sel,IMP next){
 Method m=class_getInstanceMethod(cls,sel);if(!m)return NULL;
 IMP prev=method_getImplementation(m);
 if(!class_addMethod(cls,sel,next,method_getTypeEncoding(m)))prev=method_setImplementation(class_getInstanceMethod(cls,sel),next);
 return prev;
}
static UIViewController *visibleLauncher(UIViewController *vc,Class cls){
 if(!vc || !vc.viewIfLoaded.window)return nil;
 if(vc.presentedViewController){UIViewController *presented=visibleLauncher(vc.presentedViewController,cls);if(presented)return presented;}
 if([vc isKindOfClass:cls])return vc;
 for(UIViewController *child in vc.childViewControllers){UIViewController *found=visibleLauncher(child,cls);if(found)return found;}
 return nil;
}
static UIViewController *launcherOwningView(UIView *view,Class cls){
 if(view.hidden || view.alpha<.01 || !view.window)return nil;
 if([view isKindOfClass:UIButton.class]){
  UIButton *button=(UIButton*)view;
  for(id target in button.allTargets){
   if([target isKindOfClass:cls] && [[button actionsForTarget:target forControlEvent:UIControlEventTouchUpInside] containsObject:@"tabTapped:"] && [(UIViewController*)target viewIfLoaded].window==view.window)return target;
  }
 }
 UIResponder *owner=view.nextResponder;
 if([owner isKindOfClass:cls] && [(UIViewController*)owner viewIfLoaded]==view)return (UIViewController*)owner;
 for(UIView *child in view.subviews.reverseObjectEnumerator){UIViewController *vc=launcherOwningView(child,cls);if(vc)return vc;}
 return nil;
}
static void attach(void){
 Class cls=NSClassFromString(@"MPLauncherViewController");if(!cls || ![cls isSubclassOfClass:UIViewController.class]){trace(@"waiting for launcher class");return;}
 if(!kit){kit=[AMARYTKit new];
  didLoad=install(cls,@selector(viewDidLoad),(IMP)onLoad);
  appeared=install(cls,@selector(viewDidAppear:),(IMP)onAppear);
  disappeared=install(cls,@selector(viewDidDisappear:),(IMP)onDisappear);
  layout=install(cls,@selector(viewDidLayoutSubviews),(IMP)onLayout);
  toggle=install(cls,NSSelectorFromString(@"toggleSidebar"),(IMP)onToggle);
  trace(@"launcher class found; lifecycle attached");
 }
 if(!kit.visible || !kit.host.viewIfLoaded.window){
  NSMutableOrderedSet *windows=[NSMutableOrderedSet orderedSetWithArray:UIApplication.sharedApplication.windows];
  for(UIScene *scene in UIApplication.sharedApplication.connectedScenes)if([scene isKindOfClass:UIWindowScene.class] && scene.activationState!=UISceneActivationStateBackground)[windows addObjectsFromArray:[(UIWindowScene*)scene windows]];
  for(UIWindow *window in windows){
   if(window.hidden || window.alpha<.01)continue;
   UIViewController *vc=visibleLauncher(window.rootViewController,cls)?:launcherOwningView(window,cls);if(vc){[kit appeared:vc];break;}
  }
 }
 if(!kit.visible)trace(@"launcher not visible yet");
 if(!kit.config)[kit refreshIfNeeded];
}
__attribute__((constructor)) static void startKit(void){
 @autoreleasepool{trace(@"startKit entered · build 8");}
 dispatch_async(dispatch_get_main_queue(),^{
  for(NSString *name in @[UIApplicationDidFinishLaunchingNotification,UIApplicationDidBecomeActiveNotification,UIWindowDidBecomeKeyNotification,UIWindowDidBecomeVisibleNotification,UISceneDidActivateNotification])
   [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){attach();}];
  attach();
  for(NSNumber *delay in @[@0.3,@1,@3]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(!kit.visible)attach();});
 });
}
