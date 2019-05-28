//
//  EUExAliPay.m
//  EUExAliPay
//
//  Created by liguofu on 15/1/22.
//  Copyright (c) 2015年 AppCan.can. All rights reserved.
//

#import "EUExAliPay.h"
#import <AlipaySDK/AlipaySDK.h>
#import "EUtility.h"

#define EUExAliPaystandbyCallback @"EUExAliPaystandbyCallback"

@interface EUExAliPay()
@property (nonatomic, retain) PartnerConfig * partnerConfig;
@property (nonatomic, retain) NSMutableDictionary * productDic;
@property (nonatomic, copy)   NSString * cbStr;
@property (nonatomic, copy)   NSString *aliPaySignString;
@end

@implementation EUExAliPay

-(id)initWithBrwView:(EBrowserView *)eInBrwView {
    if (self=[super initWithBrwView:eInBrwView]) {
        self.productDic = [NSMutableDictionary dictionary];
        _partnerConfig = [[PartnerConfig alloc]init];
        [self addNotification];
    }
    return self;
}

- (void)addNotification
{
    //支付成功或失败的通知
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(aliPaystandbyCallback:) name:EUExAliPaystandbyCallback object:nil];
}

-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:EUExAliPaystandbyCallback object:nil];
    [self clean];
}

-(void)clean{
    if (_cbStr) {
        _cbStr = nil;
    }
    if (_partnerConfig) {
        _partnerConfig = nil;
    }
}

//支付宝是否安装，已安装yes，未安装no
- (BOOL)isAliPayInstalled:(NSMutableArray *)inArguments{
    NSURL * alipay_app_url = [NSURL URLWithString:@"alipay://"];
    BOOL ali = [[UIApplication sharedApplication] canOpenURL:alipay_app_url];
    return ali;
}

-(void)setPayInfo:(NSMutableArray *)inArguments{
    
    if (![inArguments isKindOfClass:[NSMutableArray class]] || [inArguments count] < 4) {
        
        return;
        
    }
    
    NSString * partnerID = [inArguments objectAtIndex:0];
    NSString * sellerID = [inArguments objectAtIndex:1];
    NSString * partnerPrivKey = [inArguments objectAtIndex:2];
    NSString * alipayPubKey = [inArguments objectAtIndex:3];
    NSString * notifyUrl = nil;
    if ([inArguments count] == 5) {
        notifyUrl = [inArguments objectAtIndex:4];
    }

    //设置appschame
    NSString *appScheme = nil;
    NSArray *scharray = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
    if ([scharray count]>0) {
        NSDictionary *subDict = [scharray objectAtIndex:0];
        if ([subDict count]>0) {
            NSArray *urlArray = [subDict objectForKey:@"CFBundleURLSchemes"];
            if ([urlArray count]>0) {
                appScheme = [urlArray objectAtIndex:0];
            }
        }
    }
    [self.partnerConfig setPartnerID:partnerID];
    [self.partnerConfig setSellerID:sellerID];
    [self.partnerConfig setAlipayPubKey:alipayPubKey];
    [self.partnerConfig setPartnerPrivKey:partnerPrivKey];
    [self.partnerConfig setNotifyUrl:notifyUrl];
    [self.partnerConfig setAppScheme:appScheme];
}

-(void)pay:(NSMutableArray *)inArguments{
    NSString * tradeNO = [inArguments objectAtIndex:0];
    NSString * productName = [inArguments objectAtIndex:1];
    NSString * productDescription = [inArguments objectAtIndex:2];
    NSString * amount = [NSString stringWithFormat:@"%@",[inArguments objectAtIndex:3]];
    
    [self.productDic setObject:tradeNO forKey:@"tradeNO"];//订单ID(由商家自行制定)
    [self.productDic setObject:productName forKey:@"productName"];//商品标题
    [self.productDic setObject:productDescription forKey:@"productDescription"];//商品描述
    [self.productDic setObject:amount forKey:@"amount"];//商品价格
    
    NSString *appScheme = self.partnerConfig.appScheme;
    //将商品信息拼接成字符串
    NSString* orderInfo = [self getOrderInfo];
    //获取私钥并将商户信息签名,外部商户可以根据情况存放私钥和签名,只需要遵循RSA签名规范,并将签名字符串base64编码和UrlEncode
    NSString* signedStr = [self doRsa:orderInfo];
    
    //将签名成功字符串格式化为订单字符串,请严格按照该格式
    NSString *orderString = nil;
    if (signedStr != nil) {
        orderString = [NSString stringWithFormat:@"%@&sign=\"%@\"&sign_type=\"%@\"",
                       orderInfo, signedStr, @"RSA"];
    }
    
    [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic)
     {
         int  resultStatus; //本次操作的状态返回值,标 识本次调用的结果
         NSString *resultString = nil; //本次操作返回的结果数据
         resultStatus = [[resultDic objectForKey:@"resultStatus"] intValue];
         resultString = [resultDic objectForKey:@"memo"];
         if (resultStatus == 9000) {
             self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,UEX_CPAYSUCCESSDES];
         }
         else  if (resultStatus == 6001) {
             self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYCANCLE,UEX_CPAYCANCLEDES];
         }
         else {
             self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,UEX_CPAYFAILEDDES];
         }
         [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
     }];
}

// 阿里支付回调
- (void)aliPaystandbyCallback:(NSNotification *)notification{
    //回调接口
    NSDictionary *resultDic = notification.object;
    int  resultStatus; //本次操作的状态返回值,标 识本次调用的结果
    NSString *resultString = nil; //本次操作返回的结果数据
    resultStatus = [[resultDic objectForKey:@"resultStatus"] intValue];
    resultString = [resultDic objectForKey:@"memo"];
    if (resultStatus == 9000) {
        self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,UEX_CPAYSUCCESSDES];
    }
    else  if (resultStatus == 6001) {
        self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYCANCLE,UEX_CPAYCANCLEDES];
    }
    else {                 self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,UEX_CPAYFAILEDDES];
    }
    [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
    
}

- (void)gotoPay:(NSMutableArray *)inArguments {
    //设置appschame
    NSString *appScheme = nil;
    NSString *orderString = nil;
    NSArray *scharray = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleURLTypes"];
    if ([scharray count]>0) {
        NSDictionary *subDict = [scharray objectAtIndex:0];
        if ([subDict count]>0) {
            NSArray *urlArray = [subDict objectForKey:@"CFBundleURLSchemes"];
            if ([urlArray count]>0) {
                appScheme = [urlArray objectAtIndex:0];
            }
        }
    }
    if (inArguments.count > 0) {
        orderString = [inArguments objectAtIndex:0];
    }
    [[AlipaySDK defaultService] payOrder:orderString fromScheme:appScheme callback:^(NSDictionary *resultDic)
     {
         int  resultStatus; //本次操作的状态返回值,标 识本次调用的结果
         NSString *resultString = nil; //本次操作返回的结果数据
         resultStatus = [[resultDic objectForKey:@"resultStatus"] intValue];
         resultString = [resultDic objectForKey:@"memo"];
         if (resultStatus == 9000) {
             self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,UEX_CPAYSUCCESSDES];
         }
         else  if (resultStatus == 6001) {
             self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYCANCLE,UEX_CPAYCANCLEDES];
         }
         else {
             self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,UEX_CPAYFAILEDDES];
         }
         [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
     }];

}
-(NSString *)getOrderInfo {
    
    ACPAliPayOrder *order = [[ACPAliPayOrder alloc] init];
    order.partner = self.partnerConfig.partnerID;//合作者身份ID,以 2088 开头由 16 位纯数字组成的字符串
    order.seller = self.partnerConfig.sellerID;//支付宝收款账号,手机号码或邮箱格式
    order.tradeNO = [self.productDic objectForKey:@"tradeNO"];//订单ID(由商家自行制定)
    order.productName = [self.productDic objectForKey:@"productName"];//商品标题
    order.productDescription = [self.productDic objectForKey:@"productDescription"];//商品描述
    order.amount = [self.productDic objectForKey:@"amount"];//商品价格
    order.notifyURL =  self.partnerConfig.notifyUrl;//回调URL,(服务器异 步通知页 面路径)支付宝服务器主动通知商户 网站里指定的页面 http 路径
    order.service = @"mobile.securitypay.pay";//接口名称。固定值。
    order.inputCharset = @"utf-8";//商户网站使用的编码格式,固定为 utf-8。
     //order.itBPay = @"30m";
     //order.showUrl = @"m.alipay.com";
     //order.paymentType = @"1";
    return [order description];
}
////获取私钥并将商户信息签名,外部商户可以根据情况存放私钥和签名,只需要遵循RSA签名规范,并将签名字符串base64编码和UrlEncode
-(NSString *)doRsa:(NSString *)orderInfo {
    id<DataSigner> signer;
    signer = CreateRSADataSigner(self.partnerConfig.partnerPrivKey);
    NSString *signedString = [signer signString:orderInfo];
    self.aliPaySignString = signedString;
    return signedString;
}

-(void)uexOnPayWithStatus:(int)inStatus des:(NSString *)inDes{
    inDes =[inDes stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *jsStr = [NSString stringWithFormat:@"if(uexAliPay.onStatus!=null){uexAliPay.onStatus(%d,\'%@\')}",inStatus,inDes];
    [EUtility brwView:self.meBrwView evaluateScript:jsStr];

}

- (void)parseURL:(NSURL *)url application:(UIApplication *)application {
    
    self.cbStr = nil;
    //跳转支付宝钱包进行支付，需要将支付宝钱包的支付结果回传给SDK
    if ([url.host isEqualToString:@"safepay"]) {
        [[AlipaySDK defaultService]
         processOrderWithPaymentResult:url
         standbyCallback:^(NSDictionary *resultDic) {
             int  resultStatus; //本次操作的状态返回值,标 识本次调用的结果
             NSString *resultString = nil; //本次操作返回的结果数据
             resultStatus = [[resultDic objectForKey:@"resultStatus"] intValue];
             resultString = [resultDic objectForKey:@"memo"];
             if (resultStatus == 9000) {
                 self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,UEX_CPAYSUCCESSDES];
             }
             else  if (resultStatus == 6001) {
                 self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYCANCLE,UEX_CPAYCANCLEDES];
             }
             else {
                 self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,UEX_CPAYFAILEDDES];
             }
             [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
         }];
        
    }
    
    //支付宝钱包快登授权返回 authCode
    if ([url.host isEqualToString:@"platformapi"]){
        [[AlipaySDK defaultService] processAuthResult:url standbyCallback:^(NSDictionary *resultDic) {
            int  resultStatus; //本次操作的状态返回值,标 识本次调用的结果
            NSString *resultString = nil; //本次操作返回的结果数据
            resultStatus = [[resultDic objectForKey:@"resultStatus"] intValue];
            resultString = [resultDic objectForKey:@"memo"];
            if (resultStatus == 9000) {
                self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYSUCCESS,UEX_CPAYSUCCESSDES];
            }
            else  if (resultStatus == 6001) {
                self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYCANCLE,UEX_CPAYCANCLEDES];
            }
            else {                 self.cbStr = [NSString stringWithFormat:@"if(%@!=null){%@(%d,\'%@\');}",@"uexAliPay.onStatus",@"uexAliPay.onStatus",UEX_CPAYFAILED,UEX_CPAYFAILEDDES];
            }
            [self performSelector:@selector(delayCB) withObject:self afterDelay:1.0];
        }];
        
    }
}
-(void)delayCB {
    [EUtility brwView:self.meBrwView evaluateScript:self.cbStr];
}


+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    
    if ([url.host isEqualToString:@"safepay"]) {
        //跳转支付宝钱包进行支付，处理支付结果
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"result = %@",resultDic);
            //支付状态通知
            [[NSNotificationCenter defaultCenter] postNotificationName:EUExAliPaystandbyCallback object:resultDic];
        }];
    }
    return YES;
}

+ (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<NSString*, id> *)options
{
    if ([url.host isEqualToString:@"safepay"]) {
        //跳转支付宝钱包进行支付，处理支付结果
        [[AlipaySDK defaultService] processOrderWithPaymentResult:url standbyCallback:^(NSDictionary *resultDic) {
            NSLog(@"result = %@",resultDic);
            //支付状态通知
            [[NSNotificationCenter defaultCenter] postNotificationName:EUExAliPaystandbyCallback object:resultDic];
        }];
    }
    return YES;
}


@end
