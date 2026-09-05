import { useRef } from 'react';
import type { CellState } from './useGameState';

interface CellProps {
  cell: CellState;
  row: number;
  col: number;
  isExploded?: boolean;
  onReveal: (row: number, col: number) => void;
  onFlag: (row: number, col: number) => void;
}

// 冷色系數字：保留八個可辨識的色相，但降低彩度以配合全站霧色調。
// 這裡不套用 --accent 等 token：數字必須彼此可分辨，那是功能不是裝飾。
const NUMBER_COLORS: Record<number, string> = {
  1: '#4e8496',
  2: '#5d7a63',
  3: '#a2585c',
  4: '#5a5f8c',
  5: '#8a6a4a',
  6: '#3f7f85',
  7: '#141a1c',
  8: '#7d8f96',
};

export default function Cell({ cell, row, col, isExploded, onReveal, onFlag }: CellProps) {
  const longPressTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const touchMoved = useRef(false);

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    onFlag(row, col);
  };

  const handleClick = () => {
    onReveal(row, col);
  };

  const handleTouchStart = (e: React.TouchEvent) => {
    touchMoved.current = false;
    longPressTimer.current = setTimeout(() => {
      if (!touchMoved.current) {
        onFlag(row, col);
      }
    }, 500);
  };

  const handleTouchEnd = (e: React.TouchEvent) => {
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
    // If not a long press, treat as normal reveal
    if (!touchMoved.current) {
      e.preventDefault();
      onReveal(row, col);
    }
  };

  const handleTouchMove = (e: React.TouchEvent) => {
    touchMoved.current = true;
    if (longPressTimer.current) {
      clearTimeout(longPressTimer.current);
      longPressTimer.current = null;
    }
  };

  let content: string | null = null;
  let cellClass = 'ms-cell';

  if (cell.isRevealed) {
    cellClass += ' revealed';
    if (cell.isMine) {
      cellClass += isExploded ? ' exploded' : ' mine';
      content = '💣';
    } else if (cell.neighborCount > 0) {
      content = String(cell.neighborCount);
    }
  } else if (cell.isFlagged) {
    content = '🚩';
    cellClass += ' flagged';
  }

  const style: React.CSSProperties = {};
  if (cell.isRevealed && !cell.isMine && cell.neighborCount > 0) {
    style.color = NUMBER_COLORS[cell.neighborCount] ?? '#555';
  }

  return (
    <button
      className={cellClass}
      onClick={handleClick}
      onContextMenu={handleContextMenu}
      onTouchStart={handleTouchStart}
      onTouchEnd={handleTouchEnd}
      onTouchMove={handleTouchMove}
      style={style}
      aria-label={
        cell.isFlagged ? 'flagged' :
        cell.isRevealed ? (cell.isMine ? 'mine' : `${cell.neighborCount}`) :
        'hidden'
      }
    >
      {content}
    </button>
  );
}
