import { WebPlugin } from '@capacitor/core';

import type { SmartWinnrDailyPlugin } from './definitions';

export class SmartWinnrDailyWeb
  extends WebPlugin
  implements SmartWinnrDailyPlugin
{
  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}
