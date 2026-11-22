#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <JavaScriptCore/JavaScriptCore.h>
#import <CommonCrypto/CommonDigest.h>
#import <objc/runtime.h>

static NSString *const configURL=@"https://raw.githubusercontent.com/Amaryt1/PROOOOO/main/config.json";
static NSString *const storeKey=@"AMARYTKit5.";
static const NSInteger kitVersion=5;
static NSUserDefaults *prefs(void){return NSUserDefaults.standardUserDefaults;}
static NSString *key(NSString *s){return [storeKey stringByAppendingString:s];}
static NSURL *asset(NSString *name){return [NSBundle.mainBundle.resourceURL URLByAppendingPathComponent:[@"AMARYTKit" stringByAppendingPathComponent:name]];}
static id decode(NSData *data){return data.length?[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]:nil;}
static void trace(NSString *message){
 static dispatch_queue_t queue;static dispatch_once_t once;
 dispatch_once(&once,^{queue=dispatch_queue_create("AMARYT.diagnostics",DISPATCH_QUEUE_SERIAL);});
 dispatch_async(queue,^{
  NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
  NSURL *url=[docs URLByAppendingPathComponent:@"AMARYT-debug.txt"];
  NSData *line=[[NSString stringWithFormat:@"%@ %@\n",NSDate.date,message] dataUsingEncoding:NSUTF8StringEncoding];
  NSFileHandle *h=[NSFileHandle fileHandleForWritingToURL:url error:nil];
  if(!h){[line writeToURL:url atomically:YES];return;}
  @try{if([h seekToEndOfFile]>65536)[h truncateFileAtOffset:0];[h writeData:line];}@finally{[h closeFile];}
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
@property(nonatomic,weak) UIViewController *lastHost;
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
 self.config=[self valid:cached mods:NO]?cached:decode([NSData dataWithContentsOfURL:asset(@"config.json")]);
 if(![self valid:self.config mods:NO])self.config=nil;
 trace(self.config?@"config loaded and validated":@"config validation failed");
}
-(void)loadMods{
 self.modsSource=self.config[@"modsURL"];NSDictionary *c=[prefs() dictionaryForKey:key(@"catalog")];
 self.catalog=[c[@"url"] isEqual:self.modsSource] && [self valid:c[@"value"] mods:YES]?c[@"value"]:decode([NSData dataWithContentsOfURL:asset(@"mods.json")]);
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
 self.host=vc;self.visible=YES;[self layout:vc];[self evaluate];
 trace(@"launcher visible");[self refreshIfNeeded];
}
-(void)hide{
 [self.panel.configuration.userContentController removeScriptMessageHandlerForName:@"amar"];
 [self.fallback removeFromSuperview];self.fallback=nil;[self.panel removeFromSuperview];self.panel=nil;self.kind=nil;self.ready=NO;
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
 for(NSString *kind in @[@"optional",@"welcome",@"notification"]){
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
 BOOL native=self.fallback && [self.kind isEqual:kind];
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
 self.kind=kind;if(native)[self nativePanel];else{[self.host.view bringSubviewToFront:self.panel];[self render];}
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
 NSDictionary *state=@{@"kind":self.kind,@"config":self.config,@"version":@(kitVersion),@"catalog":self.catalog?:@{@"categories":@[],@"mods":@[]},@"favorites":[prefs() arrayForKey:key(@"favorites")]?:@[],@"downloaded":[self downloaded],@"busy":@(self.transfer!=nil),@"connection":self.connection?:@"",@"build":@"6",@"status":self.status?:@"",@"last":@([prefs() doubleForKey:key(@"last")])};
 NSData *data=[NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
 NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 WKWebView *web=self.panel;if(json)[web evaluateJavaScript:[NSString stringWithFormat:@"render(%@)",json] completionHandler:^(id result,NSError *error){if(error && self.panel==web)[self nativePanel];}];
}
-(void)openStore{if([self.config[@"sections"][@"mods"] boolValue] && ![[self updateMode] isEqual:@"force"]){[self loadMods];[self show:@"catalog"];[self fetch:YES];}}
-(void)nativeAction:(UIButton*)button{[self action:button.accessibilityIdentifier ident:@""];}
-(void)nativePanel{
 NSString *kind=self.kind;if(!kind || !self.visible)return;
 trace([@"native fallback " stringByAppendingString:kind]);
 [self.panel.configuration.userContentController removeScriptMessageHandlerForName:@"amar"];
 [self.panel removeFromSuperview];self.panel=nil;self.ready=NO;
 [self.fallback removeFromSuperview];
 UIView *root=self.host.view;UIView *shade=[[UIView alloc]initWithFrame:root.bounds];self.fallback=shade;
 shade.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
 shade.backgroundColor=[UIColor colorWithWhite:0 alpha:.82];shade.accessibilityViewIsModal=YES;[root addSubview:shade];
 UIScrollView *scroll=[UIScrollView new];scroll.translatesAutoresizingMaskIntoConstraints=NO;[shade addSubview:scroll];
 UIStackView *stack=[UIStackView new];stack.axis=UILayoutConstraintAxisVertical;stack.spacing=10;stack.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:stack];
 UILayoutGuide *g=shade.safeAreaLayoutGuide;
 [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:g.leadingAnchor constant:24],[scroll.trailingAnchor constraintEqualToAnchor:g.trailingAnchor constant:-24],[scroll.topAnchor constraintEqualToAnchor:g.topAnchor constant:18],[scroll.bottomAnchor constraintEqualToAnchor:g.bottomAnchor constant:-18],[stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],[stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],[stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],[stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],[stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor]]];
 BOOL update=[kind isEqual:@"force"] || [kind isEqual:@"optional"];NSDictionary *m=self.config[update?@"update":kind];BOOL store=[kind isEqual:@"catalog"];
 NSMutableArray *lines=[NSMutableArray arrayWithArray:@[@"AMAR YT V5 · 6",m[@"title"]?:@"المودات",m[@"body"]?:@"تعذّر فتح صفحة المتجر. أعد فتح القسم للمحاولة مجددًا."]];
 if(update){[lines addObject:[NSString stringWithFormat:@"الإصدار %@",m[[kind isEqual:@"force"]?@"minimum":@"latest"]]];[lines addObjectsFromArray:m[@"features"]];}
 for(NSString *line in lines){UILabel *label=[UILabel new];label.text=line;label.numberOfLines=0;label.textAlignment=NSTextAlignmentCenter;label.textColor=UIColor.whiteColor;[stack addArrangedSubview:label];}
 void (^button)(NSString*,NSString*)=^(NSString *title,NSString *action){UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.accessibilityIdentifier=action;[b setTitle:title forState:0];b.tintColor=UIColor.whiteColor;b.backgroundColor=UIColor.darkGrayColor;[b addTarget:self action:@selector(nativeAction:) forControlEvents:UIControlEventTouchUpInside];[stack addArrangedSubview:b];};
 button(m[@"action"]?:@"إغلاق",update?@"update":@"close");
 if([m[@"contactURL"] length] && [m[@"contact"] length])button(m[@"contact"],@"contact");
 if(!store && ![kind isEqual:@"force"])button(@"إغلاق",@"close");
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
 NSArray *names=@[@"الألعاب",@"الحفظ",@"الإعدادات",@"المودات"];
 NSMutableArray *visible=[NSMutableArray new];CGFloat total=0;
 for(UIButton *b in tabs){
  if(![b isKindOfClass:UIButton.class] || b.tag<0 || b.tag>=4)continue;
  NSString *name=names[b.tag];NSAttributedString *old=[b attributedTitleForState:0];
  NSMutableDictionary *attrs=old.length?[[old attributesAtIndex:0 effectiveRange:NULL] mutableCopy]:[NSMutableDictionary new];
  [attrs removeObjectForKey:NSKernAttributeName];attrs[NSFontAttributeName]=[UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
  NSAttributedString *title=[[NSAttributedString alloc]initWithString:name attributes:attrs];
  if(!old || ![title isEqualToAttributedString:old])[b setAttributedTitle:title forState:0];
  b.titleLabel.adjustsFontSizeToFitWidth=YES;b.titleLabel.minimumScaleFactor=.60;b.titleLabel.textAlignment=NSTextAlignmentCenter;
  b.contentEdgeInsets=UIEdgeInsetsZero;b.titleEdgeInsets=UIEdgeInsetsZero;b.accessibilityLabel=name;
  if(!b.hidden){[visible addObject:b];total+=ceil(title.size.width)+12;}
 }
 if(visible.count){
  UIButton *first=visible.firstObject;UIView *parent=first.superview;UIView *avatar=member(vc,"_avatar");
  CGRect rail=[side convertRect:side.bounds toView:parent];CGFloat left=MAX(parent.safeAreaInsets.left+3,CGRectGetMaxX(rail)+4);
  CGFloat right=CGRectGetWidth(parent.bounds)-parent.safeAreaInsets.right-4;
  if([avatar isKindOfClass:UIView.class] && !avatar.hidden && avatar.superview==parent)right=MIN(right,CGRectGetMinX(avatar.frame)-5);
  CGFloat free=right-left, gap=4,room=free-gap*(visible.count-1);
  if(room>0 && total>0){CGFloat scale=MIN(1,room/total),x=right-(total*scale+gap*(visible.count-1));
   for(UIButton *b in visible){CGRect f=b.frame;f.origin.x=x;f.size.width=(ceil([b attributedTitleForState:0].size.width)+12)*scale;if(!CGRectEqualToRect(b.frame,f))b.frame=f;x=CGRectGetMaxX(f)+gap;}
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
 UIView *anchor=member(vc,"_gta6Icon");CGFloat pivot=anchor.superview==side?CGRectGetMaxY(originalFrame(anchor)):h*.5;
 for(UIView *v in side.subviews)if(v!=self.storeButton && !v.hidden && brandView(v))pivot=MAX(pivot,CGRectGetMaxY(originalFrame(v)));
 CGFloat row=MIN(42,MAX(0,h*.13)),k=h>0?(h-row-4)/h:1;
 for(UIView *v in side.subviews){
  if(v==self.storeButton || v.hidden)continue;CGRect raw=originalFrame(v);
  if(raw.size.height>h*.85)continue;
  CGRect f=raw;if(enabled){f.origin.y=raw.origin.y*k+(CGRectGetMidY(raw)>pivot?row+4:0);f.size.height=raw.size.height*k;}
  objc_setAssociatedObject(v,&sidebarFrames,@[[NSValue valueWithCGRect:raw],[NSValue valueWithCGRect:f]],OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  if(!CGRectEqualToRect(v.frame,f))v.frame=f;
 }
 self.storeButton.frame=CGRectMake(3,MIN(h-row,MAX(0,pivot*k+2)),MAX(0,w-6),row);self.storeButton.hidden=!enabled;
 NSString *caption=w>=96?@"  المودات":@"";if(![[self.storeButton titleForState:0] isEqual:caption])[self.storeButton setTitle:caption forState:0];
 NSString *sig=[NSString stringWithFormat:@"tabs=%lu sidebar=%.0fx%.0f modsY=%.0f",(unsigned long)visible.count,w,h,self.storeButton.frame.origin.y];
 if(![self.layoutSignature isEqual:sig]){self.layoutSignature=sig;trace(sig);}
 UIView *top=self.fallback?:self.panel;if(top.superview==vc.view)[vc.view bringSubviewToFront:top];
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
 if(store && [a isEqual:@"social"])link=self.config[@"social"][ident];
 if(link.length){NSURL *url=[NSURL URLWithString:link];if([url.scheme.lowercaseString isEqual:@"https"])[UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];}
 if(!store)return;
 if([a isEqual:@"clearCatalog"]){[prefs() removeObjectForKey:key(@"catalog")];[self loadMods];self.status=@"تم مسح قائمة المودات المخزّنة.";[self render];return;}
 if([a isEqual:@"refreshConfig"]){[self fetch:NO];return;}
 if([a isEqual:@"refreshMods"]){[self fetch:YES];return;}
 for(NSDictionary *mod in self.catalog[@"mods"])if([mod[@"id"] isEqual:ident]){
  if([a isEqual:@"favorite"]){NSMutableArray *f=[[prefs() arrayForKey:key(@"favorites")] mutableCopy]?:[NSMutableArray new];if([f containsObject:ident])[f removeObject:ident];else [f addObject:ident];[prefs() setObject:f forKey:key(@"favorites")];[self render];}
  if([a isEqual:@"download"] && !self.download && !self.verifying && [mod[@"minKit"] integerValue]<=kitVersion && kitVersion<=[mod[@"maxKit"] integerValue]){
   [self beginMod:mod];
  }break;
 }
}
static NSURL *modRoot(void){
 NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 return [docs URLByAppendingPathComponent:@"AMARYT-Mods" isDirectory:YES];
}
static BOOL regularFolder(NSURL *url){
 return [[[NSFileManager.defaultManager attributesOfItemAtPath:url.path error:nil] fileType] isEqual:NSFileTypeDirectory];
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
  [self finishTransfer:ok?@"اكتمل تنزيل كل ملفات المود والتحقق منها.":@"تعذّر حفظ مجلد المود."];return;
 }
 NSDictionary *file=self.files[self.fileIndex];NSURL *url=[NSURL URLWithString:file[@"url"]];
 if(!url.host.length || ![url.scheme.lowercaseString isEqual:@"https"]){[self finishTransfer:@"رابط الملف غير صالح."];return;}
 self.lastPercent=-1;self.download=[self.session downloadTaskWithURL:url];
 self.status=[NSString stringWithFormat:@"تنزيل %lu / %lu · %@",(unsigned long)self.fileIndex+1,(unsigned long)self.files.count,file[@"name"]];[self render];[self.download resume];
}
-(void)beginMod:(NSDictionary*)mod{
 if(self.transfer)return;
 self.files=mod[@"files"]?:@[@{@"name":[NSString stringWithFormat:@"%@.%@",mod[@"id"],mod[@"extension"]],@"url":mod[@"url"],@"size":mod[@"size"],@"sha256":mod[@"sha256"],@"extension":mod[@"extension"]}];
 NSURL *prior=[modRoot() URLByAppendingPathComponent:mod[@"id"]];
 NSArray *receipt=[NSArray arrayWithContentsOfURL:[prior URLByAppendingPathComponent:@".amar-files.plist"]];
 if([receipt isEqual:self.files] && [[self downloaded] containsObject:mod[@"id"]]){[self finishTransfer:@"كل ملفات هذه النسخة موجودة."];return;}
 self.stage=[[NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES] URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
 if(![NSFileManager.defaultManager createDirectoryAtURL:self.stage withIntermediateDirectories:NO attributes:nil error:nil]){[self finishTransfer:@"تعذّر إنشاء مجلد التنزيل المؤقت."];return;}
 self.transfer=mod;self.fileIndex=0;[self nextFile];
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
 while((n=[stream read:buf maxLength:sizeof buf])>0){if(!total)header=n>=4 && !memcmp(buf,"RSC7",4);CC_SHA256_Update(&ctx,buf,(CC_LONG)n);total+=n;}
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
   if(mods)self.catalog=value;else{self.config=value;if(self.modsSource && ![self.modsSource isEqual:value[@"modsURL"]]){[self loadMods];if([self.kind isEqual:@"catalog"])[self fetch:YES];}}
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
static IMP appeared,disappeared,layout,toggle;
static void onToggle(UIViewController *vc,SEL sel){((void(*)(id,SEL))toggle)(vc,sel);[vc.view setNeedsLayout];}
static void onAppear(UIViewController *vc,SEL s,BOOL animated){((void(*)(id,SEL,BOOL))appeared)(vc,s,animated);[kit appeared:vc];}
static void onDisappear(UIViewController *vc,SEL s,BOOL animated){((void(*)(id,SEL,BOOL))disappeared)(vc,s,animated);if(kit.host==vc){kit.visible=NO;[kit hide];}}
static void onLayout(UIViewController *vc,SEL s){((void(*)(id,SEL))layout)(vc,s);if(kit.host==vc)[kit layout:vc];else if(vc.viewIfLoaded.window && !vc.presentedViewController)[kit appeared:vc];}
static IMP install(Class cls,SEL sel,IMP next){
 Method m=class_getInstanceMethod(cls,sel);if(!m)return NULL;
 IMP prev=method_getImplementation(m);
 if(!class_addMethod(cls,sel,next,method_getTypeEncoding(m)))prev=method_setImplementation(class_getInstanceMethod(cls,sel),next);
 return prev;
}
static UIViewController *visibleLauncher(UIViewController *vc,Class cls){
 if(!vc || !vc.viewIfLoaded.window)return nil;
 if(vc.presentedViewController)return visibleLauncher(vc.presentedViewController,cls);
 if([vc isKindOfClass:cls])return vc;
 for(UIViewController *child in vc.childViewControllers){UIViewController *found=visibleLauncher(child,cls);if(found)return found;}
 return nil;
}
static void attach(void){
 Class cls=NSClassFromString(@"MPLauncherViewController");if(!cls || ![cls isSubclassOfClass:UIViewController.class]){trace(@"waiting for launcher class");return;}
 if(!kit){kit=[AMARYTKit new];
  appeared=install(cls,@selector(viewDidAppear:),(IMP)onAppear);
  disappeared=install(cls,@selector(viewDidDisappear:),(IMP)onDisappear);
  layout=install(cls,@selector(viewDidLayoutSubviews),(IMP)onLayout);
  toggle=install(cls,NSSelectorFromString(@"toggleSidebar"),(IMP)onToggle);
  trace(@"launcher class found; lifecycle attached");
 }
 if(!kit.visible){
  for(UIWindow *window in UIApplication.sharedApplication.windows){
   if(window.hidden || window.windowLevel!=UIWindowLevelNormal)continue;
   UIViewController *vc=visibleLauncher(window.rootViewController,cls);if(vc){[kit appeared:vc];break;}
  }
 }
 if(!kit.config)[kit refreshIfNeeded];
}
__attribute__((constructor)) static void startKit(void){
 @autoreleasepool{trace(@"AMARYTKit loaded · build 6");}
 dispatch_async(dispatch_get_main_queue(),^{
  for(NSString *name in @[UIApplicationDidFinishLaunchingNotification,UIApplicationDidBecomeActiveNotification,UIWindowDidBecomeKeyNotification])
   [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){attach();}];
  attach();
  for(NSNumber *delay in @[@0.3,@1,@3]) dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(delay.doubleValue*NSEC_PER_SEC)),dispatch_get_main_queue(),^{if(!kit.visible)attach();});
 });
}
