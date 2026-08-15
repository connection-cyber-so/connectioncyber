import type { LandingPage } from '../types';
import { LandingPageCard } from './LandingPageCard';

export function LandingPageList({ landingPages }: { landingPages: LandingPage[] }) {
  if (landingPages.length === 0) {
    return (
      <div className="pf-empty">
        <strong>Nenhuma landing page ainda</strong>
        Crie a primeira a partir de uma oferta cadastrada.
      </div>
    );
  }

  return (
    <div className="pf-grid-2">
      {landingPages.map((landingPage) => (
        <LandingPageCard key={landingPage.id} landingPage={landingPage} />
      ))}
    </div>
  );
}
