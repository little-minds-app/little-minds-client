'use client';

import React from 'react';

export type ParentFeedbackKind = 'error' | 'success' | 'info' | 'warning';

const titles: Record<ParentFeedbackKind, string> = {
  error: 'Hata',
  success: 'Başarılı',
  info: 'Bilgi',
  warning: 'Uyarı',
};

export function ParentFeedback({
  kind,
  title,
  message,
  onRetry,
  retryLabel = 'Yeniden dene',
}: {
  kind: ParentFeedbackKind;
  title?: string;
  message: string;
  onRetry?: () => void;
  retryLabel?: string;
}) {
  const role = kind === 'error' ? 'alert' : 'status';
  return (
    <div className={`parent-feedback parent-feedback--${kind}`} role={role}>
      <strong>{title ?? titles[kind]}</strong>
      <p>{message}</p>
      {onRetry && <button type="button" onClick={onRetry}>{retryLabel}</button>}
    </div>
  );
}
