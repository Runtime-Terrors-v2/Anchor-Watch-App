import { PushExtensionAbility } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';
import { wantAgent, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'PushAbility';

interface AlertPayload {
  type:      string;
  ownerName: string;
  watchName: string;
}

export default class PushAbility extends PushExtensionAbility {

  async onReceiveMessage(want: Want): Promise<void> {
    hilog.info(0x0000, TAG, 'Push message received');

    try {
      const parameters  = want.parameters as Record<string, string> ?? {};
      const rawData     = parameters['data'] ?? '{}';
      const payload     = JSON.parse(rawData) as AlertPayload;

      const watchOwnerName = payload.ownerName ?? 'Someone';
      const watchName      = payload.watchName  ?? 'their watch';
      const alertType      = payload.type       ?? 'disconnect';

      if (alertType === 'disconnect') {

        const agentWant: Want = {
          bundleName:  'com.example.anchor',
          abilityName: 'EntryAbility',
          parameters:  { page: 'pages/AlertHistoryPage' }
        };

        const wantAgentInfoParam: wantAgent.WantAgentInfo = {
          wants:       [agentWant],
          actionType:  wantAgent.OperationType.START_ABILITY,
          requestCode: 200,
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
        hilog.info(0x0000, TAG, 'Alert shown for: %{public}s', watchOwnerName);

        const alerts = AppStorage.get<AlertPayload[]>('alertHistory') ?? [];
        alerts.unshift(payload);
        AppStorage.setOrCreate('alertHistory', alerts);
      }

    } catch (err) {
      hilog.error(0x0000, TAG,
        'onReceiveMessage error: %{public}s', JSON.stringify(err));
    }
  }
}
