import { useState, useEffect } from 'react';
import { useHyperbolicState } from './useHyperbolicState';
import { DiskCanvas } from './DiskCanvas';
import { InfoPanel } from './InfoPanel';

export default function PoincareDisk() {
  const [diskR, setDiskR] = useState(320);
  const state = useHyperbolicState();

  useEffect(() => {
    function updateSize() {
      setDiskR(window.innerWidth <= 768 ? 180 : 320);
    }
    updateSize();
    window.addEventListener('resize', updateSize);
    return () => window.removeEventListener('resize', updateSize);
  }, []);

  return (
    <div className="hb-container">
      <DiskCanvas {...state} diskR={diskR} />
      <InfoPanel
        embeddedNodes={state.embeddedNodes}
        selectedIds={state.selectedIds}
        lcaNode={state.lcaNode}
        treePathDist={state.treePathDist}
        wuPalmerSim={state.wuPalmerSim}
      />
    </div>
  );
}
