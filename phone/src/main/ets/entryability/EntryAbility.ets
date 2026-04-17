import { UIAbility, AbilityConstant, Want, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { initialize } from '@hw-agconnect/hmcore';
import { util } from '@kit.ArkTS';
import { WatchMonitorService } from '../services/WatchMonitorService';
import { PushService } from '../services/PushService';
import { CloudSyncService } from '../services/CloudSyncService';
import { SmsService, AlertContact } from '../services/SmsService';
import { UserSession } from '../services/UserSession';
import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/function-ohos';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    agconnect.instance().init(this.context);
    hilog.info(0x0000, TAG, 'onCreate called');
    try {
      const rawFile    = await this.context.resourceManager.getRawFileContent('agconnect-services.json');
      const jsonString = new util.TextDecoder('utf-8').decodeToString(rawFile);
      initialize(this.context, JSON.parse(jsonString));
      hilog.info(0x0000, TAG, 'AGConnect initialized');
    } catch (err) {
      const error = err as Error;
      hilog.error(0x0000, TAG, 'AGConnect init failed: %{public}s', error.message);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const isLoggedIn = AppStorage.get<boolean>('isLoggedIn') ?? false;
    const startPage  = isLoggedIn ? 'pages/HomePage' : 'pages/LoginPage';

    windowStage.loadContent(startPage, async (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'loadContent failed: %{public}s', JSON.stringify(err));
        return;
      }

      const push = PushService.getInstance();
      await push.requestNotificationPermission(this.context as common.UIAbilityContext);
      const token = await push.getPushToken();

      if (isLoggedIn && token) {
        await CloudSyncService.getInstance().savePushToken(token);
      }

      const monitor = WatchMonitorService.getInstance();
      monitor.init(this.context as common.UIAbilityContext);
      monitor.setCallbacks(
        (deviceName: string) => {
          hilog.info(0x0000, TAG, 'CONNECTED: %{public}s', deviceName);
          AppStorage.setOrCreate('watchConnected', true);
          AppStorage.setOrCreate('watchName', deviceName);
        },
        (deviceName: string) => {
          hilog.warn(0x0000, TAG, 'DISCONNECTED: %{public}s', deviceName);
          AppStorage.setOrCreate('watchConnected', false);
          AppStorage.setOrCreate('watchName', deviceName);

          const stored: AlertContact[] = AppStorage.get<AlertContact[]>('contacts') ?? [];
          const contacts: AlertContact[] = stored.map((c: AlertContact) => {
            const contact: AlertContact = {
              name:        c.name,
              pushToken:   c.pushToken,
              phoneNumber: c.phoneNumber
            };
            return contact;
          });

          const ownerName: string = UserSession.getOpenID();
          SmsService.getInstance()
            .sendDisconnectAlert(deviceName, ownerName, contacts)
            .catch((e: Error) => {
              hilog.error(0x0000, TAG, 'Alert error: %{public}s', e.message);
            });
        }
      );
      monitor.startMonitoring();
    });
  }

  onDestroy(): void {
    WatchMonitorService.getInstance().stopMonitoring();
  }
}
