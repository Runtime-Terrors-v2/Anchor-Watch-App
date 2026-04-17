import { call } from '@kit.TelephonyKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { promptAction } from '@kit.ArkUI';
import router from '@ohos.router';

interface ContactInfo {
  name: string;
  relationship: string;
  phone: string;
}

interface CommunityCardModel {
  fullName: string;
  homeAddress: string;
  preferredLanguage: string;
  emergencyContact: ContactInfo;
  secondaryContact: ContactInfo;
  bloodType: string;
  allergies: string[];
  medicalSummary: string;
  lastUpdatedAt: string;
}

// Sub-page navigation within the Community Card screen
enum CardView {
  MENU      = 'MENU',
  IDENTITY  = 'IDENTITY',
  CONTACTS  = 'CONTACTS',
  MEDICAL   = 'MEDICAL',
  EDIT      = 'EDIT'
}

@Entry
@Component
struct CommunityCard {
  private readonly PROFILE_STORAGE_KEY: string = 'anchorCommunityProfileV1';

  // Which sub-page is currently visible
  @State private cardView: CardView = CardView.MENU;

  // Carousel scroll state — tracks vertical offset of the menu scroll
  @State private menuScrollY: number = 0;
  private menuScroller: Scroller = new Scroller();

  @StorageLink('anchorCommunityProfileV1')
  storedProfileText: string = '';

  @State editFullName: string = '';
  @State editHomeAddress: string = '';
  @State editPreferredLanguage: string = '';
  @State editEmergencyName: string = '';
  @State editEmergencyRelationship: string = '';
  @State editEmergencyPhone: string = '';
  @State editSecondaryName: string = '';
  @State editSecondaryRelationship: string = '';
  @State editSecondaryPhone: string = '';
  @State editBloodType: string = '';
  @State editAllergies: string = '';
  @State editMedicalSummary: string = '';
  @State editMessage: string = '';
  @State hasInitStorage: boolean = false;
  @State profileRenderVersion: number = 0;

  @State displayFullName: string = '';
  @State displayHomeAddress: string = '';
  @State displayPreferredLanguage: string = '';
  @State displayEmergencyName: string = '';
  @State displayEmergencyRelationship: string = '';
  @State displayEmergencyPhone: string = '';
  @State displaySecondaryName: string = '';
  @State displaySecondaryRelationship: string = '';
  @State displaySecondaryPhone: string = '';
  @State displayBloodType: string = '';
  @State displayAllergiesText: string = '';
  @State displayMedicalSummary: string = '';
  @State displayLastUpdatedAt: string = '';

  @State profile: CommunityCardModel = {
    fullName: 'Tan Mei Lin',
    homeAddress: 'Blk 221 Ang Mo Kio Ave 1, #09-102, Singapore 560221',
    preferredLanguage: 'English, Mandarin',
    emergencyContact: { name: 'Daniel Tan', relationship: 'Son', phone: '+65 9173 4826' },
    secondaryContact: { name: 'Lim Siew Hoon', relationship: 'Neighbor', phone: '+65 8264 3951' },
    bloodType: 'O+',
    allergies: ['Penicillin', 'Peanuts'],
    medicalSummary: 'Mild dementia. Hypertension medication at 8AM and 8PM.',
    lastUpdatedAt: '2026-03-13 09:30'
  };

  // ------------------------------------------------------------------
  // Lifecycle
  // ------------------------------------------------------------------

  aboutToAppear(): void {
    if (!this.hasInitStorage) {
      PersistentStorage.persistProp(this.PROFILE_STORAGE_KEY, '');
      this.hasInitStorage = true;
    }
    this.loadProfileFromStorage();
    this.syncDisplayFieldsFromProfile();
    this.syncEditFieldsFromProfile();
  }

  private syncDisplayFieldsFromProfile(): void {
    this.displayFullName              = this.profile.fullName;
    this.displayHomeAddress           = this.profile.homeAddress;
    this.displayPreferredLanguage     = this.profile.preferredLanguage;
    this.displayEmergencyName         = this.profile.emergencyContact.name;
    this.displayEmergencyRelationship = this.profile.emergencyContact.relationship;
    this.displayEmergencyPhone        = this.profile.emergencyContact.phone;
    this.displaySecondaryName         = this.profile.secondaryContact.name;
    this.displaySecondaryRelationship = this.profile.secondaryContact.relationship;
    this.displaySecondaryPhone        = this.profile.secondaryContact.phone;
    this.displayBloodType             = this.profile.bloodType;
    this.displayAllergiesText         = this.profile.allergies.join(', ');
    this.displayMedicalSummary        = this.profile.medicalSummary;
    this.displayLastUpdatedAt         = this.profile.lastUpdatedAt;
  }

  private loadProfileFromStorage(): void {
    if (this.storedProfileText.trim().length === 0) return;
    try {
      const parsed: CommunityCardModel = JSON.parse(this.storedProfileText) as CommunityCardModel;
      this.profile = {
        fullName:          parsed.fullName          ?? this.profile.fullName,
        homeAddress:       parsed.homeAddress       ?? this.profile.homeAddress,
        preferredLanguage: parsed.preferredLanguage ?? this.profile.preferredLanguage,
        emergencyContact: {
          name:         parsed.emergencyContact?.name         ?? this.profile.emergencyContact.name,
          relationship: parsed.emergencyContact?.relationship ?? this.profile.emergencyContact.relationship,
          phone:        parsed.emergencyContact?.phone        ?? this.profile.emergencyContact.phone
        },
        secondaryContact: {
          name:         parsed.secondaryContact?.name         ?? this.profile.secondaryContact.name,
          relationship: parsed.secondaryContact?.relationship ?? this.profile.secondaryContact.relationship,
          phone:        parsed.secondaryContact?.phone        ?? this.profile.secondaryContact.phone
        },
        bloodType:      parsed.bloodType      ?? this.profile.bloodType,
        allergies:      parsed.allergies      ?? this.profile.allergies,
        medicalSummary: parsed.medicalSummary ?? this.profile.medicalSummary,
        lastUpdatedAt:  parsed.lastUpdatedAt  ?? this.profile.lastUpdatedAt
      };
    } catch (_err) {
      this.editMessage = 'Stored profile is invalid. Using current values.';
    }
  }

  private syncEditFieldsFromProfile(): void {
    this.editFullName              = this.profile.fullName;
    this.editHomeAddress           = this.profile.homeAddress;
    this.editPreferredLanguage     = this.profile.preferredLanguage;
    this.editEmergencyName         = this.profile.emergencyContact.name;
    this.editEmergencyRelationship = this.profile.emergencyContact.relationship;
    this.editEmergencyPhone        = this.profile.emergencyContact.phone;
    this.editSecondaryName         = this.profile.secondaryContact.name;
    this.editSecondaryRelationship = this.profile.secondaryContact.relationship;
    this.editSecondaryPhone        = this.profile.secondaryContact.phone;
    this.editBloodType             = this.profile.bloodType;
    this.editAllergies             = this.profile.allergies.join(', ');
    this.editMedicalSummary        = this.profile.medicalSummary;
  }

  private validateEditProfile(): string {
    if (this.editFullName.trim().length === 0) return 'Name is required.';
    if (this.editHomeAddress.trim().length === 0) return 'Home address is required.';
    if (this.editPreferredLanguage.trim().length === 0) return 'Preferred language is required.';
    if (this.editEmergencyName.trim().length === 0 ||
        this.editEmergencyRelationship.trim().length === 0 ||
        this.editEmergencyPhone.trim().length === 0) {
      return 'Primary emergency contact is required.';
    }
    if (this.editMedicalSummary.trim().length === 0) return 'Medical summary is required.';
    const hasAny: boolean = this.editSecondaryName.trim().length > 0 ||
      this.editSecondaryRelationship.trim().length > 0 ||
      this.editSecondaryPhone.trim().length > 0;
    const hasAll: boolean = this.editSecondaryName.trim().length > 0 &&
      this.editSecondaryRelationship.trim().length > 0 &&
      this.editSecondaryPhone.trim().length > 0;
    if (hasAny && !hasAll) return 'Complete all secondary contact fields or clear all.';
    return '';
  }

  private saveEditedProfile(): void {
    const msg: string = this.validateEditProfile();
    if (msg.length > 0) { this.editMessage = msg; return; }

    const parsedAllergies: string[] = this.editAllergies.split(',')
      .map((s: string) => s.trim()).filter((s: string) => s.length > 0).slice(0, 8);

    this.profile = {
      fullName:          this.editFullName.trim(),
      homeAddress:       this.editHomeAddress.trim(),
      preferredLanguage: this.editPreferredLanguage.trim(),
      emergencyContact: {
        name:         this.editEmergencyName.trim(),
        relationship: this.editEmergencyRelationship.trim(),
        phone:        this.editEmergencyPhone.trim()
      },
      secondaryContact: {
        name:         this.editSecondaryName.trim().length > 0 ? this.editSecondaryName.trim() : 'Not set',
        relationship: this.editSecondaryRelationship.trim().length > 0 ? this.editSecondaryRelationship.trim() : 'Not set',
        phone:        this.editSecondaryPhone.trim().length > 0 ? this.editSecondaryPhone.trim() : 'Not set'
      },
      bloodType:      this.editBloodType.trim().length > 0 ? this.editBloodType.trim() : 'Unknown',
      allergies:      parsedAllergies.length > 0 ? parsedAllergies : ['None listed'],
      medicalSummary: this.editMedicalSummary.trim(),
      lastUpdatedAt:  new Date().toISOString().slice(0, 16).replace('T', ' ')
    };

    this.storedProfileText = JSON.stringify(this.profile);
    this.syncDisplayFieldsFromProfile();
    this.profileRenderVersion++;
    this.editMessage = 'Saved successfully.';
  }

  private restoreEditFields(): void {
    this.syncEditFieldsFromProfile();
    this.editMessage = 'Changes cleared.';
  }

  // Scale factor for each menu card based on its distance from the scroll viewport centre.
  // Cards at centre → 1.0, cards at edges → 0.62 (magnifier/fishbowl effect).
  // VP_HALF = TOP_PAD + HALF_H = 110 + 30 = 140, so item 0 is perfectly centred at scroll=0.
  private menuItemScale(index: number): number {
    const TOP_PAD: number  = 110;   // height of fixed header above the scroll area
    const STRIDE: number   = 70;    // card height (~60vp) + spacing (10vp)
    const HALF_H: number   = 100;    // half of card height — centre of each card relative to its top
    const VP_HALF: number  = 140;   // = TOP_PAD + HALF_H → item 0 centred at scroll offset 0
    const itemCenter: number = TOP_PAD + index * STRIDE + HALF_H;
    const viewCenter: number = this.menuScrollY + VP_HALF;
    const dist: number = Math.abs(itemCenter - viewCenter);
    // Narrower falloff (×1.2 vs ×1.5) means items shrink faster away from centre.
    const t: number = Math.min(dist / (STRIDE * 1.2), 1.0);
    return 1.0 - t * 0.3; // 1.0 at centre → 0.62 at edges
  }

  // Opacity factor matching the scale — centre card is fully opaque, edge cards fade to 55%.
  private menuItemOpacity(index: number): number {
    const TOP_PAD: number  = 110;
    const STRIDE: number   = 70;
    const HALF_H: number   = 30;
    const VP_HALF: number  = 140;
    const itemCenter: number = TOP_PAD + index * STRIDE + HALF_H;
    const viewCenter: number = this.menuScrollY + VP_HALF;
    const dist: number = Math.abs(itemCenter - viewCenter);
    const t: number = Math.min(dist / (STRIDE * 1.2), 1.0);
    return 1.0 - t * 0.45; // 1.0 at centre → 0.55 at edges
  }

  private callContact(name: string, phone: string): void {
    const digits: string = phone.replace(/[^\d+]/g, '');
    promptAction.showToast({ message: 'Calling ' + name + '…', duration: 2500 });
    call.makeCall(digits).catch((err: BusinessError) => {
      console.error('Call failed: ' + JSON.stringify(err));
    });
  }

  // ------------------------------------------------------------------
  // Shared back-to-menu button used on every sub-page
  // ------------------------------------------------------------------
  @Builder
  BackToMenu() {
    Text('< Back')
      .fontSize(11)
      .fontColor('#666666')
      .padding({ top: 4, bottom: 4, left: 6, right: 6 })
      .onClick(() => { this.cardView = CardView.MENU; })
  }

  // ------------------------------------------------------------------
  // PAGE 0 — Menu (4 option cards)
  // ------------------------------------------------------------------
  @Builder
  MenuPage() {
    Column() {

      // ── Fixed header (not part of the scroll) ────────────────────
      // Kept outside Scroll so it doesn't move while the cards slide
      Column({ space: 3 }) {
        // Back to main app
        Text('< Back')
          .fontSize(11)
          .fontColor('#666666')
          .padding({ top: 4, bottom: 2, left: 6, right: 6 })
          .onClick(() => { router.back(); })

        // Section label + resident name
        Text('COMMUNITY CARD')
          .fontSize(9)
          .fontColor('#555555')
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.5)
          .textAlign(TextAlign.Center)
          .width('100%')
        Text(this.displayFullName)
          .fontSize(19)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 8, bottom: 4 })

      // ── Scrollable card list ─────────────────────────────────────
      // Scroller object lets us read the live yOffset for scale math.
      // Blank spacers at top/bottom ensure every card can reach centre.
      Scroll(this.menuScroller) {
        Column({ space: 10 }) {

          // Top spacer — allows Card 0 to scroll up to viewport centre
          Blank().height(110)

          // ── Card 1 — Identity ──────────────────────────────────
          Row({ space: 12 }) {
            Column() {
              Text('⊙')
                .fontSize(17)
                .fontColor('#60A5FA')
            }
            .width(38).height(38)
            .borderRadius(19)
            .backgroundColor('#1A2A40')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 2 }) {
              Text('Identity')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('Profile · Help info')
                .fontSize(10)
                .fontColor('#9CA3AF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(20)
              .fontColor('#60A5FA')
          }
          .width('86%')
          .padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .backgroundColor('#CC1A1A1A')
          .borderRadius(20)
          .border({ width: { left: 3 }, color: '#60A5FA' })
          .scale({ x: this.menuItemScale(0), y: this.menuItemScale(0) })
          .opacity(this.menuItemOpacity(0))
          .onClick(() => { this.cardView = CardView.IDENTITY; })

          // ── Card 2 — Contacts ──────────────────────────────────
          Row({ space: 12 }) {
            Column() {
              Text('✆')
                .fontSize(17)
                .fontColor('#4ADE80')
            }
            .width(38).height(38)
            .borderRadius(19)
            .backgroundColor('#142A1E')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 2 }) {
              Text('Contacts')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.displayEmergencyName + ' · ' + this.displayEmergencyRelationship)
                .fontSize(10)
                .fontColor('#9CA3AF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(20)
              .fontColor('#4ADE80')
          }
          .width('86%')
          .padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .backgroundColor('#CC1A1A1A')
          .borderRadius(20)
          .border({ width: { left: 3 }, color: '#4ADE80' })
          .scale({ x: this.menuItemScale(1), y: this.menuItemScale(1) })
          .opacity(this.menuItemOpacity(1))
          .onClick(() => { this.cardView = CardView.CONTACTS; })

          // ── Card 3 — Medical ───────────────────────────────────
          Row({ space: 12 }) {
            Column() {
              Text('✚')
                .fontSize(17)
                .fontColor('#F87171')
            }
            .width(38).height(38)
            .borderRadius(19)
            .backgroundColor('#2A1414')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 2 }) {
              Text('Medical Info')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.displayBloodType + ' · ' + this.displayAllergiesText)
                .fontSize(10)
                .fontColor('#9CA3AF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(20)
              .fontColor('#F87171')
          }
          .width('86%')
          .padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .backgroundColor('#CC1A1A1A')
          .borderRadius(20)
          .border({ width: { left: 3 }, color: '#F87171' })
          .scale({ x: this.menuItemScale(2), y: this.menuItemScale(2) })
          .opacity(this.menuItemOpacity(2))
          .onClick(() => { this.cardView = CardView.MEDICAL; })

          // ── Card 4 — Edit ──────────────────────────────────────
          Row({ space: 12 }) {
            Column() {
              Text('✎')
                .fontSize(17)
                .fontColor('#FBBF24')
            }
            .width(38).height(38)
            .borderRadius(19)
            .backgroundColor('#2A2210')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)

            Column({ space: 2 }) {
              Text('Edit Profile')
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('Updated ' + this.displayLastUpdatedAt)
                .fontSize(10)
                .fontColor('#9CA3AF')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(20)
              .fontColor('#FBBF24')
          }
          .width('86%')
          .padding({ left: 14, right: 14, top: 11, bottom: 11 })
          .backgroundColor('#CC1A1A1A')
          .borderRadius(20)
          .border({ width: { left: 3 }, color: '#FBBF24' })
          .scale({ x: this.menuItemScale(3), y: this.menuItemScale(3) })
          .opacity(this.menuItemOpacity(3))
          .onClick(() => {
            this.syncEditFieldsFromProfile();
            this.editMessage = '';
            this.cardView = CardView.EDIT;
          })

          // Bottom spacer — allows Card 3 to scroll up to viewport centre
          Blank().height(110)

        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }
      .scrollable(ScrollDirection.Vertical)
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .onScroll((_x: number, _y: number) => {
        // Update scroll position so menuItemScale() re-evaluates for each card
        this.menuScrollY = this.menuScroller.currentOffset().yOffset;
      })

    }
    .width('100%')
    .height('100%')
  }

  // ------------------------------------------------------------------
  // PAGE 1 — Identity
  // Who this person is; what to do if you find them disoriented
  // ------------------------------------------------------------------
  @Builder
  IdentityPage() {
    Scroll() {
      Column({ space: 10 }) {

        this.BackToMenu()

        // Page header with blue accent
        Row({ space: 8 }) {
          Text('⊙')
            .fontSize(14)
            .fontColor('#60A5FA')
          Text('IDENTITY')
            .fontSize(11)
            .fontColor('#60A5FA')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
        }
        .alignItems(VerticalAlign.Center)

        // Resident name — large, for a passerby to read instantly
        Text(this.displayFullName)
          .fontSize(24)
          .fontColor('#FFFFFF')
          .fontWeight(FontWeight.Bold)
          .textAlign(TextAlign.Center)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // Instruction for anyone who finds the resident
        Text('If this person appears disoriented or lost,\nplease help them contact their family.')
          .fontSize(11)
          .fontColor('#9CA3AF')
          .textAlign(TextAlign.Center)
          .lineHeight(17)
          .width('100%')

        // Primary contact — most prominent action
        Column({ space: 5 }) {
          Text('CALL FOR HELP')
            .fontSize(9)
            .fontColor('#4ADE80')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .textAlign(TextAlign.Center)
          Text(this.displayEmergencyName)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.displayEmergencyRelationship)
            .fontSize(11)
            .fontColor('#9CA3AF')
            .textAlign(TextAlign.Center)
          Text(this.displayEmergencyPhone)
            .fontSize(14)
            .fontColor('#4ADE80')
            .fontWeight(FontWeight.Bold)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(20)
        .border({ width: 1, color: '#334D33' })
        .onClick(() => {
          this.callContact(this.displayEmergencyName, this.displayEmergencyPhone);
        })

        // Language — useful for a passerby to know how to communicate
        Row({ space: 8 }) {
          Text('Language')
            .fontSize(10)
            .fontColor('#9CA3AF')
          Text(this.displayPreferredLanguage)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(14)

        // Address
        Column({ space: 3 }) {
          Text('Home Address')
            .fontSize(10)
            .fontColor('#9CA3AF')
            .width('100%')
          Text(this.displayHomeAddress)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .lineHeight(16)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(14)

        Blank().height(24)

      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  // ------------------------------------------------------------------
  // PAGE 2 — Contacts
  // Primary and secondary emergency contacts, each tappable to call
  // ------------------------------------------------------------------
  @Builder
  ContactsPage() {
    Scroll() {
      Column({ space: 10 }) {

        this.BackToMenu()

        Row({ space: 8 }) {
          Text('✆')
            .fontSize(14)
            .fontColor('#4ADE80')
          Text('CONTACTS')
            .fontSize(11)
            .fontColor('#4ADE80')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
        }
        .alignItems(VerticalAlign.Center)

        // Primary contact
        Column({ space: 5 }) {
          Row({ space: 6 }) {
            Text('● PRIMARY')
              .fontSize(9)
              .fontColor('#4ADE80')
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1)
            Text('Tap to call')
              .fontSize(9)
              .fontColor('#444444')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Text(this.displayEmergencyName)
            .fontSize(17)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.displayEmergencyRelationship)
            .fontSize(11)
            .fontColor('#9CA3AF')
            .width('100%')
          Text(this.displayEmergencyPhone)
            .fontSize(14)
            .fontColor('#4ADE80')
            .fontWeight(FontWeight.Bold)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(20)
        .border({ width: { left: 3 }, color: '#4ADE80' })
        .onClick(() => {
          this.callContact(this.displayEmergencyName, this.displayEmergencyPhone);
        })

        // Secondary contact
        Column({ space: 5 }) {
          Row({ space: 6 }) {
            Text('● SECONDARY')
              .fontSize(9)
              .fontColor('#9CA3AF')
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1)
            Text('Tap to call')
              .fontSize(9)
              .fontColor('#444444')
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)

          Text(this.displaySecondaryName)
            .fontSize(17)
            .fontColor('#FFFFFF')
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.displaySecondaryRelationship)
            .fontSize(11)
            .fontColor('#9CA3AF')
            .width('100%')
          Text(this.displaySecondaryPhone)
            .fontSize(14)
            .fontColor('#AAAAAA')
            .fontWeight(FontWeight.Bold)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(20)
        .border({ width: { left: 3 }, color: '#444444' })
        .onClick(() => {
          this.callContact(this.displaySecondaryName, this.displaySecondaryPhone);
        })

        // Resident label
        Text('Resident: ' + this.displayFullName)
          .fontSize(9)
          .fontColor('#444444')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        // Re-render trigger after save
        Text('').fontSize(1).fontColor(Color.Transparent).height(1).width(1)
          .opacity(this.profileRenderVersion % 2)

        Blank().height(24)

      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  // ------------------------------------------------------------------
  // PAGE 3 — Medical Info
  // Critical health data for first responders or caregivers
  // ------------------------------------------------------------------
  @Builder
  MedicalPage() {
    Scroll() {
      Column({ space: 10 }) {

        this.BackToMenu()

        Row({ space: 8 }) {
          Text('✚')
            .fontSize(14)
            .fontColor('#F87171')
          Text('MEDICAL INFO')
            .fontSize(11)
            .fontColor('#F87171')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
        }
        .alignItems(VerticalAlign.Center)

        // Blood type — most critical, shown largest
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('BLOOD TYPE')
              .fontSize(9)
              .fontColor('#9CA3AF')
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1)
            Text(this.displayBloodType)
              .fontSize(32)
              .fontColor('#77D7FF')
              .fontWeight(FontWeight.Bold)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 2 }) {
            Text('LANGUAGE')
              .fontSize(9)
              .fontColor('#9CA3AF')
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1)
            Text(this.displayPreferredLanguage)
              .fontSize(11)
              .fontColor('#8FF0C4')
              .fontWeight(FontWeight.Medium)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        // Allergies
        Column({ space: 6 }) {
          Text('ALLERGIES')
            .fontSize(9)
            .fontColor('#FFD37A')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .width('100%')

          // Allergy chips
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(this.profile.allergies, (item: string) => {
              Text(item)
                .fontSize(11)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Medium)
                .padding({ left: 9, right: 9, top: 3, bottom: 3 })
                .backgroundColor('#992A2010')
                .borderRadius(10)
                .border({ width: 1, color: '#FFD37A40' })
                .margin({ right: 6, bottom: 6 })
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        // Medical notes
        Column({ space: 5 }) {
          Text('MEDICAL NOTES')
            .fontSize(9)
            .fontColor('#FF9FA0')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .width('100%')
          Text(this.displayMedicalSummary)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .lineHeight(17)
            .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        // Address
        Column({ space: 5 }) {
          Text('HOME ADDRESS')
            .fontSize(9)
            .fontColor('#C6B0FF')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .width('100%')
          Text(this.displayHomeAddress)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .lineHeight(16)
            .maxLines(3)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        Text('Updated ' + this.displayLastUpdatedAt)
          .fontSize(9)
          .fontColor('#444444')
          .textAlign(TextAlign.Center)
          .width('100%')

        Blank().height(24)

      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  // ------------------------------------------------------------------
  // PAGE 4 — Edit Profile
  // ------------------------------------------------------------------
  @Builder
  buildEditField(label: string, value: string, placeholder: string,
    onChangeHandler: (value: string) => void, multiline: boolean = false) {
    Column({ space: 3 }) {
      Text(label)
        .fontSize(10)
        .fontColor('#777777')
        .width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .fontSize(11)
        .height(multiline ? 46 : 34)
        .padding({ left: 10, right: 10 })
        .backgroundColor('#CC252525')
        .borderRadius(12)
        .fontColor('#FFFFFF')
        .placeholderColor('#555555')
        .width('100%')
        .onChange((v: string) => { onChangeHandler(v); })
    }
    .width('100%')
  }

  @Builder
  EditPage() {
    Scroll() {
      Column({ space: 10 }) {

        this.BackToMenu()

        Row({ space: 8 }) {
          Text('✎')
            .fontSize(14)
            .fontColor('#FBBF24')
          Text('EDIT PROFILE')
            .fontSize(11)
            .fontColor('#FBBF24')
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.5)
        }
        .alignItems(VerticalAlign.Center)

        // Form fields grouped by category
        Column({ space: 6 }) {
          Text('RESIDENT')
            .fontSize(9).fontColor('#555555').fontWeight(FontWeight.Bold).letterSpacing(1).width('100%')
          this.buildEditField('Full Name *', this.editFullName, 'Resident full name', (v: string) => {
            this.editFullName = v;
          })
          this.buildEditField('Home Address *', this.editHomeAddress, 'Street, unit, city', (v: string) => {
            this.editHomeAddress = v;
          }, true)
          this.buildEditField('Language *', this.editPreferredLanguage, 'English, Mandarin', (v: string) => {
            this.editPreferredLanguage = v;
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        Column({ space: 6 }) {
          Text('PRIMARY CONTACT')
            .fontSize(9).fontColor('#4ADE8099').fontWeight(FontWeight.Bold).letterSpacing(1).width('100%')
          this.buildEditField('Name *', this.editEmergencyName, 'Contact name', (v: string) => {
            this.editEmergencyName = v;
          })
          this.buildEditField('Relationship *', this.editEmergencyRelationship, 'Son, Daughter…', (v: string) => {
            this.editEmergencyRelationship = v;
          })
          this.buildEditField('Phone *', this.editEmergencyPhone, '+65 xxxx xxxx', (v: string) => {
            this.editEmergencyPhone = v;
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        Column({ space: 6 }) {
          Text('SECONDARY CONTACT')
            .fontSize(9).fontColor('#55555599').fontWeight(FontWeight.Bold).letterSpacing(1).width('100%')
          this.buildEditField('Name', this.editSecondaryName, 'Optional', (v: string) => {
            this.editSecondaryName = v;
          })
          this.buildEditField('Relationship', this.editSecondaryRelationship, 'Optional', (v: string) => {
            this.editSecondaryRelationship = v;
          })
          this.buildEditField('Phone', this.editSecondaryPhone, 'Optional', (v: string) => {
            this.editSecondaryPhone = v;
          })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        Column({ space: 6 }) {
          Text('MEDICAL')
            .fontSize(9).fontColor('#F8717199').fontWeight(FontWeight.Bold).letterSpacing(1).width('100%')
          this.buildEditField('Blood Type', this.editBloodType, 'O+, A-, Unknown', (v: string) => {
            this.editBloodType = v;
          })
          this.buildEditField('Allergies', this.editAllergies, 'Comma separated', (v: string) => {
            this.editAllergies = v;
          })
          this.buildEditField('Medical Summary *', this.editMedicalSummary, 'Short notes', (v: string) => {
            this.editMedicalSummary = v;
          }, true)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        .backgroundColor('#CC1A1A1A')
        .borderRadius(16)

        // Feedback message
        if (this.editMessage.length > 0) {
          Text(this.editMessage)
            .fontSize(10)
            .fontColor(this.editMessage === 'Saved successfully.' ? '#4ADE80' : '#F87171')
            .textAlign(TextAlign.Center)
            .width('100%')
        }

        // Save / Reset
        Row({ space: 10 }) {
          Button('Save')
            .fontSize(12).height(36).layoutWeight(1)
            .fontColor('#FFFFFF').backgroundColor('#994ADE80').borderRadius(18)
            .onClick(() => { this.saveEditedProfile(); })
          Button('Reset')
            .fontSize(12).height(36).layoutWeight(1)
            .fontColor('#FFFFFF').backgroundColor('#99252525').borderRadius(18)
            .onClick(() => { this.restoreEditFields(); })
        }
        .width('100%')

        Blank().height(32)

      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
    }
    .scrollable(ScrollDirection.Vertical)
    .scrollBar(BarState.Off)
    .width('100%')
    .height('100%')
  }

  // ------------------------------------------------------------------
  // Root build — routes to the correct sub-page
  // ------------------------------------------------------------------
  build() {
    Stack({ alignContent: Alignment.Center }) {

      if (this.cardView === CardView.MENU) {
        this.MenuPage()
      } else if (this.cardView === CardView.IDENTITY) {
        this.IdentityPage()
      } else if (this.cardView === CardView.CONTACTS) {
        this.ContactsPage()
      } else if (this.cardView === CardView.MEDICAL) {
        this.MedicalPage()
      } else {
        this.EditPage()
      }

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0D0D0D')
    .borderRadius(9999)
    .clip(true)
  }
}
