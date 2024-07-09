export interface SmartWinnrDailyPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
  joinCall(options: { url: string, token: string }): Promise<{ isCallJoined: boolean }>;
}
