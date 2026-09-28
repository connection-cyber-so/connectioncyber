import Link from 'next/link';
import { PublicFrame } from '@/components/PublicFrame';

type StatePanelProps = {
  code: string;
  title: string;
  description: string;
  action?: { href: string; label: string };
};

export function StatePanel({ code, title, description, action }: StatePanelProps) {
  return (
    <PublicFrame>
      <div className="state-code">{code}</div>
      <h1>{title}</h1>
      <p className="lead">{description}</p>
      {action ? (
        <Link className="button primary" href={action.href}>
          {action.label}
        </Link>
      ) : null}
    </PublicFrame>
  );
}
