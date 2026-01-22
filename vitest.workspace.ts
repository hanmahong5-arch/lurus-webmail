import { defineWorkspace } from 'vitest/config';

export default defineWorkspace([
  // Packages
  'packages/schema',
  'packages/db',
  'packages/providers',
  'packages/common',

  // Apps
  'apps/web',
  'apps/worker',
]);
