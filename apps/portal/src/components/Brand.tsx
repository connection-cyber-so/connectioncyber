import Image from 'next/image';
import Link from 'next/link';
import connectionCyberLogo from '../../../../logo/logosf.png';

export function Brand() {
  return (
    <Link href="/" className="brand" aria-label="ConnectionCyber — início do portal">
      <Image src={connectionCyberLogo} alt="" width={46} height={46} priority />
      <span className="brand-copy">
        <span className="brand-name">
          <span>Connection</span>Cyber
        </span>
        <span className="brand-tagline">Tecnologia que traz conhecimento e gestão</span>
      </span>
    </Link>
  );
}
