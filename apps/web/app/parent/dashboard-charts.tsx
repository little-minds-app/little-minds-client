'use client';

import React, { useId } from 'react';
import { LmCard } from './lm-ui';

const SEGMENT_COLORS = {
  completed: '#2d6a4f',
  interrupted: '#bc6c25',
  inProgress: '#2552a4',
  abandoned: '#6c757d',
} as const;

export function SessionCompositionDonut({
  completed,
  interrupted,
  inProgress,
  abandoned,
  eligible,
}: {
  completed: number;
  interrupted: number;
  inProgress: number;
  abandoned: number;
  eligible: number;
}) {
  const titleId = useId();
  const segments = [
    { key: 'completed', label: 'Tamamlanan', value: completed, color: SEGMENT_COLORS.completed },
    { key: 'interrupted', label: 'Yarıda kalan', value: interrupted, color: SEGMENT_COLORS.interrupted },
    { key: 'inProgress', label: 'Devam eden', value: inProgress, color: SEGMENT_COLORS.inProgress },
    { key: 'abandoned', label: 'Terk edilen', value: abandoned, color: SEGMENT_COLORS.abandoned },
  ].filter((item) => item.value > 0);
  const total = segments.reduce((sum, item) => sum + item.value, 0);

  if (eligible <= 0 || total <= 0) {
    return (
      <LmCard title="Oturum dağılımı" subtitle="Sunucu oturum sayıları">
        <div className="dashboard-chart dashboard-chart--empty" role="img" aria-label="Oturum dağılımı grafiği: uygun oturum yok">
          <div className="dashboard-chart__empty-ring" aria-hidden="true" />
          <p className="dashboard-chart__empty-copy">
            Bu dönemde dağılım gösterecek uygun oturum yok. Grafik yalnızca sunucudan gelen gerçek oturum sayılarıyla doldurulur.
          </p>
        </div>
      </LmCard>
    );
  }

  let offset = 0;
  const radius = 42;
  const circumference = 2 * Math.PI * radius;
  const slices = segments.map((segment) => {
    const fraction = segment.value / total;
    const dash = fraction * circumference;
    const slice = { ...segment, dash, gap: circumference - dash, offset };
    offset += dash;
    return slice;
  });

  return (
    <LmCard title="Oturum dağılımı" subtitle="Tamamlanan / yarıda kalan / devam eden oturumlar">
      <div className="dashboard-chart dashboard-chart--donut">
        <svg viewBox="0 0 120 120" className="dashboard-chart__donut" role="img" aria-labelledby={titleId}>
          <title id={titleId}>Oturum dağılımı: {segments.map((s) => `${s.label} ${s.value}`).join(', ')}</title>
          <circle cx="60" cy="60" r={radius} fill="none" stroke="#eef1f7" strokeWidth="16" />
          {slices.map((slice) => (
            <circle
              key={slice.key}
              cx="60"
              cy="60"
              r={radius}
              fill="none"
              stroke={slice.color}
              strokeWidth="16"
              strokeDasharray={`${slice.dash} ${slice.gap}`}
              strokeDashoffset={-slice.offset + circumference / 4}
              transform="rotate(-90 60 60)"
            />
          ))}
        </svg>
        <ul className="dashboard-chart__legend">
          {segments.map((segment) => (
            <li key={segment.key}>
              <span className="dashboard-chart__swatch" style={{ background: segment.color }} aria-hidden="true" />
              <span>{segment.label}</span>
              <strong>{segment.value}</strong>
            </li>
          ))}
        </ul>
      </div>
    </LmCard>
  );
}

export function ActivityDurationChart({
  rows,
  maxSeconds,
}: {
  rows: { key: string; label: string; sessionCount: number; playSeconds: number; playLabel: string }[];
  maxSeconds: number;
}) {
  if (rows.length === 0) {
    return (
      <LmCard title="Etkinlik oyun süresi" subtitle="Sunucu by_activity özeti">
        <div className="dashboard-chart dashboard-chart--empty" role="status">
          <p className="dashboard-chart__empty-copy">
            Bu dönemde etkinlik bazlı oyun süresi kaydı yok. Çubuk grafik yalnızca sunucunun gönderdiği etkinlik satırlarıyla oluşturulur.
          </p>
        </div>
      </LmCard>
    );
  }
  return (
    <LmCard title="Etkinlik oyun süresi" subtitle="Sunucu by_activity özeti">
      <div className="dashboard-chart" aria-label="Etkinlik oyun süresi dağılımı">
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
      </div>
    </LmCard>
  );
}

export function TrendsPlaceholderChart() {
  return (
    <LmCard title="Zaman içi trend" subtitle="LMP-87 / LMP-90">
      <div className="dashboard-chart dashboard-chart--placeholder" role="status">
        <div className="dashboard-chart__placeholder-lines" aria-hidden="true">
          <span /><span /><span />
        </div>
        <p className="dashboard-chart__empty-copy">
          Günlük trend çizgisi yalnızca yetkili bir zaman serisi uç noktası olduğunda gösterilecek. Şu an uydurma günlük değer üretilmiyor.
        </p>
      </div>
    </LmCard>
  );
}
