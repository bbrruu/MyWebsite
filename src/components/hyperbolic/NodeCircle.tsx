import type { EmbeddedNode } from './types';

interface Props {
  node: EmbeddedNode;
  diskR: number;
  isHovered: boolean;
  isSelected: boolean;
  isHighlighted: boolean;
  onHover: (id: string | null) => void;
  onSelect: (id: string) => void;
}

function getRadius(depth: number, active: boolean): number {
  const base = depth === 0 ? 10 : depth <= 2 ? 7 : depth <= 4 ? 5 : 4;
  return active ? base + 2 : base;
}

export function NodeCircle({
  node,
  diskR,
  isHovered,
  isSelected,
  isHighlighted,
  onHover,
  onSelect,
}: Props) {
  const cx = node.px * diskR;
  const cy = node.py * diskR;
  const active = isHovered || isSelected;
  const radius = getRadius(node.depth, active);

  // Always show label for top levels; show on interaction for deeper nodes
  const showLabel = node.depth <= 2 || isHovered || isSelected || isHighlighted;

  let fill = 'var(--paper)';
  let stroke = 'var(--border)';
  let strokeWidth = 1;
  let textFill = 'var(--muted)';

  if (isSelected) {
    fill = 'var(--accent)';
    stroke = 'var(--accent)';
    strokeWidth = 2;
    textFill = 'var(--accent)';
  } else if (isHovered) {
    fill = 'rgba(139,69,19,0.15)';
    stroke = 'var(--accent)';
    strokeWidth = 2;
    textFill = 'var(--accent)';
  } else if (isHighlighted) {
    fill = 'rgba(139,69,19,0.08)';
    stroke = 'var(--accent)';
    strokeWidth = 1.5;
    textFill = 'var(--ink)';
  }

  const fontSize = node.depth <= 2 ? 11 : 9;

  return (
    <g
      onMouseEnter={() => onHover(node.id)}
      onMouseLeave={() => onHover(null)}
      onClick={() => onSelect(node.id)}
      style={{ cursor: 'pointer' }}
    >
      {/* Invisible larger hit area for small nodes */}
      <circle cx={cx} cy={cy} r={Math.max(radius, 8)} fill="transparent" />
      <circle
        cx={cx}
        cy={cy}
        r={radius}
        fill={fill}
        stroke={stroke}
        strokeWidth={strokeWidth}
      />
      {showLabel && (
        <text
          x={cx}
          y={cy - radius - 4}
          textAnchor="middle"
          fontSize={fontSize}
          fill={textFill}
          style={{ userSelect: 'none', pointerEvents: 'none', fontFamily: 'LXGW WenKai TC, serif' }}
        >
          {node.label}
        </text>
      )}
    </g>
  );
}
