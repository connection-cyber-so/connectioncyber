'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase/client';

export function LogoutButton() {
  const router = useRouter();
  const [loading, setLoading] = useState(false);

  async function handleLogout() {
    setLoading(true);
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace('/login');
    router.refresh();
  }

  return (
    <button className="pf-button pf-button-secondary" style={{ width: 'auto', padding: '8px 16px' }} onClick={handleLogout} disabled={loading}>
      {loading ? 'Saindo…' : 'Sair'}
    </button>
  );
}
