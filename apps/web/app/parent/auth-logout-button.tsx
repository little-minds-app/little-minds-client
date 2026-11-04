'use client';

import React, { useCallback, useState } from 'react';
import { LmButton } from './lm-ui';
import { ParentFeedback } from './parent-feedback';

async function postLogout(): Promise<void> {
  const response = await fetch('/api/auth/logout', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    cache: 'no-store',
  });
  const result = (await response.json()) as { message?: string; error?: string };
  if (!response.ok) {
    throw new Error(result.message || 'Çıkış tamamlanamadı.');
  }
}

export function AuthLogoutButton({
  variant = 'ghost',
  className = '',
  redirectTo = '/',
  label = 'Çıkış yap',
}: {
  variant?: 'primary' | 'secondary' | 'ghost' | 'chip';
  className?: string;
  redirectTo?: string;
  label?: string;
}) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');

  const logout = useCallback(async () => {
    setBusy(true);
    setError('');
    try {
      await postLogout();
      try {
        window.location.assign(redirectTo);
      } catch {
        window.location.href = redirectTo;
      }
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : 'Çıkış tamamlanamadı.';
      if (message === 'Server logout could not be confirmed' || message.includes('onayı alınamadı')) {
        window.location.assign(redirectTo);
        return;
      }
      setError(message);
    } finally {
      setBusy(false);
    }
  }, [redirectTo]);

  return (
    <div className={className}>
      {error && (
        <ParentFeedback kind="error" title="Çıkış" message={error} onRetry={() => void logout()} retryLabel="Tekrar dene" />
      )}
      <LmButton variant={variant} disabled={busy} onClick={() => void logout()}>
        {busy ? 'Çıkış yapılıyor…' : label}
      </LmButton>
    </div>
  );
}
