import type { MpiProduct } from '../types';
import { ProductCard } from './ProductCard';

export function ProductList({ products }: { products: MpiProduct[] }) {
  if (products.length === 0) {
    return (
      <div className="pf-empty">
        <strong>Nenhum produto cadastrado</strong>
        Cadastre o primeiro produto para começar a criar ofertas.
      </div>
    );
  }

  return (
    <div className="pf-grid-2">
      {products.map((product) => (
        <ProductCard key={product.id} product={product} />
      ))}
    </div>
  );
}
