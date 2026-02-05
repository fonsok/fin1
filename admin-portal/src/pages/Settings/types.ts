export interface TwoFactorSetupResponse {
  secret: string;
  qrCodeUrl: string;
  otpauth: string;
  instructions: string;
}

export interface TwoFactorEnableResponse {
  success: boolean;
  backupCodes: string[];
  message: string;
}

export interface TwoFactorStatus {
  enabled: boolean;
  enabledAt?: string;
  backupCodesRemaining?: number;
}
