//
//  ZKMinuteView.h
//  ZKChart
//
//  Created by 李永华 on 2018/12/3.
//  Copyright © 2018 mac. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BaseModel.h"
#import "MinuteAbstract.h"
#import "VolumeAbstract.h"
#import "QueryViewAbstract.h"

@interface BitTimeModel : BaseModel <MinuteAbstract, VolumeAbstract, QueryViewAbstract>

@property (nonatomic , assign) NSInteger volume;
@property (nonatomic , assign) CGFloat price_change;
@property (nonatomic , assign) CGFloat price;
@property (nonatomic , assign) CGFloat price_change_rate;
@property (nonatomic , assign) CGFloat turnover;
@property (nonatomic , copy) NSString * date;
@property (nonatomic , assign) NSInteger total_volume;
@property (nonatomic , assign) CGFloat avg_price;
@property (nonatomic , strong) NSDate * ggDate;

@property (nonatomic , strong) NSNumber *transactionAmount;
@property (nonatomic , strong) NSNumber *marketValue;
@property (nonatomic , strong) NSNumber *priceUsd;
@property (nonatomic , assign) NSTimeInterval myTimestamp;

@end

NS_ASSUME_NONNULL_BEGIN

@interface ZKMinuteView : UIView

@property (nonatomic, readonly) UIScrollView * scrollView;  ///< 滚动视图
@property (nonatomic, strong, readonly) UIScrollView * backScrollView;  ///< 背景滚动

@property (nonatomic, strong) CAShapeLayer * redVolumLayer;   ///< 红色成交量layer层
@property (nonatomic, strong) CAShapeLayer * greenVolumLayer;     ///< 绿色成交量layer层

@property (nonatomic, strong) DBarScaler * volumScaler;   ///< 成交量定标器
@property (nonatomic, strong) DLineScaler * lineScaler;     ///< 分时线定标器

@property (nonatomic, strong, readonly) GGCanvas * stringLayer;
@property (nonatomic, strong) UIColor * axisStringColor;      ///< 文字颜色
@property (nonatomic, strong) UIFont * axisFont;        ///< 轴字体

@end

NS_ASSUME_NONNULL_END
