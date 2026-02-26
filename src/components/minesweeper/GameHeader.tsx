import type { GameStatus } from './useGameState';

interface GameHeaderProps {
  minesLeft: number;
  time: number;
  bestTime: number | null;
  status: GameStatus;
  onReset: () => void;
}

const STATUS_EMOJI: Record<GameStatus, string> = {
  idle:    '🙂',
  playing: '😮',
  won:     '😎',
  lost:    '😵',
};

export default function GameHeader({ minesLeft, time, bestTime, status, onReset }: GameHeaderProps) {
  const displayTime = Math.min(time, 999);

  return (
    <div className="ms-header">
      <div className="ms-counter">{String(Math.max(minesLeft, 0)).padStart(3, '0')}</div>

      <button className="ms-reset-btn" onClick={onReset} title="New game">
        {STATUS_EMOJI[status]}
      </button>

      <div className="ms-timer-block">
        <span className="ms-counter">{String(displayTime).padStart(3, '0')}</span>
        {bestTime !== null && (
          <span className="ms-best">Best: {bestTime}s</span>
        )}
      </div>
    </div>
  );
}
