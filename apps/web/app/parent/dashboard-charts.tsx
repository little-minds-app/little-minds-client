'use client';

import React from 'react';

export function ActivityDurationChart({
  rows,
  maxSeconds,
}: {
  rows: { key: string; label: string; sessionCount: number; playSeconds: number; playLabel: string }[];
  maxSeconds: number;
}) {
  if (rows.length === 0) return null;
  return (
    <div className="dashboard-chart" aria-label="Etkinlik oyun süresi dağılımı">
      <h4>Oyun süresi dağılımı</h4>
      <ul className="dashboard-chart__list">
        {rows.map((row) => (
          <li key={row.key}>
            <span className="dashboard-chart__label">{row.label}</span>
            <div className="dashboard-chart__bar-track" aria-hidden="true">
              <div
                className="dashboard-chart__bar-fill"
                style={{ width: maxSeconds > 0 ? `${(row.playSeconds / maxSeconds) * 100}%` : '0%' }}
              />
            </div>
            <span className="dashboard-chart__meta">{row.sessionCount} oturum · {row.playLabel}</span>
          </li>
        ))}
      </ul>
      <p className="dashboard-chart__note">Zaman içi trend grafikleri LMP-90 kapsamında; burada yalnızca sunucu özet verisi gösterilir.</p>
    </div>
  );
}
