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

  async joinCall(options: {
    url: string;
    token: string;
    is_sharable_resources_available?: boolean;
    sharable_resources?: Array<{ id: string; url: string; display_name?: string }>;
  }): Promise<{ isCallJoined: boolean }> {
    console.log('JOIN_CALL', options);
    return { isCallJoined: true };
  }

  async endCall(): Promise<{ isCallEnded: boolean }> {
    console.log('END_CALL');
    return { isCallEnded: true };
  }
}
