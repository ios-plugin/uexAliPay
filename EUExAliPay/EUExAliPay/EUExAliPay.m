//
//  EUExAliPay.m
//  EUExAliPay
//
//  Created by liguofu on 15/1/22.
//  Copyright (c) 2015年 AppCan.can. All rights reserved.
//

#import "EUExAliPay.h"
#import <AlipaySDK/AlipaySDK.h>
#import <AppCanKit/ACEXTScope.h>
#import "uexAliPayOrder.h"
#import "uexAliPayAuthInfo.h"





@interface EUExAliPay()<AppCanApplicationEventObserver>
@property (nonatomic,strong)NSString *partnerID;
@property (nonatomic,strong)NSString *sellerID;
@property (nonatomic,strong)NSString *rsaPrivateKey;
@property (nonatomic,strong)NSString *rsaPublicKey;
@property (nonatomic,strong)NSString *notifyURL;
@property (nonatomic,readonly)NSString *appURLScheme;
@end

@implementation EUExAliPay




- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    self = [super initWithWebViewEngine:engine];
    if (self) {
    }
    return self;
}


- (void)dealloc{
    [self clean];
}

- (void)clean{

}


- (NSString *)appURLScheme{
    static NSString *scheme = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSDictionary *schemeInfo = [[NSBundle mainBundle].infoDictionary[@"CFBundleURLTypes"] firstObject];
        scheme = [schemeInfo[@"CFBundleURLSchemes"] firstObject];
    });
    return scheme;
}


- (void)setPayInfo:(NSMutableArray *)inArguments{
    
    ACArgsUnpack(NSString *partnerID,NSString *sellerID,NSString *rsaPrivateKey,NSString *rsaPublicKey,NSString *notifyURL) = inArguments;
    self.partnerID = partnerID;
    self.sellerID = sellerID;
    self.rsaPrivateKey = rsaPrivateKey;
    self.rsaPublicKey = rsaPublicKey;
    self.notifyURL = notifyURL;

}

- (void)pay:(NSMutableArray *)inArguments{
    
    ACArgsUnpack(NSString *tradeNo,NSString* productName,NSString *productDescription,NSString *amount,ACJSFunctionRef *callback) = inArguments;
    uexAliPayOrder *order = [uexAliPayOrder new];
    // NOTE: partnerID设置
    order.app_id = self.partnerID;
    // NOTE: 支付接口名称
    order.method = @"alipay.trade.app.pay";
    // NOTE: 参数编码格式
    order.charset = @"utf-8";
    // NOTE: 当前时间戳
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    order.timestamp = [formatter stringFromDate:[NSDate date]];
    // NOTE: 支付版本
    order.version = @"1.0";
    // NOTE: sign_type设置
    order.sign_type = @"RSA";
    order.notify_url = self.notifyURL;
    // NOTE: 商品数据
    order.biz_content = [uexAliPayContent new];
    order.biz_content.body = productDescription;
    order.biz_content.seller_id = self.sellerID;
    order.biz_content.subject = productName;
    order.biz_content.out_trade_no = tradeNo;//订单ID（由商家自行制定）
    order.biz_content.timeout_express = @"30m"; //超时时间设置
    order.biz_content.total_amount = amount; //商品价格
    order.type = uexAliPayOrderTypeV1;
    NSString *orderString = [order orderStringSignedWithRSAPrivateKey:self.rsaPrivateKey];
    [self setPayCompletionBlockWithCallback:callback];
    [self startPayWithOrder:orderString];

}


- (void)gotoPay:(NSMutableArray *)inArguments {
    [self payWithOrder:inArguments];
    
}


- (void)payWithOrder:(NSMutableArray *)inArguments {
    ACArgsUnpack(NSString *orderString,ACJSFunctionRef *callback) = inArguments;
    [self setPayCompletionBlockWithCallback:callback];
    [self startPayWithOrder:orderString];
}

- (NSString *)generatePayOrder:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    uexAliPayOrder *order = [uexAliPayOrder new];
    
    NSString *privateKey = stringArg(info[@"private_key"]);
    NSDictionary *biz = dictionaryArg(info[@"biz_content"]);
    // NOTE: app_id设置
    order.app_id = stringArg(info[@"app_id"]);
    // NOTE: 支付接口名称
    order.method = @"alipay.trade.app.pay";
    // NOTE: 参数编码格式
    order.charset = @"utf-8";
    // NOTE: 当前时间戳
    NSDateFormatter *formatter = [NSDateFormatter new];
    [formatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    order.timestamp = [formatter stringFromDate:[NSDate date]];
    // NOTE: 支付版本
    order.version = @"1.0";
    // NOTE: sign_type设置
    order.useRSA2 = numberArg(info[@"rsa2"]).boolValue;
    // NOTE: 商品数据
    order.biz_content = [uexAliPayContent new];
    order.biz_content.body = stringArg(biz[@"body"]);
    order.biz_content.seller_id = stringArg(biz[@"seller_id"]);
    order.biz_content.subject = stringArg(biz[@"subject"]);
    order.biz_content.out_trade_no = stringArg(biz[@"out_trade_no"]);//订单ID（由商家自行制定）
    order.biz_content.timeout_express = @"30m"; //超时时间设置
    order.biz_content.total_amount = stringArg(biz[@"total_amount"]); //商品价格
    order.type = uexAliPayOrderTypeV2;
    return [order orderStringSignedWithRSAPrivateKey:privateKey];

}



- (void)startPayWithOrder:(NSString *)orderString{
    [[AlipaySDK defaultService] payOrder:orderString fromScheme:self.appURLScheme callback:_globalPayCallbackCompletion];
}

- (void)auth:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *authInfo,ACJSFunctionRef *callback) = inArguments;

    _globalAuthCallbackCompletion = ^(NSDictionary *resultDict){
        NSMutableDictionary *dict = [resultDict mutableCopy];
        NSUInteger resultStatus = numberArg(resultDict[@"resultStatus"]).integerValue;



        //success=true&auth_code=9c11732de44f4f1790b63978b6fbOX53&result_code=200&alipay_open_id=20881001757376426161095132517425&user_id=2088003646494707
        NSURLComponents *components = [[NSURLComponents alloc]init];
        components.query = stringArg(resultDict[@"result"]);
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        for (NSURLQueryItem *item in components.queryItems) {
            [result setValue:item.value forKey:item.name];
        }
        NSInteger resultCode = numberArg(result[@"result_code"]).integerValue;
        
        [dict setValue:stringArg(result[@"auth_code"]) forKey:@"authCode"];
        [dict setValue:stringArg(result[@"alipay_open_id"]) forKey:@"alipayOpenId"];

        
        UEX_ERROR error = kUexNoError;
        if (resultStatus != 9000 || resultCode != 200) {
            error = uexErrorMake(1,[@"uexAliPay.auth failed: " stringByAppendingString:stringArg(resultDict[@"memo"])]);
        }
        
        [callback executeWithArguments:ACArgsPack(error,dict.ac_JSONFragment)];
        _globalAuthCallbackCompletion = nil;
    };
    
    [[AlipaySDK defaultService] auth_V2WithInfo:authInfo fromScheme:self.appURLScheme callback:_globalAuthCallbackCompletion];
}


- (NSString *)getAuthInfo:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSDictionary *info) = inArguments;
    NSString *privateKey = stringArg(info[@"rsaPrivate"]);
    UEX_PARAM_GUARD_NOT_NIL(privateKey,nil);
    uexAliPayAuthInfo *authInfo = [[uexAliPayAuthInfo alloc]init];
    authInfo.pid = stringArg(info[@"pid"]);
    authInfo.appID = stringArg(info[@"appId"]);
    authInfo.targetID = stringArg(info[@"targetId"]);
    authInfo.useRSA2 = numberArg(info[@"rsa2"]).boolValue;
    authInfo.authType = stringArg(info[@"authType"]);
    return [authInfo authInfoStringSignedWithPrivateKey:privateKey];
    
    
}





static CompletionBlock _globalPayCallbackCompletion = nil;
static CompletionBlock _globalAuthCallbackCompletion = nil;

- (void)setPayCompletionBlockWithCallback:(ACJSFunctionRef *)callback{
    @weakify(self);
    _globalPayCallbackCompletion = ^(NSDictionary *resultDic){
        @strongify(self);
        NSUInteger resultStatus = numberArg(resultDic[@"resultStatus"]).integerValue;
        NSString *resultString = stringArg(resultDic[@"memo"]);
        UEX_ERROR error = kUexNoError;
        switch (resultStatus) {
            case 9000:
                resultString = @"支付成功";
                break;
            case 6001:
                error = uexErrorMake(4,@"uexAliPay: 支付取消");
                break;
            default:
                error = uexErrorMake(2,[@"uexAlipay: " stringByAppendingString:resultString]);
                break;
        }
        
        [self.webViewEngine callbackWithFunctionKeyPath:@"uexAliPay.onStatus" arguments:ACArgsPack(error,resultString)];
        [callback executeWithArguments:ACArgsPack(error,resultString)];
        
        _globalPayCallbackCompletion = nil;
    };
}

+ (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation{
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:_globalPayCallbackCompletion];
        [[AlipaySDK defaultService] processAuth_V2Result:url standbyCallback:_globalAuthCallbackCompletion];
    }
    
    return YES;
}




@end
