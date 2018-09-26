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
}

@property (nonatomic, strong) BaseIndexLayer * mLineIndexLayer;


@property (nonatomic, assign) CGFloat kLineProportion;  ///< 主图占比 默认 .6f

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
@property (nonatomic, strong) GGLineRenderer * lineRenderer;    ///< 虚线

@property (nonatomic, strong) CrissCrossQueryView * queryPriceView;     ///< 查价层
@property (nonatomic, strong) NSArray * bottomTitleArray;       ///< 底部轴

@end

@implementation ChartTest

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initSubviews];
    [self requestData];
}

- (void)requestData{
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
}

- (void)initSubviews{
    _currentZoom = -.001f;
    _kLineProportion = .6f;
    
    _kLineCountVisibale = 60;
    _kMaxCountVisibale = 120;
    _kMinCountVisibale = 20;
    
    //BaseShapeScaler
    _kInterval = 3;//k线间的距离
    float chartWidth = SCREEN_WIDTH-20;
    float chartHeight = 250;
    
    shapeInterval = _kInterval;//间隔
    shapeWidth = chartWidth / _kLineCountVisibale - _kInterval;//柱状图宽度
    
    //UI
    bgView = [[UIView alloc] init];
    bgView.frame = CGRectMake(10, 100, chartWidth, chartHeight);
    [self.view addSubview:bgView];
    
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
    
    //背景
    [bgView.layer addSublayer:self.backCanvas];
    self.backCanvas.frame = CGRectMake(0, 0, chartWidth, chartHeight);
    //查价层
    self.queryPriceView.frame = CGRectMake(0, 15, chartWidth, chartHeight);
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
}

#pragma mark - 更新视图

- (void)updateChart
{
    if (_kLineArray.count == 0) { return; }
    
    [self.lineScaler setObjAry:_kLineArray getSelector:@selector(ggTimePrice)];

    //渲染器  画布 颜色等属性
//    [self baseConfigRendererAndLayer];
    
    [self subLayerRespond];
//    [self updateMinuteLine];
    
    [self.backCanvas addRenderer:self.lineRenderer];
}

- (void)configLineScaler
{
//    self.lineScaler.max = _KTimeChartMaxPrice;
//    self.lineScaler.min = _KTimeChartMinPrice;
//    self.lineScaler.xMaxCount = self.timeType == TimeDay ? _bottomTitleArray.count * 240 : 240;
    self.lineScaler.xMaxCount = _kLineCountVisibale;

    self.lineScaler.xRatio = 0;
}

- (void)subLayerRespond
{
    [self baseConfigLayer];
    [self configLineScaler];

    [self updateSubLayer];
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

    CGRect volumRect = self.volumFrame;
    [self setVolumRect:volumRect];
    
    self.volumScaler.rect = CGRectMake(0, 0, contentSize.width, self.redVolumLayer.gg_height);
    self.volumScaler.barWidth = shapeWidth;
    
    self.mLineIndexLayer.gg_width = contentSize.width;
    
}

#pragma mark - rect

#define INDEX_STRING_INTERVAL   0//12
#define KLINE_VOLUM_INTERVAL    0//15

- (CGRect)volumFrame
{
    CGFloat highMLine = self.minuteLineFrame.size.height;
    CGFloat volumTop = INDEX_STRING_INTERVAL * 2 + highMLine + KLINE_VOLUM_INTERVAL;
    return CGRectMake(0, volumTop, contentSize.width, bgView.frame.size.height - volumTop);

}

- (CGRect)minuteLineFrame
{
    return CGRectMake(0, INDEX_STRING_INTERVAL, bgView.frame.size.width, bgView.frame.size.height * _kLineProportion - INDEX_STRING_INTERVAL);
}

- (void)setFrame:(CGRect)frame
{
    _scrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    _backScrollView.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
    self.backCanvas.frame = CGRectMake(0, 0, frame.size.width, frame.size.height);
}
//设置成交量层
- (void)setVolumRect:(CGRect)rect{
    self.redVolumLayer.frame = rect;
    self.greenVolumLayer.frame = rect;
}

- (CGRect)lineRect
{
    return CGRectMake(0, 15, self.queryPriceView.frame.size.width,     self.queryPriceView.frame.size.height * _kLineProportion);
}

- (CGRect)volumRect
{
    CGRect lineRect = [self lineRect];
    
    return CGRectMake(0, CGRectGetMaxY(lineRect) + 13,     self.queryPriceView.frame.size.width,self.queryPriceView.frame.size.height - CGRectGetMaxY(lineRect) - 13);
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
}

/** 柱状图实时更新 */
- (void)updateVolumLayerWithRange:(NSRange)range
{
    // 计算柱状图最大最小
    CGFloat max = FLT_MIN;
    CGFloat min = FLT_MAX;
    
    [_kLineArray getMax:&max min:&min selGetter:@selector(ggVolume) range:range base:0.1];
    
    // 更新成交量
    self.volumScaler.min = 0;
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
            if (previousObj.price >= obj.price) {
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
    for (BitTimeModel *model in _kLineArray) {
        [array addObject:@(model.price)];
    }
    [[bgView viewWithTag:100] removeFromSuperview];

    LineData * line = [[LineData alloc] init];
    line.lineWidth = 1;
    line.lineColor = C_HEX(0x177eff);
    line.lineFillColor = [C_HEX(0xf1f8ff) colorWithAlphaComponent:.8f];
    line.dataAry =  [array subarrayWithRange:range];
    line.dataFormatter = @"%.f 分";
    line.gradientFillColors = @[(__bridge id)C_HEX(0xf1f8ff).CGColor, (__bridge id)[UIColor whiteColor].CGColor];
    line.locations = @[@0.7, @1];
    line.shapeLineWidth = 1;
//    line.dashPattern = @[@2, @2];//折线虚线样式

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
    
//    float xLine = 0.0;
//    float width = bgView.gg_width;
//    if (_scrollView.contentOffset.x < 0){
//        xLine = -_scrollView.contentOffset.x;
//    }else if (_scrollView.contentSize.width -_scrollView.contentOffset.x < bgView.gg_width){
//        width = _scrollView.contentSize.width - _scrollView.contentOffset.x;
//    }
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
        
        CGPoint velocity = [recognizer locationInView:self.queryPriceView];
        velocity.y += self.queryPriceView.gg_top;
        self.queryPriceView.hidden = NO;
//        [self.queryPriceView.cirssLayer addRenderer:self.avgCircle];
//        [self.queryPriceView.cirssLayer addRenderer:self.priceCircle];
        [self updateQueryLayerWithPoint:velocity];
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        CGPoint velocity = [recognizer locationInView:self.queryPriceView];
        velocity.y += self.queryPriceView.gg_top;
        [self updateQueryLayerWithPoint:velocity];
    }
}

/** 更新十字星查价框 */
- (void)updateQueryLayerWithPoint:(CGPoint)velocity
{
    CGFloat max = FLT_MIN;
    CGFloat min = FLT_MAX;
    for (NSInteger i = tempRange.location; i<tempRange.location+tempRange.length; i++) {
        BitTimeModel *model = (BitTimeModel *)_kLineArray[i];
        max = model.ggTimePrice>max?model.ggTimePrice:max;
        min = model.ggTimePrice<min?model.ggTimePrice:min;
    }
    
    self.lineScaler.max = max;
    self.lineScaler.min = min;
    self.lineScaler.rect = CGRectMake(0, 0, bgView.gg_width, bgView.gg_height);
    NSMutableArray *array = [NSMutableArray array];
    for (BitTimeModel *model in _kLineArray) {
        [array addObject: @(model.price)];
    }
    self.lineScaler.dataAry = array;
    [self.lineScaler updateScalerWithRange:tempRange];
    
    for (int i = 0; i < tempRange.length; i++) {
        CGPoint point1 = self.lineScaler.linePoints[i];
        NSLog(@"%f==%f",point1.x,point1.y);
    }
    
    NSInteger count = tempRange.length;//self.timeType == TimeDay ? _bottomTitleArray.count * 240 : 240;
    NSInteger index = velocity.x / (bgView.frame.size.width / count);
    index = index >= tempRange.length - 1 ? tempRange.length - 1 : index;

    id <MinuteAbstract, QueryViewAbstract> kData = self.kLineArray[index];
    
    NSString * yString = @"";
    CGRect lineRect = [self lineRect];
    CGRect volumRect = [self volumRect];
    self.queryPriceView.xAxisOffsetY = CGRectGetMaxY(lineRect) - self.queryPriceView.gg_top + 2;
    if (CGRectContainsPoint(lineRect, velocity)) {
        
        yString = [NSString stringWithFormat:@"%.2f", [self.lineScaler getPriceWithYPixel:velocity.y]];
    }
    else if (CGRectContainsPoint(volumRect, velocity)) {
        
//        yString = [NSString stringWithFormat:@"%.2f手", [self.barScaler getPriceWithYPixel:velocity.y]];
    }

    
    NSString * title = [self getDateString:kData.ggTimeDate];
    [self.queryPriceView setYString:yString setXString:title];
    [self.queryPriceView.queryView setQueryData:kData];
    
//
//    NSString * yString = @"";
//
//    CGRect lineRect = [self lineRect];
//    CGRect volumRect = [self volumRect];
//
//    self.queryPriceView.xAxisOffsetY = CGRectGetMaxY(lineRect) - self.queryPriceView.gg_top + 2;
//
//    if (CGRectContainsPoint(lineRect, velocity)) {
//
//        yString = [NSString stringWithFormat:@"%.2f", [self.lineScaler getPriceWithYPixel:velocity.y]];
//    }
//    else if (CGRectContainsPoint(volumRect, velocity)) {
//
//        yString = [NSString stringWithFormat:@"%.2f手", [self.barScaler getPriceWithYPixel:velocity.y]];
//    }
//
//    NSString * format = self.timeType == TimeDay ? @"yyyy:MM:dd HH:mm" : @"HH:mm";
//    [self.queryPriceView setYString:yString setXString:[[self.objTimeAry[index] ggTimeDate] stringWithFormat:format]];
//    [self.queryPriceView.queryView setQueryData:kData];
//
    CGPoint point = self.lineScaler.linePoints[index];
//    CGPoint avgPoint = self.averageScaler.linePoints[index];
//    self.avgCircle.circle = GGCirclePointMake(CGPointMake(avgPoint.x, avgPoint.y - self.queryPriceView.gg_top), 2);
//    self.priceCircle.circle = GGCirclePointMake(CGPointMake(point.x, point.y - self.queryPriceView.gg_top), 2);
//    self.avgCircle.fillColor = [UIColor redColor];//self.avgColor;
//    self.priceCircle.fillColor = self.lineColor;
    NSLog(@"========%f=%f==%f",point.x,point.y,self.queryPriceView.gg_top);
    [self.queryPriceView setCenterPoint:CGPointMake(point.x-bgView.gg_width*(tempRange.location/_kLineCountVisibale), velocity.y - self.queryPriceView.gg_top)];
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
