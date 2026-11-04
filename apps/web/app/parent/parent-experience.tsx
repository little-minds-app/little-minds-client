'use client';

import React, { useCallback, useState } from 'react';
import { ChildProfiles } from './child-profiles';
import { OptionalParentProfile } from './optional-parent-profile';
import { ParentAppShell } from './parent-app-shell';
import { WebParentDashboard } from './web-parent-dashboard';

export function ParentExperience() {
  const [childLabel, setChildLabel] = useState<string | null>(null);

  const onSelectionChange = useCallback((_nextId: string | null, label?: string | null) => {
    setChildLabel(label ?? null);
  }, []);

  return (
    <ParentAppShell activeChildLabel={childLabel}>
      <ChildProfiles
        onSelectionChange={onSelectionChange}
        dashboardBetween={(selectedChildId) => (
          <div id="dashboard" className="parent-experience__section">
            <WebParentDashboard selectedChildId={selectedChildId} />
          </div>
        )}
        profilesPanel={(
          <div id="profiles" className="parent-experience__profiles">
            <OptionalParentProfile />
          </div>
        )}
      />
    </ParentAppShell>
  );
}
