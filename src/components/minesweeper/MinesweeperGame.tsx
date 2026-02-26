import { useState, useCallback } from 'react';
import { useGameState } from './useGameState';
import GameHeader from './GameHeader';
import DifficultyPanel from './DifficultyPanel';
import Board from './Board';
import type { Difficulty, Config } from './useGameState';

export default function MinesweeperGame() {
  const {
    board,
    status,
    minesLeft,
    time,
    bestTime,
    difficulty,
    config,
    revealCell,
    toggleFlag,
    resetGame,
    changeDifficulty,
    setCustomConfig,
  } = useGameState();

  const [explodedCell, setExplodedCell] = useState<[number, number] | null>(null);
  const [flagMode, setFlagMode] = useState(false);

  const handleReveal = useCallback((row: number, col: number) => {
    if (flagMode) {
      toggleFlag(row, col);
      return;
    }
    const cell = board[row][col];
    if (cell.isMine && !cell.isFlagged) {
      setExplodedCell([row, col]);
    }
    revealCell(row, col);
  }, [flagMode, board, revealCell, toggleFlag]);

  const handleReset = useCallback(() => {
    setExplodedCell(null);
    setFlagMode(false);
    resetGame();
  }, [resetGame]);

  const handleChangeDifficulty = useCallback((d: Exclude<Difficulty, 'custom'>) => {
    setExplodedCell(null);
    setFlagMode(false);
    changeDifficulty(d);
  }, [changeDifficulty]);

  const handleSetCustom = useCallback((cfg: Config) => {
    setExplodedCell(null);
    setFlagMode(false);
    setCustomConfig(cfg);
  }, [setCustomConfig]);

  return (
    <div className="ms-game">
      <DifficultyPanel
        current={difficulty}
        onChangeDifficulty={handleChangeDifficulty}
        onSetCustom={handleSetCustom}
      />

      <GameHeader
        minesLeft={minesLeft}
        time={time}
        bestTime={bestTime}
        status={status}
        onReset={handleReset}
      />

      {(status === 'won' || status === 'lost') && (
        <div className={`ms-status ${status}`}>
          {status === 'won'
            ? `YOU WIN! 🎉  ${time}s`
            : 'BOOM! 💥 YOU STEPPED ON A MINE'}
        </div>
      )}

      <div className="ms-flag-toggle">
        <button
          className={`ms-flag-btn ${flagMode ? 'active' : ''}`}
          onClick={() => setFlagMode(f => !f)}
        >
          🚩 {flagMode ? '插旗模式 ON' : '插旗模式 OFF'}
        </button>
        <span className="ms-flag-hint">（桌機右鍵插旗，手機長按插旗）</span>
      </div>

      <div className="ms-board-wrapper">
        <Board
          board={board}
          status={status}
          explodedCell={explodedCell}
          onReveal={handleReveal}
          onFlag={toggleFlag}
        />
      </div>
    </div>
  );
}
