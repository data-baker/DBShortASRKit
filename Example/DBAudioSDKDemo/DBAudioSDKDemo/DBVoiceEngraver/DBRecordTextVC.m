//
//  DBRecordTextVC.m
//  DBVoiceEngraverDemo
//
//  Created by linxi on 2020/3/4.
//  Copyright © 2020 biaobei. All rights reserved.
//

#import "DBRecordTextVC.h"
#import "DBVoiceEngraverManager.h"
#import "UIViewController+DBBackButtonHandler.h"
#import "UIView+Toast.h"
#import "XCHudHelper.h"
#import "DBRecordCompleteVC.h"


#ifndef KUserDefalut
#define KUserDefalut [NSUserDefaults standardUserDefaults]
#endif

static NSString * KRecordSessionID = @"KRecordSessionId"; // 录制过程中生成的SessionId


@interface DBRecordTextVC ()<UITextViewDelegate,DBVoiceDetectionDelegate>
@property (weak, nonatomic) IBOutlet UILabel *phaseTitleLabel;
@property (weak, nonatomic) IBOutlet UITextView *recordTextView;
@property (weak, nonatomic) IBOutlet UIButton *startRecordButton;
/// 下一条
@property (weak, nonatomic) IBOutlet UIButton *nextRecordButton;
/// 上一条
@property (weak, nonatomic) IBOutlet UIButton *lastRecordButton;
@property(nonatomic,strong)DBVoiceEngraverManager * voiceEngraverManager;
@property (weak, nonatomic) IBOutlet UIView *titileBackGroundView;
@property (weak, nonatomic) IBOutlet UILabel *phaseLabel;
@property (weak, nonatomic) IBOutlet UILabel *allPhaseLabel;
@property (weak, nonatomic) IBOutlet UIImageView *voiceImageView;
@property (weak, nonatomic) IBOutlet UIButton *listenButton;
@property(nonatomic,assign) CFAbsoluteTime startTime;

/// 表示当前录制的是第几条
@property (nonatomic, assign) int index;

@end

@implementation DBRecordTextVC


- (void)viewDidLoad {
    
    [super viewDidLoad];
    self.index = 0;
    self.view.backgroundColor = [UIColor whiteColor];
    self.voiceEngraverManager =  [DBVoiceEngraverManager sharedInstance];
    self.voiceEngraverManager.delegate= self;
    [self addBoardOfTitleBackgroundView:self.titileBackGroundView cornerRadius:50];
    DBTextModel *textModel = self.textArray.firstObject;
    

    
//    [self p_setTextViewAttributeText:model.];
    self.allPhaseLabel.text = [NSString stringWithFormat:@"共%@段",@(self.textArray.count)];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    if([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    }
}


- (IBAction)startRecordAction:(id)sender {
    UIButton *button = (UIButton *)sender;
    button.selected = !button.isSelected;
    if (button.isSelected) {
        NSString *sessionId =  [KUserDefalut objectForKey:KRecordSessionID];
        self.startTime = CFAbsoluteTimeGetCurrent();
        [self.voiceEngraverManager startRecordWithSessionId:sessionId TextIndex:self.index  messageHandler:^(NSString *sessionId) {
            [KUserDefalut setObject:sessionId forKey:KRecordSessionID]; // 保存当前的SessionId
            [self beginRecordState];
        } failureHander:^(NSError * _Nonnull error) {
            NSLog(@"error %@",error);
            // 发生错误停止录音
            [self.view makeToast:error.description duration:2 position:CSToastPositionCenter];
            [self.voiceEngraverManager pauseRecord];
            [self endRecordState];
        }];
    }else {
        [self endRecordState];
        [self uploadRecoginizeVoice];
    }
}

- (IBAction)nextRecordAction:(id)sender {
    [self nextItemAction];
}

- (void)nextItemAction {
    if (![self.voiceEngraverManager canNextStepByCurrentIndex:self.index]) {
        [self.view makeToast:@"请录制完当前条目再点击下一步" duration:2.f position:CSToastPositionCenter];
        return;
    }
    self.index++;
    BOOL ret = [self updateTextPhaseWithIndex:self.index];
    if (!ret) {
        self.index--;
    }
}

- (IBAction)lastRecordAction:(id)sender {
    self.index--;
    BOOL ret = [self updateTextPhaseWithIndex:self.index];
    if (!ret) {
        self.index++;
    }
}
/// 试听
- (IBAction)lisenAction:(id)sender {
    [self.voiceEngraverManager listenAudioWithTextIndex:self.index];
}


// MARK： 恢复录制
- (void)recoverReprintWithSessionId:(NSString *)sessionId {
    [self.voiceEngraverManager getTextArrayWithSeesionId:sessionId textHandler:^(NSString * _Nonnull sessionId, NSArray<DBTextModel *> * _Nonnull array) {

    } failure:^(NSError * _Nonnull error) {
        NSLog(@"error:%@",error.description);
    }];
}

- (void)showContinueReprint {
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示" message:@"检测到您有复刻录制正在进行中，是否继续?" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *resume = [UIAlertAction actionWithTitle:@"继续" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertVC addAction:resume];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [alertVC addAction:cancelAction];
    [self presentViewController:alertVC animated:YES completion:nil];
    
}


- (void)uploadRecoginizeVoice {
    [self showHUD];
    [self.voiceEngraverManager uploadRecordVoiceRecogizeHandler:^(DBVoiceRecognizeModel * _Nonnull model) {
        [self hiddenHUD];
        if ([model.passStatus.stringValue isEqualToString:@"1"]) {
            [self.view makeToast:[NSString stringWithFormat:@"太棒了：准确率：%@%%，请录制下一段吧。",model.percent] duration:2 position:CSToastPositionCenter];
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self nextItemAction];
//            });
        }else {
            [self.view makeToast:[NSString stringWithFormat:@"准确率：%@%%，请重新录制文本",model.percent] duration:2 position:CSToastPositionCenter];
        }
    }];

}

- (BOOL)updateTextPhaseWithIndex:(NSInteger)phaseIndex {
    if (phaseIndex<0) {
        NSLog(@"第一段");
        return NO;
    }
    
    if (phaseIndex >= self.textArray.count) {
        NSLog(@"最后一段");
        UIStoryboard *story = [UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]];
        DBRecordCompleteVC *completedVC  = [story instantiateViewControllerWithIdentifier:@"DBRecordCompleteVC"];
        [self.navigationController pushViewController:completedVC animated:YES];
        return NO;
    }
    
    if (phaseIndex == 0) {
        NSLog(@"第一段");
        self.lastRecordButton.hidden = YES;
    }else {
        self.lastRecordButton.hidden = NO;
    }
    
    [self p_setTextViewAttributeText:self.textArray[phaseIndex]];
    self.phaseLabel.text =  [NSString stringWithFormat:@"第%@段",@(self.index+1)];
    self.allPhaseLabel.text = [NSString stringWithFormat:@"共%@段",@(self.textArray.count)];
    [self.voiceEngraverManager stopCurrentListen];
    return YES;
}


- (void)beginRecordState {
    self.voiceImageView.hidden =  NO;
    self.lastRecordButton.hidden = YES;
    self.nextRecordButton.hidden = YES;
    self.startRecordButton.hidden = NO;
    self.listenButton.hidden = YES;
}

- (void)endRecordState {
    if (self.index >0) {
        self.lastRecordButton.hidden = NO;
    }else {
        self.lastRecordButton.hidden = YES;
    }
    self.voiceImageView.hidden = YES;
    self.nextRecordButton.hidden = NO;
    self.startRecordButton.hidden = NO;
    self.listenButton.hidden = NO;
}

// MARK: delegate Methods -

- (void)onErrorCode:(NSInteger)errorCode errorMsg:(NSString *)errorMsg {
    NSLog(@"error Code %@ ,errorMessage: %@",@(errorCode),errorMsg);
}
- (void)dbDetecting:(NSInteger)volumeDB {
    static NSInteger index = 0;
    index++;
    if (index == 1) {
        index = 0;
    }else {
        return;
    }
    if (volumeDB < 30) {
        self.voiceImageView.image = [UIImage imageNamed:@"1"];
    }else if (volumeDB < 40) {
        self.voiceImageView.image = [UIImage imageNamed:@"2"];
    }else if (volumeDB < 50) {
        self.voiceImageView.image = [UIImage imageNamed:@"3"];
    }else if (volumeDB < 55) {
        self.voiceImageView.image = [UIImage imageNamed:@"4"];
    }else if (volumeDB < 60) {
        self.voiceImageView.image = [UIImage imageNamed:@"5"];
    }else if (volumeDB < 70) {
        self.voiceImageView.image = [UIImage imageNamed:@"6"];
    }else if (volumeDB < 80) {
        self.voiceImageView.image = [UIImage imageNamed:@"7"];
    }else{
        self.voiceImageView.image = [UIImage imageNamed:@"8"];
    }
    self.startTime = CFAbsoluteTimeGetCurrent();
}

- (void)dbAudioInterrupted {
    NSLog(@"[debug]: 当前的录制音频被打断");
}

- (void)dbVoiceRecognizeError:(NSError *)error {
    [self endRecordState];
    [self.view makeToast:error.description duration:2.f position:CSToastPositionCenter];
}

- (void)playToEnd {
    self.listenButton.selected = NO;
    NSLog(@"播放完成了");
}

// MARK: private Method
- (void)p_setTextViewAttributeText:(NSString *)text {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    paragraphStyle.lineSpacing = 10;// 字体的行间距
    NSDictionary *attributes = @{
        NSFontAttributeName:[UIFont systemFontOfSize:18],
        NSParagraphStyleAttributeName:paragraphStyle
    };
    self.recordTextView.attributedText = [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

// MARK: 通过拦截方法获取返回事件
- (BOOL)navigationShouldPopOnBackButton
{
    NSLog(@"clicked navigationbar back button");
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"提示" message:@"返回了当前录制结果将会保存，再次进入可以恢复使用？" preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
       }];
    [alertVC addAction:cancelAction];

    UIAlertAction *doneAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [self.navigationController popToRootViewControllerAnimated:YES];
//        [self.voiceEngraverManager unNormalStopRecordSeesionSuccessHandler:^(NSString * _Nonnull message) {
//            [self.navigationController popToRootViewControllerAnimated:YES];
//        } failureHandler:^(NSError * _Nonnull error) {
//            [self.view makeToast:@"退出session失败" duration:2 position:CSToastPositionCenter];
//            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//                [self.navigationController popToRootViewControllerAnimated:YES];
//            });
//        }];
    }];
    [alertVC addAction:doneAction];
    [self presentViewController:alertVC animated:YES completion:nil];
    return NO;

}
// MARK: UITextViewDelegate Methods -

- (void)addBoardOfTitleBackgroundView:(UIView *)view  cornerRadius:(CGFloat)cornerRadius {
    view.layer.cornerRadius = cornerRadius;
    [self addBorderOfView:view];
}


// MARK: Pricate Methods -

- (BOOL)_isEmpty:(NSString *)str {
    return str.length == 0 || str == nil;
}

- (void)showHUD {
    [[XCHudHelper sharedInstance]showHudOnView:self.view caption:@"上传识别中" image:nil
                                     acitivity:YES autoHideTime:30];
}

- (void)hiddenHUD {
    [[XCHudHelper sharedInstance]hideHud];
}
- (void)addBorderOfView:(UIView *)view {
    view.layer.borderColor = [UIColor systemBlueColor].CGColor;
    view.layer.borderWidth = 1.f;
    view.layer.masksToBounds =  YES;
}

- (DBVoiceEngraverManager *)voiceEngraverManager {
    if (!_voiceEngraverManager) {
        _voiceEngraverManager = [DBVoiceEngraverManager sharedInstance];
    }
    return _voiceEngraverManager;
}


@end
