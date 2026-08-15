import type { VideoScript } from '../types';
import { VideoScriptCard } from './VideoScriptCard';

export function VideoScriptList({ videoScripts }: { videoScripts: VideoScript[] }) {
  if (videoScripts.length === 0) {
    return (
      <div className="pf-empty">
        <strong>Nenhum roteiro ainda</strong>
        Crie o primeiro roteiro a partir de uma oferta cadastrada.
      </div>
    );
  }

  return (
    <div className="pf-grid-2">
      {videoScripts.map((videoScript) => (
        <VideoScriptCard key={videoScript.id} videoScript={videoScript} />
      ))}
    </div>
  );
}
