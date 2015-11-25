//
//  MyWebSocket.h
//  Elderly_langlang
//
//  Created by hutingting on 15/2/6.
//  Copyright (c) 2015年 langlangit. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NBBSDSocket : NSObject
+(id)SharedNBBSDSocket;

/**
 *  初始化url 与 port
 *
 *  @param url
 *  @param prot
 */
-(void)initUrl:(NSString *) url  WithPort:(int )  port;

/**
 *  bsd请求
 *
 *  @param url  发送的url
 *  @param data 发送的数据
 *
 *  @return 接收到的数据
 */
-(NSString *)requertServerWithData:(NSData *) data;
@end
