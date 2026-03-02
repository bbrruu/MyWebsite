import { useMemo } from 'react';
import type { EmbeddedNode } from './types';
import type { SelectedIds } from './types';
import { GeodesicEdge } from './GeodesicEdge';
import { NodeCircle } from './NodeCircle';

const DEPTH_SCALE = 0.6;
const DEPTH_LEVELS = [1, 2, 3, 4, 5, 6];

interface Props {
  embeddedNodes: EmbeddedNode[];
  diskR: number;
  hoveredId: string | null;
  selectedIds: SelectedIds;
  highlightedSet: Set<string>;
  handleHover: (id: string | null) => void;
  handleSelect: (id: string) => void;
}

export function DiskCanvas({
  embeddedNodes,
  diskR,
  hoveredId,
  selectedIds,
  highlightedSet,
  handleHover,
  handleSelect,
}: Props) {
  const nodeMap = useMemo(
    () => new Map(embeddedNodes.map((n) => [n.id, n])),
    [embeddedNodes]
  );

  // Build parent→child edge list
  const edges = useMemo<[EmbeddedNode, EmbeddedNode][]>(
    () =>
      embeddedNodes.flatMap((node) =>
        node.children
          .map((childId) => nodeMap.get(childId))
          .filter((child): child is EmbeddedNode => child !== undefined)
          .map((child) => [node, child] as [EmbeddedNode, EmbeddedNode])
      ),
    [embeddedNodes, nodeMap]
  );

  return (
    <svg
      width={diskR * 2}
      height={diskR * 2}
      className="hb-disk-svg"
      style={{ display: 'block' }}
    >
      <g transform={`translate(${diskR},${diskR})`}>
        {/* Boundary circle */}
        <circle r={diskR - 2} fill="none" stroke="var(--border)" strokeWidth={1.5} />

        {/* Depth reference rings */}
        {DEPTH_LEVELS.map((d) => (
          <circle
            key={d}
            r={Math.tanh(d * DEPTH_SCALE) * (diskR - 2)}
            fill="none"
            stroke="var(--border)"
            strokeWidth={0.5}
            opacity={0.3}
          />
        ))}

        {/* Geodesic edges (rendered below nodes) */}
        {edges.map(([from, to]) => {
          const eid = `${from.id}-${to.id}`;
          const highlighted =
            highlightedSet.has(from.id) && highlightedSet.has(to.id);
          return (
            <GeodesicEdge
              key={eid}
              from={from}
              to={to}
              diskR={diskR - 2}
              highlighted={highlighted}
            />
          );
        })}

        {/* Nodes (rendered above edges) */}
        {embeddedNodes.map((node) => (
          <NodeCircle
            key={node.id}
            node={node}
            diskR={diskR - 2}
            isHovered={hoveredId === node.id}
            isSelected={selectedIds.includes(node.id)}
            isHighlighted={highlightedSet.has(node.id)}
            onHover={handleHover}
            onSelect={handleSelect}
          />
        ))}
      </g>
    </svg>
  );
}
