//
//  Test.m
//  HQZMarket
//
//  Created by mac on 2018/7/27.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "Test.h"
#import "KLineChart.h"
#import "KLineData.h"
#import "NSDate+GGDate.h"

#import "LineBarChart.h"

#import "LineDataSet.h"
#import "LineChart.h"

#import "MinuteAbstract.h"
#import "QueryViewAbstract.h"
#import "HorizontalKLineViewController.h"
#import "KTimeViewController.h"
#import "MinuteChart.h"

#import "BitLineChart.h"

#import "BLineChart.h"
@interface Test ()

@property (nonatomic, strong) BarData * barData1;
@property (nonatomic, strong) BarData * barData2;
@property (nonatomic, strong) LineData * lineData1;
@property (nonatomic, strong) LineData * lineData2;
@property (nonatomic) LineBarChart * lineBarChart;

@end

@implementation Test

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    if (_index == 0) {
        [self showKLineChart];
    }else{
        [self showMinuteChart];
    }
   
//    [self showLineChart];
    
//    [self showLineBarChart];
    
    
//    [self showBitLineChart];
    
//    [self showBLineChart];
}

- (void)showBLineChart{
    BLineChart *bchart = [[BLineChart alloc] initWithFrame:CGRectMake(10, 100+300+30, self.view.frame.size.width - 20, 250)];
    bchart.backgroundColor = [UIColor grayColor];
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockWeekDataJsonPath]];
    NSArray *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
//    NSArray <KLineData *> *datas = [[[KLineData arrayForArray:stockJson class:[KLineData class]] reverseObjectEnumerator] allObjects];
//    [bitchart setKLineArray:datas type:BitLineTypeWeek];
    [bchart updateChart];
    [self.view addSubview:bchart];
}

- (void)showBitLineChart{
    BitLineChart *bitchart = [[BitLineChart alloc] initWithFrame:CGRectMake(10, 80+250+30, self.view.frame.size.width - 20, 250)];
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockWeekDataJsonPath]];
    NSArray *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
    NSArray <KLineData *> *datas = [[[KLineData arrayForArray:stockJson class:[KLineData class]] reverseObjectEnumerator] allObjects];
    [bitchart setKLineArray:datas type:BitLineTypeWeek];
    [bitchart updateChart];
    [self.view addSubview:bitchart];
}

- (void)showMinuteChart{
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockFiveDataJsonPath]];
    NSArray * stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
    
    NSArray <MinuteAbstract, VolumeAbstract> * timeAry = (NSArray <MinuteAbstract, VolumeAbstract> *) [BaseModel arrayForArray:stockJson class:[TimeModel class]];
    
    [timeAry enumerateObjectsUsingBlock:^(TimeModel * obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        obj.ggDate = [NSDate dateWithString:obj.date format:@"yyyy-MM-dd HH:mm:ss"];
    }];
    
    MinuteChart * timeChart = [[MinuteChart alloc] initWithFrame:CGRectMake(10, 100, self.view.frame.size.width - 20, 250)];
    [timeChart setMinuteTimeArray:timeAry timeChartType:TimeDay];
    
    [self.view addSubview:timeChart];
    [timeChart drawChart];
    
    UIBarButtonItem * bar = [[UIBarButtonItem alloc] initWithTitle:@"横屏" style:0 target:self action:@selector(present)];
    self.navigationItem.rightBarButtonItem = bar;
}

- (void)showKLineChart{
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockWeekDataJsonPath]];
    NSArray *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
    
    NSArray <KLineData *> *datas = [[[KLineData arrayForArray:stockJson class:[KLineData class]] reverseObjectEnumerator] allObjects];
    
    self.title = @"伊利股份(600887)";
    
    [datas enumerateObjectsUsingBlock:^(KLineData * obj, NSUInteger idx, BOOL * stop) {
        
        obj.ggDate = [NSDate dateWithString:obj.date format:@"yyyy-MM-dd HH:mm:ss"];
    }];
    
    KLineChart * kChart = [[KLineChart alloc] initWithFrame:CGRectMake(10, 100, [UIScreen mainScreen].bounds.size.width - 20, 300)];
    [kChart setKLineArray:datas type:KLineTypeWeek];
    [kChart updateChart];
    
    [self.view addSubview:kChart];
}

- (void)showLineChart{
    self.title = @"LineChart";
    
    NSData *dataStock = [NSData dataWithContentsOfFile:[self stockDataJsonPathLine]];
    NSDictionary *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
    NSArray *beforeAry = stockJson[@"beforeData"];
    
    NSMutableArray * aryLineData = [NSMutableArray array];
    NSMutableSet * indexSet = [NSMutableSet set];
    NSMutableSet * indexPointSet = [NSMutableSet set];
    NSMutableArray * aryTitles = [NSMutableArray array];
    
    for (NSInteger i = 0; i < beforeAry.count; i++) {
        
        NSDictionary * dictionary = beforeAry[i];
        [aryLineData addObject:dictionary[@"close_price"]];
        [aryTitles addObject:[self titleDataString:dictionary[@"date"]]];
        
        if (i % 130 == 0) {
            
            [indexSet addObject:@(i)];
        }
        
        if (![dictionary[@"dividend"] isKindOfClass:[NSNull class]]) {
            
            [indexPointSet addObject:@(i)];
        }
    }
    
    LineData * lineData = [[LineData alloc] init];
    lineData.dataAry = aryLineData;
    lineData.lineWidth = .5f;
    lineData.lineColor = __RGB_BLUE;
    lineData.lineFillColor = [__RGB_BLUE colorWithAlphaComponent:.3f];
    lineData.showShapeIndexSet = indexPointSet;
    lineData.shapeRadius = 1.5f;
    lineData.shapeFillColor = __RGB_RED;
    
    LineDataSet * lineSet = [[LineDataSet alloc] init];
    lineSet.insets = UIEdgeInsetsMake(15, 0, 15, 0);
    lineSet.lineAry = @[lineData];
    lineSet.idRatio = .1f;
    lineSet.updateNeedAnimation = YES;
    
    /** 网格 */
    lineSet.gridConfig.lineColor = RGB(186, 167, 169);
    lineSet.gridConfig.lineWidth = .7f;
    lineSet.gridConfig.axisLineColor = [UIColor blackColor];
    lineSet.gridConfig.axisLableFont = [UIFont systemFontOfSize:8];
    lineSet.gridConfig.axisLableColor = RGB(186, 167, 169);
    lineSet.gridConfig.dashPattern = @[@2, @2];
    
    /** 底轴 */
    lineSet.gridConfig.bottomLableAxis.lables = aryTitles;
    lineSet.gridConfig.bottomLableAxis.over = 0;
    lineSet.gridConfig.bottomLableAxis.showSplitLine = YES;
    lineSet.gridConfig.bottomLableAxis.showQueryLable = YES;
    lineSet.gridConfig.bottomLableAxis.showIndexSet = indexSet;
    lineSet.gridConfig.bottomLableAxis.offSetRatio = GGRatioBottomRight;
    
    /** 左轴 */
    lineSet.gridConfig.leftNumberAxis.splitCount = 7;
    lineSet.gridConfig.leftNumberAxis.dataFormatter = @"%.2f";
    lineSet.gridConfig.leftNumberAxis.over = 0;
    lineSet.gridConfig.leftNumberAxis.showSplitLine = YES;
    lineSet.gridConfig.leftNumberAxis.showQueryLable = YES;
    lineSet.gridConfig.leftNumberAxis.offSetRatio = GGRatioTopRight;
    lineSet.gridConfig.leftNumberAxis.stringGap = 2;
    
    CGRect rect = CGRectMake(10, 100, [UIScreen mainScreen].bounds.size.width - 20, 250);
    LineChart * lineChart = [[LineChart alloc] initWithFrame:rect];
    lineChart.lineDataSet = lineSet;
    [lineChart drawLineChart];
    [self.view addSubview:lineChart];
}

- (void)showLineBarChart{
    _barData1 = [[BarData alloc] init];
    _barData1.dataAry = @[@1.29, @-1.88, @1.46, @-3.30, @3.66, @3.23, @-3.48, @-3.51];
    _barData1.barWidth = 10;
    _barData1.barFillColor = __RGB_RED;
    
    _barData2 = [[BarData alloc] init];
    _barData2.dataAry = @[@11.29, @11.88, @11.46, @13.30, @13.66, @13.23, @13.48, @13.51];
    _barData2.barWidth = 10;
    _barData2.barFillColor = __RGB_CYAN;
    
    _lineData1 = [[LineData alloc] init];
    _lineData1.lineColor = __RGB_RED;
    _lineData1.scalerMode = ScalerAxisRight;
    _lineData1.shapeRadius = 2;
    _lineData1.dataAry = @[@50.29, @-51.88, @51.46, @-53.30, @53.66, @53.23, @-53.48, @-53.51];
    
//    _lineData1.lineFillColor = [UIColor orangeColor];
//    _lineData1.showShapeIndexSet =[ NSSet setWithObjects:@(10),@(20), nil];
//    _lineData1.gradientFillColors = @[(__bridge id)C_HEX(0xF9EDD9).CGColor, (__bridge id)[UIColor orangeColor].CGColor, (__bridge id)[UIColor orangeColor].CGColor, (__bridge id)[UIColor orangeColor].CGColor, (__bridge id)[UIColor orangeColor].CGColor, (__bridge id)[UIColor orangeColor].CGColor, (__bridge id)[UIColor orangeColor].CGColor];
//    _lineData1.locations = @[@(50),@(40),@(30),@(20),@(10),@(0),@(-10)];
    
    _lineData2 = [[LineData alloc] init];
    _lineData2.lineColor = __RGB_ORIGE;
    _lineData2.scalerMode = ScalerAxisRight;
    _lineData2.shapeRadius = 2;
    _lineData2.dataAry = @[@61.29, @-61.88, @61.46, @-53.30, @53.66, @53.23, @-53.48, @-53.51];
    
    LineBarDataSet * lineBarSet = [[LineBarDataSet alloc] init];
    lineBarSet.insets = UIEdgeInsetsMake(30, 40, 30, 40);
    lineBarSet.lineAry = @[_lineData1];
    lineBarSet.barAry = @[_barData1];
    lineBarSet.updateNeedAnimation = YES;
    
    lineBarSet.gridConfig.lineColor = C_HEX(0xe4e4e4);
    lineBarSet.gridConfig.lineWidth = .5f;
    lineBarSet.gridConfig.axisLineColor = RGB(146, 146, 146);
    lineBarSet.gridConfig.axisLableColor = RGB(146, 146, 146);
    
    lineBarSet.gridConfig.bottomLableAxis.lables = @[@"15Q1", @"15Q2", @"15Q3", @"15Q4", @"16Q1", @"16Q2", @"16Q3", @"16Q4"];
    lineBarSet.gridConfig.bottomLableAxis.drawStringAxisCenter = YES;
    lineBarSet.gridConfig.bottomLableAxis.showSplitLine = YES;
    lineBarSet.gridConfig.bottomLableAxis.over = 2;
    lineBarSet.gridConfig.bottomLableAxis.showQueryLable = YES;
    
    lineBarSet.gridConfig.leftNumberAxis.splitCount = 4;
    lineBarSet.gridConfig.leftNumberAxis.dataFormatter = @"%.0f";
    lineBarSet.gridConfig.leftNumberAxis.showSplitLine = YES;
    lineBarSet.gridConfig.leftNumberAxis.showQueryLable = YES;
    
    lineBarSet.gridConfig.rightNumberAxis.splitCount = 4;
    lineBarSet.gridConfig.rightNumberAxis.dataFormatter = @"%.0f";
    lineBarSet.gridConfig.rightNumberAxis.showQueryLable = YES;
    
//    lineBarSet.midLineWidth = 1;
//    lineBarSet.lineBarMode = LineBarDrawCenter;
    
    _lineBarChart = [[LineBarChart alloc] initWithFrame:CGRectMake(5, 70, [UIScreen mainScreen].bounds.size.width - 10, 200)];
    _lineBarChart.lineBarDataSet = lineBarSet;
    [_lineBarChart drawLineBarChart];
    [_lineBarChart startLineAnimationsWithType:LineAnimationRiseType duration:.8f];
    [_lineBarChart startBarAnimationsWithType:BarAnimationRiseType duration:.8f];
    [self.view addSubview:_lineBarChart];
}
#pragma mark MinuteChart
- (void)present
{
    [self presentViewController:[HorizontalKLineViewController new] animated:YES completion:nil];
}

- (NSString *)stockDataJsonPath
{
    return [[NSBundle mainBundle] pathForResource:@"time_chart_data" ofType:@"json"];
}

- (NSString *)stockFiveDataJsonPath
{
    return [[NSBundle mainBundle] pathForResource:@"600887_five_day" ofType:@"json"];
}

#pragma mark LineChart

- (NSString *)stockWeekDataJsonPath
{
    return [[NSBundle mainBundle] pathForResource:@"week_k_data_60087" ofType:@"json"];
}
- (NSString *)titleDataString:(NSString *)string
{
    if ([string isEqualToString:@"--"]) {
        
        return @"--";
    }
    
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    NSDate * date = [formatter dateFromString:string];
    
    NSDateFormatter * showFormatter = [[NSDateFormatter alloc] init];
    showFormatter.dateFormat = @"yy/MM/dd";
    
    return [showFormatter stringFromDate:date];
}

- (NSString *)stockDataJsonPathLine
{
    return [[NSBundle mainBundle] pathForResource:@"stock_data" ofType:@"json"];
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
