import { registerPlugin } from '@capacitor/core';

import type { SmartWinnrDailyPlugin } from './definitions';

const SmartWinnrDaily = registerPlugin<SmartWinnrDailyPlugin>(
  'SmartWinnrDaily',
  {
    web: () => import('./web').then(m => new m.SmartWinnrDailyWeb()),
  },
);

export * from './definitions';
export { SmartWinnrDaily };
