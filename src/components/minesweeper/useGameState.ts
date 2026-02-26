import { useState, useEffect, useCallback, useRef } from 'react';

export type CellState = {
  isMine: boolean;
  isRevealed: boolean;
  isFlagged: boolean;
  neighborCount: number;
};

export type GameStatus = 'idle' | 'playing' | 'won' | 'lost';
export type Difficulty = 'easy' | 'medium' | 'hard' | 'custom';

export type Config = { rows: number; cols: number; mines: number };

export const PRESETS: Record<Exclude<Difficulty, 'custom'>, Config> = {
  easy:   { rows: 9,  cols: 9,  mines: 10 },
  medium: { rows: 16, cols: 16, mines: 40 },
  hard:   { rows: 16, cols: 30, mines: 99 },
};

function createEmptyBoard(rows: number, cols: number): CellState[][] {
  return Array.from({ length: rows }, () =>
    Array.from({ length: cols }, () => ({
      isMine: false,
      isRevealed: false,
      isFlagged: false,
      neighborCount: 0,
    }))
  );
}

function placeMines(board: CellState[][], safeRow: number, safeCol: number, mineCount: number): CellState[][] {
  const rows = board.length;
  const cols = board[0].length;
  const newBoard = board.map(r => r.map(c => ({ ...c })));

  // Safe zone: first-click cell and its 8 neighbors
  const safeSet = new Set<string>();
  for (let dr = -1; dr <= 1; dr++) {
    for (let dc = -1; dc <= 1; dc++) {
      const nr = safeRow + dr;
      const nc = safeCol + dc;
      if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
        safeSet.add(`${nr},${nc}`);
      }
    }
  }

  let placed = 0;
  while (placed < mineCount) {
    const r = Math.floor(Math.random() * rows);
    const c = Math.floor(Math.random() * cols);
    if (!newBoard[r][c].isMine && !safeSet.has(`${r},${c}`)) {
      newBoard[r][c].isMine = true;
      placed++;
    }
  }
  return newBoard;
}

function calculateNeighbors(board: CellState[][]): CellState[][] {
  const rows = board.length;
  const cols = board[0].length;
  const newBoard = board.map(r => r.map(c => ({ ...c })));

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      if (newBoard[r][c].isMine) continue;
      let count = 0;
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
          if (dr === 0 && dc === 0) continue;
          const nr = r + dr;
          const nc = c + dc;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && newBoard[nr][nc].isMine) {
            count++;
          }
        }
      }
      newBoard[r][c].neighborCount = count;
    }
  }
  return newBoard;
}

function revealCells(board: CellState[][], startRow: number, startCol: number): CellState[][] {
  const rows = board.length;
  const cols = board[0].length;
  const newBoard = board.map(r => r.map(c => ({ ...c })));

  if (newBoard[startRow][startCol].isFlagged) return newBoard;
  if (newBoard[startRow][startCol].isRevealed) return newBoard;

  const queue: [number, number][] = [[startRow, startCol]];
  while (queue.length > 0) {
    const [r, c] = queue.shift()!;
    if (newBoard[r][c].isRevealed || newBoard[r][c].isFlagged) continue;
    newBoard[r][c].isRevealed = true;

    // Flood fill if zero neighbors
    if (newBoard[r][c].neighborCount === 0 && !newBoard[r][c].isMine) {
      for (let dr = -1; dr <= 1; dr++) {
        for (let dc = -1; dc <= 1; dc++) {
          if (dr === 0 && dc === 0) continue;
          const nr = r + dr;
          const nc = c + dc;
          if (nr >= 0 && nr < rows && nc >= 0 && nc < cols && !newBoard[nr][nc].isRevealed) {
            queue.push([nr, nc]);
          }
        }
      }
    }
  }
  return newBoard;
}

function checkWin(board: CellState[][]): boolean {
  for (const row of board) {
    for (const cell of row) {
      if (!cell.isMine && !cell.isRevealed) return false;
    }
  }
  return true;
}

function getBestKey(difficulty: Difficulty, config: Config): string {
  if (difficulty === 'custom') {
    return `minesweeper-best-custom-${config.rows}x${config.cols}x${config.mines}`;
  }
  return `minesweeper-best-${difficulty}`;
}

export function useGameState() {
  const [difficulty, setDifficulty] = useState<Difficulty>('easy');
  const [config, setConfig] = useState<Config>(PRESETS.easy);
  const [board, setBoard] = useState<CellState[][]>(() => createEmptyBoard(PRESETS.easy.rows, PRESETS.easy.cols));
  const [status, setStatus] = useState<GameStatus>('idle');
  const [minesLeft, setMinesLeft] = useState(PRESETS.easy.mines);
  const [time, setTime] = useState(0);
  const [bestTime, setBestTime] = useState<number | null>(null);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const firstClickRef = useRef(true);

  // Load best time when difficulty/config changes
  useEffect(() => {
    const key = getBestKey(difficulty, config);
    const stored = localStorage.getItem(key);
    setBestTime(stored ? parseInt(stored, 10) : null);
  }, [difficulty, config]);

  // Timer logic
  useEffect(() => {
    if (status === 'playing') {
      timerRef.current = setInterval(() => setTime(t => t + 1), 1000);
    } else {
      if (timerRef.current) {
        clearInterval(timerRef.current);
        timerRef.current = null;
      }
    }
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, [status]);

  const applyConfig = useCallback((diff: Difficulty, cfg: Config) => {
    setDifficulty(diff);
    setConfig(cfg);
    setBoard(createEmptyBoard(cfg.rows, cfg.cols));
    setStatus('idle');
    setMinesLeft(cfg.mines);
    setTime(0);
    firstClickRef.current = true;
  }, []);

  const changeDifficulty = useCallback((diff: Exclude<Difficulty, 'custom'>) => {
    applyConfig(diff, PRESETS[diff]);
  }, [applyConfig]);

  const setCustomConfig = useCallback((cfg: Config) => {
    applyConfig('custom', cfg);
  }, [applyConfig]);

  const resetGame = useCallback(() => {
    applyConfig(difficulty, config);
  }, [applyConfig, difficulty, config]);

  const revealCell = useCallback((row: number, col: number) => {
    if (status === 'won' || status === 'lost') return;

    setBoard(prev => {
      if (prev[row][col].isFlagged || prev[row][col].isRevealed) return prev;

      let currentBoard = prev;

      // First click: place mines and calculate neighbors
      if (firstClickRef.current) {
        firstClickRef.current = false;
        currentBoard = placeMines(prev, row, col, config.mines);
        currentBoard = calculateNeighbors(currentBoard);
        setStatus('playing');
      }

      if (currentBoard[row][col].isMine) {
        // Reveal all mines
        const lostBoard = currentBoard.map(r =>
          r.map(c => ({
            ...c,
            isRevealed: c.isMine ? true : c.isRevealed,
          }))
        );
        lostBoard[row][col] = { ...lostBoard[row][col], isRevealed: true };
        setStatus('lost');
        return lostBoard;
      }

      const revealed = revealCells(currentBoard, row, col);
      if (checkWin(revealed)) {
        setStatus('won');
        // Save best time
        const key = getBestKey(difficulty, config);
        setTime(t => {
          const stored = localStorage.getItem(key);
          const prev = stored ? parseInt(stored, 10) : Infinity;
          if (t < prev) {
            localStorage.setItem(key, String(t));
            setBestTime(t);
          }
          return t;
        });
      }
      return revealed;
    });
  }, [status, config, difficulty]);

  const toggleFlag = useCallback((row: number, col: number) => {
    if (status === 'won' || status === 'lost') return;
    if (status === 'idle') return;

    setBoard(prev => {
      const cell = prev[row][col];
      if (cell.isRevealed) return prev;

      const newBoard = prev.map(r => r.map(c => ({ ...c })));
      newBoard[row][col].isFlagged = !cell.isFlagged;
      setMinesLeft(m => m + (cell.isFlagged ? 1 : -1));
      return newBoard;
    });
  }, [status]);

  return {
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
  };
}
