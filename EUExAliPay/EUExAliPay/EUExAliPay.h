//
//  EUExAliPay.h
//  EUExAliPay
//
//  Created by liguofu on 15/1/22.
//  Copyright (c) 2015年 AppCan.can. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EUExBase.h"
#import "EUExBaseDefine.h"
#import "EUtility.h"
#import "PartnerConfig.h"
#import "DataSigner.h"
#import "DataVerifier.h"
#import "ACPAliPayOrder.h"
#import "DataVerifier.h"

#define UEX_CPAYSUCCESS			0
#define UEX_CPAYING             1
#define UEX_CPAYFAILED			2
#define UEX_CPAYPLUGINERROR		3
#define UEX_CPAYCANCLE          4

#define UEX_CPAYSUCCESSDES   @"支付成功"
#define UEX_CPAYFAILEDDES    @"支付失败"
#define UEX_CPAYCANCLEDES    @"支付取消"

@interface EUExAliPay : EUExBase

- (void)uexOnPayWithStatus:(int)inStatus des:(NSString *)inDes;
- (void)parseURL:(NSURL *)url application:(UIApplication *)application;

@end

