//
//  ChartTest.m
//  ZKChart
//
//  Created by mac on 2018/8/5.
//  Copyright © 2018年 mac. All rights reserved.
//

#import "ChartTest.h"
#import "KLineData.h"

#import "BaseIndexLayer.h"
#import "NSObject+FireBlock.h"

#import "LineCanvas.h"
#import "LineDataSet.h"
#import "LineData.h"
#import "GridBackCanvas.h"
#import "LineChart.h"
#import "CrissCrossQueryView.h"
#import "NSDate+GGDate.h"

#include <objc/runtime.h>

typedef enum : NSUInteger {
    TimeMiddle,
    TimeHalfAnHour,
    TimeDay,
} TimeChartType;

#define INDEX_STRING_INTERVAL   0//12 分时线上下
#define KLINE_VOLUM_INTERVAL    0//15 柱状图上

/*
 1天
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=1d
 1周
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=7d
 1月
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=1m
 3月
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=3m
 1年
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=1y
 今年
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=ytd
 所有
 https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=all
 */


@implementation BitTimeModel

- (NSDate *)ggDate{
    return _ggDate;
}

-(CGFloat)ggTransactionAmount{
    return [_transactionAmount floatValue];
}

- (CGFloat)ggTimePriceUsd
{
    return [_priceUsd floatValue];
}

- (CGFloat)ggTimeAveragePrice
{
    return _avg_price;
}

- (CGFloat)ggTimePrice
{
    return _price;
}

- (CGFloat)ggTimeClosePrice
{
    return _price / (1 + _price_change_rate / 100);
}

- (NSDate *)ggTimeDate
{
    return _ggDate;
}

- (CGFloat)ggVolume
{
    return _volume;
}

- (NSDate *)ggVolumeDate
{
    return _ggDate;
}

/**
 * 查询Value颜色
 *
 * @{@"key" : [UIColor redColor]}
 */
- (NSDictionary *)queryKeyForColor
{
    return @{@"价格" : [UIColor blackColor],
             @"均价" : [UIColor blackColor],
             @"成交量" : [UIColor blackColor]};
}

/**
 * 查询Key颜色
 *
 * @{@"key" : [UIColor redColor]}
 */
- (NSDictionary *)queryValueForColor
{
    return @{[NSString stringWithFormat:@"%.2f", _price] : [UIColor blackColor],
             [NSString stringWithFormat:@"%.2f", _avg_price] : [UIColor blackColor],
             [NSString stringWithFormat:@"%zd手", _volume] : [UIColor blackColor]};
}

/**
 * 键值对
 *
 * @[@{@"key" : @"value"},
 *   @{@"key" : @"value"},
 *   @{@"key" : @"value"}]
 */
- (NSArray <NSDictionary *> *)valueForKeyArray
{
    return @[@{@"价格" : [NSString stringWithFormat:@"%.2f", _price]},
             @{@"均价" : [NSString stringWithFormat:@"%.2f", _avg_price]},
             @{@"成交量" : [NSString stringWithFormat:@"%zd手", _volume]}];
}

@end

@interface ChartTest ()<UIScrollViewDelegate>{
    UIView *bgView;
    
    //BaseShapeScaler
    CGFloat shapeWidth;
    CGFloat shapeInterval;
    CGSize contentSize;
    
    NSRange tempRange;
    
//    float upSpace;
//    float middleSpace;
//    float downSpace;
}
@property (nonatomic, assign) TimeChartType timeType;

@property (nonatomic, strong) BaseIndexLayer * mLineIndexLayer;


@property (nonatomic, assign) CGFloat kLineProportion;  ///< 主图占比 默认 .73f

@property (nonatomic, readonly) NSArray <id <MinuteAbstract, VolumeAbstract, QueryViewAbstract> > * kLineArray;    ///< k线数组
@property (nonatomic, assign) CGFloat kInterval;    ///< k线之间的间隔

@property (nonatomic, assign) NSInteger kLineCountVisibale;     ///< 一屏幕显示多少根k线     默认60
@property (nonatomic, assign) NSInteger kMaxCountVisibale;      ///< 屏幕最多显示多少k线     默认120
@property (nonatomic, assign) NSInteger kMinCountVisibale;      ///< 屏幕最少显示多少k线     默认20

//手势相关
@property (nonatomic, assign) BOOL isLoadingMore;       ///< 是否在刷新状态
@property (nonatomic, assign) BOOL isWaitPulling;       ///< 是否正在等待刷新

#pragma mark - 缩放手势
@property (nonatomic, assign) CGFloat currentZoom;  ///< 当前缩放比例
@property (nonatomic, assign) CGFloat zoomCenterSpacingLeft;    ///< 缩放中心K线位置距离左边的距离
@property (nonatomic, assign) NSUInteger zoomCenterIndex;     ///< 中心点k线

@property (nonatomic, strong) GGCanvas * backCanvas;        ///< 背景层
@property (nonatomic, strong) GGLineRenderer * lineRenderer;    ///< 虚线 最新价格线

@property (nonatomic, strong) CrissCrossQueryView * queryPriceView;     ///< 查价层
@property (nonatomic, strong) NSArray * bottomTitleArray;       ///< 底部轴
@property (nonatomic, strong) GGAxisRenderer * bottomRenderer;  ///< 底部轴
@property (nonatomic, assign) NSUInteger dirAxisSplitCount;     ///< 单向轴分割数

@end

@implementation ChartTest

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initSubviews];
    [self requestData];
}

- (void)requestData{
    /*
     //数据
     NSData *dataStock = [NSData dataWithContentsOfFile:[self stockWeekDataJsonPath]];
     NSArray *stockJson = [NSJSONSerialization JSONObjectWithData:dataStock options:0 error:nil];
     NSArray <MinuteAbstract, VolumeAbstract> * timeAry = (NSArray <MinuteAbstract, VolumeAbstract> *) [BaseModel arrayForArray:stockJson class:[BitTimeModel class]];
     [timeAry enumerateObjectsUsingBlock:^(BitTimeModel * obj, NSUInteger idx, BOOL * _Nonnull stop) {
     obj.ggDate = [NSDate dateWithString:obj.date format:@"yyyy-MM-dd HH:mm:ss"];
     }];
     _kLineArray = timeAry;
     
     //定标器
     self.volumScaler = [[DBarScaler alloc] init];
     [self.volumScaler setObjAry:_kLineArray
     getSelector:@selector(ggVolume)];
     self.volumScaler.rect = CGRectMake(0, 0, self.redVolumLayer.gg_width, self.redVolumLayer.gg_height);
     self.volumScaler.barWidth = shapeWidth;//lyh 最窄1?
     
     [self updateChart];
     
     */

    NSMutableArray *array = [NSMutableArray array];
    AFHTTPSessionManager *sessionManager = [AFHTTPSessionManager manager];
    [sessionManager GET:@"https://fastmarket.niuyan.com/api/v4/app/coin/chart?coin_id=bitcoin&lan=zh-cn&type=1d" parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
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
        _kLineArray = array;
        
        //定标器
        self.volumScaler = [[DBarScaler alloc] init];
        [self.volumScaler setObjAry:_kLineArray
                        getSelector:@selector(ggTransactionAmount)];
        self.volumScaler.rect = CGRectMake(0, 0, self.redVolumLayer.gg_width, self.redVolumLayer.gg_height);
        self.volumScaler.barWidth = shapeWidth;//成交额模型宽度
        
        [self updateChart];
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
    }];
}

- (void)initSubviews{
    _currentZoom = -.001f;
    _kLineProportion = .73f;
    float chartWidth = SCREEN_WIDTH;
    float chartHeight = 250;
    _dirAxisSplitCount = 2;
    
//    upSpace = 15;
//    middleSpace = 15;
//    downSpace = 15;

    _kInterval = 3;//模型间距
    shapeInterval = _kInterval;//间隔
    shapeWidth = 2;//模型“默认”宽度
    
    _kMinCountVisibale = 12;
    _kMaxCountVisibale = chartWidth/(shapeWidth + _kInterval);
    _kLineCountVisibale = _kMaxCountVisibale;

    /*
     _kLineCountVisibale = 60;
     _kMaxCountVisibale = 120;
     _kMinCountVisibale = 20;
     
     //BaseShapeScaler
     _kInterval = 3;//k线间的距离
     shapeInterval = _kInterval;//间隔
     shapeWidth = chartWidth / _kLineCountVisibale - _kInterval;//柱状图宽度
     */
    
    //UI
    bgView = [[UIView alloc] init];
    bgView.frame = CGRectMake(0, 100, chartWidth, chartHeight);
    [self.view addSubview:bgView];
    //lyh debug
    bgView.backgroundColor = [UIColor lightGrayColor];
    
    _backScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, chartWidth, chartHeight)];
    _backScrollView.showsHorizontalScrollIndicator = NO;
    _backScrollView.showsVerticalScrollIndicator = NO;
    _backScrollView.userInteractionEnabled = NO;
    [bgView addSubview:_backScrollView];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0,chartWidth, chartHeight)];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.delegate = self;
    [_scrollView.layer addSublayer:self.redVolumLayer];
    [_scrollView.layer addSublayer:self.greenVolumLayer];
    [bgView addSubview:_scrollView];

    //计算scrollview的contentsize
    contentSize = CGSizeMake((shapeInterval + shapeWidth) * _kLineArray.count, chartHeight);
    self.scrollView.contentSize = contentSize;
    self.backScrollView.contentSize = contentSize;
    
    //网格背景
    [bgView.layer addSublayer:self.backCanvas];
    self.backCanvas.frame = CGRectMake(0, 0, chartWidth, chartHeight);
    [self.backCanvas addRenderer:self.lineRenderer];
    
//    [self.backScrollView.layer addSublayer:self.backCanvas];
//    [self.backCanvas addRenderer:self.bottomRenderer];

    //查价层
    self.queryPriceView.frame = CGRectMake(0, 0, chartWidth, chartHeight);
    [bgView addSubview:self.queryPriceView];
    
    //手势
    UIPinchGestureRecognizer * pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchesViewOnGesturer:)];
    [bgView addGestureRecognizer:pinchGestureRecognizer];
    
    UILongPressGestureRecognizer * longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressViewOnGesturer:)];
    [bgView addGestureRecognizer:longPress];
    
    //配置
    self.redVolumLayer.strokeColor = [UIColor redColor].CGColor;
    self.redVolumLayer.fillColor = [UIColor redColor].CGColor;
    self.greenVolumLayer.strokeColor = C_HEXA(0x3ebb3f,1.0).CGColor;
    self.greenVolumLayer.fillColor = C_HEXA(0x3ebb3f,1.0).CGColor;
    
    //确定redVolumLayer 和 greenVolumLayer的frame
    [self setVolumRect:CGRectMake(0, chartHeight*_kLineProportion, contentSize.width, chartHeight*(1-_kLineProportion))];//确定 redVolumLayer greenVolumLayer 的frame
    
    //bgView上的view 从下到上
//    bgView.backgroundColor = [UIColor redColor];
    //_backScrollView.backgroundColor = [UIColor blueColor];//背景滚动
    //_scrollView.backgroundColor = [UIColor purpleColor];
//    _stringLayer.backgroundColor = [UIColor cyanColor].CGColor;
//    _queryPriceView.backgroundColor = [UIColor greenColor];
    
    //scrollView上字view  lineChart
    //scrollView addSubview:lineChart   bgView.gg_height*_kLineProportion

    //网格背景层
    // _backScrollView.layer addSublayer:self.backCanvas];
    
    //_scrollView的layer上   从下到上
//    self.redVolumLayer.backgroundColor = [UIColor brownColor].CGColor;
//    self.greenVolumLayer.backgroundColor = [UIColor grayColor].CGColor;
}

#pragma mark - 更新视图

- (void)updateChart
{
    if (_kLineArray.count == 0) { return; }
    
    //渲染器  画布 颜色等属性
//    [self baseConfigRendererAndLayer];
    
    [self subLayerRespond];
//    [self updateMinuteLine];
    
}

- (void)subLayerRespond
{
    [self baseConfigLayer];
    [self configLineScaler];

    [self updateSubLayer];
}

- (void)configLineScaler{
//    self.lineScaler.max = _KTimeChartMaxPrice;
//    self.lineScaler.min = _KTimeChartMinPrice;
//    self.lineScaler.xMaxCount = _kLineCountVisibale;
//    self.lineScaler.xRatio = 0;
}

//- (void)updateMinuteLine{
//    runMainThreadWithBlock(^{
//        [_mLineIndexLayer removeFromSuperlayer];
//        _mLineIndexLayer = [[BaseIndexLayer alloc] init];
//        _mLineIndexLayer.frame = CGRectMake(0, 0, contentSize.width, bgView.gg_height*_kLineProportion);
//        [_mLineIndexLayer setKLineArray:_kLineArray];
//        _mLineIndexLayer.currentKLineWidth = shapeWidth;
//        [self.scrollView.layer addSublayer:_mLineIndexLayer];
//
//        [self updateSubLayer];
//    });
//}

- (void)baseConfigLayer{
    shapeWidth = bgView.gg_width / _kLineCountVisibale - _kInterval;
    shapeInterval = _kInterval;

    contentSize = CGSizeMake((shapeWidth+shapeInterval)*_kLineArray.count,  self.redVolumLayer.gg_height);
    contentSize.width = contentSize.width < bgView.gg_width ? bgView.gg_width : contentSize.width;
   
    self.scrollView.contentSize = contentSize;
    self.backScrollView.contentSize = contentSize;
    
    //成交量/额frame
    CGRect volumRect = self.volumRect;
    [self setVolumRect:volumRect];
    
    //成交额定标器
    self.volumScaler.rect = CGRectMake(0, 0, contentSize.width, self.redVolumLayer.gg_height);
    self.volumScaler.barWidth = shapeWidth;
    
    self.mLineIndexLayer.gg_width = contentSize.width;
    
    self.bottomRenderer.strFont = [UIFont systemFontOfSize:18];
    self.bottomRenderer.strColor = [UIColor redColor];
    self.bottomRenderer.offSetRatio = self.timeType == TimeDay ? GGRatioBottomCenter : GGRatioBottomRight;
    self.bottomRenderer.isStringFirstLastindent = YES;
    
}

#pragma mark - rect

- (CGRect)lineRect
{
    return CGRectMake(0, INDEX_STRING_INTERVAL, bgView.frame.size.width, bgView.frame.size.height * _kLineProportion - INDEX_STRING_INTERVAL);
}

//成交额frame
- (CGRect)volumRect{
    CGFloat highMLine = self.lineRect.size.height;
    CGFloat volumTop = INDEX_STRING_INTERVAL * 2 + highMLine + KLINE_VOLUM_INTERVAL;
    return CGRectMake(0, volumTop, contentSize.width, bgView.frame.size.height - volumTop);
}

//lyh没用
- (void)setFrame:(CGRect)frame
{
    _scrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    _backScrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
}

//设置成交量层/成交额层
- (void)setVolumRect:(CGRect)rect{
    self.redVolumLayer.frame = rect;
    self.greenVolumLayer.frame = rect;
}


#pragma mark -------------------

/**
 * 成交量视图是否为红色
 *
 * @parm obj volumScaler.lineObjAry[idx]
 */

- (BOOL)volumIsRed:(id)obj
{
    return [self isRed:obj];
}

/** k线是否为红 */
- (BOOL)isRed:(id <KLineAbstract>)kLineObj
{
    return kLineObj.ggOpen > kLineObj.ggClose;
}

- (NSString *)stockWeekDataJsonPath{
    //600887_five_day  week_k_data_60087
    return [[NSBundle mainBundle] pathForResource:@"600887_five_day" ofType:@"json"];
}

#pragma mark - 实时更新

- (void)updateSubLayer
{
    // 计算显示的在屏幕中的k线
    NSInteger index = round(self.scrollView.contentOffset.x / (0+ shapeWidth+shapeInterval));
    NSInteger len = _kLineCountVisibale;
    if (index < 0) index = 0;
    if (index > _kLineArray.count) index = _kLineArray.count;
    if (index + _kLineCountVisibale > _kLineArray.count) { len = _kLineArray.count - index; }

    NSRange range = NSMakeRange(index, len);
    tempRange = range;
    
    // 更新视图
    [self updateMinuteLayerWithRange:range];
    [self updateVolumLayerWithRange:range];
    
    [self updateAxisStringPrice];
    [self updateRenderers];

}

- (void)updateAxisStringPrice
{
//    self.leftRenderer.aryString = [NSArray splitWithMax:_KTimeChartMaxPrice min:_KTimeChartMinPrice split:_dirAxisSplitCount * 2 format:@"%.2f" attached:@""];
//    self.rightRenderer.aryString = [self.leftRenderer.aryString percentageStringWithBase:[self.objTimeAry.firstObject ggTimeClosePrice]];
    
//    NSMutableArray *arr = [NSMutableArray array];
//    for (int i = 0; i<1000; i++) {
//        [arr addObject:[NSString stringWithFormat:@"%d",i]];
//    }
//    static int k = 0;
//    k++;
//    NSArray *subArr = [arr subarrayWithRange:NSMakeRange(k, 5)];//数组越界  这里代码重新梳理
//    self.bottomRenderer.aryString = subArr;//_bottomTitleArray;
//    self.bottomRenderer.drawAxisCenter = self.timeType == TimeDay;
    
//    CGFloat barMax;
//    CGFloat barMin;
//    [_objTimeAry getMax:&barMax min:&barMin selGetter:@selector(ggVolume) base:0];
//    self.volumRenderer.aryString = [NSArray splitWithMax:barMax min:0 split:2 format:@"%.f" attached:@"手"];
}

- (void)updateRenderers
{
    CGFloat bottomSplit = self.timeType == TimeDay ? self.bottomRenderer.aryString.count : (self.bottomRenderer.aryString.count - 1);
    
    CGRect lineRect = [self lineRect];
//    CGFloat ySplit = lineRect.size.height / (_dirAxisSplitCount * 2);
    CGFloat split = bottomSplit > 0 ? bgView.frame.size.width / bottomSplit : bgView.frame.size.width;
    
//    self.leftRenderer.axis = GGAxisLineMake(GGLeftLineRect(lineRect), 0, ySplit);
//    self.rightRenderer.axis = GGAxisLineMake(GGRightLineRect(lineRect), 0, ySplit);
    self.bottomRenderer.axis = GGAxisLineMake(GGBottomLineRect(lineRect), 1, split);
//    self.gridRenderer.grid = GGGridRectMake(lineRect, ySplit, split);
    
//    CGRect volumRect = [self volumRect];
//    CGFloat yVolumSplit = volumRect.size.height / 2;
//    self.volumRenderer.axis = GGAxisLineMake(GGLeftLineRect(volumRect), 0, yVolumSplit);
//    self.volumGridRenderer.grid = GGGridRectMake(volumRect, yVolumSplit, split);
}


/** 柱状图实时更新 */
- (void)updateVolumLayerWithRange:(NSRange)range
{
    // 计算柱状图最大最小
    CGFloat max = FLT_MIN;
    CGFloat min = FLT_MAX;
    
    [_kLineArray getMax:&max min:&min selGetter:@selector(ggTransactionAmount) range:range base:0.1];
    
    // 更新成交量
    self.volumScaler.min = min;
    self.volumScaler.max = max;
    [self.volumScaler updateScalerWithRange:range];//定标器 确定部分参数
    [self updateVolumLayer:range];//用贝塞尔曲线绘图
}

/**
 * 局部更新成交量
 *
 * range 成交量更新k线的区域, CGRangeMAx(range) <= volumScaler.lineObjAry.count
 */
- (void)updateVolumLayer:(NSRange)range{
    CGMutablePathRef refRed = CGPathCreateMutable();
    CGMutablePathRef refGreen = CGPathCreateMutable();
    
    for (NSInteger i = range.location; i < NSMaxRange(range); i++) {
        CGRect shape = self.volumScaler.barRects[i];
        BitTimeModel * obj = (BitTimeModel *)self.volumScaler.lineObjAry[i];
        if (i == 0) {
            GGPathAddCGRect(refGreen, shape);
        }else{
            BitTimeModel *previousObj = (BitTimeModel *)self.volumScaler.lineObjAry[i-1];
            if ([previousObj.priceUsd floatValue] >= [obj.priceUsd floatValue ]) {
                //绿跌红涨
                GGPathAddCGRect(refGreen, shape);
            }else{
                GGPathAddCGRect(refRed, shape);
            }
        }
//        [self volumIsRed:obj] ? GGPathAddCGRect(refRed, shape) : GGPathAddCGRect(refGreen, shape);
    }
    
    self.redVolumLayer.path = refRed;
    CGPathRelease(refRed);
    
    self.greenVolumLayer.path = refGreen;
    CGPathRelease(refGreen);
}

- (void)updateMinuteLayerWithRange:(NSRange)range{
    //--------------------- 方案一
    //lyh 会崩 改 mLineIndexLayer.sublayers = nil
//    for (CAShapeLayer *layer in _mLineIndexLayer.sublayers) {
//        [layer removeFromSuperlayer];
//    }
//    _mLineIndexLayer.sublayers = nil;
//    // 计算最大最小
//    CGFloat max = FLT_MIN;
//    CGFloat min = FLT_MAX;
//    //    [_kLineIndexLayer getIndexWithRange:range max:&max min:&min];
//    for (NSInteger i = range.location; i<range.location+range.length; i++) {
//        BitTimeModel *model = (BitTimeModel *)_kLineArray[i];
//        max = model.ggTimePrice>max?model.ggTimePrice:max;
//        min = model.ggTimePrice<min?model.ggTimePrice:min;
//    }
//    [_mLineIndexLayer updateLayerWithRange:range max:max min:min];
//
//    DLineScaler * lineScaler = [[DLineScaler alloc] init];
//    lineScaler.max = max;
//    lineScaler.min = min;
//    lineScaler.rect = CGRectMake(0, 0, _mLineIndexLayer.gg_width, _mLineIndexLayer.gg_height);
//    NSMutableArray *array = [NSMutableArray array];
//    for (BitTimeModel *model in _kLineArray) {
//        [array addObject: @(model.price)];
//    }
//    lineScaler.dataAry = array;
//    [lineScaler updateScalerWithRange:range];
//
//    CAShapeLayer * layer = [CAShapeLayer layer];
//    layer.fillColor = [UIColor clearColor].CGColor;
//    layer.strokeColor = [C_HEX(0x177eff) CGColor];
//    layer.lineWidth = 1;
//    layer.frame = CGRectMake(0, 0, _mLineIndexLayer.gg_width, _mLineIndexLayer.gg_height);
//    [_mLineIndexLayer addSublayer:layer];
//
//    CGMutablePathRef ref = CGPathCreateMutable();
//    GGPathAddRangePoints(ref, lineScaler.linePoints, range);
//    layer.path = ref;
//    CGPathRelease(ref);
//
//    //填充
//    CAShapeLayer * fillLayer = [CAShapeLayer layer];
//    fillLayer.fillColor = [C_HEX(0xf1f8ff) colorWithAlphaComponent:1.0f].CGColor;
//    fillLayer.lineWidth = 1;
//    fillLayer.frame = CGRectMake(0, 0, _mLineIndexLayer.gg_width, _mLineIndexLayer.gg_height);
//    [_mLineIndexLayer addSublayer:fillLayer];
//
//    CGMutablePathRef refFill = CGPathCreateMutable();
//    GGPathAddRangePoints(refFill, lineScaler.linePoints, range);
//    CGPathAddLineToPoint(refFill, NULL, lineScaler.linePoints[range.location+range.length - 1].x, CGRectGetMaxY(fillLayer.frame));
//    CGPathAddLineToPoint(refFill, NULL, 0, CGRectGetMaxY(fillLayer.frame));
//    CGPathAddLineToPoint(refFill, NULL, 0, lineScaler.linePoints[range.location].y);
//    fillLayer.path = refFill;
//    CGPathRelease(refFill);
    
    //--------------------- 方案二
    NSMutableArray *array = [NSMutableArray array];
    for (NSUInteger i = range.location; i <range.location+range.length; i++) {
        BitTimeModel *model = _kLineArray[i];
        [array addObject:model.priceUsd];
    }
    [[bgView viewWithTag:100] removeFromSuperview];
    LineData * line = [[LineData alloc] init];
    line.lineWidth = 1;
    line.lineColor = C_HEX(0x177eff);
    line.lineFillColor = [C_HEX(0xf1f8ff) colorWithAlphaComponent:.8f];
    line.dataAry =  array;
    line.dataFormatter = @"%.f 分";
    line.gradientFillColors = @[(__bridge id)C_HEX(0xf1f8ff).CGColor, (__bridge id)[UIColor whiteColor].CGColor];
    line.locations = @[@0.7, @1];
    line.shapeLineWidth = 1;
//    line.dashPattern = @[@2, @2];//折线虚线样式
    self.lineScaler = line.lineBarScaler;
    
    LineDataSet * lineSet = [[LineDataSet alloc] init];
    lineSet.lineAry = @[line];
    
    float x = 0.0;
    if (_scrollView.contentOffset.x < 0){
        x = 0.0;
    }else if (_scrollView.contentSize.width -_scrollView.contentOffset.x < bgView.gg_width){
        x = _scrollView.contentSize.width - bgView.gg_width;
    }else{
        x = _scrollView.contentOffset.x;
    }
    LineChart * lineChart = [[LineChart alloc] initWithFrame:CGRectMake(x, 0, bgView.gg_width, bgView.gg_height*_kLineProportion)];
    lineChart.tag = 100;
    lineChart.lineDataSet = lineSet;
    [lineChart drawLineChart];
    [self.scrollView addSubview:lineChart];
    //lyh debug
    lineChart.backgroundColor = [UIColor redColor];

    //最新价格线
    CGFloat max = FLT_MIN;
    CGFloat min = FLT_MAX;
    int minIndex = 0;
    int maxIndex = 0;
    for (int i = 0; i<line.dataAry.count; i++) {
        double price = [line.dataAry[i] floatValue];
        if (price>max) {
            max = price;
            maxIndex = i;
        }
        if (price<min) {
            min = price;
            minIndex = i;
        }
    }
    
    CGPoint point0 = line.lineBarScaler.linePoints[minIndex];
    double price0 = [line.dataAry[minIndex] doubleValue];
    CGPoint point1 = line.lineBarScaler.linePoints[maxIndex];
    double price1 = [line.dataAry[maxIndex] doubleValue];

    double ratio = (point1.y-point0.y)/(price0-price1);
    double priceLast = [[array lastObject] doubleValue];

    double y = (price0-priceLast)*ratio+point0.y;
    if (y < 0) {
        y = 0;
    }else if (y>lineChart.gg_height){
        y = lineChart.gg_height;
    }
    self.lineRenderer.width = 2.f;
    self.lineRenderer.color = C_HEX(0x86beff);
    self.lineRenderer.dashPattern = @[@3, @3];
    
    self.lineRenderer.line = GGLineMake(0, y, bgView.gg_width, y);
    [self.backCanvas setNeedsDisplay];
}

#pragma mark - 手势
/** 长按十字星 */
- (void)longPressViewOnGesturer:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        self.queryPriceView.hidden = YES;
    }
    else if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint velocity = [recognizer locationInView:bgView];
        velocity.y += self.queryPriceView.gg_top;
        self.queryPriceView.hidden = NO;
        [self updateQueryLayerWithPoint:velocity];
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint velocity = [recognizer locationInView:bgView];
        [self updateQueryLayerWithPoint:velocity];
    }
}

/** 更新十字星查价框 */
- (void)updateQueryLayerWithPoint:(CGPoint)velocity
{
    //计算显示区最大、最小值
    CGFloat max = FLT_MIN;
    CGFloat min = FLT_MAX;
    for (NSInteger i = tempRange.location; i<tempRange.location+tempRange.length; i++) {
        BitTimeModel *model = (BitTimeModel *)_kLineArray[i];
        max = model.ggTimePriceUsd>max?model.ggTimePriceUsd:max;
        min = model.ggTimePriceUsd<min?model.ggTimePriceUsd:min;
    }

    //计算触摸点对应的数据----index为触摸点在折线关键点次序
    CGPoint velocityInScroll = [self.scrollView convertPoint:velocity fromView:self.queryPriceView];
    NSInteger index = [self pointConvertIndex:velocityInScroll.x];
    id <MinuteAbstract, QueryViewAbstract> kData = self.kLineArray[index];
    
    //显示折线图和柱状图坐标信息
    CGRect lineRect = [self lineRect];
    CGRect volumRect = [self volumRect];
    //查价层x轴纵向位置
    self.queryPriceView.xAxisOffsetY =self.queryPriceView.gg_bottom-15;
    NSString * yString = @"";
    CGPoint centerPoint;
    if (CGRectContainsPoint(lineRect, velocity)) {
        //该折线图内边距为(20,5,20,5)见BaseLineBarData中初始化方法
        CGRect realLineRect = lineRect;
        realLineRect.origin.y += 20;
        realLineRect.size.height -= 40;
        if (CGRectContainsPoint(realLineRect, velocity)) {
            yString = [NSString stringWithFormat:@"%.2f", [self.lineScaler getPriceWithYPixel:velocity.y]];
        }
        //计算centerPoint
        NSInteger count = tempRange.length;
        NSInteger lineIndex = velocity.x / (bgView.frame.size.width / count);
        lineIndex = lineIndex >= tempRange.length - 1 ? tempRange.length - 1 : lineIndex;
        centerPoint = self.lineScaler.linePoints[lineIndex];
        [self.queryPriceView setCenterPoint:CGPointMake(centerPoint.x, velocity.y - self.queryPriceView.gg_top)];
    }else if (CGRectContainsPoint(volumRect, velocity)) {
        yString = [NSString stringWithFormat:@"%.2f", [self.volumScaler getPriceWithPoint:CGPointMake(0, velocity.y - self.redVolumLayer.gg_top)]];
        [self.queryPriceView setCenterPoint:velocity];
    }
    NSString * title = [self getDateString:kData.ggTimeDate];
    //显示横坐标和纵坐标的值
    [self.queryPriceView setYString:yString setXString:title];
    //显示横坐标对应的信息
    [self.queryPriceView.queryView setQueryData:kData];
}


/** 日期转字符串 */
- (NSString *)getDateString:(NSDate *)date
{
    NSDateFormatter * showFormatter = [[NSDateFormatter alloc] init];
    showFormatter.dateFormat = @"yyyy-MM-dd";
    return [showFormatter stringFromDate:date];
}


/** 放大手势 */
-(void)pinchesViewOnGesturer:(UIPinchGestureRecognizer *)recognizer
{
    self.scrollView.scrollEnabled = NO;     // 放大禁用滚动手势
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        _currentZoom = recognizer.scale;
        
        self.scrollView.scrollEnabled = YES;
    }
    else if (recognizer.state == UIGestureRecognizerStateBegan && _currentZoom != 0.0f) {
        
        recognizer.scale = _currentZoom;

        CGPoint touch1 = [recognizer locationOfTouch:0 inView:bgView];
        CGPoint touch2 = [recognizer locationOfTouch:1 inView:bgView];
        
        // 放大开始记录位置等数据
        CGFloat center_x = (touch1.x + touch2.x) / 2.0f;
        _zoomCenterIndex = [self pointConvertIndex:self.scrollView.contentOffset.x + center_x];
        _zoomCenterSpacingLeft = _zoomCenterIndex*(shapeWidth+shapeInterval) - self.scrollView.contentOffset.x;

    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        CGFloat tmpZoom;
        tmpZoom = recognizer.scale / _currentZoom;
        _currentZoom = recognizer.scale;
        NSInteger showNum = round(_kLineCountVisibale / tmpZoom);

        // 避免没必要计算
        if (showNum == _kLineCountVisibale) { return; }
        if (showNum >= _kLineCountVisibale && _kLineCountVisibale == _kMaxCountVisibale) return;
        if (showNum <= _kLineCountVisibale && _kLineCountVisibale == _kMinCountVisibale) return;
        
        // 极大值极小值
        _kLineCountVisibale = showNum;
        _kLineCountVisibale = _kLineCountVisibale < _kMinCountVisibale ? _kMinCountVisibale : _kLineCountVisibale;
        _kLineCountVisibale = _kLineCountVisibale > _kMaxCountVisibale ? _kMaxCountVisibale : _kLineCountVisibale;
        
        [self subLayerRespond];
        
        // 定位中间的k线
        CGFloat shape_x = (_zoomCenterIndex + .5) * shapeInterval + (_zoomCenterIndex + .5) * shapeWidth;
        CGFloat offsetX = shape_x - _zoomCenterSpacingLeft;
        
        if (offsetX < 0) { offsetX = 0; }
        if (offsetX > self.scrollView.contentSize.width - self.scrollView.frame.size.width) {
            offsetX = self.scrollView.contentSize.width - self.scrollView.frame.size.width;
        }
        self.scrollView.contentOffset = CGPointMake(offsetX, 0);
    }
}

/** 获取点对应的数据 */
- (NSInteger)pointConvertIndex:(CGFloat)x
{
    NSInteger idx = x / (shapeWidth + shapeInterval);
    return idx >= _kLineArray.count ? _kLineArray.count - 1 : idx;

}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self scrollViewContentSizeDidChange];
    
    if (scrollView.contentOffset.x < -40) {
        
        if (!self.isLoadingMore) {

            self.isWaitPulling = YES;
        }
    }
    
    if (self.isWaitPulling &&
        scrollView.contentOffset.x == 0) {

        self.isLoadingMore = YES;
        self.isWaitPulling = NO;
        //横屏用到
//        if (self.RefreshBlock) {
//            self.RefreshBlock();
//        }
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
//    CGFloat minMove = self.kLineScaler.shapeWidth + self.kLineScaler.shapeInterval;
//    self.scrollView.contentOffset = CGPointMake(round(self.scrollView.contentOffset.x / minMove) * minMove, 0);
    [self scrollViewContentSizeDidChange];
}

/**
 * 视图滚动
 */
- (void)scrollViewContentSizeDidChange
{
    
    CGPoint contentOffset = self.scrollView.contentOffset;
    
    if (_scrollView.contentOffset.x < 0) {
        
        contentOffset = CGPointMake(0, 0);
    }
    
    if (_scrollView.contentOffset.x + _scrollView.frame.size.width > _scrollView.contentSize.width) {
        
        contentOffset = CGPointMake(_scrollView.contentSize.width - _scrollView.frame.size.width, 0);
    }
    
    [self.backScrollView setContentOffset:contentOffset];
    
    [self updateSubLayer];
    
}

/** 结束刷新状态 */
- (void)endLoadingState
{
    self.isLoadingMore = NO;
}

#pragma mark - Lazy

GGLazyGetMethod(CAShapeLayer, redVolumLayer);
GGLazyGetMethod(CAShapeLayer, greenVolumLayer);

GGLazyGetMethod(DBarScaler, volumScaler);
GGLazyGetMethod(DLineScaler, lineScaler);

GGLazyGetMethod(GGLineRenderer, lineRenderer);
GGLazyGetMethod(GGAxisRenderer, bottomRenderer);

GGLazyGetMethod(GGCanvas, backCanvas);

GGLazyGetMethod(CrissCrossQueryView, queryPriceView);

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
