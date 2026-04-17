import { wearEngine } from '@kit.WearEngine';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

const TAG = 'WatchMonitorService';

export type DisconnectCallback = (deviceName: string) => void;
export type ConnectCallback   = (deviceName: string) => void;

// Interfaces to satisfy "arkts-no-untyped-obj-literals"
interface P2pTarget {
  bundleName: string;
}

interface P2pMessage {
  data: Uint8Array;
}

export class WatchMonitorService {
  private static instance: WatchMonitorService;
  private deviceClient:  wearEngine.DeviceClient | null = null;
  private authClient:    wearEngine.AuthClient   | null = null;
  private p2pClient:     wearEngine.P2pClient    | null = null;
  private isMonitoring:  boolean = false;
  private pollTimer: number = 0;
  private isTimerRunning: boolean = false;

  private onDisconnect: DisconnectCallback | null = null;
  private onConnect:    ConnectCallback    | null = null;

  private lastSyncPayload: string = '';

  public isWatchConnected:    boolean = false;
  public connectedDeviceName: string  = '';
  public connectedDevices:    wearEngine.Device[] = [];

  private savedContext: common.UIAbilityContext | null = null;

  static getInstance(): WatchMonitorService {
    if (!WatchMonitorService.instance) {
      WatchMonitorService.instance = new WatchMonitorService();
    }
    return WatchMonitorService.instance;
  }

  init(context: common.UIAbilityContext): void {
    this.savedContext = context;
    this.deviceClient = wearEngine.getDeviceClient(context);
    this.authClient   = wearEngine.getAuthClient(context);
    this.p2pClient    = wearEngine.getP2pClient(context);
    hilog.info(0x0000, TAG, 'WatchMonitorService initialized');
  }

  setCallbacks(onConnect: ConnectCallback, onDisconnect: DisconnectCallback): void {
    this.onConnect    = onConnect;
    this.onDisconnect = onDisconnect;
  }

  async startMonitoring(): Promise<void> {
    if (!this.deviceClient || !this.authClient) {
      hilog.error(0x0000, TAG, 'Not initialized');
      return;
    }
    if (this.isMonitoring) return;

    try {
      const authRequest: wearEngine.AuthorizationRequest = {
        permissions: [wearEngine.Permission.DEVICE_IDENTIFIER]
      };
      await this.authClient.requestAuthorization(authRequest);
      hilog.info(0x0000, TAG, 'Authorization granted');

      await this.refreshConnectedDevices();

      this.isMonitoring = true;
      const timerId: number = setInterval((): void => {
        this.checkConnectionState().catch((e: Error): void => {
          hilog.error(0x0000, TAG, 'poll error: %{public}s', e.message);
        });
      }, 10000) as number;

      this.pollTimer = timerId;
      this.isTimerRunning = true;
      hilog.info(0x0000, TAG, 'Watch monitoring started');

    } catch (err) {
      const error = err as BusinessError;
      hilog.error(0x0000, TAG, 'startMonitoring failed: %{public}s', error.message);
    }
  }

  async refreshConnectedDevices(): Promise<void> {
    if (!this.deviceClient) return;
    try {
      const deviceList: wearEngine.Device[] = await this.deviceClient.getConnectedDevices();
      this.connectedDevices    = deviceList;
      this.isWatchConnected    = deviceList.length > 0;
      this.connectedDeviceName = deviceList.length > 0 ? (deviceList[0].name ?? 'Watch') : '';
    } catch (err) {
      this.isWatchConnected = false;
    }
  }

  private async checkConnectionState(): Promise<void> {
    const wasConnected = this.isWatchConnected;
    await this.refreshConnectedDevices();
    const isNowConnected = this.isWatchConnected;

    if (!wasConnected && isNowConnected) {
      this.onConnect?.(this.connectedDeviceName);
      if (this.lastSyncPayload !== '') {
        this.syncContactsToWatch(this.lastSyncPayload).catch((e: Error): void => {
          hilog.error(0x0000, TAG, 'Reconnect sync failed: %{public}s', e.message);
        });
      }
    } else if (wasConnected && !isNowConnected) {
      this.onDisconnect?.(this.connectedDeviceName);
    }
  }

  async syncContactsToWatch(contactsJson: string): Promise<void> {
    if (!this.p2pClient) {
      hilog.error(0x0000, TAG, 'P2P client not initialized');
      return;
    }

    this.lastSyncPayload = contactsJson;

    try {
      // Target must match the wearable module's bundleName in AppScope/app.json5
      const target: P2pTarget = {
        bundleName: 'com.example.anchor'
      };

      const encoder = new util.TextEncoder();
      const dataArray: Uint8Array = encoder.encode(contactsJson);

      const p2pMessage: P2pMessage = {
        data: dataArray
      };

      const client: ESObject = this.p2pClient;

      hilog.info(0x0000, TAG, 'Attempting sync to: %{public}s', target.bundleName);

      if (typeof client.sendMessage === 'function') {
        await client.sendMessage(target, p2pMessage);
      } else if (typeof client.send === 'function') {
        await client.send(target, p2pMessage);
      } else {
        throw new Error('Neither sendMessage nor send methods found on P2pClient');
      }

      hilog.info(0x0000, TAG, 'Contacts synced to watch successfully');
    } catch (err) {
      const error = err as BusinessError;
      // Error 203 = App not installed on watch
      // Error 201 = Devices not paired/connected
      hilog.error(0x0000, TAG, 'Sync failed: Code=%{public}d, Msg=%{public}s',
        error.code, error.message);
    }
  }

  stopMonitoring(): void {
    if (this.isTimerRunning) {
      clearInterval(this.pollTimer);
      this.pollTimer = 0;
      this.isTimerRunning = false;
    }
    this.isMonitoring = false;
    hilog.info(0x0000, TAG, 'Watch monitoring stopped');
  }
}
