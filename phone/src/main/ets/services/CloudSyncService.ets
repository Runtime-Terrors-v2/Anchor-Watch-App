import { hilog } from '@kit.PerformanceAnalysisKit';
import agconnect from '@hw-agconnect/api-ohos';
import '@hw-agconnect/function-ohos';
import { UserSession } from './UserSession';

const TAG = 'CloudSyncService';

export interface UserRecord {
  openID:    string;
  pushToken: string;
  contacts:  string[];
  updatedAt: number;
}

export class CloudSyncService {

  private static instance: CloudSyncService;

  static getInstance(): CloudSyncService {
    if (!CloudSyncService.instance) {
      CloudSyncService.instance = new CloudSyncService();
    }
    return CloudSyncService.instance;
  }

  async savePushToken(pushToken: string): Promise<void> {
    const openID = UserSession.getOpenID();
    if (!openID || !pushToken) {
      hilog.warn(0x0000, TAG, 'Missing openID or pushToken');
      return;
    }

    const body: UserRecord = {
      openID,
      pushToken,
      contacts:  [],
      updatedAt: Date.now()
    };

    try {
      const callable = agconnect.function()
        .wrap('/functions/3id7okrp/guardiansavetoken-$latest');
      await callable.call(body as object);
      hilog.info(0x0000, TAG, 'Push token saved to cloud');
    } catch (err) {
      hilog.error(0x0000, TAG, 'savePushToken error: %{public}s', (err as Error).message);
    }
  }

  async saveContacts(contactOpenIDs: string[]): Promise<void> {
    const openID = UserSession.getOpenID();
    if (!openID) {
      hilog.warn(0x0000, TAG, 'Missing openID — skipping contact sync');
      return;
    }

    interface SaveContactsBody {
      openID:   string;
      contacts: string[];
    }
    const body: SaveContactsBody = { openID, contacts: contactOpenIDs };

    try {
      const callable = agconnect.function()
        .wrap('/functions/3id7okrp/guardiansavecontacts-$latest');
      await callable.call(body as object);
      hilog.info(0x0000, TAG, 'Contacts saved to cloud');
    } catch (err) {
      hilog.error(0x0000, TAG, 'saveContacts error: %{public}s', (err as Error).message);
    }
  }
}
