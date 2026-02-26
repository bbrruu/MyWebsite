import Cell from './Cell';
import type { CellState, GameStatus } from './useGameState';

interface BoardProps {
  board: CellState[][];
  status: GameStatus;
  explodedCell: [number, number] | null;
  onReveal: (row: number, col: number) => void;
  onFlag: (row: number, col: number) => void;
}

export default function Board({ board, status, explodedCell, onReveal, onFlag }: BoardProps) {
  return (
    <div
      className="ms-board"
      style={{ '--cols': board[0]?.length ?? 9 } as React.CSSProperties}
    >
      {board.map((row, r) =>
        row.map((cell, c) => (
          <Cell
            key={`${r}-${c}`}
            cell={cell}
            row={r}
            col={c}
            isExploded={explodedCell?.[0] === r && explodedCell?.[1] === c}
            onReveal={onReveal}
            onFlag={onFlag}
          />
        ))
      )}
    </div>
  );
}
