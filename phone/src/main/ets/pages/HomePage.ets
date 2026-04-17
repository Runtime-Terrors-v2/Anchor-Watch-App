import { WatchMonitorService } from '../services/WatchMonitorService';
import { UserSession } from '../services/UserSession';
import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { SmsService, AlertContact } from '../services/SmsService';

interface AlertRecord {
  ownerName: string;
  watchName: string;
  timestamp: number;
}

@Entry
@Component
struct HomePage {

  @StorageLink('watchConnected') watchConnected: boolean = false;
  @StorageLink('watchName')      watchName: string       = '';
  @StorageLink('alertHistory')   alertHistory: AlertRecord[] = [];

  private getInitials(): string {
    const id = UserSession.getOpenID();
    return id.length >= 2 ? id.substring(0, 2).toUpperCase() : 'HJ';
  }

  private getLastSeenText(): string {
    if (this.watchConnected) return 'Last seen: just now';
    const alerts = this.alertHistory;
    if (alerts.length > 0) {
      const diff = Date.now() - alerts[0].timestamp;
      const mins = Math.floor(diff / 60000);
      if (mins < 60) return `Offline · ${mins}m ago`;
      const hrs = Math.floor(mins / 60);
      return `Offline · ${hrs}h ago`;
    }
    return 'Offline · alerts sent to contacts';
  }

  private getAlertCount(): number {
    const now       = Date.now();
    const weekAgo   = now - 7 * 24 * 60 * 60 * 1000;
    return this.alertHistory.filter(a => a.timestamp > weekAgo).length;
  }

  build() {
    Column() {

      // Header
      Row() {
        Text('ANCHOR')
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')

        // Avatar circle
        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill('#E6F1FB')
          Text(this.getInitials())
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#0C447C')
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20, top: 20, bottom: 0 })

      // Connection status card
      Column({ space: 6 }) {
        Row({ space: 10 }) {
          Circle()
            .width(10)
            .height(10)
            .fill(this.watchConnected ? '#1DAB5F' : '#E84026')

          Text(this.watchConnected ? 'Watch connected' : 'Watch disconnected')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.watchConnected ? '#0F6E56' : '#A32D2D')
        }
        .alignItems(VerticalAlign.Center)

        Text(this.watchName !== '' ? this.watchName : 'Huawei Watch Ultimate')
          .fontSize(13)
          .fontColor('#666666')

        Text(this.getLastSeenText())
          .fontSize(12)
          .fontColor('#999999')
      }
      .width('90%')
      .alignItems(HorizontalAlign.Start)
      .padding(20)
      .margin({ top: 16 })
      .borderRadius(12)
      .border({
        width: 0.5,
        color: this.watchConnected ? '#9FE1CB' : '#F7C1C1'
      })
      .backgroundColor(this.watchConnected ? '#E1F5EE' : '#FCEBEB')

      // Stats row
      Row({ space: 10 }) {
        // Contacts count
        Column({ space: 4 }) {
          Text('Contacts')
            .fontSize(11)
            .fontColor('#888888')
          Text((AppStorage.get<object[]>('contacts') ?? []).length.toString())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
          Text('priority')
            .fontSize(11)
            .fontColor('#AAAAAA')
        }
        .layoutWeight(1)
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')
        .alignItems(HorizontalAlign.Start)

        // Alert count
        Column({ space: 4 }) {
          Text('Alerts')
            .fontSize(11)
            .fontColor('#888888')
          Text(this.getAlertCount().toString())
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
          Text('this week')
            .fontSize(11)
            .fontColor('#AAAAAA')
        }
        .layoutWeight(1)
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')
        .alignItems(HorizontalAlign.Start)

        // Status
        Column({ space: 4 }) {
          Text('Status')
            .fontSize(11)
            .fontColor('#888888')
          Text(this.watchConnected ? 'ON' : 'OFF')
            .fontSize(20)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.watchConnected ? '#1DAB5F' : '#E84026')
          Text('guardian')
            .fontSize(11)
            .fontColor('#AAAAAA')
        }
        .layoutWeight(1)
        .padding(12)
        .borderRadius(8)
        .backgroundColor('#F5F5F5')
        .alignItems(HorizontalAlign.Start)
      }
      .width('90%')
      .margin({ top: 12 })

      // Section label
      Text('MANAGE')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#999999')
        .width('90%')
        .margin({ top: 20, bottom: 8 })
        .letterSpacing(0.5)

      // Nav items
      Column({ space: 8 }) {

        // Contacts
        Row({ space: 12 }) {
          Column() {
            Text('👥')
              .fontSize(16)
          }
          .width(36)
          .height(36)
          .borderRadius(8)
          .backgroundColor('#EEEDFE')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 2 }) {
            Text('Priority contacts')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1A1A1A')
            Text((AppStorage.get<object[]>('contacts') ?? []).length.toString() + ' contacts added')
              .fontSize(12)
              .fontColor('#888888')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(18)
            .fontColor('#CCCCCC')
        }
        .width('100%')
        .padding(14)
        .borderRadius(12)
        .border({ width: 0.5, color: '#EEEEEE' })
        .backgroundColor('#FFFFFF')
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/ContactsPage' })
            .catch((e: BusinessError) => {
              console.error('Nav error: ' + JSON.stringify(e));
            });
        })

        // Alert history
        Row({ space: 12 }) {
          Column() {
            Text('🔔')
              .fontSize(16)
          }
          .width(36)
          .height(36)
          .borderRadius(8)
          .backgroundColor('#FAEEDA')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          Column({ space: 2 }) {
            Row({ space: 6 }) {
              Text('Alert history')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
              if (this.getAlertCount() > 0) {
                Text(this.getAlertCount().toString())
                  .fontSize(10)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor('#E84026')
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .borderRadius(10)
              }
            }
            Text('Last alert: ' + (this.alertHistory.length > 0 ? 'recently' : 'none'))
              .fontSize(12)
              .fontColor('#888888')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text('›')
            .fontSize(18)
            .fontColor('#CCCCCC')
        }
        .width('100%')
        .padding(14)
        .borderRadius(12)
        .border({ width: 0.5, color: '#EEEEEE' })
        .backgroundColor('#FFFFFF')
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          router.pushUrl({ url: 'pages/AlertHistoryPage' })
            .catch((e: BusinessError) => {
              console.error('Nav error: ' + JSON.stringify(e));
            });
        })

      }
      .width('90%')

      // Bottom bar
      Row() {
        Button('Refresh status')
          .height(36)
          .fontSize(13)
          .fontColor('#666666')
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .onClick(async () => {
            await WatchMonitorService.getInstance().refreshConnectedDevices();
            const monitor = WatchMonitorService.getInstance();
            AppStorage.setOrCreate('watchConnected', monitor.isWatchConnected);
            AppStorage.setOrCreate('watchName',      monitor.connectedDeviceName);
          })
        // DEBUG ONLY — remove before submission
        Button('Simulate disconnect')
          .width('60%')
          .height(44)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#E84026')
          .borderRadius(22)
          .onClick(() => {
            AppStorage.setOrCreate('watchConnected', false);
            AppStorage.setOrCreate('watchName', 'Watch Ultimate');

            interface AlertRecord {
              ownerName: string;
              watchName: string;
              timestamp: number;
            }

            const existing: AlertRecord[] = AppStorage.get<AlertRecord[]>('alertHistory') ?? [];
            const newAlert: AlertRecord = {
              ownerName: 'Guardian',
              watchName: 'Watch Ultimate',
              timestamp: Date.now()
            };
            AppStorage.setOrCreate('alertHistory', [newAlert, ...existing]);

            const stored = AppStorage.get<AlertContact[]>('contacts') ?? [];
            const contacts: AlertContact[] = stored.map((c: AlertContact) => {
              const contact: AlertContact = {
                name:        c.name,
                pushToken:   c.pushToken,
                phoneNumber: c.phoneNumber
              };
              return contact;
            });

            SmsService.getInstance()
              .sendDisconnectAlert('Watch Ultimate', 'Guardian', contacts)
              .catch((e: Error) => {
                console.error('Alert error: ' + e.message);
              });
          })
        Button('Sign out')
          .height(36)
          .fontSize(13)
          .fontColor('#E84026')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            WatchMonitorService.getInstance().stopMonitoring();
            UserSession.logout();
            router.pushUrl({ url: 'pages/LoginPage' })
              .catch((e: BusinessError) => {
                console.error('Nav error: ' + JSON.stringify(e));
              });
          })
      }
      .width('90%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 20 })
      .padding({ bottom: 20 })

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Center)
  }
}
