import { useState, useEffect, useMemo, useCallback } from 'react';
import type { Member, Expense, Transaction, Step } from './types';
import { MEMBER_COLORS } from './types';

interface SplitState {
  members: Member[];
  expenses: Expense[];
  step: Step;
}

const STORAGE_KEY = 'split-state-v1';

function loadState(): SplitState {
  if (typeof window === 'undefined') return { members: [], expenses: [], step: 'members' };
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw) as SplitState;
  } catch {
    // ignore
  }
  return { members: [], expenses: [], step: 'members' };
}

function nanoid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

function computeSettlement(members: Member[], expenses: Expense[]): Transaction[] {
  const balance = new Map<string, number>();
  for (const m of members) balance.set(m.id, 0);

  for (const expense of expenses) {
    balance.set(expense.paidBy, (balance.get(expense.paidBy) ?? 0) + expense.totalAmount);
    for (const split of expense.splits) {
      balance.set(split.memberId, (balance.get(split.memberId) ?? 0) - split.amount);
    }
  }

  // Split into creditors (positive) and debtors (negative), sorted descending by absolute value
  const creditors: { id: string; amount: number }[] = [];
  const debtors: { id: string; amount: number }[] = [];
  for (const [id, bal] of balance.entries()) {
    const rounded = Math.round(bal * 100) / 100;
    if (rounded > 0.005) creditors.push({ id, amount: rounded });
    else if (rounded < -0.005) debtors.push({ id, amount: -rounded });
  }
  creditors.sort((a, b) => b.amount - a.amount);
  debtors.sort((a, b) => b.amount - a.amount);

  const transactions: Transaction[] = [];
  let ci = 0, di = 0;
  while (ci < creditors.length && di < debtors.length) {
    const c = creditors[ci];
    const d = debtors[di];
    const amt = Math.min(c.amount, d.amount);
    transactions.push({ from: d.id, to: c.id, amount: Math.round(amt * 100) / 100 });
    c.amount -= amt;
    d.amount -= amt;
    if (c.amount < 0.005) ci++;
    if (d.amount < 0.005) di++;
  }
  return transactions;
}

export function useSplitState() {
  const [state, setState] = useState<SplitState>(loadState);

  useEffect(() => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch {
      // ignore
    }
  }, [state]);

  const settlement = useMemo(
    () => computeSettlement(state.members, state.expenses),
    [state.members, state.expenses]
  );

  // Net balance per member: paid - owed
  const balances = useMemo(() => {
    const bal = new Map<string, number>();
    for (const m of state.members) bal.set(m.id, 0);
    for (const expense of state.expenses) {
      bal.set(expense.paidBy, (bal.get(expense.paidBy) ?? 0) + expense.totalAmount);
      for (const split of expense.splits) {
        bal.set(split.memberId, (bal.get(split.memberId) ?? 0) - split.amount);
      }
    }
    return bal;
  }, [state.members, state.expenses]);

  const addMember = useCallback((name: string) => {
    setState(prev => {
      const color = MEMBER_COLORS[prev.members.length % MEMBER_COLORS.length];
      return {
        ...prev,
        members: [...prev.members, { id: nanoid(), name: name.trim(), color }],
      };
    });
  }, []);

  const removeMember = useCallback((id: string) => {
    setState(prev => ({
      ...prev,
      members: prev.members.filter(m => m.id !== id),
      expenses: prev.expenses.filter(
        e => e.paidBy !== id && !e.splits.some(s => s.memberId === id)
      ),
    }));
  }, []);

  const addExpense = useCallback((expense: Omit<Expense, 'id'>) => {
    setState(prev => ({
      ...prev,
      expenses: [...prev.expenses, { ...expense, id: nanoid() }],
    }));
  }, []);

  const removeExpense = useCallback((id: string) => {
    setState(prev => ({
      ...prev,
      expenses: prev.expenses.filter(e => e.id !== id),
    }));
  }, []);

  const setStep = useCallback((step: Step) => {
    setState(prev => ({ ...prev, step }));
  }, []);

  const reset = useCallback(() => {
    const fresh: SplitState = { members: [], expenses: [], step: 'members' };
    setState(fresh);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(fresh));
    } catch {
      // ignore
    }
  }, []);

  return {
    members: state.members,
    expenses: state.expenses,
    step: state.step,
    settlement,
    balances,
    addMember,
    removeMember,
    addExpense,
    removeExpense,
    setStep,
    reset,
  };
}
