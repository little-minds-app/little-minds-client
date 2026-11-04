'use client';

import React from 'react';
import { AuthLogoutButton } from './auth-logout-button';

export function ParentAppShell({
  children,
  activeChildLabel,
}: {
  children: React.ReactNode;
  activeChildLabel?: string | null;
}) {
  return (
    <div className="parent-app">
      <header className="parent-app__header">
        <div className="parent-app__header-inner">
          <div className="parent-app__brand">
            <span className="parent-app__logo" aria-hidden="true">LM</span>
            <div>
              <p className="parent-app__eyebrow">Little Minds</p>
              <h1 className="parent-app__title">Ebeveyn paneli</h1>
            </div>
          </div>
          <nav className="parent-app__nav" aria-label="Ebeveyn gezintisi">
            <a className="parent-app__nav-link parent-app__nav-link--active" href="#dashboard">Özet</a>
            <a className="parent-app__nav-link" href="#profiles">Profiller</a>
            <AuthLogoutButton variant="ghost" className="parent-app__logout" label="Çıkış yap" />
          </nav>
        </div>
        {activeChildLabel && (
          <p className="parent-app__context" role="status">
            Aktif çocuk: <strong>{activeChildLabel}</strong>
          </p>
        )}
      </header>
      <div className="parent-app__main">{children}</div>
    </div>
  );
}
