import type { Offer } from '../types';
import { OfferCard } from './OfferCard';

export function OfferList({ offers }: { offers: Offer[] }) {
  if (offers.length === 0) {
    return (
      <div className="pf-empty">
        <strong>Nenhuma oferta ainda</strong>
        Crie a primeira oferta a partir de um produto cadastrado.
      </div>
    );
  }

  return (
    <div className="pf-grid-2">
      {offers.map((offer) => (
        <OfferCard key={offer.id} offer={offer} />
      ))}
    </div>
  );
}
