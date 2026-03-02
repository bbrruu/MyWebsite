import { useMemo } from 'react';
import type { EmbeddedNode, SelectedIds } from './types';

interface Props {
  embeddedNodes: EmbeddedNode[];
  selectedIds: SelectedIds;
  lcaNode: EmbeddedNode | null;
  treePathDist: number | null;
  wuPalmerSim: number | null;
}

export function InfoPanel({ embeddedNodes, selectedIds, lcaNode, treePathDist, wuPalmerSim }: Props) {
  const nodeMap = useMemo(
    () => new Map(embeddedNodes.map((n) => [n.id, n])),
    [embeddedNodes]
  );

  const [id1, id2] = selectedIds;
  const node1 = id1 ? nodeMap.get(id1) : undefined;
  const node2 = id2 ? nodeMap.get(id2) : undefined;
  const bothSelected = node1 && node2;

  return (
    <div className="hb-info-panel">
      <div className="hb-info-title">節點資訊</div>

      {!node1 && !node2 && (
        <p className="hb-hint">Hover 節點以高亮層次；點擊兩個節點以計算語意距離</p>
      )}

      {node1 && (
        <div className="hb-info-node">
          <div className="hb-info-node-label">節點一</div>
          <div className="hb-node-name">{node1.label}</div>
          <div className="hb-info-row">
            <span className="hb-info-key">深度</span>
            <span>{node1.depth}</span>
          </div>
          <div className="hb-info-row">
            <span className="hb-info-key">子節點</span>
            <span>{node1.children.length}</span>
          </div>
          <div className="hb-info-row">
            <span className="hb-info-key">半徑</span>
            <span>{Math.sqrt(node1.px ** 2 + node1.py ** 2).toFixed(3)}</span>
          </div>
        </div>
      )}

      {node2 && (
        <div className="hb-info-node">
          <div className="hb-info-node-label">節點二</div>
          <div className="hb-node-name">{node2.label}</div>
          <div className="hb-info-row">
            <span className="hb-info-key">深度</span>
            <span>{node2.depth}</span>
          </div>
          <div className="hb-info-row">
            <span className="hb-info-key">子節點</span>
            <span>{node2.children.length}</span>
          </div>
          <div className="hb-info-row">
            <span className="hb-info-key">半徑</span>
            <span>{Math.sqrt(node2.px ** 2 + node2.py ** 2).toFixed(3)}</span>
          </div>
        </div>
      )}

      {bothSelected && treePathDist !== null && wuPalmerSim !== null && (
        <div className="hb-distance-block">
          <div className="hb-info-row hb-dist-row">
            <span className="hb-info-key">LCA（最近公共祖先）</span>
            <span className="hb-distance-value">{lcaNode ? lcaNode.label : '—'}</span>
          </div>
          <div className="hb-info-row hb-dist-row">
            <span className="hb-info-key">路徑距離</span>
            <span className="hb-distance-value">{treePathDist} hops</span>
          </div>
          <div className="hb-info-row hb-dist-row">
            <span className="hb-info-key">Wu-Palmer 相似度</span>
            <span className="hb-distance-value">{wuPalmerSim.toFixed(3)}</span>
          </div>
          <div className="hb-formula">wu_palmer(u,v) = 2·d(lca) / (d(u)+d(v))</div>
        </div>
      )}

      <div className="hb-hint-section">
        <p className="hb-hint">
          路徑越短 = 語意越近；Wu-Palmer 越接近 1 = 越相似（最大值：同一節點 = 1）
        </p>
        {node1 && !node2 && (
          <p className="hb-hint">點擊另一個節點以計算距離</p>
        )}
        {bothSelected && (
          <p className="hb-hint">再次點擊已選節點以取消選取</p>
        )}
      </div>
    </div>
  );
}
