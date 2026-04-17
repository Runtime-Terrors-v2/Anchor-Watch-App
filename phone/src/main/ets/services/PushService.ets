import { pushService } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { wantAgent, common, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PushService';

export class PushService {

  private static instance: PushService;
  private pushToken: string = '';

  static getInstance(): PushService {
    if (!PushService.instance) {
      PushService.instance = new PushService();
    }
    return PushService.instance;
  }

  async requestNotificationPermission(context: common.UIAbilityContext): Promise<void> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await notificationManager.requestEnableNotification(context);
        hilog.info(0x0000, TAG, 'Notification permission granted');
      }
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, 'Permission error: %{public}s', error.message);
    }
  }

  async getPushToken(): Promise<string> {
    try {
      const token = await pushService.getToken();
      this.pushToken = token;
      AppStorage.setOrCreate('pushToken', token);
      hilog.info(0x0000, TAG, 'Push token obtained');
      return token;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG,
        'getToken failed: code=%{public}d msg=%{public}s',
        error.code, error.message);
      return '';
    }
  }

  getStoredToken(): string {
    return this.pushToken || (AppStorage.get<string>('pushToken') ?? '');
  }

  async publishAlertNotification(
    watchOwnerName: string,
    watchName: string,
    context: common.UIAbilityContext
  ): Promise<void> {
    try {
      const want: Want = {
        bundleName:  'com.example.anchor',
        abilityName: 'EntryAbility',
        parameters:  { page: 'pages/AlertHistoryPage' }
      };

      const wantAgentInfoParam: wantAgent.WantAgentInfo = {
        wants:       [want],
        actionType:  wantAgent.OperationType.START_ABILITY,
        requestCode: 100,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };

      const agent = await wantAgent.getWantAgent(wantAgentInfoParam);

      const notificationRequest: notificationManager.NotificationRequest = {
        id: Date.now() % 100000,
        content: {
          notificationContentType:
          notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title:          'Watch Disconnected',
            text:           `${watchOwnerName}'s ${watchName} has gone offline`,
            additionalText: 'Tap to view alert details'
          }
        },
        wantAgent:    agent,
        deliveryTime: Date.now(),
        tapDismissed: true
      };

      await notificationManager.publish(notificationRequest);
      hilog.info(0x0000, TAG, 'Alert notification published');

    } catch (err) {
      hilog.error(0x0000, TAG,
        'publishNotification failed: %{public}s', JSON.stringify(err));
    }
  }
}
