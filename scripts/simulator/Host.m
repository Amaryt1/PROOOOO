// UIKit integration fixture. No game data, executable or private signing material.
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// Force an offline launch inside the fixture only. WKWebView still reads its local file.
@interface FixtureOffline:NSURLProtocol @end
@implementation FixtureOffline
+(BOOL)canInitWithRequest:(NSURLRequest*)r{return [r.URL.scheme isEqual:@"https"];}
+(NSURLRequest*)canonicalRequestForRequest:(NSURLRequest*)r{return r;}
-(void)startLoading{[self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];}
-(void)stopLoading{}
@end
@interface NSURLSessionConfiguration(Fixture)
+(NSURLSessionConfiguration*)fixtureOffline;
@end
@implementation NSURLSessionConfiguration(Fixture)
+(void)load{method_exchangeImplementations(class_getClassMethod(self,@selector(ephemeralSessionConfiguration)),class_getClassMethod(self,@selector(fixtureOffline)));}
+(NSURLSessionConfiguration*)fixtureOffline{NSURLSessionConfiguration *c=[self fixtureOffline];c.protocolClasses=@[FixtureOffline.class];return c;}
@end
static void record(NSString *result){
 NSURL *docs=[NSFileManager.defaultManager URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
 [result writeToURL:[docs URLByAppendingPathComponent:@"result.txt"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
static UIView *match(UIView *v, BOOL (^accept)(UIView*)){
 if(v.hidden || v.alpha<.01)return nil;
 if(accept(v))return v;
 for(UIView *child in v.subviews){UIView *found=match(child,accept);if(found)return found;}
 return nil;
}
static UIView *label(UIView *v, NSString *value){
 return match(v,^BOOL(UIView *x){return [x isKindOfClass:UILabel.class] && [[(UILabel*)x text] containsString:value];});
}
@interface MPLauncherViewController:UIViewController{
 UIView *_sidebar,*_avatar,*_gta6Icon;
 NSArray *_tabs;NSUInteger _plays;UILabel *_brand;
}
@end
@implementation MPLauncherViewController
-(void)viewDidLoad{
 [super viewDidLoad];self.view.backgroundColor=UIColor.blackColor;
 _sidebar=[UIView new];[self.view addSubview:_sidebar];_gta6Icon=[UIImageView new];[_sidebar addSubview:_gta6Icon];
 _avatar=[UIView new];[self.view addSubview:_avatar];_brand=[UILabel new];_brand.text=@"AMAR YT";[_sidebar addSubview:_brand];
 UILabel *footer=[UILabel new];footer.tag=100;footer.text=@"AMAR YT";[_sidebar addSubview:footer];
 NSMutableArray *tabs=[NSMutableArray new];
 for(NSString *s in @[@"Games",@"Data",@"Settings",@"Mods"]){
  UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.tag=tabs.count;b.accessibilityLabel=s;[b setTitle:s forState:0];[b addTarget:self action:@selector(tabTapped:) forControlEvents:UIControlEventTouchUpInside];[tabs addObject:b];[self.view addSubview:b];
 }_tabs=tabs;
 UIButton *play=[UIButton buttonWithType:UIButtonTypeSystem];play.tag=99;[play setTitle:@"PLAY" forState:0];[play addTarget:self action:@selector(playTapped) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:play];
}
-(void)playTapped{_plays++;}
-(void)tabTapped:(id)sender{}
-(void)toggleSidebar{}
-(void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];CGFloat w=self.view.bounds.size.width,h=self.view.bounds.size.height;_sidebar.frame=CGRectMake(0,0,130,h);_avatar.frame=CGRectMake(w-35,20,28,28);_gta6Icon.frame=CGRectMake(6,90,28,28);_brand.frame=CGRectMake(5,124,105,30);[_sidebar viewWithTag:100].frame=CGRectMake(5,h-54,105,30);
 for(UIButton *b in _tabs)b.frame=CGRectMake(140+35*b.tag,50,30,34);
 [self.view viewWithTag:99].frame=CGRectMake(150,300,100,50);
}
-(void)viewDidAppear:(BOOL)animated{
 [super viewDidAppear:animated];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(),^{[self check];});
}
-(void)check{
 if(!label(self.view,@"Kit Active · Build 8") || !label(self.view,@"أهلًا بك في AMAR YT")){record(@"FAIL attachment or welcome");return;}
 for(NSString *name in @[@"social-instagram",@"social-telegram",@"social-tiktok"]){
  if(!match(self.view,^BOOL(UIView *v){return [v.accessibilityIdentifier isEqual:name];})){record(@"FAIL social button");return;}
 }
 UIButton *close=(id)match(self.view,^BOOL(UIView *v){return [v isKindOfClass:UIButton.class] && [[(UIButton*)v currentTitle] isEqual:@"متابعة اللعب"];});
 if(!close){record(@"FAIL continue");return;}[close sendActionsForControlEvents:UIControlEventTouchUpInside];
 if(_plays || label(self.view,@"متابعة اللعب")){record(@"FAIL dismiss-only");return;}
 NSArray *names=@[@"الألعاب",@"الحفظ",@"الإعدادات",@"المودات"];
 for(UIButton *b in _tabs){UILabel *caption=(id)label(b,names[b.tag]);if(!caption || caption==b.titleLabel || ceil([caption sizeThatFits:CGSizeMake(1000,48)].width)>CGRectGetWidth(b.bounds)){record(@"FAIL tab width");return;}}
 UIButton *store=(id)match(_sidebar,^BOOL(UIView *v){return [v isKindOfClass:UIButton.class] && [v.accessibilityLabel isEqual:@"المودات"];});
 if(!store || CGRectGetMinY(store.frame)<CGRectGetMaxY(_brand.frame) || CGRectGetMinY(store.frame)>CGRectGetMaxY(_brand.frame)+10){record(@"FAIL sidebar row");return;}
 CGPoint middle=[store convertPoint:CGPointMake(CGRectGetMidX(store.bounds),CGRectGetMidY(store.bounds)) toView:self.view];UIView *hit=[self.view hitTest:middle withEvent:nil];
 if(![hit isDescendantOfView:store]){record(@"FAIL sidebar hit test");return;}
 [(UIButton*)[self.view viewWithTag:99] sendActionsForControlEvents:UIControlEventTouchUpInside];if(_plays!=1){record(@"FAIL fixture PLAY action");return;}
 [store sendActionsForControlEvents:UIControlEventTouchUpInside];
 if(!match(self.view,^BOOL(UIView *v){return [v isKindOfClass:NSClassFromString(@"WKWebView")];})){record(@"FAIL catalog");return;}
 record(@"PASS native welcome, dismiss-only, three social actions, four full-width labels, top-brand sidebar hit test, catalog open and original fixture PLAY action");
}
@end
@interface Host:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@end
@implementation Host
-(BOOL)application:(UIApplication*)app didFinishLaunchingWithOptions:(NSDictionary*)options{
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.window.rootViewController=[MPLauncherViewController new];[self.window makeKeyAndVisible];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(Host.class));}}
