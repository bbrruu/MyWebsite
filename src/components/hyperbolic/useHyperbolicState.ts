import { useState, useMemo, useCallback } from 'react';
import { wordNodes } from './wordnetData';
import {
  embedTree,
  getSubtree,
  getAncestors,
  findLCA,
  treePathDistance,
  wuPalmerSimilarity,
} from './hyperbolicMath';
import type { EmbeddedNode, SelectedIds } from './types';

export function useHyperbolicState() {
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [selectedIds, setSelectedIds] = useState<SelectedIds>([null, null]);

  // Compute embedded positions once (tree embedding is deterministic)
  const embeddedNodes = useMemo<EmbeddedNode[]>(() => {
    const positions = embedTree(wordNodes, 'entity');
    return wordNodes.map((node) => ({
      ...node,
      px: positions.get(node.id)?.[0] ?? 0,
      py: positions.get(node.id)?.[1] ?? 0,
    }));
  }, []);

  const nodeMap = useMemo(
    () => new Map(embeddedNodes.map((n) => [n.id, n])),
    [embeddedNodes]
  );

  // Highlighted set: full subtree + all ancestors of hovered node
  const highlightedSet = useMemo<Set<string>>(() => {
    if (!hoveredId) return new Set();
    const subtree = getSubtree(hoveredId, nodeMap);
    const ancestors = getAncestors(hoveredId, nodeMap);
    return new Set([...subtree, ...ancestors]);
  }, [hoveredId, nodeMap]);

  // Semantic distance metrics between the two selected nodes
  const lcaNode = useMemo<EmbeddedNode | null>(() => {
    const [id1, id2] = selectedIds;
    if (!id1 || !id2) return null;
    return findLCA(id1, id2, nodeMap) ?? null;
  }, [selectedIds, nodeMap]);

  const treePathDist = useMemo<number | null>(() => {
    const [id1, id2] = selectedIds;
    if (!id1 || !id2) return null;
    const d = treePathDistance(id1, id2, nodeMap);
    return d >= 0 ? d : null;
  }, [selectedIds, nodeMap]);

  const wuPalmerSim = useMemo<number | null>(() => {
    const [id1, id2] = selectedIds;
    if (!id1 || !id2) return null;
    return wuPalmerSimilarity(id1, id2, nodeMap);
  }, [selectedIds, nodeMap]);

  const handleHover = useCallback((id: string | null) => {
    setHoveredId(id);
  }, []);

  // Click logic:
  // - Click unselected node with empty slot → fill slot
  // - Click already-selected node → deselect it
  // - Click new node with both slots full → shift (remove first, add new)
  const handleSelect = useCallback((id: string) => {
    setSelectedIds((prev) => {
      const [id1, id2] = prev;
      if (id === id1) return [null, id2];
      if (id === id2) return [id1, null];
      if (!id1) return [id, id2];
      if (!id2) return [id1, id];
      return [id2, id]; // both full: cycle
    });
  }, []);

  return {
    embeddedNodes,
    hoveredId,
    selectedIds,
    highlightedSet,
    lcaNode,
    treePathDist,
    wuPalmerSim,
    handleHover,
    handleSelect,
  };
}
