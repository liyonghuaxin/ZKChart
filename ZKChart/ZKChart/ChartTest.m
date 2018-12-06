//
//  ChartTest.m
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "ChartTest.h"
#import "ZKMinuteView.h"
#import "HorizontalVC.h"

@interface ChartTest (){
    ZKMinuteView *minuteView;
}

@end

@implementation ChartTest

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    minuteView = [[ZKMinuteView alloc] initWithFrame:CGRectMake(0, 100, SCREEN_WIDTH, 300)];
    minuteView.isShowLargeBtn = YES;
    [minuteView updateChart];
    __weak ChartTest *weakSelf = self;
    minuteView.largeBlock = ^{
        HorizontalVC *vc = [[HorizontalVC alloc] init];
        [weakSelf presentViewController:vc animated:YES completion:nil];
    };
    [self.view addSubview:minuteView];
    
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


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
