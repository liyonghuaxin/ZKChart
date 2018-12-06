//
//  HorizontalVC.m
//  ZKChart
//
//  Created by 李永华 on 2018/12/6.
//  Copyright © 2018 mac. All rights reserved.
//

#import "HorizontalVC.h"
#import "ZKMinuteView.h"
#import "SlideTabView.h"

@interface HorizontalVC ()<SwitchTabViewDelegate>{
    SlideTabView *slideTab;
    ZKMinuteView *minuteView;
}

@end

@implementation HorizontalVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self initSubviews];
}

- (void)initSubviews{
    CGFloat padding = 8;
    
    CGRect topRect = CGRectMake(0, 0, SCREEN_HEIGHT, 40);
    CGRect botomRect = CGRectMake(0, SCREEN_WIDTH - 35, SCREEN_HEIGHT, 35);
    CGRect mLineRect = CGRectMake(padding, topRect.size.height+padding, SCREEN_HEIGHT - padding * 2, SCREEN_WIDTH-topRect.size.height-botomRect.size.height-padding*2);

    UIButton * btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(SCREEN_HEIGHT - 50, 0, 40, 40);
    [btn setTitle:@"×" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:30];
    [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(pop) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    slideTab = [SlideTabView switchTabView:@[@"1天",@"1周",@"1月",@"3年",@"1年",@"今年",@"所有"]];
    slideTab.frame = CGRectMake(0, SCREEN_WIDTH-35, SCREEN_HEIGHT, 35);
    slideTab.delegate = self;
    [self.view addSubview:slideTab];
    
    minuteView = [[ZKMinuteView alloc] initWithFrame:mLineRect];
    [self.view addSubview:minuteView];
    [minuteView updateChart];
    [self requestData];

}

- (void)requestData{
    NSMutableArray *array = [NSMutableArray array];
    AFHTTPSessionManager *sessionManager = [AFHTTPSessionManager manager];
    [sessionManager GET:@"https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=1m" parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSDictionary *dataDic = responseObject[@"data"];
        NSArray *dataArr = dataDic[@"data"];
        for (NSArray *arr in dataArr) {
            BitTimeModel *model = [[BitTimeModel alloc] init];
            model.priceUsd = arr[1];
            model.transactionAmount = arr[3];
            model.marketValue = arr[4];
            model.ggDate = [NSDate dateWithTimeIntervalSince1970:[arr[0] doubleValue]];
            [array addObject:model];
        }
        [minuteView updateDataWithArray:array];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
}


- (void)pop{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - SlideDelegate

- (void)tabBtnClicked:(NSInteger)btnTag
{

}
#pragma mark - 旋转
- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscapeRight;
}

- (BOOL)shouldAutorotate
{
    return YES;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
