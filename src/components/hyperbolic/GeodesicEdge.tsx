import { geodesicArcPath } from './hyperbolicMath';
import type { EmbeddedNode } from './types';

interface Props {
  from: EmbeddedNode;
  to: EmbeddedNode;
  diskR: number;
  highlighted: boolean;
}

export function GeodesicEdge({ from, to, diskR, highlighted }: Props) {
  const d = geodesicArcPath([from.px, from.py], [to.px, to.py], diskR);
  return (
    <path
      d={d}
      fill="none"
      stroke={highlighted ? 'var(--accent)' : 'var(--muted)'}
      strokeWidth={highlighted ? 2 : 0.8}
      strokeOpacity={highlighted ? 0.75 : 0.35}
    />
  );
}
