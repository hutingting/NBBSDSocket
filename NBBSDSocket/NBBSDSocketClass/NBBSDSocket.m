
//
//  MyWebSocket.m
//  Elderly_langlang
//
//  Created by hutingting on 15/2/6.
//  Copyright (c) 2015年 langlangit. All rights reserved.
//
#import "NBBSDSocket.h"
#import <arpa/inet.h>
#import <netdb.h>

@interface NBBSDSocket ()
@property(nonatomic,assign) struct in_addr  remoteInAddr;
@property(nonatomic,strong) NSURL *url;
@property(nonatomic,strong) NSNumber *port;
@end

@implementation NBBSDSocket

+(id)SharedNBBSDSocket{
    static NBBSDSocket *g_SocketTool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_SocketTool = [[self alloc] init];
    });
    return g_SocketTool;
}

/**
 *  初始化url 与 port
 *
 *  @param url
 *  @param prot
 */
-(void)initUrl:(NSString *) url  WithPort:(int )  port{
    _url=[NSURL URLWithString:url];
    if(_url.port>0){
        _port = _url.port;
    }else{
        _port = [[NSNumber alloc] initWithInt:port];
    }
}

/**
 *  获取ip
 *
 *  @return 获取是否成功
 */
-(BOOL)updatesocketParameter{
    NSString * host = _url.host;
    struct hostent * remoteHostEnt = gngethostbyname([host UTF8String],5);
    if (NULL == remoteHostEnt) {
        //[self networkFailedWithErrorMessage:@"Unable to resolve the hostname of the warehouse server."];
        return NO;
    }
    _remoteInAddr = *((struct in_addr *)remoteHostEnt->h_addr_list[0]);
    return YES;
}


/**
 *  bsd请求
 *
 *  @param url  发送的url
 *  @param data 发送的数据
 *
 *  @return 接收到的数据
 */
-(NSString *)requertServerWithData:(NSData *) data
{
    @synchronized(self)
    {
        /***************************************************/
        //设置不被SIGPIPE信号中断，物理链路损坏时才不会导致程序直接被Terminate
        //在网络异常的时候如果程序收到SIGPIRE是会直接被退出的。
        struct sigaction sa;
        sa.sa_handler = SIG_IGN;
        sigaction( SIGPIPE, &sa, 0 );
        /***************************************************/
        
        
        // Create socket
        //
        int socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0);
        
        if (-1 == socketFileDescriptor) {
            NSLog(@"Failed to create socket.");
            return nil;
        }
        
        // Get IP address from host
        //
        if(_remoteInAddr.s_addr == 0){
            if (![self updatesocketParameter]) {
                NSLog(@ "Failed to get ip");
                return nil;
            }
        }
        
        // Set the socket parameters
        //
        struct sockaddr_in socketParameters;
        socketParameters.sin_family = AF_INET;
        socketParameters.sin_addr = _remoteInAddr;
        socketParameters.sin_port = htons([_port intValue]);
        
        int _error = -1, len;
        len = sizeof(int);
        struct timeval tm;
        fd_set set;
        
        //设置为非阻塞模式
        //
        BOOL flags = fcntl(socketFileDescriptor, F_GETFL,0);
        flags |= O_NONBLOCK;
        fcntl(socketFileDescriptor,F_SETFL, flags);
        //NSLog(@"flags  %d",flags);
        bool ret = false;
        if( connect(socketFileDescriptor,(struct sockaddr *)&socketParameters,sizeof(socketParameters)) == -1)
        {
            tm.tv_sec  = 5;
            tm.tv_usec = 0;
            FD_ZERO(&set);
            FD_SET(socketFileDescriptor, &set);
            if( select(socketFileDescriptor+1, NULL, &set, NULL, &tm) > 0)
            {
                getsockopt(socketFileDescriptor, SOL_SOCKET, SO_ERROR, &_error, (socklen_t *)&len);
                if(_error == 0) ret = true;
                else ret = false;
            } else ret = false;
        }
        else ret = true;
        
        //设置为阻塞模式
        //
        flags = fcntl(socketFileDescriptor, F_GETFL,0);
        flags &= ~ O_NONBLOCK;
        fcntl(socketFileDescriptor,F_SETFL, flags);
        //NSLog(@"flags  %d",flags);
        
        if(!ret)
        {
            NSLog(@ "Cannot Connect the server!\n");
            [self updatesocketParameter];
            return nil;
        }
               
        //忽略SIGPIPE
        int setSIGPIPE = 1;
        setsockopt(socketFileDescriptor, SOL_SOCKET, SO_NOSIGPIPE, (void *)&setSIGPIPE, sizeof(int));
        
        /////////////////////////发送信息给服务器////////////////////////
        int nNetTimeout=5000;//1秒，
        //设置发送超时
        setsockopt(socketFileDescriptor , SOL_SOCKET,SO_SNDTIMEO , (char *)&nNetTimeout,sizeof(int));
        NSInteger ls=(int)data.length;
        send(socketFileDescriptor,[data bytes], ls, 0);
        shutdown(socketFileDescriptor, SHUT_WR);

        
        /////////接收数据///////////
        // Continually receive data until we reach the end of the data
        //
        NSMutableData * recData = [[NSMutableData alloc] init];
        struct timeval tv;
        tv.tv_sec=2;
        tv.tv_usec=0;
        setsockopt(socketFileDescriptor, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
        ssize_t result;
        while (1) {
            const char * buffer[512];
            //int length = sizeof(buffer);
            
            // Read a buffer's amount of data from the socket; the number of bytes read is returned
            //
            result = recv(socketFileDescriptor, &buffer, 512,0);;
            
            if (result > 0) {
                [recData appendBytes:buffer length:result];
            }
            else {
//                NSLog(@"===%s",strerror(errno));
                if((result<0) &&(errno == EAGAIN||errno == EWOULDBLOCK||errno == EINTR))
                {
                    NSLog(@"===%s",strerror(errno));
                   // continue;//继续接收数据
                }
                break;//跳出接收循环
            }
        }
        
        // Close the socket
        //
        close(socketFileDescriptor);
        NSString *rets=[[NSString alloc] initWithBytes:[recData bytes] length:recData.length encoding:NSUTF8StringEncoding];
        return rets;
        
    }
}






/**
 *  设置获取ip超时机制
 *
 */
static sigjmp_buf jmpbuf;
static void alarm_func()
{
    siglongjmp(jmpbuf, 1);
}

static struct hostent *gngethostbyname(const char *HostName, int timeout)
{
    struct hostent *lpHostEnt;
    
    signal(SIGALRM, alarm_func);
    if(sigsetjmp(jmpbuf, 1) != 0)
    {
        alarm(0);//timout
        signal(SIGALRM, SIG_IGN);
        return NULL;
    }
    alarm(timeout);//setting alarm
    lpHostEnt = gethostbyname(HostName);
    signal(SIGALRM, SIG_IGN);
    
    return lpHostEnt;
}


@end
