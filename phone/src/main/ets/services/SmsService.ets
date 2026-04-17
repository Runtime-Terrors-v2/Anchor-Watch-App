import { hilog } from '@kit.PerformanceAnalysisKit';
import agconnect from '@hw-agconnect/api-ohos';
import { FunctionResult } from '@hw-agconnect/function-ohos';
import '@hw-agconnect/function-ohos';

const TAG = 'SmsService';

export interface AlertContact {
  name:        string;
  pushToken:   string;
  phoneNumber: string;
}

interface AlertRequest {
  ownerName: string;
  watchName: string;
  contacts:  AlertContact[];
}

export class SmsService {

  private static instance: SmsService;

  static getInstance(): SmsService {
    if (!SmsService.instance) {
      SmsService.instance = new SmsService();
    }
    return SmsService.instance;
  }

  async sendDisconnectAlert(
    watchName: string,
    ownerName: string,
    contacts:  AlertContact[]
  ): Promise<void> {

    if (contacts.length === 0) {
      hilog.warn(0x0000, TAG, 'No contacts — skipping alert');
      return;
    }

    const body: AlertRequest = { ownerName, watchName, contacts };

    try {
      const callable = agconnect.function().wrap('/functions/3id7okrp/guardianalert-$latest');
      const result: FunctionResult = await callable.call(body as object);
      hilog.info(0x0000, TAG, 'Alert response: %{public}s', JSON.stringify(result.getValue() as object));

    } catch (err) {
      hilog.error(0x0000, TAG, 'sendAlert error: %{public}s', (err as Error).message);
    }
  }
}
