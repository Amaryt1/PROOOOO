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
@end
static AMARYTKit *kit;
@implementation AMARYTKit
-(instancetype)init{
 if((self=[super init])){
  _policy=[JSContext new];[_policy evaluateScript:[NSString stringWithContentsOfURL:asset(@"policy.js") encoding:NSUTF8StringEncoding error:nil]?:@""];
  _seen=[NSMutableSet set];_pending=[NSMutableSet set];_requests=[NSMutableDictionary new];
  NSURLSessionConfiguration *sc=NSURLSessionConfiguration.ephemeralSessionConfiguration;
  sc.timeoutIntervalForRequest=8;sc.timeoutIntervalForResource=180;sc.URLCache=nil;
  _session=[NSURLSession sessionWithConfiguration:sc delegate:self delegateQueue:NSOperationQueue.mainQueue];
  [self loadConfig];
  [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(active:) name:UIApplicationDidBecomeActiveNotification object:nil];
 }return self;
}
-(BOOL)valid:(id)obj mods:(BOOL)mods{return [obj isKindOfClass:NSDictionary.class] && [NSPropertyListSerialization propertyList:obj isValidForFormat:NSPropertyListBinaryFormat_v1_0] && [[self.policy[mods?@"validMods":@"validConfig"] callWithArguments:@[obj]] toBool];}
-(void)loadConfig{
 NSDictionary *cached=[prefs() dictionaryForKey:key(@"config")][@"value"];
 self.config=[self valid:cached mods:NO]?cached:decode([NSData dataWithContentsOfURL:asset(@"config.json")]);
 if(![self valid:self.config mods:NO])self.config=nil;
}
-(void)loadMods{
 self.modsSource=self.config[@"modsURL"];NSDictionary *c=[prefs() dictionaryForKey:key(@"catalog")];
 self.catalog=[c[@"url"] isEqual:self.modsSource] && [self valid:c[@"value"] mods:YES]?c[@"value"]:decode([NSData dataWithContentsOfURL:asset(@"mods.json")]);
}
-(void)fetch:(BOOL)mods{
 NSString *url=mods?self.config[@"modsURL"]:configURL;
 NSURL *endpoint=[NSURL URLWithString:url?:@""];
 if(!endpoint.host.length || ![endpoint.scheme.lowercaseString isEqual:@"https"] || [self.pending containsObject:url])return;
 [self.pending addObject:url];
 NSString *slot=mods?@"catalog":@"config";NSDictionary *cache=[prefs() dictionaryForKey:key(slot)];
 NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:endpoint cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:8];
 if([cache[@"url"] isEqual:url] && [self valid:cache[@"value"] mods:mods] && [cache[@"etag"] length])[req setValue:cache[@"etag"] forHTTPHeaderField:@"If-None-Match"];
 NSURLSessionDownloadTask *task=[self.session downloadTaskWithRequest:req];
 self.requests[@(task.taskIdentifier)]=@{@"url":url,@"slot":slot};[task resume];
}
-(void)active:(NSNotification*)note{
 if(self.visible){[self evaluate];if([self.kind isEqual:@"force"])[self fetch:NO];}
}
-(void)appeared:(UIViewController*)vc{
 self.host=vc;self.visible=YES;[self layout:vc];[self evaluate];
 if(!self.started){self.started=YES;[self fetch:NO];}
}
-(void)hide{
 [self.panel.configuration.userContentController removeScriptMessageHandlerForName:@"amar"];
 [self.panel removeFromSuperview];self.panel=nil;self.kind=nil;self.ready=NO;
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
 if(!self.panel){
  WKWebViewConfiguration *cfg=[WKWebViewConfiguration new];cfg.websiteDataStore=WKWebsiteDataStore.nonPersistentDataStore;
  [cfg.userContentController addScriptMessageHandler:self name:@"amar"];
  WKWebView *p=[[WKWebView alloc]initWithFrame:self.host.view.bounds configuration:cfg];p.navigationDelegate=self;
  p.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;p.opaque=NO;p.backgroundColor=UIColor.clearColor;p.scrollView.backgroundColor=UIColor.clearColor;
  p.accessibilityViewIsModal=YES;self.panel=p;[self.host.view addSubview:p];
  [p loadFileURL:asset(@"panel.html") allowingReadAccessToURL:asset(@"panel.html")];
 }
 self.kind=kind;[self.host.view bringSubviewToFront:self.panel];[self render];
 [self.expiry invalidate];self.expiry=nil;
 if([kind isEqual:@"force"]){
  double end=[[self.policy evaluateScript:@"Date.parse"] callWithArguments:@[self.config[@"update"][@"expiresUTC"]]].toDouble/1000;
  self.expiry=[NSTimer scheduledTimerWithTimeInterval:MAX(.1,end-NSDate.date.timeIntervalSince1970+.1) target:self selector:@selector(expired:) userInfo:nil repeats:NO];
 }
}
-(void)expired:(NSTimer*)timer{[self evaluate];}
-(void)webView:(WKWebView*)web didFinishNavigation:(WKNavigation*)nav{if(web==self.panel){self.ready=YES;[self render];}}
-(void)webView:(WKWebView*)web didFailProvisionalNavigation:(WKNavigation*)nav withError:(NSError*)error{if(web==self.panel)[self hide];}
-(void)webViewWebContentProcessDidTerminate:(WKWebView*)web{if(web==self.panel){[self hide];[self evaluate];}}
-(void)webView:(WKWebView*)web decidePolicyForNavigationAction:(WKNavigationAction*)action decisionHandler:(void (^)(WKNavigationActionPolicy))reply{
 reply([action.request.URL isEqual:asset(@"panel.html")]?WKNavigationActionPolicyAllow:WKNavigationActionPolicyCancel);
}
-(void)render{
 if(!self.ready || !self.kind)return;
 NSDictionary *state=@{@"kind":self.kind,@"config":self.config,@"version":@(kitVersion),@"catalog":self.catalog?:@{@"categories":@[],@"mods":@[]},@"favorites":[prefs() arrayForKey:key(@"favorites")]?:@[],@"status":self.status?:@"",@"last":@([prefs() doubleForKey:key(@"last")])};
 NSData *data=[NSJSONSerialization dataWithJSONObject:state options:0 error:nil];
 NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 if(json)[self.panel evaluateJavaScript:[NSString stringWithFormat:@"render(%@)",json] completionHandler:nil];
}
-(void)openStore{if([self.config[@"sections"][@"mods"] boolValue] && ![[self updateMode] isEqual:@"force"]){[self loadMods];[self show:@"catalog"];[self fetch:YES];}}
-(void)layout:(UIViewController*)vc{
 id tabs=member(vc,"_tabs");if([tabs isKindOfClass:NSArray.class])for(id b in tabs){
  if(![b isKindOfClass:UIButton.class])continue;
  UIButton *button=b;
  NSString *old=[button attributedTitleForState:UIControlStateNormal].string?:[button titleForState:UIControlStateNormal];
  NSDictionary *names=@{@"GAMES":@"الألعاب",@"MODS":@"المودات",@"SAVES":@"الحفظ",@"SETTINGS":@"الإعدادات",@"ملفات الحفظ":@"الحفظ",@"ملفات الحفظ والتختيم":@"الحفظ",@"إعدادات القائمة":@"الإعدادات"};
  NSString *name=names[old.uppercaseString?:@""]?:old;
  if(![@[@"الألعاب",@"المودات",@"الحفظ",@"الإعدادات"] containsObject:name?:@""])continue;
  NSAttributedString *at=[button attributedTitleForState:UIControlStateNormal];
  if(at.length && (![old isEqual:name] || [[at attribute:NSKernAttributeName atIndex:0 effectiveRange:NULL] doubleValue]!=0)){
   NSMutableDictionary *attrs=[[at attributesAtIndex:0 effectiveRange:NULL] mutableCopy];[attrs removeObjectForKey:NSKernAttributeName];
   [button setAttributedTitle:[[NSAttributedString alloc]initWithString:name attributes:attrs] forState:UIControlStateNormal];
  }else if(!at && ![old isEqual:name])[button setTitle:name forState:UIControlStateNormal];
  UILabel *label=button.titleLabel;label.adjustsFontSizeToFitWidth=YES;label.minimumScaleFactor=.66;label.textAlignment=NSTextAlignmentCenter;
 }
 UIView *side=member(vc,"_sidebar");if(![side isKindOfClass:UIView.class])return;
 if(self.storeButton.superview!=side){
  [self.storeButton removeFromSuperview];UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];
  b.titleLabel.font=[UIFont boldSystemFontOfSize:13];b.titleLabel.adjustsFontSizeToFitWidth=YES;b.tintColor=UIColor.whiteColor;b.backgroundColor=[UIColor colorWithWhite:.16 alpha:1];b.layer.cornerRadius=7;
  [b setTitle:@"▣  المودات — Mods" forState:UIControlStateNormal];[b addTarget:self action:@selector(openStore) forControlEvents:UIControlEventTouchUpInside];[side addSubview:b];self.storeButton=b;
 }
 CGFloat width=CGRectGetWidth(side.bounds),height=CGRectGetHeight(side.bounds);
 BOOL fits=NO;
 for(CGFloat y=height-43;y>=6;y-=4){
  CGRect frame=CGRectMake(5,y,MAX(0,width-10),36);BOOL occupied=NO;
  for(UIView *v in side.subviews){if(v!=self.storeButton && !v.hidden && v.alpha>.01 && CGRectGetHeight(v.frame)<height*.85 && CGRectIntersectsRect(v.frame,frame)){occupied=YES;break;}}
  if(!occupied && width>=42){self.storeButton.frame=frame;fits=YES;break;}
 }
 self.storeButton.hidden=!fits || ![self.config[@"sections"][@"mods"] boolValue];
 if(self.panel.superview==vc.view)[vc.view bringSubviewToFront:self.panel];
}
-(void)userContentController:(WKUserContentController*)c didReceiveScriptMessage:(WKScriptMessage*)msg{
 if(msg.webView!=self.panel || !msg.frameInfo.mainFrame || ![msg.frameInfo.request.URL isEqual:asset(@"panel.html")] || ![msg.body isKindOfClass:NSDictionary.class])return;
 NSString *a=msg.body[@"action"],*ident=msg.body[@"id"];if(![a isKindOfClass:NSString.class] || ![ident isKindOfClass:NSString.class])return;
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
   NSURL *u=[NSURL URLWithString:mod[@"url"]];if(!u.host.length)return;
   self.transfer=mod;self.download=[self.session downloadTaskWithURL:u];self.status=@"جارٍ تنزيل الملف…";[self render];[self.download resume];
  }break;
 }
}
-(void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)req completionHandler:(void (^)(NSURLRequest*))done{
 done([req.URL.scheme.lowercaseString isEqual:@"https"]?req:nil);
}
-(void)URLSession:(NSURLSession*)s downloadTask:(NSURLSessionDownloadTask*)t didWriteData:(int64_t)chunk totalBytesWritten:(int64_t)bytes totalBytesExpectedToWrite:(int64_t)expected{
 int64_t limit=t==self.download?[self.transfer[@"size"] longLongValue]:2097152;
 if(bytes>limit || expected>limit)[t cancel];
}
static BOOL saveMod(NSURL *tmp,NSDictionary *mod){
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
 NSURL *docs=[fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 NSURL *dir=[docs URLByAppendingPathComponent:@"AMARYT-Mods" isDirectory:YES];
 if(![fm createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil])return NO;
 NSString *name=[NSString stringWithFormat:@"%@-%@.%@",mod[@"id"],sha,mod[@"extension"]];
 NSData *content=[NSData dataWithContentsOfURL:tmp options:NSDataReadingMappedIfSafe error:nil];
 return [content writeToURL:[dir URLByAppendingPathComponent:name] options:NSDataWritingAtomic error:nil];
}
-(void)URLSession:(NSURLSession*)s downloadTask:(NSURLSessionDownloadTask*)t didFinishDownloadingToURL:(NSURL*)location{
 NSHTTPURLResponse *response=(id)t.response;NSInteger code=response.statusCode;
 if(t==self.download){
  NSDictionary *m=self.transfer;
  NSURL *tmp=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString]];
  if(code!=200 || ![NSFileManager.defaultManager moveItemAtURL:location toURL:tmp error:nil]){self.status=@"تعذّر تنزيل الملف.";return;}
  self.verifying=YES;self.status=@"جارٍ التحقق من الحجم والبصمة…";
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{
   BOOL ok=saveMod(tmp,m);[NSFileManager.defaultManager removeItemAtURL:tmp error:nil];
   dispatch_async(dispatch_get_main_queue(),^{self.verifying=NO;self.status=ok?@"تم حفظ الملف في AMARYT-Mods. يمكنك اختياره من المستورد المتوافق.":@"رُفض الملف بسبب الحجم أو البصمة أو صيغة المورد.";[self render];});
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
 self.status=ok?(mods?@"قائمة المودات محدّثة.":@"اكتمل فحص الإصدار."):@"تعذّر اعتماد البيانات. تُعرض آخر نسخة صالحة.";
 if(ok && !mods){[prefs() setDouble:NSDate.date.timeIntervalSince1970 forKey:key(@"last")];if([self.kind isEqual:@"catalog"] && [[self updateMode] isEqual:@"optional"]){[self show:@"optional"];return;}}
 if(self.host)[self layout:self.host];[self evaluate];
}
-(void)URLSession:(NSURLSession*)s task:(NSURLSessionTask*)task didCompleteWithError:(NSError*)err{
 NSNumber *ident=@(task.taskIdentifier);NSString *url=self.requests[ident][@"url"];if(url)[self.pending removeObject:url];[self.requests removeObjectForKey:ident];
 if(task==self.download){self.download=nil;self.transfer=nil;}
 if(err)self.status=@"تعذّر الاتصال أو تجاوز الملف الحجم المحدد.";[self render];
}
@end
// Chain only the launcher's own lifecycle implementations after UIKit has loaded.
static IMP appeared,disappeared,layout;
static void onAppear(UIViewController *vc,SEL s,BOOL animated){((void(*)(id,SEL,BOOL))appeared)(vc,s,animated);[kit appeared:vc];}
static void onDisappear(UIViewController *vc,SEL s,BOOL animated){((void(*)(id,SEL,BOOL))disappeared)(vc,s,animated);if(kit.host==vc){kit.visible=NO;[kit hide];}}
static void onLayout(UIViewController *vc,SEL s){((void(*)(id,SEL))layout)(vc,s);if(kit.host==vc)[kit layout:vc];}
static IMP install(Class cls,SEL sel,IMP next){
 Method m=class_getInstanceMethod(cls,sel);if(!m)return NULL;
 IMP prev=method_getImplementation(m);
 if(!class_addMethod(cls,sel,next,method_getTypeEncoding(m)))prev=method_setImplementation(class_getInstanceMethod(cls,sel),next);
 return prev;
}
__attribute__((constructor)) static void startKit(void){
 dispatch_async(dispatch_get_main_queue(),^{
  Class cls=NSClassFromString(@"MPLauncherViewController");if(!cls || ![cls isSubclassOfClass:UIViewController.class])return;
  kit=[AMARYTKit new];if(!kit.config)return;
  appeared=install(cls,@selector(viewDidAppear:),(IMP)onAppear);
  disappeared=install(cls,@selector(viewDidDisappear:),(IMP)onDisappear);
  layout=install(cls,@selector(viewDidLayoutSubviews),(IMP)onLayout);
 });
}
