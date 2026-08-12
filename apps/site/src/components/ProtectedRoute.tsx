import React, { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { getCurrentSession, getUserRoles, hasRole, UserRole } from '@/lib/auth';

interface ProtectedRouteProps {
  children: React.ReactNode;
  allowedRoles?: UserRole[];
  redirectTo?: string;
}

/**
 * Envolve páginas que exigem autenticação (e opcionalmente papéis
 * específicos — admin, instrutor, aluno, cliente, suporte, técnico).
 * Uso:
 *   <ProtectedRoute allowedRoles={['aluno', 'admin']}>...</ProtectedRoute>
 */
export default function ProtectedRoute({
  children,
  allowedRoles,
  redirectTo = '/login',
}: ProtectedRouteProps) {
  const router = useRouter();
  const [status, setStatus] = useState<'checking' | 'authorized' | 'denied'>('checking');

  useEffect(() => {
    let active = true;

    async function check() {
      try {
        const session = await getCurrentSession();
        if (!session) {
          if (active) setStatus('denied');
          router.replace(redirectTo);
          return;
        }
        if (allowedRoles && allowedRoles.length > 0) {
          const roles = await getUserRoles(session.user.id);
          if (!hasRole(roles, allowedRoles)) {
            if (active) setStatus('denied');
            router.replace('/');
            return;
          }
        }
        if (active) setStatus('authorized');
      } catch {
        if (active) setStatus('denied');
        router.replace(redirectTo);
      }
    }

    check();
    return () => {
      active = false;
    };
  }, [allowedRoles, redirectTo, router]);

  if (status !== 'authorized') {
    return (
      <div style={{ padding: '80px 24px', textAlign: 'center', color: 'var(--cc-text-muted)' }}>
        Verificando acesso…
      </div>
    );
  }

  return <>{children}</>;
}
