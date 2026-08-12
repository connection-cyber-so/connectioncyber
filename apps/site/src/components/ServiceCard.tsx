import React from 'react';

interface ServiceCardProps {
  title: string;
  description: string;
  bullets?: string[];
}

export default function ServiceCard({ title, description, bullets }: ServiceCardProps) {
  return (
    <div className="card">
      <div className="stripe-accent" />
      <h3 style={{ fontSize: '1.15rem' }}>{title}</h3>
      <p>{description}</p>
      {bullets && bullets.length > 0 && (
        <ul style={{ margin: 0, paddingLeft: 18, color: 'var(--cc-text-muted)', fontSize: '0.9rem' }}>
          {bullets.map((b) => (
            <li key={b} style={{ marginBottom: 4 }}>
              {b}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
