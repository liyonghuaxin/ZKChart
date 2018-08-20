//
//  PriceChart.m
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "PriceChart.h"

#import "KLineData.h"
#import "BitLineChart.h"

@interface PriceChart ()

@end

@implementation PriceChart

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    BitLineChart *bitchart = [[BitLineChart alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 250)];
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockWeekDataJsonPath]];
    NSArray *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
    NSArray <KLineData *> *datas = [[[KLineData arrayForArray:stockJson class:[KLineData class]] reverseObjectEnumerator] allObjects];
    [bitchart setKLineArray:datas type:BitLineTypeWeek];
    [bitchart updateChart];
    [self.view addSubview:bitchart];
}

- (NSString *)stockWeekDataJsonPath
{
    return [[NSBundle mainBundle] pathForResource:@"week_k_data_60087" ofType:@"json"];
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
