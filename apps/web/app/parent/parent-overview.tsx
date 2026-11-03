'use client';

import React, { useCallback, useState } from 'react';
import { ChildProfiles } from './child-profiles';
import { WebParentDashboard } from './web-parent-dashboard';

/** A single selected child is shared by profile editor and both dashboard panels. */
export function ParentOverview() {
  const [childId, setChildId] = useState<string | null>(null);
  const select = useCallback((next: string | null) => setChildId(next), []);
  return <>
    <ChildProfiles onSelectionChange={select} />
    <WebParentDashboard selectedChildId={childId} />
  </>;
}
