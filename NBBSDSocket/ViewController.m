//
//  ViewController.m
//  NBBSDSocket
//
//  Created by hutingting on 15/11/25.
//  Copyright © 2015年 hutingting. All rights reserved.
//

#import "ViewController.h"
#import "NBBSDSocket.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NBBSDSocket *socket =[NBBSDSocket SharedNBBSDSocket];
   
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
