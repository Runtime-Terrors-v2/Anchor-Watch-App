import { LoginWithHuaweiIDButton, loginComponentManager, authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { router } from '@kit.ArkUI';

const TAG = 'LoginPage';

@Entry
@Component
struct LoginPage {

  @State isLoading: boolean = false;
  @State errorMsg: string = '';

  private context = this.getUIContext().getHostContext();

  private buttonController: loginComponentManager.LoginWithHuaweiIDButtonController =
    new loginComponentManager.LoginWithHuaweiIDButtonController();

  private loginWithHuaweiID(): void {
    this.isLoading = true;
    this.errorMsg = '';

    try {
      const authRequest = new authentication.HuaweiIDProvider()
        .createAuthorizationWithHuaweiIDRequest();

      authRequest.scopes = ['profile', 'openid'];
      authRequest.permissions = ['scope.baseProfile'];
      authRequest.forceAuthorization = false;

      const authController = new authentication.AuthenticationController(this.context);

      authController.executeRequest(authRequest,
        (err: BusinessError<Object>, data: authentication.AuthenticationResponse) => {
          this.isLoading = false;

          if (err) {
            hilog.error(0x0000, TAG, 'Login failed: %{public}s', JSON.stringify(err));
            // 1001500001 = user cancelled, not a real error
            if (err.code !== 1001500001) {
              this.errorMsg = 'Sign in failed. Please try again.';
            }
            return;
          }

          const response = data as authentication.AuthorizationWithHuaweiIDResponse;

          if (response && response.data) {
            const openID  = response.data.openID  ?? '';
            const unionID = response.data.unionID ?? '';
            const idToken = response.data.idToken ?? '';

            hilog.info(0x0000, TAG, 'Login success — openID: %{public}s', openID);

            AppStorage.setOrCreate('userOpenID',  openID);
            AppStorage.setOrCreate('userUnionID', unionID);
            AppStorage.setOrCreate('userIDToken', idToken);
            AppStorage.setOrCreate('isLoggedIn',  true);

            router.pushUrl({ url: 'pages/HomePage' })
              .catch((e: BusinessError) => {
                hilog.error(0x0000, TAG, 'Navigation failed: %{public}s', JSON.stringify(e));
              });
          }
        });

    } catch (err) {
      this.isLoading = false;
      hilog.error(0x0000, TAG, 'Unexpected error: %{public}s', JSON.stringify(err));
      this.errorMsg = 'An unexpected error occurred.';
    }
  }

  build() {
    Column() {

      Column({ space: 12 }) {
        Image($r('app.media.layered_image'))
          .width(88)
          .height(88)
          .borderRadius(22)

        Text('ANCHOR')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')

        Text('Stay connected with those who matter')
          .fontSize(14)
          .fontColor('#888888')
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })
      }
      .margin({ top: 100, bottom: 72 })

      if (this.errorMsg !== '') {
        Text(this.errorMsg)
          .fontSize(13)
          .fontColor('#E84026')
          .margin({ bottom: 20 })
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })
      }

      if (this.isLoading) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color('#CC0000')
          .margin({ bottom: 20 })
      }

      LoginWithHuaweiIDButton({
        params: {
          style: loginComponentManager.Style.BUTTON_RED,
          borderRadius: 24,
          loginType: loginComponentManager.LoginType.QUICK_LOGIN,
          supportDarkMode: true
        },
        controller: this.buttonController
      })
        .width('80%')
        .height(48)
        .onClick(() => {
          if (!this.isLoading) {
            this.loginWithHuaweiID();
          }
        })

      // DEBUG ONLY — remove before release
      Button('Skip login (emulator debug)')
        .width('80%')
        .height(44)
        .backgroundColor('#444444')
        .fontColor('#FFFFFF')
        .borderRadius(22)
        .margin({ top: 12 })
        .onClick(() => {
          AppStorage.setOrCreate('userOpenID',  'debug-openid-001');
          AppStorage.setOrCreate('userUnionID', 'debug-unionid-001');
          AppStorage.setOrCreate('userIDToken', 'debug-token-001');
          AppStorage.setOrCreate('isLoggedIn',  true);
          router.pushUrl({ url: 'pages/HomePage' })
            .catch((e: BusinessError) => {
              console.error('Nav failed: ' + JSON.stringify(e));
            });
        })

      Text('By signing in you agree to our Terms of Service')
        .fontSize(11)
        .fontColor('#AAAAAA')
        .margin({ top: 20 })
        .textAlign(TextAlign.Center)
        .padding({ left: 32, right: 32 })

    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Start)
  }
}
