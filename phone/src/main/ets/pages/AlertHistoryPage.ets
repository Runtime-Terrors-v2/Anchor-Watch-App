import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

interface AlertRecord {
  ownerName: string;
  watchName: string;
  timestamp: number;
}

@Entry
@Component
struct AlertHistoryPage {

  @StorageLink('alertHistory') alertHistory: AlertRecord[] = [];

  private formatDate(timestamp: number): string {
    const date  = new Date(timestamp);
    const day   = date.getDate().toString().padStart(2, '0');
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const mins  = date.getMinutes().toString().padStart(2, '0');
    return `${day}/${month} at ${hours}:${mins}`;
  }

  private getTimeAgo(timestamp: number): string {
    const diff = Date.now() - timestamp;
    const mins = Math.floor(diff / 60000);
    if (mins < 1)   return 'just now';
    if (mins < 60)  return `${mins}m ago`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24)   return `${hrs}h ago`;
    const days = Math.floor(hrs / 24);
    return `${days}d ago`;
  }

  private clearHistory(): void {
    AppStorage.setOrCreate('alertHistory', [] as AlertRecord[]);
  }

  build() {
    Column() {

      // Header
      Row() {
        Row({ space: 8 }) {
          Text('←')
            .fontSize(20)
            .fontColor('#1A1A1A')
            .onClick(() => {
              router.pushUrl({ url: 'pages/HomePage' })
                .catch((e: BusinessError) => {
                  console.error('Nav error: ' + JSON.stringify(e));
                });
            })
          Text('Alert history')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
        }
        .alignItems(VerticalAlign.Center)

        if (this.alertHistory.length > 0) {
          Text('Clear all')
            .fontSize(13)
            .fontColor('#E84026')
            .onClick(() => {
              this.clearHistory();
            })
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })
      .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })

      // Empty state
      if (this.alertHistory.length === 0) {
        Column({ space: 12 }) {
          Text('No alerts yet')
            .fontSize(16)
            .fontColor('#888888')
          Text('Disconnect events will appear here\nwhen your watch goes offline.')
            .fontSize(13)
            .fontColor('#AAAAAA')
            .textAlign(TextAlign.Center)
        }
        .margin({ top: 80 })
        .alignItems(HorizontalAlign.Center)

      } else {

        // Summary banner
        Row({ space: 8 }) {
          Text(this.alertHistory.length.toString())
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .fontColor('#E84026')
          Text(this.alertHistory.length === 1 ? 'disconnect event recorded' : 'disconnect events recorded')
            .fontSize(13)
            .fontColor('#666666')
        }
        .width('90%')
        .padding(14)
        .borderRadius(10)
        .backgroundColor('#FFF5F5')
        .border({ width: 0.5, color: '#F7C1C1' })
        .margin({ top: 16, bottom: 8 })
        .alignItems(VerticalAlign.Center)

        // Alert list
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.alertHistory, (alert: AlertRecord, index: number) => {
              Row({ space: 12 }) {

                // Index indicator
                Column() {
                  Text((index + 1).toString())
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#A32D2D')
                }
                .width(28)
                .height(28)
                .borderRadius(14)
                .backgroundColor('#FCEBEB')
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)

                // Alert info
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text(alert.watchName !== '' ? alert.watchName : 'Huawei Watch')
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A1A')
                    Text('offline')
                      .fontSize(10)
                      .fontColor('#A32D2D')
                      .backgroundColor('#FCEBEB')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .borderRadius(4)
                  }

                  Text(this.formatDate(alert.timestamp))
                    .fontSize(12)
                    .fontColor('#888888')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // Time ago
                Text(this.getTimeAgo(alert.timestamp))
                  .fontSize(11)
                  .fontColor('#AAAAAA')
              }
              .width('100%')
              .padding(14)
              .borderRadius(12)
              .border({ width: 0.5, color: '#EEEEEE' })
              .backgroundColor('#FFFFFF')
              .alignItems(VerticalAlign.Center)
            }, (alert: AlertRecord) => alert.timestamp.toString())
          }
          .width('90%')
          .padding({ bottom: 40 })
        }
        .layoutWeight(1)
        .width('100%')
        .align(Alignment.TopStart)
        .padding({ left: '5%' })
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F8F8F8')
    .alignItems(HorizontalAlign.Center)
  }
}
