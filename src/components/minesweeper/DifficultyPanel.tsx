import { useState } from 'react';
import type { Difficulty, Config } from './useGameState';
import { PRESETS } from './useGameState';

interface DifficultyPanelProps {
  current: Difficulty;
  onChangeDifficulty: (d: Exclude<Difficulty, 'custom'>) => void;
  onSetCustom: (config: Config) => void;
}

export default function DifficultyPanel({ current, onChangeDifficulty, onSetCustom }: DifficultyPanelProps) {
  const [showCustom, setShowCustom] = useState(false);
  const [rows, setRows] = useState('9');
  const [cols, setCols] = useState('9');
  const [mines, setMines] = useState('10');
  const [error, setError] = useState('');

  const handleCustomSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const r = parseInt(rows, 10);
    const c = parseInt(cols, 10);
    const m = parseInt(mines, 10);

    if (isNaN(r) || isNaN(c) || isNaN(m)) {
      setError('請輸入有效數字');
      return;
    }
    if (r < 2 || r > 30 || c < 2 || c > 50) {
      setError('行列數範圍：2-30 行，2-50 列');
      return;
    }
    if (m < 1 || m >= r * c) {
      setError(`地雷數必須在 1 到 ${r * c - 1} 之間`);
      return;
    }
    setError('');
    onSetCustom({ rows: r, cols: c, mines: m });
    setShowCustom(false);
  };

  return (
    <div className="ms-difficulty">
      <div className="ms-difficulty-btns">
        {(['easy', 'medium', 'hard'] as const).map(d => (
          <button
            key={d}
            className={`ms-diff-btn ${current === d ? 'active' : ''}`}
            onClick={() => { onChangeDifficulty(d); setShowCustom(false); }}
          >
            {d === 'easy' ? '初級' : d === 'medium' ? '中級' : '高級'}
            <span className="ms-diff-hint">
              {PRESETS[d].rows}×{PRESETS[d].cols} / {PRESETS[d].mines}雷
            </span>
          </button>
        ))}
        <button
          className={`ms-diff-btn ${current === 'custom' ? 'active' : ''}`}
          onClick={() => setShowCustom(s => !s)}
        >
          自訂
        </button>
      </div>

      {showCustom && (
        <form className="ms-custom-form" onSubmit={handleCustomSubmit}>
          <label>
            行數
            <input type="number" value={rows} min={2} max={30} onChange={e => setRows(e.target.value)} />
          </label>
          <label>
            列數
            <input type="number" value={cols} min={2} max={50} onChange={e => setCols(e.target.value)} />
          </label>
          <label>
            地雷數
            <input type="number" value={mines} min={1} onChange={e => setMines(e.target.value)} />
          </label>
          {error && <p className="ms-error">{error}</p>}
          <button type="submit" className="ms-apply-btn">套用</button>
        </form>
      )}
    </div>
  );
}
