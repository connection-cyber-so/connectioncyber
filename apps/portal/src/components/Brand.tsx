import Image from 'next/image';
import Link from 'next/link';
import connectionCyberLogo from '../../../../logo/logosf.png';

// M19-G4 — logoUrl opcional (branding por tenant, supabase/migrations/0035).
// Quando presente usa <img> simples em vez de next/image: é uma URL https
// arbitrária validada por tenant, não um asset do próprio build — o
// otimizador do next/image exige um allowlist de domínio por host
// (`images.remotePatterns`), intratável pra domínio livre por cliente.
export function Brand({ logoUrl }: { logoUrl?: string | null }) {
  return (
    <Link href="/" className="brand" aria-label="ConnectionCyber — início do portal">
      {logoUrl ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img src={logoUrl} alt="" width={46} height={46} />
      ) : (
        <Image src={connectionCyberLogo} alt="" width={46} height={46} priority />
      )}
      <span className="brand-copy">
        <span className="brand-name">
          <span>Connection</span>Cyber
        </span>
        <span className="brand-tagline">Tecnologia que traz conhecimento e gestão</span>
      </span>
    </Link>
  );
}
