//
//  ZKMinuteView.m
//  ZKChart
//
//  Created by 李永华 on 2018/12/3.
//  Copyright © 2018 mac. All rights reserved.
//

#import "ZKMinuteView.h"
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

#define FONT_ARIAL    @"ArialMT"
#define SECOND                                  (1)
#define MINUTE                                  (60)
#define HOUR                                    (60 * 60)
#define DAY                                     (24 * 60 * 60)
#define WEEK                                    (7 * 24 * 60 * 60)

#define INDEX_STRING_INTERVAL   15 //价格、成交量指标高度
#define KLINE_VOLUM_INTERVAL    17 //时间轴高度

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

@interface ZKMinuteView ()<UIScrollViewDelegate>{
    float chartWidth;
    float chartHeight;
    
    CGFloat shapeWidth;
    CGFloat shapeInterval;
    CGSize contentSize;
    
    NSRange tempRange;
    NSMutableArray *curLineArray;
    
    NSInteger lineIndex;
    float lineX;
    float lineWidth;
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
@property (nonatomic, assign) NSUInteger dirAxisSplitCount;     ///< 单向轴分割数

@property (nonatomic, strong) GGAxisRenderer * axisRenderer;        ///< 轴渲染
@property (nonatomic, strong) GGAxisRenderer * kAxisRenderer;       ///< 分时线轴
@property (nonatomic, strong) GGAxisRenderer * vAxisRenderer;       ///< 成交量轴

@end


@implementation ZKMinuteView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    // Drawing code
}
*/

-(instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        chartWidth = frame.size.width;
        chartHeight = frame.size.height;
        _currentZoom = -.001f;
        _kLineProportion = .65f;
        _dirAxisSplitCount = 2;
        
        _kInterval = 3;//模型间距
        shapeInterval = _kInterval;//间距
        shapeWidth = 2;//模型“默认”宽度
        
        _mAxisSplit = 3;

        _axisStringColor = C_HEX(0xaeb1b6);
        //lyh debug
//        _axisStringColor = [UIColor orangeColor];
        _axisFont = [UIFont fontWithName:FONT_ARIAL size:10];

        _kMinCountVisibale = 12;
        _kMaxCountVisibale = chartWidth/(shapeWidth + _kInterval);
        _kLineCountVisibale = _kMaxCountVisibale;
        
        curLineArray = [NSMutableArray array];
        
        [self initSubviews];
        [self requestData];
        
    }
    return self;
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
        _kLineArray = array;
        [self updateKLineTitles:array];
        
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

static void * kLineTitle = "keyTitle";

- (void)updateKLineTitles:(NSArray<id<MinuteAbstract, VolumeAbstract, QueryViewAbstract>> *)kLineArray{
//    if (_kStyle == KLineTypeDay) {
//
//    }else if (_kStyle == KLineTypeWeek) {
//
//    }else if (_kStyle == KLineTypeMonth) {
//
//    }
    __block NSInteger flag = 0;
    [kLineArray enumerateObjectsUsingBlock:^(id <MinuteAbstract, VolumeAbstract, QueryViewAbstract> obj, NSUInteger idx, BOOL * stop) {
        NSString * title = nil;
        if (flag != obj.ggTimeDate.day) {
            title = [obj.ggTimeDate stringWithFormat:@"dd"];
            flag = obj.ggTimeDate.day;
        }
        
        if (title.integerValue == 1) {
            title = [obj.ggTimeDate stringWithFormat:@"MM/dd"];
        }
        objc_setAssociatedObject(obj, kLineTitle, title, OBJC_ASSOCIATION_COPY);
    }];
}

- (void)initSubviews{
    
    //lyh debug
//    self.backgroundColor = [UIColor lightGrayColor];
    
    _backScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, chartWidth, chartHeight)];
    _backScrollView.showsHorizontalScrollIndicator = NO;
    _backScrollView.showsVerticalScrollIndicator = NO;
    _backScrollView.userInteractionEnabled = NO;
    [self addSubview:_backScrollView];
    
    _scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0,chartWidth, chartHeight)];
    _scrollView.showsHorizontalScrollIndicator = NO;
    _scrollView.showsVerticalScrollIndicator = NO;
    _scrollView.delegate = self;
    [_scrollView.layer addSublayer:self.redVolumLayer];
    [_scrollView.layer addSublayer:self.greenVolumLayer];
    [self addSubview:_scrollView];
    
    //计算scrollview的contentsize
    contentSize = CGSizeMake((shapeInterval + shapeWidth) * _kLineArray.count, chartHeight);
    self.scrollView.contentSize = contentSize;
    self.backScrollView.contentSize = contentSize;
    
    _stringLayer = [[GGCanvas alloc] init];
    _stringLayer.frame = CGRectMake(0, 0, chartWidth, chartHeight);
    [self.layer addSublayer:_stringLayer];
    self.axisRenderer.width = 0.25;
    [self.stringLayer addRenderer:self.axisRenderer];
    self.kAxisRenderer.width = 0.25;
    [self.stringLayer addRenderer:self.kAxisRenderer];
    self.vAxisRenderer.width = 0.25;
    [self.stringLayer addRenderer:self.vAxisRenderer];
    
    //网格背景
    [self.layer addSublayer:self.backCanvas];
    self.backCanvas.frame = CGRectMake(0, 0, chartWidth, chartHeight);
    [self.backCanvas addRenderer:self.lineRenderer];
    
    //查价层
    self.queryPriceView.frame = CGRectMake(0, 0, chartWidth, chartHeight);
    self.queryPriceView.queryView.hidden = YES;
    [self addSubview:self.queryPriceView];
    
    //手势
    UIPinchGestureRecognizer * pinchGestureRecognizer = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchesViewOnGesturer:)];
    [self addGestureRecognizer:pinchGestureRecognizer];
    
    UILongPressGestureRecognizer * longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPressViewOnGesturer:)];
    [self addGestureRecognizer:longPress];
    
    //配置
    self.redVolumLayer.strokeColor = [UIColor redColor].CGColor;
    self.redVolumLayer.fillColor = [UIColor redColor].CGColor;
    self.greenVolumLayer.strokeColor = C_HEXA(0x3ebb3f,1.0).CGColor;
    self.greenVolumLayer.fillColor = C_HEXA(0x3ebb3f,1.0).CGColor;
    
    //确定redVolumLayer 和 greenVolumLayer的frame
    [self setVolumRect:self.volumRect];//确定 redVolumLayer greenVolumLayer 的frame

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
    [self updateSubLayer];
}

- (void)baseConfigLayer{
    shapeWidth = self.gg_width / _kLineCountVisibale - _kInterval;
    shapeInterval = _kInterval;
    
    contentSize = CGSizeMake((shapeWidth+shapeInterval)*_kLineArray.count,self.gg_height);
    contentSize.width = contentSize.width < self.gg_width ? self.gg_width : contentSize.width;
    
    self.scrollView.contentSize = contentSize;
    self.backScrollView.contentSize = contentSize;
    
    //成交量/额frame
    CGRect volumRect = self.volumRect;
    [self setVolumRect:volumRect];
    
    //成交额定标器
    self.volumScaler.rect = CGRectMake(0, 0, contentSize.width, self.redVolumLayer.gg_height);
    self.volumScaler.barWidth = shapeWidth;
    
    self.mLineIndexLayer.gg_width = contentSize.width;
    
    // X横轴设置
    self.axisRenderer.strColor = _axisStringColor;
    self.axisRenderer.showLine = NO;
    self.axisRenderer.strFont = _axisFont;
    // 分时线线Y轴设置
    self.kAxisRenderer.strColor = _axisStringColor;
    self.kAxisRenderer.showLine = NO;
    self.kAxisRenderer.strFont = _axisFont;
    self.kAxisRenderer.offSetRatio = GGRatioTopRight;
    // 成交量Y轴设置
    self.vAxisRenderer.strColor = _axisStringColor;
    self.vAxisRenderer.showLine = NO;
    self.vAxisRenderer.strFont = _axisFont;
    self.vAxisRenderer.offSetRatio = GGRatioTopRight;
    //Y轴值
    __weak ZKMinuteView * weakSelf = self;
    [self.kAxisRenderer setStringBlock:^NSString *(CGPoint point, NSInteger index, NSInteger max) {
//        if (index == 0) { return @""; }
        point.y = point.y - self.lineRect.origin.y;
        return [NSString stringWithFormat:@"%.2f", [weakSelf.lineScaler getPriceWithPoint:point]];
    }];
    [self.vAxisRenderer setStringBlock:^NSString *(CGPoint point, NSInteger index, NSInteger max) {
//        if (index == 0) { return @""; }
        point.y = point.y - weakSelf.redVolumLayer.gg_top;
        NSString *priceStr = [NSString stringWithFormat:@"%f",[weakSelf.volumScaler getPriceWithYPixel:point.y]];
        return [NSString stringWithFormat:@"%@",priceStr];
    }];
}

#pragma mark - rect

- (CGRect)lineRect
{
    return CGRectMake(0, INDEX_STRING_INTERVAL, self.frame.size.width, self.frame.size.height * _kLineProportion - INDEX_STRING_INTERVAL);
}

//成交额frame
- (CGRect)volumRect{
    CGFloat highMLine = self.lineRect.size.height;
    CGFloat volumTop = INDEX_STRING_INTERVAL * 2 + highMLine;
    return CGRectMake(0, volumTop, contentSize.width, self.frame.size.height - volumTop - KLINE_VOLUM_INTERVAL);
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
    // 计算显示的在屏幕中数据的起始点、及个数
    NSInteger index = round(self.scrollView.contentOffset.x / (shapeWidth+shapeInterval));
    NSInteger len = _kLineCountVisibale;
    if (index < 0) index = 0;
    if (index > _kLineArray.count) index = _kLineArray.count;
    if (index + _kLineCountVisibale > _kLineArray.count) { len = _kLineArray.count - index; }
    
    NSRange range = NSMakeRange(index, len);
    tempRange = range;
    
    //即将显示数据
    [curLineArray removeAllObjects];
    for (NSUInteger i = range.location; i <range.location+range.length; i++) {
        BitTimeModel *model = _kLineArray[i];
        [curLineArray addObject:model.priceUsd];
    }
    
    BOOL isRefreshLine = YES;
    //isRefreshLine 主要是解决分时线和底部x轴卡顿现象
    if (![self viewWithTag:100]) {
        //第一次绘制
        isRefreshLine = YES;
        lineX = (shapeWidth+shapeInterval)/2.0;
        lineWidth = _scrollView.frame.size.width-(shapeWidth+shapeInterval);
    }else if (lineIndex == range.location){
        isRefreshLine = NO;
    }else{
        BOOL isLeftSlide = YES;
        float startAdjust;
        if (range.location > lineIndex){
            //向左滑
            isLeftSlide = YES;
            startAdjust = shapeWidth+shapeInterval;
        }else{
            //向右滑
            isLeftSlide = NO;
            startAdjust = 0;
        }
        lineIndex = range.location;

        if (_scrollView.contentOffset.x < 0){
            //滑倒最左侧继续右滑
            lineX = (shapeWidth+shapeInterval)/2.0;
            lineWidth = _scrollView.frame.size.width-(shapeWidth+shapeInterval);
        }else if (_scrollView.contentSize.width -_scrollView.contentOffset.x < _scrollView.gg_width){
            //滑倒最右侧继续左滑
            lineX = _scrollView.contentOffset.x+startAdjust;
            if (isLeftSlide) {
                lineWidth = _scrollView.contentSize.width - lineX-(shapeWidth+shapeInterval)/2.0;
            }else{
                lineWidth = _scrollView.contentSize.width - lineX-(shapeWidth+shapeInterval)/2.0;
            }
        }else{
            lineX = _scrollView.contentOffset.x+startAdjust;
            lineWidth = _scrollView.frame.size.width-(shapeWidth+shapeInterval);
        }
    }
    
    if (isRefreshLine) {
        // 更新视图
        [self updateMinuteLayerWithRange:range];
    }
    [self updateVolumLayerWithRange:range];
    [self updateGridBackLayerWithRange:range];
}

- (void)updateMinuteLayerWithRange:(NSRange)range{
    [[self viewWithTag:100] removeFromSuperview];
    LineData * line = [[LineData alloc] init];
    line.lineWidth = 1;
    line.lineColor = C_HEX(0x177eff);
    line.lineFillColor = [C_HEX(0xf1f8ff) colorWithAlphaComponent:.8f];
    line.dataAry =  curLineArray;
    line.dataFormatter = @"%.f 分";
    line.gradientFillColors = @[(__bridge id)C_HEX(0xf1f8ff).CGColor, (__bridge id)C_HEX(0xf1f8ff).CGColor];
    line.locations = @[@0.7, @1];
    line.shapeLineWidth = 1;
    //    line.dashPattern = @[@2, @2];//折线虚线样式
    self.lineScaler = line.lineBarScaler;
    
    LineDataSet * lineSet = [[LineDataSet alloc] init];
    lineSet.lineAry = @[line];
    //默认该折线图内边距为(20,5,20,5)见BaseLineBarSet中初始化方法
    lineSet.insets = UIEdgeInsetsZero;
    
    LineChart * lineChart = [[LineChart alloc] initWithFrame:CGRectMake(lineX, self.lineRect.origin.y, lineWidth, self.lineRect.size.height)];
    lineChart.tag = 100;
    lineChart.lineDataSet = lineSet;
    [lineChart drawLineChart];
    [self.scrollView addSubview:lineChart];
    //lyh debug
//    lineChart.backgroundColor = [UIColor blackColor];
    
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
    double priceLast = [[curLineArray lastObject] doubleValue];
    
    double y = (price0-priceLast)*ratio+point0.y;
    if (y < 0) {
        y = 0;
    }else if (y>lineChart.gg_height){
        y = lineChart.gg_height;
    }
    self.lineRenderer.width = 2.f;
    self.lineRenderer.color = C_HEX(0x86beff);
    self.lineRenderer.dashPattern = @[@3, @3];
    
    self.lineRenderer.line = GGLineMake(0, y, self.gg_width, y);
    [self.backCanvas setNeedsDisplay];
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
    }
    
    self.redVolumLayer.path = refRed;
    CGPathRelease(refRed);
    
    self.greenVolumLayer.path = refGreen;
    CGPathRelease(refGreen);
}

- (void)updateGridBackLayerWithRange:(NSRange)range{
    NSInteger maxCount = NSMaxRange(range);
    // X横轴设置
    [self.axisRenderer removeAllPointString];
    for (NSInteger i = range.location; i < maxCount; i++) {
        NSString * title = objc_getAssociatedObject(_kLineArray[i], kLineTitle);
        if (title.length) {
            CGPoint point = self.volumScaler.linePoints[i];
            [self.axisRenderer addString:title point:CGPointMake(point.x- self.scrollView.contentOffset.x, chartHeight-KLINE_VOLUM_INTERVAL)];
        }
    }
    
    // 分时线Y轴设置
    CGRect rect = self.lineRect;
    //坐标轴本身有高度，Y轴起始坐标a高于0十多像素，最高坐标也相应高出一点，这里做调整
    rect.origin.y += 10;
    rect.size.height -= 10;
    GGLine leftLine = GGLeftLineRect(rect);
    self.kAxisRenderer.axis = GGAxisLineMake(leftLine, 0, GGLengthLine(leftLine) / _mAxisSplit);
    // 成交量Y轴设置
    CGRect vRect = self.redVolumLayer.frame;
    //坐标轴本身有高度，Y轴起始坐标a高于0十多像素，最高坐标也相应高出一点，这里做调整
    vRect.origin.y += 10;
    vRect.size.height -= 10;
    CGFloat v_spe = vRect.size.height;
    leftLine = GGLeftLineRect(vRect);
    self.vAxisRenderer.axis = GGAxisLineMake(leftLine, 0, v_spe);
    [self.stringLayer setNeedsDisplay];
}

#pragma mark - 手势
/** 长按十字星 */
- (void)longPressViewOnGesturer:(UILongPressGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        self.queryPriceView.hidden = YES;
    }
    else if (recognizer.state == UIGestureRecognizerStateBegan) {
        
        CGPoint velocity = [recognizer locationInView:self];
        velocity.y += self.queryPriceView.gg_top;
        self.queryPriceView.hidden = NO;
        [self updateQueryLayerWithPoint:velocity];
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint velocity = [recognizer locationInView:self];
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
    self.queryPriceView.xAxisOffsetY =self.queryPriceView.gg_bottom-KLINE_VOLUM_INTERVAL;
    NSString * yString = @"";
    CGPoint centerPoint;
    if (CGRectContainsPoint(lineRect, velocity)) {
        yString = [NSString stringWithFormat:@"%.2f", [self.lineScaler getPriceWithYPixel:velocity.y-self.lineRect.origin.y]];
        //计算centerPoint
        NSInteger count = tempRange.length;
        NSInteger lineIndex = velocity.x / (self.frame.size.width / count);
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
        
        CGPoint touch1 = [recognizer locationOfTouch:0 inView:self];
        CGPoint touch2 = [recognizer locationOfTouch:1 inView:self];
        
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
GGLazyGetMethod(GGAxisRenderer, axisRenderer);
GGLazyGetMethod(GGAxisRenderer, kAxisRenderer);
GGLazyGetMethod(GGAxisRenderer, vAxisRenderer);

GGLazyGetMethod(GGCanvas, backCanvas);

GGLazyGetMethod(CrissCrossQueryView, queryPriceView);


@end
