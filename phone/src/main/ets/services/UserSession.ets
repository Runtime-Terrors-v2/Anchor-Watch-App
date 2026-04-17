export class UserSession {

  static isLoggedIn(): boolean {
    return AppStorage.get<boolean>('isLoggedIn') ?? false;
  }

  static getOpenID(): string {
    return AppStorage.get<string>('userOpenID') ?? '';
  }

  static getUnionID(): string {
    return AppStorage.get<string>('userUnionID') ?? '';
  }

  static getIDToken(): string {
    return AppStorage.get<string>('userIDToken') ?? '';
  }

  static logout(): void {
    AppStorage.setOrCreate('isLoggedIn',  false);
    AppStorage.setOrCreate('userOpenID',  '');
    AppStorage.setOrCreate('userUnionID', '');
    AppStorage.setOrCreate('userIDToken', '');
  }
}
