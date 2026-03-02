import type { WordNode, EmbeddedNode } from './types';

type Vec2 = [number, number];

// ── Möbius addition in the Poincaré disk ──────────────────────────────────
// u ⊕ v = ((1 + 2⟨u,v⟩ + |v|²)u + (1 - |u|²)v) / (1 + 2⟨u,v⟩ + |u|²|v|²)
export function mobiusAdd(u: Vec2, v: Vec2): Vec2 {
  const [ux, uy] = u;
  const [vx, vy] = v;
  const uDotV = ux * vx + uy * vy;
  const uSq = ux * ux + uy * uy;
  const vSq = vx * vx + vy * vy;
  const denom = 1 + 2 * uDotV + uSq * vSq;
  const factorU = 1 + 2 * uDotV + vSq;
  const factorV = 1 - uSq;
  return [(factorU * ux + factorV * vx) / denom, (factorU * uy + factorV * vy) / denom];
}

// ── Hyperbolic distance: d(u,v) = 2·atanh(|(-u) ⊕ v|) ────────────────────
export function hyperbolicDistance(u: Vec2, v: Vec2): number {
  const negU: Vec2 = [-u[0], -u[1]];
  const diff = mobiusAdd(negU, v);
  const norm = Math.sqrt(diff[0] * diff[0] + diff[1] * diff[1]);
  // Clamp to avoid atanh(1) = Infinity at boundary
  return 2 * Math.atanh(Math.min(norm, 0.9999));
}

// ── Tree embedding via BFS sector division ────────────────────────────────
// Root → (0,0). Each depth-d node gets radius = tanh(d * depthScale).
// Children equally partition parent's angular sector.
export function embedTree(
  nodes: WordNode[],
  rootId: string,
  depthScale = 0.6
): Map<string, Vec2> {
  const nodeMap = new Map(nodes.map((n) => [n.id, n]));
  const positions = new Map<string, Vec2>();
  const sectors = new Map<string, [number, number]>(); // [angleMin, angleMax]

  positions.set(rootId, [0, 0]);
  // Start from top (-π/2) going clockwise for nicer visual layout
  sectors.set(rootId, [-Math.PI / 2, -Math.PI / 2 + 2 * Math.PI]);

  const queue: string[] = [rootId];

  while (queue.length > 0) {
    const nodeId = queue.shift()!;
    const node = nodeMap.get(nodeId);
    if (!node || node.children.length === 0) continue;

    const [sMin, sMax] = sectors.get(nodeId)!;
    const sectorSize = sMax - sMin;
    const n = node.children.length;

    node.children.forEach((childId, i) => {
      const childSMin = sMin + (i / n) * sectorSize;
      const childSMax = sMin + ((i + 1) / n) * sectorSize;
      sectors.set(childId, [childSMin, childSMax]);

      const theta = (childSMin + childSMax) / 2;
      const child = nodeMap.get(childId);
      if (!child) return;

      const r = Math.tanh(child.depth * depthScale);
      positions.set(childId, [r * Math.cos(theta), r * Math.sin(theta)]);
      queue.push(childId);
    });
  }

  return positions;
}

// ── SVG arc path for the geodesic between two Poincaré disk points ────────
// Geodesics are arcs of circles orthogonal to the boundary circle.
// For disk of radius R, orthogonality condition: |O|² = R² + r²
// This gives: ⟨O, p⟩ = (|p|² + R²) / 2 for any p on the arc.
// Coordinates are in SVG space (scaled by diskR, y increases downward).
export function geodesicArcPath(p1: Vec2, p2: Vec2, diskR: number): string {
  const [x1, y1] = [p1[0] * diskR, p1[1] * diskR];
  const [x2, y2] = [p2[0] * diskR, p2[1] * diskR];

  // Check for degeneracy: p1, p2, and origin are collinear
  // Cross product of vectors (p1) and (p2) = x1*y2 - y1*x2
  const cross = x1 * y2 - y1 * x2;
  if (Math.abs(cross) < 1e-6) {
    return `M ${x1.toFixed(3)} ${y1.toFixed(3)} L ${x2.toFixed(3)} ${y2.toFixed(3)}`;
  }

  // Perpendicular bisector of segment p1p2:
  // Midpoint M, direction perp ⊥ (p2 - p1)
  const mx = (x1 + x2) / 2;
  const my = (y1 + y2) / 2;
  const dx = x2 - x1;
  const dy = y2 - y1;
  const perpx = -dy;
  const perpy = dx;

  // O = M + t * perp, satisfying ⟨O, p1⟩ = (|p1|² + R²) / 2
  // (mx + t*perpx)*x1 + (my + t*perpy)*y1 = (x1² + y1² + R²) / 2
  const R2 = diskR * diskR;
  const dotMp1 = mx * x1 + my * y1;
  const dotPerpp1 = perpx * x1 + perpy * y1;
  // dotPerpp1 = 0 only when p1, p2, origin are collinear (handled above)
  const target = (x1 * x1 + y1 * y1 + R2) / 2;
  const t = (target - dotMp1) / dotPerpp1;

  const cx = mx + t * perpx;
  const cy = my + t * perpy;
  const r = Math.sqrt((x1 - cx) * (x1 - cx) + (y1 - cy) * (y1 - cy));

  // Sweep flag: determined by cross product (p1-O) × (p2-O) in SVG coords
  // In SVG (y down): cross > 0 → triangle (O,p1,p2) is CW → sweep = 1 (CW)
  //                  cross < 0 → CCW → sweep = 0 (CCW)
  const crossOp1p2 =
    (x1 - cx) * (y2 - cy) - (y1 - cy) * (x2 - cx);
  const sweep = crossOp1p2 > 0 ? 1 : 0;

  return (
    `M ${x1.toFixed(3)} ${y1.toFixed(3)} ` +
    `A ${r.toFixed(3)} ${r.toFixed(3)} 0 0 ${sweep} ` +
    `${x2.toFixed(3)} ${y2.toFixed(3)}`
  );
}

// ── BFS downward: returns subtree rooted at nodeId (inclusive) ───────────
export function getSubtree(
  nodeId: string,
  nodeMap: Map<string, EmbeddedNode>
): Set<string> {
  const result = new Set<string>();
  const queue = [nodeId];
  while (queue.length > 0) {
    const id = queue.shift()!;
    result.add(id);
    const node = nodeMap.get(id);
    if (node) node.children.forEach((childId) => queue.push(childId));
  }
  return result;
}

// ── Walk up parentId chain: returns all ancestors (not including nodeId) ──
export function getAncestors(
  nodeId: string,
  nodeMap: Map<string, EmbeddedNode>
): Set<string> {
  const result = new Set<string>();
  let current = nodeMap.get(nodeId);
  while (current && current.parentId) {
    result.add(current.parentId);
    current = nodeMap.get(current.parentId);
  }
  return result;
}

// ── LCA: walk up id1's ancestors, then walk up id2 until common node ──────
export function findLCA(
  id1: string,
  id2: string,
  nodeMap: Map<string, EmbeddedNode>
): EmbeddedNode | undefined {
  const ancestors1 = new Set<string>();
  let cur: EmbeddedNode | undefined = nodeMap.get(id1);
  while (cur) {
    ancestors1.add(cur.id);
    cur = cur.parentId ? nodeMap.get(cur.parentId) : undefined;
  }
  cur = nodeMap.get(id2);
  while (cur) {
    if (ancestors1.has(cur.id)) return cur;
    cur = cur.parentId ? nodeMap.get(cur.parentId) : undefined;
  }
  return undefined;
}

// ── Tree path distance = depth(u) + depth(v) − 2·depth(LCA) ──────────────
export function treePathDistance(
  id1: string,
  id2: string,
  nodeMap: Map<string, EmbeddedNode>
): number {
  const lca = findLCA(id1, id2, nodeMap);
  if (!lca) return -1;
  const n1 = nodeMap.get(id1)!;
  const n2 = nodeMap.get(id2)!;
  return n1.depth + n2.depth - 2 * lca.depth;
}

// ── Wu-Palmer similarity = 2·depth(LCA) / (depth(u) + depth(v)) ──────────
export function wuPalmerSimilarity(
  id1: string,
  id2: string,
  nodeMap: Map<string, EmbeddedNode>
): number {
  if (id1 === id2) return 1;
  const lca = findLCA(id1, id2, nodeMap);
  if (!lca) return 0;
  const n1 = nodeMap.get(id1)!;
  const n2 = nodeMap.get(id2)!;
  const denom = n1.depth + n2.depth;
  if (denom === 0) return 1;
  return (2 * lca.depth) / denom;
}
