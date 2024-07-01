export interface SmartWinnrDailyPlugin {
  echo(options: { value: string }): Promise<{ value: string }>;
}
