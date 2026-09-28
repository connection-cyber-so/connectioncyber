'use client';

import { useState } from 'react';

type PasswordToggleInputProps = {
  name: string;
  autoComplete?: string;
  minLength?: number;
  required?: boolean;
  disabled?: boolean;
};

const EYE_PATH = 'M1.5 12s3.5-6.5 10.5-6.5S22.5 12 22.5 12 19 18.5 12 18.5 1.5 12 1.5 12Z';
const EYE_PUPIL = 'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z';

function EyeIcon({ crossed }: { crossed: boolean }) {
  return (
    <svg
      viewBox="0 0 24 24"
      width="18"
      height="18"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
    >
      <path d={EYE_PATH} />
      {crossed ? (
        <>
          <path d="M4 4l16 16" />
          <path d="M9.9 9.9a3 3 0 0 0 4.2 4.2" />
        </>
      ) : (
        <path d={EYE_PUPIL} />
      )}
    </svg>
  );
}

export function PasswordToggleInput({
  name,
  autoComplete = 'current-password',
  minLength,
  required,
  disabled,
}: PasswordToggleInputProps) {
  const [visible, setVisible] = useState(false);

  return (
    <span className="password-field">
      <input
        name={name}
        type={visible ? 'text' : 'password'}
        autoComplete={autoComplete}
        minLength={minLength}
        required={required}
        disabled={disabled}
      />
      <button
        type="button"
        className="password-toggle"
        onClick={() => setVisible((current) => !current)}
        aria-pressed={visible}
        aria-label={visible ? 'Ocultar senha' : 'Mostrar senha'}
        title={visible ? 'Ocultar senha' : 'Mostrar senha'}
        disabled={disabled}
      >
        <EyeIcon crossed={!visible} />
      </button>
    </span>
  );
}
