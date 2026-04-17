import { router } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { CloudSyncService } from '../services/CloudSyncService';
import { SmsService, AlertContact } from '../services/SmsService';
import { WatchMonitorService } from '../services/WatchMonitorService';
import { UserSession } from '../services/UserSession';

interface Contact {
  id:          string;
  name:        string;
  phoneNumber: string;
  pushToken:   string;
  openID:      string;
}

@Entry
@Component
struct ContactsPage {

  @State contacts: Contact[]    = [];
  @State showAddForm: boolean   = false;
  @State newName: string        = '';
  @State newPhone: string       = '';
  @State newOpenID: string      = '';
  @State isSaving: boolean      = false;
  @State errorMsg: string       = '';

  aboutToAppear(): void {
    const stored = AppStorage.get<Contact[]>('contacts') ?? [];
    this.contacts = stored;
  }

  private saveContacts(): void {
    AppStorage.setOrCreate('contacts', this.contacts);

    // Sync to cloud
    const openIDs = this.contacts.map(c => c.openID).filter(id => id !== '');
    CloudSyncService.getInstance().saveContacts(openIDs)
      .catch((e: Error) => {
        console.error('Cloud Sync error: ' + e.message);
      });

    // Sync to Watch via WearEngine
    const payload = JSON.stringify({
      contacts: this.contacts,
      ownerName: AppStorage.get<string>('ownerName') ?? 'Guardian',
      authToken: UserSession.getIDToken()
    });
    WatchMonitorService.getInstance().syncContactsToWatch(payload)
      .catch((e: Error) => {
        console.error('Watch hardware sync error: ' + e.message);
      });
  }

  private addContact(): void {
    if (this.newName.trim() === '') {
      this.errorMsg = 'Name is required';
      return;
    }
    if (this.newPhone.trim() === '' && this.newOpenID.trim() === '') {
      this.errorMsg = 'Enter a phone number or app user ID';
      return;
    }

    this.isSaving = true;
    this.errorMsg = '';

    const contact: Contact = {
      id:          Date.now().toString(),
      name:        this.newName.trim(),
      phoneNumber: this.newPhone.trim(),
      pushToken:   '',
      openID:      this.newOpenID.trim()
    };

    this.contacts = [...this.contacts, contact];
    this.saveContacts();

    this.newName    = '';
    this.newPhone   = '';
    this.newOpenID  = '';
    this.showAddForm = false;
    this.isSaving   = false;
  }

  private removeContact(id: string): void {
    this.contacts = this.contacts.filter(c => c.id !== id);
    this.saveContacts();
  }

  private getInitials(name: string): string {
    const parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return name.substring(0, 2).toUpperCase();
  }

  build() {
    Column() {

      // Debug buttons
      Button('Force Sync to Watch')
        .fontSize(12)
        .backgroundColor('#007DFF')
        .margin({ bottom: 10 })
        .onClick(() => {
          const json = JSON.stringify({
            contacts: this.contacts,
            ownerName: AppStorage.get<string>('ownerName') ?? 'Guardian',
            authToken: UserSession.getIDToken()
          });
          WatchMonitorService.getInstance().syncContactsToWatch(json);
        })
      Button('Test SMS Alert')
        .fontSize(12)
        .backgroundColor('#E84026')
        .fontColor('#FFFFFF')
        .margin({ bottom: 10 })
        .onClick(() => {
          const stored = AppStorage.get<AlertContact[]>('contacts') ?? [];
          SmsService.getInstance()
            .sendDisconnectAlert(
              AppStorage.get<string>('watchName') ?? 'Test Watch',
              UserSession.getOpenID(),
              stored
            )
            .then(() => {
              console.info('Test alert sent');
            })
            .catch((e: Error) => {
              console.error('Test alert failed: ' + e.message);
            });
        })

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
          Text('Priority contacts')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
        }
        .alignItems(VerticalAlign.Center)

        Button('+ Add')
          .height(34)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .backgroundColor('#1A1A1A')
          .borderRadius(8)
          .onClick(() => {
            this.showAddForm = !this.showAddForm;
            this.errorMsg    = '';
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .alignItems(VerticalAlign.Center)
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })
      .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })

      // Info banner
      Row({ space: 8 }) {
        Text('ℹ')
          .fontSize(13)
          .fontColor('#0C447C')
        Text('ANCHOR: Syncing these to your watch. They will be alerted even if your phone is offline.')
          .fontSize(12)
          .fontColor('#185FA5')
          .layoutWeight(1)
      }
      .width('90%')
      .padding(12)
      .borderRadius(8)
      .backgroundColor('#E6F1FB')
      .margin({ top: 16, bottom: 8 })
      .alignItems(VerticalAlign.Top)

      // Add contact form
      if (this.showAddForm) {
        Column({ space: 10 }) {

          Text('Add contact')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .width('100%')

          Column({ space: 4 }) {
            Text('Name *')
              .fontSize(12)
              .fontColor('#888888')
            TextInput({ placeholder: 'e.g. Riya Sharma', text: this.newName })
              .fontSize(14)
              .height(44)
              .borderRadius(8)
              .backgroundColor('#F5F5F5')
              .border({ width: 0.5, color: '#EEEEEE' })
              .onChange((val: string) => {
                this.newName = val;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('Phone number (for SMS alerts)')
              .fontSize(12)
              .fontColor('#888888')
            TextInput({ placeholder: 'e.g. +919876543210', text: this.newPhone })
              .fontSize(14)
              .height(44)
              .borderRadius(8)
              .backgroundColor('#F5F5F5')
              .border({ width: 0.5, color: '#EEEEEE' })
              .type(InputType.PhoneNumber)
              .onChange((val: string) => {
                this.newPhone = val;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          Column({ space: 4 }) {
            Text('App user ID (for push notifications)')
              .fontSize(12)
              .fontColor('#888888')
            TextInput({ placeholder: 'Their Huawei ID openID', text: this.newOpenID })
              .fontSize(14)
              .height(44)
              .borderRadius(8)
              .backgroundColor('#F5F5F5')
              .border({ width: 0.5, color: '#EEEEEE' })
              .onChange((val: string) => {
                this.newOpenID = val;
              })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (this.errorMsg !== '') {
            Text(this.errorMsg)
              .fontSize(12)
              .fontColor('#E84026')
              .width('100%')
          }

          Row({ space: 10 }) {
            Button('Cancel')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontColor('#666666')
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .onClick(() => {
                this.showAddForm = false;
                this.errorMsg    = '';
                this.newName     = '';
                this.newPhone    = '';
                this.newOpenID   = '';
              })

            Button(this.isSaving ? 'Saving...' : 'Save contact')
              .layoutWeight(1)
              .height(44)
              .fontSize(14)
              .fontColor('#FFFFFF')
              .backgroundColor('#1A1A1A')
              .borderRadius(8)
              .enabled(!this.isSaving)
              .onClick(() => {
                this.addContact();
              })
          }
          .width('100%')
        }
        .width('90%')
        .padding(16)
        .borderRadius(12)
        .border({ width: 0.5, color: '#EEEEEE' })
        .backgroundColor('#FFFFFF')
        .margin({ bottom: 12 })
        .alignItems(HorizontalAlign.Start)
      }

      // Contacts list
      if (this.contacts.length === 0 && !this.showAddForm) {
        Column({ space: 12 }) {
          Text('No contacts yet')
            .fontSize(16)
            .fontColor('#888888')
          Text('Add priority contacts who will be\nalerted when your watch disconnects.')
            .fontSize(13)
            .fontColor('#AAAAAA')
            .textAlign(TextAlign.Center)
          Button('+ Add first contact')
            .height(44)
            .fontSize(14)
            .fontColor('#FFFFFF')
            .backgroundColor('#1A1A1A')
            .borderRadius(8)
            .margin({ top: 8 })
            .onClick(() => {
              this.showAddForm = true;
            })
        }
        .margin({ top: 60 })
        .alignItems(HorizontalAlign.Center)

      } else {
        Scroll() {
          Column({ space: 8 }) {
            ForEach(this.contacts, (contact: Contact) => {
              Row({ space: 12 }) {

                // Avatar
                Column() {
                  Text(this.getInitials(contact.name))
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#3C3489')
                }
                .width(44)
                .height(44)
                .borderRadius(22)
                .backgroundColor('#EEEDFE')
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)

                // Info
                Column({ space: 3 }) {
                  Text(contact.name)
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1A1A')

                  if (contact.phoneNumber !== '') {
                    Row({ space: 4 }) {
                      Text('SMS')
                        .fontSize(10)
                        .fontColor('#0F6E56')
                        .backgroundColor('#E1F5EE')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(4)
                      Text(contact.phoneNumber)
                        .fontSize(12)
                        .fontColor('#666666')
                    }
                  }

                  if (contact.openID !== '') {
                    Row({ space: 4 }) {
                      Text('APP')
                        .fontSize(10)
                        .fontColor('#3C3489')
                        .backgroundColor('#EEEDFE')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .borderRadius(4)
                      Text(contact.openID.substring(0, 16) + '...')
                        .fontSize(12)
                        .fontColor('#666666')
                    }
                  }
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                // Remove button
                Text('✕')
                  .fontSize(16)
                  .fontColor('#CCCCCC')
                  .padding(8)
                  .onClick(() => {
                    this.removeContact(contact.id);
                  })
              }
              .width('100%')
              .padding(14)
              .borderRadius(12)
              .border({ width: 0.5, color: '#EEEEEE' })
              .backgroundColor('#FFFFFF')
              .alignItems(VerticalAlign.Center)
            }, (contact: Contact) => contact.id)
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
