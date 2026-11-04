'use client';

import React from 'react';

export function LmCard({
  title,
  subtitle,
  children,
  className = '',
  id,
}: {
  title?: string;
  subtitle?: string;
  children: React.ReactNode;
  className?: string;
  id?: string;
}) {
  return (
    <section className={`lm-card ${className}`.trim()} id={id}>
      {(title || subtitle) && (
        <header className="lm-card__header">
          {title && <h3 className="lm-card__title">{title}</h3>}
          {subtitle && <p className="lm-card__subtitle">{subtitle}</p>}
        </header>
      )}
      <div className="lm-card__body">{children}</div>
    </section>
  );
}

export function LmButton({
  children,
  variant = 'primary',
  type = 'button',
  disabled,
  onClick,
  className = '',
  'aria-pressed': ariaPressed,
}: {
  children: React.ReactNode;
  variant?: 'primary' | 'secondary' | 'ghost' | 'chip';
  type?: 'button' | 'submit';
  disabled?: boolean;
  onClick?: () => void;
  className?: string;
  'aria-pressed'?: boolean;
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      aria-pressed={ariaPressed}
      className={`lm-btn lm-btn--${variant} ${className}`.trim()}
    >
      {children}
    </button>
  );
}

export function LmField({
  label,
  hint,
  error,
  children,
  htmlFor,
}: {
  label: string;
  hint?: string;
  error?: string;
  children: React.ReactNode;
  htmlFor?: string;
}) {
  return (
    <div className={`lm-field${error ? ' lm-field--error' : ''}`}>
      <label className="lm-field__label" htmlFor={htmlFor}>{label}</label>
      {children}
      {hint && !error && <p className="lm-field__hint">{hint}</p>}
      {error && <p className="lm-field__error" role="alert">{error}</p>}
    </div>
  );
}

export function LmInput(props: React.InputHTMLAttributes<HTMLInputElement>) {
  const { className = '', ...rest } = props;
  return <input {...rest} className={`lm-input ${className}`.trim()} />;
}

export function LmSelect(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  const { className = '', children, ...rest } = props;
  return <select {...rest} className={`lm-select ${className}`.trim()}>{children}</select>;
}

export function LmKpiMetric({
  label,
  value,
  unavailable,
  emphasis,
}: {
  label: string;
  value: string;
  unavailable?: boolean;
  emphasis?: boolean;
}) {
  return (
    <article className={`lm-kpi-metric${emphasis ? ' lm-kpi-metric--emphasis' : ''}`}>
      <p className="lm-kpi-metric__label">{label}</p>
      <p className="lm-kpi-metric__value">
        {unavailable ? <span aria-label="Oran kullanılamıyor">{value}</span> : value}
      </p>
    </article>
  );
}

export function LmDisclosure({
  summary,
  children,
  defaultOpen = false,
}: {
  summary: string;
  children: React.ReactNode;
  defaultOpen?: boolean;
}) {
  return (
    <details className="lm-disclosure" open={defaultOpen}>
      <summary className="lm-disclosure__summary">{summary}</summary>
      <div className="lm-disclosure__content">{children}</div>
    </details>
  );
}
